# テキストレンダリング修正計画 V2（修正版）

**日付**: 2026-02-02 00:25
**状態**: Phase 3 - 計画立案中
**前回の試行**: Dirty flag実装（失敗 - タイミングエラー）

---

## 前回の失敗からの学習

**V1で試みた修正**: グリフラスタライズ時にdirty flagをセット、end_frame()でテクスチャ一括更新

**失敗の原因**: タイミングエラー
```
1. DrawString() → グリフラスタライズ → dirty = 1
2. draw_glyph() → GPU描画コマンド送信（テクスチャは空）
3. end_frame() → テクスチャ更新（遅すぎる！）
```

**視覚的結果**: 修正前と完全に同じ（効果なし）

---

## 新しい根本原因分析

### 観察された症状（再確認）

**表示されるもの:**
- 行95の末尾: "below, the fix works!" （白）
- 行109: "Image rendering: (ring.png below)" （緑）

**表示されないもの:**
- 行94: "VISUAL TEST - Metal Fragment Shader Fix" （白）
- 行99: "Frame: %d" （黄色）
- 行100: "Text rendering: WORKING" （黄色）
- Ring.png画像（白い円の明滅のみ）

### 重要なパターン

1. **同じ色でも一部は表示、一部は非表示**
   - 白: 行94は非表示、行95の一部は表示
   - これは色の問題ではない

2. **文字列の後半のみ表示**
   - 行95: "If you can see this text AND the image **below, the fix works!**"
   - 表示されているのは末尾のみ

3. **最後に描画されたものは表示される**
   - 行109（最後のDrawString）は完全に表示
   - 最初の方のDrawStringは表示されない

### 真の根本原因（修正版）

**仮説: グリフアトラスが初回フレームで正しく初期化されていない**

**詳細分析:**

1. **初回フレームの流れ:**
```
フレーム1:
  ProcessEvents()
  DrawString(行94) → グリフA,B,C... をラスタライズ → atlas->dirty = 1
    → draw_glyph() 呼び出し → 頂点バッファに追加
  DrawString(行95) → グリフD,E,F... をラスタライズ → atlas->dirty = 1
    → draw_glyph() 呼び出し → 頂点バッファに追加
  ...
  DrawString(行109) → グリフX,Y,Z をラスタライズ → atlas->dirty = 1
    → draw_glyph() 呼び出し → 頂点バッファに追加
  end_frame():
    flush_batches() → GPUに描画コマンド送信
    sg_flush_dirty_atlases() → テクスチャ更新 ← 遅すぎる！
    endEncoding()
    present()
```

2. **問題点:**
   - グリフがラスタライズされ、描画コマンドが送信される
   - しかし、テクスチャ更新は描画コマンドの**後**
   - GPUは空のテクスチャから描画しようとする → 何も表示されない

3. **なぜ一部のテキストは表示されるのか？**
   - フレーム2以降は、前フレームでアトラスが更新されている
   - しかし、フレーム1で描画されなかった文字は、フレーム2では再描画されない
   - visual_test.luaは静的テキストなので、フレーム1のみ描画
   - **待って、これは間違い。visual_test.luaは毎フレーム描画している！**

4. **再分析が必要:**

実際には、visual_test.luaを見ると、**毎フレーム**DrawStringが呼ばれています：
```lua
while sg.IsUserTerminated() == 0 do
    sg.ProcessEvents()
    sg.DrawString(...) -- 毎フレーム呼ばれる
    ...
end
```

ということは、フレーム2以降は：
- グリフはすでにアトラスにある（キャッシュヒット）
- テクスチャも前フレームで更新済み
- **なのになぜ表示されない？**

**新しい仮説: グリフはアトラスに追加されているが、テクスチャが更新されていない**

待って、私の実装を見直すと：
```cpp
// sg_rasterize_glyph() - 修正後
atlas->dirty = 1;  // テクスチャ更新はend_frame()まで遅延
```

これは、**最初のフレーム**で：
1. すべてのグリフがアトラスにラスタライズされる
2. dirty = 1 になる
3. end_frame()でテクスチャが更新される

**2フレーム目以降**では：
1. グリフはキャッシュにヒット（sg_find_glyph()が成功）
2. sg_rasterize_glyph()は呼ばれない
3. dirty = 0 のまま
4. テクスチャは更新されない

**しかし、1フレーム目でテクスチャは更新されたはず！**

もう一度実装を確認：
```cpp
void sg_flush_dirty_atlases() {
    SGFontFace* font = g_ctx->font_cache;
    while (font) {
        if (font->atlas && font->atlas->dirty) {
            // RGBA変換
            // update_texture()
            font->atlas->dirty = 0;  // クリア
        }
        font = font->next;
    }
}
```

これは正しく見える。1フレーム目にテクスチャが更新されるはず。

**では、なぜ表示されないのか？**

もう一度タイミングを考える：

