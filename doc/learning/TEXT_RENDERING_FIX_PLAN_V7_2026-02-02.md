# テキストレンダリング修正計画 V7: Debug Mod C - テクスチャ可視化

**日付**: 2026-02-02 19:10
**状態**: Phase 3 - 計画立案
**前提**: 戦略A成功、Fragment Shader デバッグ環境確立

---

## 状況の総括

### 戦略A（V6改善版）の成功

**視覚的結果**: 全てマゼンタ（紫色）表示 ✅

**証明されたこと**:
1. ✅ V4/V4.1の失敗原因（シェーダーキャッシュ）を解決
2. ✅ Fragment Shader更新が確実に反映される
3. ✅ Debug Modが完全に機能する

**スクリーンショット**: `/Users/kokage/Desktop/スクリーンショット 2026-02-02 19.06.08.png`

### Progressive Elimination の最終状況

```
✅ CPU Layer (Lua DrawString, グリフラスタライズ, テクスチャ更新)
✅ GPU Vertex Layer (頂点バッファ, UV座標)
🔍 GPU Fragment Shader Layer (デバッグ環境確立、詳細調査可能)
```

---

## V7の目的: テクスチャサンプリング結果の可視化

### 根本原因の候補

**仮説1: テクスチャアルファチャンネル問題**（最も可能性高い）
- V2 ログ分析: グリフラスタライズ正常
- V3 ログ分析: 頂点バッファ正常
- しかし視覚的には一部テキストのみ表示
- 可能性: アルファチャンネルが0または間違った位置

**仮説2: RGBAマッピング問題**
- sg_text.cpp でグレースケール→RGBAの変換
- Stage 2で修正済みだが、完全検証していない
- 可能性: RGB/アルファの配置が間違っている

**仮説3: 頂点カラー問題**
- Fragment Shader: `texColor * in.color`
- 頂点カラーが0または間違った値
- 可能性: CPU層での SetDrawColor() が反映されていない

### Debug Mod C の戦略

**アプローチ**: **生のテクスチャ色を返す**（頂点カラー乗算なし）

```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    // DEBUG MOD C: Visualize raw texture sampling results
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));

    // Return raw texture RGBA (no vertex color multiplication)
    return texColor;
}
```

**理由**:
- 頂点カラー（`in.color`）の影響を排除
- テクスチャ自体が正しいかを直接確認
- 最もシンプルな検証方法

---

## V7 実装プラン

### ステップ1: Debug Mod C 実装（Artisan、3分）

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
**行**: 112-117

**修正内容**: Debug Mod B → Debug Mod C
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    // DEBUG MOD C: Visualize raw texture sampling results
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));
    return texColor;  // Raw texture, no vertex color multiplication
}
```

**重要**: 戦略Aで学習したとおり、Clean Rebuild が必須

**タイムボックス**: 3分

---

### ステップ2: Clean Rebuild + デプロイ（Artisan、3分）

**手順**:
```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
rm -rf build/
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build

# タイムスタンプ確認
ls -lh build/libSimpleGraphic.dylib
date

