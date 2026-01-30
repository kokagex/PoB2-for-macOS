# Metal描画修復 - 詳細分析レポート

**報告日時**: 2026-01-31
**プロジェクト**: PRJ-003 pob2macos Metal描画修復
**分析対象**: DrawString (正常) vs DrawImage (不動作)

## 実行結果

### 現状確認
- ✅ **DrawString**: テキスト描画が正常に動作
- ❌ **DrawImage**: 画像描画が完全に不動作
- ⚠️ **テスト用赤矩形**: begin_frameで描画試行があるが表示されず

---

## 主要な問題発見

### 【重大問題1】Draw Strategyの根本的な違い

#### DrawString (metal_draw_glyph) - 正常動作パターン
```cpp
// 558行目: インデックスの更新を追跡
NSUInteger idx = metal->textVertexCount;  // ← 現在のカウントから開始

// 617行目: 6頂点を追加
metal->textVertexCount += 6;

// metal_end_frame()で一括描画
if (metal->textVertexCount > 0 && metal->currentAtlasTexture) {
    [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:0
                              vertexCount:metal->textVertexCount];  // ← ALL batched
    metal->textVertexCount = 0;
}
```

**特徴**: バッチ処理
- 複数のグリフを頂点バッファに蓄積
- フレーム終了時に一括描画
- `metal->currentAtlasTexture`で同じテクスチャのバッチを保持
- テクスチャが変わったら自動フラッシュ

---

#### DrawImage (metal_draw_image) - 不動作パターン
```cpp
// 711行目: 常にインデックス0に上書き
NSUInteger idx = 0;  // ← 每回リセット！

// 6頂点を書き込み...

// 772-778行目: 即座に描画
[metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];  // ← 即座実行
```

**問題**: 頂点バッファの上書き
- **毎呼び出しで`idx=0`にリセット** → 前のデータが上書きされる
- テクスチャ切り替え時に複雑なロジック（647-657行目）
- 即座描画によるバッチ効率の低下

---

### 【重大問題2】テクスチャの扱いの不一貫性

#### 647-657行目の問題コード
```cpp
if (metal->textVertexCount > 0 && metal->currentAtlasTexture) {
    // テキストのバッチをフラッシュ
    [metal->renderEncoder setFragmentTexture:metal->currentAtlasTexture atIndex:0];
    [metal->renderEncoder drawPrimitives...];
    metal->textVertexCount = 0;
    metal->currentAtlasTexture = nil;  // ← nilにリセット
}
```

**結果**:
- DrawStringの最後のグリフ後、`currentAtlasTexture = nil`
- 次のDrawImage呼び出しで、フラッシュロジックがスキップされる可能性
- テクスチャの切り替え管理が不適切

---

### 【重大問題3】ダミーテクスチャの不適切な使用

#### 636-642行目
```cpp
id<MTLTexture> texture = metal->dummyWhiteTexture;  // ← デフォルト
bool usingDummyTexture = true;
if (handle && handle->texture) {
    texture = (__bridge id<MTLTexture>)handle->texture;
    usingDummyTexture = false;
}
```

**問題**:
- ダミーテクスチャ（1x1白）は初期化時に生成されるか不明
- dummyWhiteTextureが未初期化の可能性
- nullハンドルの場合、デフォルトで白いテクスチャを使うべきだが、未実装の可能性

---

### 【重大問題4】テスト用赤矩形が表示されない理由

#### 350-378行目のコード分析
```cpp
// begin_frameで描画を試みている
testVerts[0].position = {-1.0f, 1.0f};  // 左上
testVerts[1].position = {-1.0f, -1.0f}; // 左下
testVerts[2].position = {1.0f, -1.0f};  // 右下
// ... (正しいNDC座標)

[metal->renderEncoder setFragmentTexture:metal->dummyWhiteTexture atIndex:0];
[metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
```

