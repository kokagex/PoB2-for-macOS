# テキストレンダリング修正計画 V3（頂点バッファ検証）

**日付**: 2026-02-02 06:20
**状態**: Phase 3 - 計画立案完了
**前回の試行**: V2調査完了（テクスチャ更新タイミング仮説を否定）

---

## V1/V2からの学習

### V1の試行（失敗）
- **仮説**: テクスチャ更新タイミング問題（グリフラスタライズ直後 vs end_frame）
- **実装**: dirty flag パターン（end_frame で一括更新）
- **結果**: 視覚的結果に変化なし
- **原因**: タイミングエラー（描画コマンド送信後にテクスチャ更新）

### V2の調査（成功）
- **目的**: V1をロールバック + 詳細ログ調査
- **結果**: テクスチャ更新のタイミングは問題ではないことが判明
- **発見**: ログレベルではすべて正常、視覚レベルで異常 → レンダリングパイプラインの問題
- **学習**: 問題範囲を「テクスチャ更新」から「レンダリングパイプライン」に絞り込み

---

## 現状の観察（V2調査より）

### ログレベル: すべて正常 ✅

1. **グリフラスタライズ**: 80個のグリフがすべて正しくラスタライズ
   ```
   RASTERIZE: codepoint=V (U+0056) size=15x18 at atlas(0,0)
   RASTERIZE: codepoint=I (U+0049) size=11x18 at atlas(15,0)
   ```

2. **テクスチャ更新**: 各ラスタライズ直後に即座更新
   - フォント24px: テクスチャ 0x7fea69b13630
   - フォント16px: テクスチャ 0x7fea69d116e0

3. **フラッシュ**: テクスチャ切り替え時に正常動作
   ```
   DIAG-GLYPH-FLUSH: tex=0x7fea69b13630 count=198 vertices
   DIAG-GLYPH-FLUSH: tex=0x7fea69d116e0 count=288 vertices
   ```

4. **頂点数の検証**: 数学的に正しい
   - 198 vertices = 33グリフ × 6 vertices/glyph ✅
   - 288 vertices = 48グリフ × 6 vertices/glyph ✅

### 視覚レベル: 一部のみ表示 ❌

- 行95末尾: "below, the fix works!" （白） ✅ 表示
- 行109: "Image rendering: (ring.png below)" （緑） ✅ 表示
- 行94: "VISUAL TEST - Metal Fragment Shader Fix" （白） ❌ 非表示
- 行99: "Frame: %d" （黄色） ❌ 非表示
- 行100: "Text rendering: WORKING" （黄色） ❌ 非表示

### 重要な矛盾

**ログでは80個のグリフがすべて処理されているのに、視覚的には一部のテキストしか表示されない。**

→ 問題は**ログに記録されていない部分**にある

---

## V3の根本原因仮説

### 仮説: 頂点バッファの内容破損

**理由**:
1. ログレベル（グリフラスタライズ、テクスチャ更新、フラッシュ）はすべて正常
2. 視覚レベルで異常 → レンダリング時の問題
3. **頂点バッファの内容は V2調査でログ出力されていない**（唯一の未検証部分）

**具体的な問題の可能性**:

#### 可能性A: 頂点データの上書き
```cpp
// metal_draw_glyph() で頂点を追加
vertices[i] = { x, y, u, v, ... };

// しかし、バッファがフラッシュ前に上書きされる？
vertices[i] = { 0, 0, 0, 0, ... };  // ← データ破損
```

#### 可能性B: UV座標の誤り
```cpp
// 期待: u=0.5, v=0.3（グリフの正しい位置）
vertices[i].u = 0.5;
vertices[i].v = 0.3;

// 実際: u=0.0, v=0.0（テクスチャの左上隅）
vertices[i].u = 0.0;  // ← UV座標が間違っている
vertices[i].v = 0.0;
```

#### 可能性C: テクスチャポインタのミスマッチ
```cpp
// 追加時: texture A
add_vertex_with_texture(tex_A, ...);

// フラッシュ時: texture B が設定されている
setFragmentTexture(tex_B, 0);  // ← ミスマッチ
drawPrimitives(...);
```

---

## V3調査計画

### ステップ1: 頂点追加時のログ出力

**修正ファイル**: `simplegraphic/src/backend/metal/metal_backend.mm`

**metal_draw_glyph() 関数**:
```cpp
void metal_draw_glyph(...) {
    // 既存コード: 頂点をバッファに追加
    SGMetalTextVertex* v = &metal->textVertices[metal->textVertexCount];
    v[0] = { ... };  // 6頂点を追加
    v[1] = { ... };
    ...

    // 新規追加: ログ出力
    printf("VERTEX-ADD: glyph=%c count=%d tex=%p u0=%.3f v0=%.3f u1=%.3f v1=%.3f\n",
           (char)codepoint,
           metal->textVertexCount,
           (void*)metal->currentTextTexture,
           v[0].u, v[0].v, v[2].u, v[2].v);

    metal->textVertexCount += 6;
}
```