# デプロイ
cp build/libSimpleGraphic.dylib ../runtime/SimpleGraphic.dylib
ls -lh ../runtime/SimpleGraphic.dylib
```

**検証**: タイムスタンプが現在時刻と一致することを確認

**タイムボックス**: 3分

---

### ステップ3: 視覚的検証（Paladin、2分）

**実行**:
```bash
cd /Users/kokage/national-operations/pob2macos/dev
luajit visual_test.lua
```

**期待される結果と判定**:

#### ケースA: 白色のテキストが表示 ✅
- **意味**: テクスチャRGBA正常、アルファチャンネル正常
- **根本原因**: 問題は頂点カラー（`in.color`）または乗算処理
- **次ステップ**: 頂点カラーの検証（Debug Mod D）

#### ケースB: テキストが不可視または黒色 ❌
- **意味**: アルファチャンネルが0、または間違った位置
- **根本原因**: RGBAマッピング問題（sg_text.cpp）
- **次ステップ**: sg_text.cpp のRGBA変換コードを修正

#### ケースC: テキストが赤色/緑色/青色のいずれか ⚠️
- **意味**: RGBチャンネルの順序問題
- **根本原因**: テクスチャフォーマット不一致（RGBA vs BGRA）
- **次ステップ**: テクスチャフォーマット設定の修正

#### ケースD: テキストが半透明/グレー ⚠️
- **意味**: RGB値が低い、またはアルファが中間値
- **根本原因**: グレースケール→RGBA変換の値問題
- **次ステップ**: sg_text.cpp の変換式を修正

#### ケースE: まだマゼンタ ❌
- **意味**: Debug Mod C が反映されていない（あり得ない）
- **次ステップ**: Clean Rebuild 再実行

**スクリーンショット必須**: デスクトップに保存

**タイムボックス**: 2分

---

## タイムライン

- ステップ1: Debug Mod C 実装（3分）
- ステップ2: Clean Rebuild + デプロイ（3分）
- ステップ3: 視覚的検証（2分）
- **合計: 約8分**

---

## リスク評価

### リスク1: Clean Rebuild 失敗

**影響**: LOW
**確率**: LOW（戦略Aで成功実績あり）
**対策**: ビルドログ確認、CMake設定確認

### リスク2: テクスチャサンプリング失敗

**影響**: MEDIUM
**確率**: LOW（V2/V3でテクスチャ更新・頂点データ確認済み）
**対策**: ケースA-Eの条件分岐で対応

### リスク3: 視覚的結果が予期しない

**影響**: MEDIUM
**確率**: MEDIUM（新しいデバッグモード）
**対策**: 5つのケースで分類、次ステップ明確化

---

## 成功基準

### V7 成功基準

1. ✅ Debug Mod C 実装完了
2. ✅ Clean Rebuild + デプロイ完了（タイムスタンプ確認）
3. ✅ 視覚的結果がケースA-Eのいずれかに分類可能
4. ✅ 次ステップが明確（ケースに応じた方針決定）

### 最終成功基準（V7以降）

1. ✅ パッシブツリーが正しく表示される
2. ✅ すべてのテキストが正しく表示される
3. ✅ 画像が正しく表示される
4. ✅ ユーザー確認済み

---

## CRITICAL LESSONS の適用

### ルール1: ログは参考、視覚的結果が真実

**適用**:
- ビルドログではなく、視覚的結果で判定
- スクリーンショット必須

### ルール2: すべての実装後、必ず視覚的検証（15分以内）

**適用**:
- V7 タイムライン: 8分
- ステップ3 で必ず視覚的検証

### ルール3: Occam's Razor - 最もシンプルな説明

**適用**:
- Debug Mod C: 生のテクスチャ色を返すだけ（最もシンプル）
- 複雑な条件分岐なし

### Clean Rebuild は Build Cache を無視する

**適用**:
- ステップ2で `rm -rf build/` → Clean Rebuild
- 戦略Aで学習した手順を厳守

### Progressive Elimination の継続

**適用**:
- V1→V2→V3→V4→V6→戦略A→V7
- 段階的に問題範囲を絞り込む

---

## V7 後の条件分岐

### ケースA: 白色のテキスト → Debug Mod D

**Debug Mod D: 頂点カラー可視化**
```metal
return in.color;  // 頂点カラーのみを返す
```

**目的**: 頂点カラーが正しく設定されているか確認
**期待**: 黄色/赤色（visual_test.lua の SetDrawColor() 指定色）

### ケースB: テキスト不可視/黒色 → sg_text.cpp 修正

**修正箇所**: sg_text.cpp の RGBA 変換
```cpp
// 現在（Stage 2修正済み）
rgba_buffer[i * 4 + 0] = 255;  // R = 白
rgba_buffer[i * 4 + 1] = 255;  // G = 白
rgba_buffer[i * 4 + 2] = 255;  // B = 白
rgba_buffer[i * 4 + 3] = value; // A = グレースケール

// 検証: value が正しく設定されているか確認
```

### ケースC: 赤/緑/青色 → テクスチャフォーマット修正

**修正箇所**: metal_backend.mm のテクスチャフォーマット設定
```objc
textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;  // または BGRA8Unorm
```

### ケースD: 半透明/グレー → RGBA変換値の修正

**修正箇所**: sg_text.cpp の RGB値設定
```cpp
// RGB を 255 ではなく、value に応じた値に変更
```

### ケースE: マゼンタ継続 → Clean Rebuild 再実行

**原因**: ビルドキャッシュ問題（再発）
**対策**: 戦略Aの手順を再実行

---

**状態**: Phase 3 完了 - Phase 4（レビュー）に進む