```
フレーム1:
  begin_frame() → renderEncoderを作成
  DrawString(...) → グリフラスタライズ → draw_glyph() → 頂点追加
  DrawString(...) → グリフラスタライズ → draw_glyph() → 頂点追加
  end_frame():
    flush_batches() → [renderEncoder drawPrimitives] ← GPUコマンド送信
    sg_flush_dirty_atlases() → update_texture() ← テクスチャ更新
    [renderEncoder endEncoding]
    present()
```

**問題**: GPUコマンド送信時、テクスチャはまだ古い（空）。
テクスチャ更新は描画コマンドの後なので、効果がない。

**解決策**: テクスチャ更新を描画コマンドの**前**に移動する。

---

## 提案する修正（Option A: begin_frame直後にフラッシュ）

### 戦略

end_frame()でフラッシュするのではなく、**begin_frame()直後**にフラッシュする。

### 理由

```
フレーム1:
  begin_frame() → renderEncoderを作成
  sg_flush_dirty_atlases() → テクスチャ更新 ← 最初に実行
  DrawString(...) → グリフラスタライズ → draw_glyph() → 頂点追加（テクスチャは最新）
  end_frame():
    flush_batches() → [renderEncoder drawPrimitives] ← 正しいテクスチャで描画
    [renderEncoder endEncoding]
    present()

フレーム2:
  begin_frame()
  sg_flush_dirty_atlases() → dirty=0なのでスキップ
  DrawString(...) → キャッシュヒット → draw_glyph() → 頂点追加
  end_frame():
    flush_batches() → 描画
```

これで、テクスチャは描画前に更新される。

**しかし、問題がある:**
- フレーム1では、begin_frame()時点でまだグリフがラスタライズされていない
- dirty=0なので、フラッシュされない
- その後グリフがラスタライズされ、dirty=1になる
- しかし、描画時にはまだテクスチャが更新されていない

**これも失敗する。**

---

## 提案する修正（Option B: 即座更新に戻す）

### 戦略

V1の実装（dirty flag）を**ロールバック**し、元の実装（即座更新）に戻す。

### 理由

元の実装は、グリフラスタライズ直後にテクスチャを更新していた：
```cpp
// sg_rasterize_glyph() - 元の実装
// グリフをアトラスにコピー
// ...
// テクスチャを即座に更新
ctx->renderer->update_texture(atlas->texture, rgba_buffer);
```

これなら、draw_glyph()呼び出し前にテクスチャが更新される。

**しかし、これでも問題が解決しない可能性:**
- 元の実装でも同じ症状が出ていた
- つまり、テクスチャ更新のタイミングが問題ではない可能性

---

## 提案する修正（Option C: 本当の原因を調査）

### 戦略

視覚的症状を再分析し、本当の原因を特定する。

### 新しい調査方向

1. **なぜ一部のテキストだけ表示されるのか？**
   - 行95の末尾と行109が表示される
   - 共通点: どちらも後半に描画される

2. **可能性: バッファオーバーフロー**
   - 頂点バッファのサイズ制限？
   - 最初の方の頂点が上書きされている？

3. **可能性: テクスチャレイヤーの問題**
   - グリフアトラスと通常テクスチャが混在
   - レイヤーインデックスが間違っている？

4. **可能性: 描画順序の問題**
   - 最後に描画されたものだけ表示される
   - フラッシュタイミングの問題？

### 次のステップ

ロールバックして、**ログ出力を追加**して調査する：
1. 各DrawStringでどのグリフがラスタライズされたか
2. 各draw_glyph()でどのテクスチャが使用されたか
3. 各フラッシュでどれだけの頂点が描画されたか

---

## 実装プラン（Option B: ロールバック + 調査）

### ステップ1: V1の実装をロールバック

**元に戻すファイル:**
1. `sg_internal.h` - dirtyフィールドを削除
2. `sg_text.cpp` - sg_rasterize_glyph()を元の実装に戻す、sg_flush_dirty_atlases()を削除
3. `metal_backend.mm` - sg_flush_dirty_atlases()の呼び出しを削除

### ステップ2: 詳細なログ出力を追加

**sg_text.cpp の sg_rasterize_glyph():**
```cpp
printf("RASTERIZE: codepoint=%c (U+%04X) at atlas(%d,%d)\n",
       (codepoint < 128 ? codepoint : '?'), codepoint,
       atlas->current_x, atlas->current_y);
```

**sg_text.cpp の DrawString():**
```cpp
printf("DRAWSTRING: '%s' (first 20 chars)\n", text);
```

### ステップ3: visual_test.luaを実行し、ログを分析

- どのグリフがラスタライズされたか確認
- どのテキストが描画されたか確認
- パターンを特定

### ステップ4: ログに基づいて新しい仮説を立てる

---

## タイムライン

- ステップ1: ロールバック（5分）
- ステップ2: ログ追加（5分）
- ステップ3: ビルド&テスト（7分）
- ステップ4: ログ分析&新仮説（10分）
- **合計: 約27分**

---

## 成功基準

1. ✅ 元の実装に正しくロールバックできた
2. ✅ 詳細なログが出力される
3. ✅ ログから問題のパターンを特定できる
4. ✅ 新しい仮説を立てられる

---

**状態**: Phase 3 完了 - Phase 4（レビュー）に進む