**推測される原因**:
1. `metal->dummyWhiteTexture`が未初期化 → 無効なテクスチャハンドル
2. シェーダがフラグメント出力を生成しない
3. 描画状態（ブレンディング、深度テスト）が不正
4. render encodeの初期化が不完全

---

## Windows版との比較（推測）

### OpenGL実装の特性
- **即座描画が一般的**: OpenGLではバッチ処理より即座描画が普通
- **テクスチャ管理**: 各DrawImageで異なるテクスチャを使用可能
- **頂点バッファ**: 毎回の上書きが許容される（GLはその後をメモリに同期）

### Metal実装の課題
- **バッファメモリ管理**: Metal独自の制約がある
- **パイプライン状態**: より明示的な状態管理が必要
- **テクスチャサンプリング**: 明示的なサンプラー設定必須

---

## DrawStringが動く理由の分析

1. **テクスチャが統一**: 同じグリフアトラステクスチャを使用継続
2. **バッチ処理**: 複数グリフを蓄積してから描画
3. **`currentAtlasTexture`管理**: テクスチャの切り替え時のみフラッシュ
4. **メモリアクセス**: 頂点バッファのまとまった書き込み と読み込み

---

## DrawImageが動かない理由のまとめ

### 最小根本原因（Critical Path）:
1. **頂点バッファの毎回上書き** (idx=0)
   - 描画コマンドが発行される直前に頂点データを書き込み
   - Metal GPUがデータを読む前に上書きされる可能性
   - CPU-GPU同期の問題

2. **ダミーテクスチャの未初期化**
   - 描画パイプラインにnullテクスチャが渡される可能性
   - 完全な描画失敗につながる

3. **フラッシュロジックの複雑性**
   - テクスチャの状態管理が曖昧
   - 前のDrawStringの状態が残存

---

## 推奨される修正戦略（優先順）

### フェーズ1: 基本的な動作確認
1. ダミーテクスチャの初期化確認
2. テスト用赤矩形の表示確認
3. 最小限のDrawImage呼び出し

### フェーズ2: メモリ同期
1. 頂点バッファのメモリ同期メカニズム
   - `[metal->textVertexBuffer didModifyRange:]`追加
   - または、静的頂点バッファの実装
2. GPU完了待機の確認

### フェーズ3: バッチ処理への統一
1. DrawImageもバッチキューに追加
2. テクスチャごとのバッチ分割
3. フレーム終了時の一括描画

### フェーズ4: テクスチャ管理
1. テクスチャハンドルの有効性確認
2. テクスチャキャッシュの実装
3. ダミーテクスチャの適切な使用

---

## ログ分析結果

### パターン確認
```
DEBUG: Metal presenting drawable #0,1,2,...2600+
DEBUG: [Frame X] metal_draw_image #1-5 - handle=..., pos=..., NDC=...
```

**結論**:
- Metalの初期化自体は成功
- 描画コマンドは発行されている
- しかし**GPU側で描画が実行されていない**可能性が高い

---

## 次のステップ

### Task #2の入力
- ダミーテクスチャが実装されているか確認
- `dummyWhiteTexture`の初期化コード検索

### Task #3の入力
- 頂点バッファのメモリ同期メカニズム検証
- Metal command encoderの完全な状態確認
- フラグメントシェーダの出力検証

### Task #4の入力
- `idx = metal->textVertexCount`への変更 (DrawImageで)
- または完全なバッチ統合
- ダミーテクスチャの生成と初期化

---

## 参考情報

### ファイル位置
- Metal実装: `/Users/kokage/national-operations/pob2macos/simplegraphic/src/backend/metal/metal_backend.mm`
- DrawString: Line 535-618 (metal_draw_glyph)
- DrawImage: Line 620-779 (metal_draw_image)
- テスト描画: Line 350-378 (metal_begin_frame)

### キー関数
- `metal_draw_glyph()`: テキスト描画 (正常)
- `metal_draw_image()`: 画像描画 (不動作)
- `metal_begin_frame()`: フレーム初期化
- `metal_end_frame()`: バッチフラッシュ + プレゼント