**期待される出力**:
```
VERTEX-ADD: glyph=V count=0 tex=0x7fea69b13630 u0=0.125 v0=0.250 u1=0.375 v1=0.500
VERTEX-ADD: glyph=I count=6 tex=0x7fea69b13630 u0=0.500 v0=0.250 u1=0.625 v1=0.500
```

### ステップ2: フラッシュ時のログ出力

**flush_text_batch() 関数**:
```cpp
void flush_text_batch() {
    if (metal->textVertexCount == 0) return;

    // 新規追加: 最初と最後の頂点をログ出力
    SGMetalTextVertex* first = &metal->textVertices[0];
    SGMetalTextVertex* last = &metal->textVertices[metal->textVertexCount - 1];

    printf("VERTEX-FLUSH: count=%d tex=%p first_uv=(%.3f,%.3f) last_uv=(%.3f,%.3f)\n",
           metal->textVertexCount,
           (void*)metal->currentTextTexture,
           first->u, first->v,
           last->u, last->v);

    // 既存コード: GPU に送信
    [renderEncoder drawPrimitives:...];

    metal->textVertexCount = 0;
}
```

**期待される出力**:
```
VERTEX-FLUSH: count=198 tex=0x7fea69b13630 first_uv=(0.125,0.250) last_uv=(0.625,0.500)
```

### ステップ3: ビルド・デプロイ・テスト

1. クリーンビルド
   ```bash
   cd simplegraphic
   rm -rf build
   cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
   make -C build
   ```

2. デプロイ
   ```bash
   cp simplegraphic/build/libSimpleGraphic.dylib runtime/
   cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
   ```

3. テスト実行
   ```bash
   luajit visual_test.lua 2>&1 | tee v3_vertex_log.txt
   ```

### ステップ4: ログ分析

**比較ポイント**:

1. **VERTEX-ADD と VERTEX-FLUSH の整合性**
   - 追加された頂点のUV座標
   - フラッシュ時の頂点のUV座標
   - → 一致していなければ、バッファが破損している

2. **テクスチャポインタの一貫性**
   - VERTEX-ADD 時のテクスチャ
   - VERTEX-FLUSH 時のテクスチャ
   - → 異なっていれば、テクスチャミスマッチ

3. **頂点数の検証**
   - VERTEX-ADD の累積数
   - VERTEX-FLUSH のcount
   - → 一致しない場合、バッファオーバーフローまたはカウントエラー

**期待される発見**:
- ケースA: UV座標が (0.0, 0.0) になっている → UV計算エラー
- ケースB: テクスチャポインタが異なる → テクスチャバインディングエラー
- ケースC: 頂点数が一致しない → バッファ管理エラー

---

## タイムライン

- **ステップ1**: ログ追加（10分）
  - metal_draw_glyph() 修正: 5分
  - flush_text_batch() 修正: 5分

- **ステップ2**: ビルド・デプロイ（5分）
  - クリーンビルド: 3分
  - デプロイ: 2分

- **ステップ3**: テスト・ログ収集（5分）
  - visual_test.lua 実行: 3分
  - ログ保存: 2分

- **ステップ4**: ログ分析（10分）
  - VERTEX-ADD/FLUSH 比較: 5分
  - 根本原因特定: 5分

**合計**: 30分

---

## 成功基準

1. ✅ 頂点追加時とフラッシュ時のログが出力される
2. ✅ VERTEX-ADD と VERTEX-FLUSH の整合性を検証できる
3. ✅ 頂点データの破損、UV座標誤り、またはテクスチャミスマッチを特定できる
4. ✅ 根本原因が明確になる

---

## リスク評価

### 技術的リスク: 低

- ✅ ログ追加のみ（読み取り専用、既存動作に影響なし）
- ✅ ビルド・デプロイは V2 で検証済み
- ✅ 既存コードの変更なし

### 調査失敗リスク: 低-中

- ✅ V2 で問題範囲を「レンダリングパイプライン」に絞り込み済み
- ✅ 頂点バッファは唯一の未検証部分
- ⚠️ 頂点バッファが正常な場合、シェーダーまたは他の部分を調査する必要

### タイムライン遵守: 高

- ✅ 30分のタイムボックス
- ✅ V2 で同様のプロセスを30分で完了した実績

---

## ロールバック手順

V3 調査後、元に戻す場合:

```bash
# ログ出力を削除
git checkout simplegraphic/src/backend/metal/metal_backend.mm

# 再ビルド
cd simplegraphic && make -C build && cp build/libSimpleGraphic.dylib runtime/
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

**所要時間**: 5分

---

**状態**: Phase 3 完了 - Phase 4（レビュー）に進む
