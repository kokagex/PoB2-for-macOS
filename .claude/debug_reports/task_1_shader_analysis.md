# タスク1: シェーダー分析結果

**日付**: 2026-02-04
**調査者**: Sage
**調査時間**: 15分
**目的**: 黄色テキスト（RGB ~1,1,0）を生成する可能性のあるシェーダーコードパスを特定

---

## 概要

pob2macosプロジェクトのMetal shaderコードを網羅的に調査し、黄色テキスト（RGB ~1,1,0）を生成する可能性のあるすべてのコードパスを特定しました。

**主要な発見**:
1. **2つの異なるシェーダーソースファイル**が存在する
2. **実際に使用されているシェーダー**は`metal_backend.mm`内のインラインソース（lines 96-139）
3. `metal_shaders.metal`は**使用されていない**（Debug Mod Aが残存しているが無効）
4. **黄色生成の主要原因**: 頂点カラー乗算が正常に動作している

---

## 発見されたファイル

### 検索対象ファイル

| ファイル | 行数 | 用途 | 使用状況 |
|---------|-----|------|---------|
| `metal_shaders.metal` | 45 | スタンドアロンシェーダー | ❌ **未使用** |
| `metal_backend.mm` | 1294 | Metal バックエンド実装 | ✅ **使用中** |
| `metal_pipeline.mm` | 10 | パイプライン管理（スタブ） | ❌ 未実装 |

---

## 発見された色出力コード

### 1. metal_shaders.metal: Fragment Shader（未使用）

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_shaders.metal`
**行番号**: 30-44
**使用状況**: ❌ **未使用**（metal_backend.mmがインラインシェーダーを使用）

**コード**:
```metal
// Fragment shader
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 texColor = tex.sample(sam, in.texCoord);

    // DEBUG MODIFICATION A: Texture Alpha Visualization
    // If texColor.a < 0.01 → RED (texture alpha = 0)
    // Else → GREEN (texture alpha > 0)
    if (texColor.a < 0.01) {
        return float4(1.0, 0.0, 0.0, 1.0);  // RED = alpha is 0
    } else {
        return float4(0.0, 1.0, 0.0, texColor.a);  // GREEN with alpha
    }
}
```

**分析**:
- このシェーダーには**Debug Mod A**が残存している
- しかし、`metal_backend.mm:176`で別のシェーダーソースをコンパイルしているため、このファイルは使用されていない
- Debug Mod Aが有効であれば、黄色（RGB 1,1,0）は理論上生成されない（RED または GREEN のみ）

**黄色生成可能性**: **NONE**（未使用のため）

---

### 2. metal_backend.mm: Inline Shader Source（使用中）

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
**行番号**: 122-138
**使用状況**: ✅ **実際に使用されているシェーダー**

**コード**:
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    // Sample texture array using xy for UV coords, z for layer
    // Metal requires layer index to be uint
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));

    // For R8Unorm textures (glyph atlas), red channel is alpha
    // Heuristic: if R is non-zero but G, B are zero, it's likely R8 format (glyph)
    if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
        float alpha = texColor.r;
        return float4(in.color.rgb, alpha * in.color.a);
    }

    // For RGBA textures (images) or dummy white texture, multiply by vertex color
    return texColor * in.color;
}
```

**分析**:
- このシェーダーは**正常な実装**（デバッグコードなし）
- 2つの処理パス:
  1. **グリフアトラス処理** (lines 131-134): R8フォーマット → `in.color.rgb`を使用
  2. **RGBA画像処理** (line 137): テクスチャ色 × 頂点カラー

**黄色生成可能性**: **HIGH**
- **パス1（グリフアトラス）**: `return float4(in.color.rgb, alpha * in.color.a);`
  - `in.color.rgb`が黄色（1.0, 1.0, 0.0）の場合 → 黄色テキスト出力 ✅
- **パス2（RGBA画像）**: `return texColor * in.color;`
  - `in.color`が黄色（1.0, 1.0, 0.0, 1.0）の場合 → 黄色出力 ✅

---

### 3. metal_backend.mm: set_draw_color 関数

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
**行番号**: 486-496

**コード**:
```objc
static void metal_set_draw_color(float r, float g, float b, float a) {
    if (!g_ctx || !g_ctx->renderer) return;

    MetalContext* metal = (MetalContext*)g_ctx->renderer->backend_data;
    if (!metal) return;

    metal->drawColor[0] = r;
    metal->drawColor[1] = g;
    metal->drawColor[2] = b;
    metal->drawColor[3] = a;
}
```

**分析**:
- `SetDrawColor(1.0, 1.0, 0.0, 1.0)`が呼ばれると、`metal->drawColor`に黄色が格納される
- この色は`metal_draw_glyph()`および`metal_draw_image()`で頂点カラーとして使用される

**黄色生成可能性**: **INDIRECT**（色の保存のみ、直接的な出力はしない）

---

### 4. metal_backend.mm: metal_draw_glyph 関数

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
**行番号**: 740-885

**重要部分** (lines 814-869):
```objc
vertices[idx + 0].color[0] = r;
vertices[idx + 0].color[1] = g;
vertices[idx + 0].color[2] = b;
vertices[idx + 0].color[3] = a;
// ... (6頂点すべてに同じ色を設定)
```

**分析**:
- `r, g, b, a`パラメータは`DrawString()`から渡される色
- Lua層で`SetDrawColor(1.0, 1.0, 0.0, 1.0)`が呼ばれた場合、`metal->drawColor`が黄色になる
- この黄色が頂点カラーとしてGPUに送信される
- フラグメントシェーダーで`float4(in.color.rgb, alpha * in.color.a)`として出力される

**黄色生成可能性**: **HIGH**（グリフレンダリングで頂点カラーを使用）

---

### 5. metal_backend.mm: metal_draw_image 関数

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
**行番号**: 887-1120

**重要部分** (lines 948-951, 1051-1106):
```objc
// Get draw color
float r = metal->drawColor[0];
float g = metal->drawColor[1];
float b = metal->drawColor[2];
float a = metal->drawColor[3];

// ... (頂点カラーとして設定)
vertices[idx + 0].color[0] = r;
vertices[idx + 0].color[1] = g;
vertices[idx + 0].color[2] = b;
vertices[idx + 0].color[3] = a;
```

**分析**:
- 画像描画でも`metal->drawColor`を頂点カラーとして使用
- `SetDrawColor(1.0, 1.0, 0.0, 1.0)`が呼ばれた場合、画像も黄色で着色される
- フラグメントシェーダーで`return texColor * in.color;`として乗算される

**黄色生成可能性**: **HIGH**（画像レンダリングで頂点カラー乗算）

---

## 黄色生成コードパス

### パス1: グリフアトラステキスト（最も可能性高い）

**フロー**:
```
Lua: SetDrawColor(1.0, 1.0, 0.0, 1.0)
  ↓
C++: metal_set_draw_color() → metal->drawColor = {1.0, 1.0, 0.0, 1.0}
  ↓
Lua: DrawString()
  ↓
C++: metal_draw_glyph(r=1.0, g=1.0, b=0.0, a=1.0)
  ↓
GPU: vertices[].color = {1.0, 1.0, 0.0, 1.0}
  ↓
Fragment Shader (metal_backend.mm:131-134):
  if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
      float alpha = texColor.r;
      return float4(in.color.rgb, alpha * in.color.a);  // ← 黄色出力！
  }
  ↓
Output: RGB(1.0, 1.0, 0.0) with alpha
```

**可能性**: **HIGH**
**理由**: グリフアトラスはR8フォーマットのため、このパスが実行される。`in.color.rgb`が黄色（1.0, 1.0, 0.0）の場合、そのまま黄色が出力される。

---

### パス2: RGBA画像レンダリング

**フロー**:
```
Lua: SetDrawColor(1.0, 1.0, 0.0, 1.0)
  ↓
C++: metal_set_draw_color() → metal->drawColor = {1.0, 1.0, 0.0, 1.0}
  ↓
Lua: DrawImage()
  ↓
C++: metal_draw_image()
  ↓
GPU: vertices[].color = {1.0, 1.0, 0.0, 1.0}
  ↓
Fragment Shader (metal_backend.mm:137):
  return texColor * in.color;  // ← テクスチャ色 × 黄色
  ↓
Output: テクスチャ色に黄色が乗算される
```

**可能性**: **MEDIUM**
**理由**: RGBA画像の場合、テクスチャ色と頂点カラーが乗算される。テクスチャが白（1,1,1,1）の場合、黄色が出力される。

---

### パス3: Debug Mod A（未使用）

**ファイル**: `metal_shaders.metal` (lines 39-42)

**フロー**:
```
Fragment Shader (metal_shaders.metal):
  if (texColor.a < 0.01) {
      return float4(1.0, 0.0, 0.0, 1.0);  // RED
  } else {
      return float4(0.0, 1.0, 0.0, texColor.a);  // GREEN
  }
```

**可能性**: **NONE**
**理由**: このファイルは使用されていない（metal_backend.mmがインラインシェーダーを使用）。Debug Mod Aが有効であれば、黄色（RED + GREEN）は理論上生成されないはずだが、実際にはこのコードは実行されていない。

---

## デバッグコード確認結果

### Debug Mod A（metal_shaders.metal）

**ステータス**: ❌ **残存しているが未使用**
**理由**: `metal_backend.mm:176`で別のシェーダーソースをコンパイルしている

```objc
// metal_backend.mm:174-176
NSString* shaderSource = [NSString stringWithUTF8String:metalShaderSource];
NSError* error = nil;
metal->library = [metal->device newLibraryWithSource:shaderSource options:nil error:&error];
```

`metalShaderSource`は`metal_backend.mm:96-139`のインライン文字列であり、`metal_shaders.metal`ファイルではない。

### Debug Mod B（マゼンタ）

**ステータス**: ❌ **見つからない**

検索パターン: `float4(1.0, 0.0, 1.0, 1.0)` または `return.*1\.0.*0\.0.*1\.0`

### Debug Mod C（生のテクスチャ色）

**ステータス**: ❌ **見つからない**（ただし、line 137が類似）

`metal_backend.mm:137`の`return texColor * in.color;`は、`in.color`が白（1,1,1,1）の場合、生のテクスチャ色を返すのと同等。

---

## シェーダーコンパイルフロー

### 実際の動作（現在）

```
metal_backend.mm:143-183 (metal_init関数)
  ↓
line 174: NSString* shaderSource = [NSString stringWithUTF8String:metalShaderSource];
  ↓
line 176: metal->library = [metal->device newLibraryWithSource:shaderSource options:nil error:&error];
  ↓
line 220-221: vertexFunction = [metal->library newFunctionWithName:@"vertex_main"];
              fragmentFunction = [metal->library newFunctionWithName:@"fragment_main"];
  ↓
使用されるシェーダー: metal_backend.mm lines 96-139（インラインソース）
```

### metal_shaders.metalが使用される条件（現在は該当しない）

```
metal_backend.mm:176を以下に変更した場合:
metal->library = [metal->device newDefaultLibrary];
  ↓
metal_shaders.metalがコンパイル済みバイナリとして使用される
```

---

## 結論

### 最も疑わしいコードパス

**パス1: グリフアトラステキストレンダリング**が最も可能性が高い。

**根拠**:
1. `metal_backend.mm:131-134`のフラグメントシェーダーで`in.color.rgb`をそのまま出力
2. Lua層で`SetDrawColor(1.0, 1.0, 0.0, 1.0)`が明示的に指定されている（visual_test.lua:98）
3. 頂点カラーとして黄色（1.0, 1.0, 0.0）がGPUに送信される
4. グリフアトラスはR8フォーマットのため、このパスが実行される

### Debug Mod Aについて

**ステータス**: 残存しているが**無効**

- `metal_shaders.metal`にDebug Mod Aが残存している
- しかし、`metal_backend.mm`がインラインシェーダーをコンパイルしているため、`metal_shaders.metal`は使用されていない
- 実際に使用されているシェーダー（`metal_backend.mm:122-138`）はデバッグコードを含まない正常な実装

### 黄色テキストの原因

**結論**: **意図的な設定による正常な動作**

1. Lua層で`SetDrawColor(1.0, 1.0, 0.0, 1.0)`を明示的に指定（visual_test.lua:98）
2. 頂点カラーとして黄色がGPUに送信される
3. フラグメントシェーダーが頂点カラーを使用して黄色テキストを出力

これは**バグではなく、仕様通りの動作**である。

---

## 推奨される次のステップ

### ケースA: 黄色は意図的な設定（最も可能性高い）

**判定**: ✅ **これが実際の状況**

**推奨アクション**:
1. 調査完了（問題なし）
2. ユーザーに報告: 黄色テキストはLua層のSetDrawColor()で設定された意図的な色
3. 必要に応じて、visual_test.luaで色を変更

### ケースB: Debug Mod Aをクリーンアップ

**判定**: 🔄 オプション（機能に影響しない）

**推奨アクション**:
1. `metal_shaders.metal`からDebug Mod Aを除去
2. または、ファイル全体を削除（未使用のため）
3. 注釈を追加: "// NOTE: This file is not used. Shaders are compiled from metal_backend.mm:96-139"

### ケースC: インラインシェーダーをファイルに移動

**判定**: 🔄 オプション（リファクタリング）

**推奨アクション**:
1. `metal_backend.mm:96-139`のインラインシェーダーを`metal_shaders.metal`に移動
2. `metal_backend.mm:176`を`newDefaultLibrary()`に変更
3. ビルドシステムでシェーダーコンパイルを設定

**注意**: これは大規模なリファクタリングであり、現在の機能に影響しない。

---

## 付録: 色関連コード検索結果

### 検索パターン

| パターン | ファイル | 行番号 | 説明 |
|---------|---------|--------|------|
| `color\|rgb\|rgba` | metal_backend.mm | 多数 | 頂点カラー、drawColor |
| `float4\|float3` | metal_backend.mm | 多数 | RGBA色の型 |
| `1\.0.*1\.0.*0` | なし | - | 黄色リテラルは見つからず |
| `fragment` | metal_shaders.metal | 30 | fragment_main (未使用) |
| `fragment` | metal_backend.mm | 122 | fragment_main (使用中) |

### 頂点カラーの使用箇所

| 関数 | 行番号 | 用途 |
|------|--------|------|
| `metal_set_draw_color` | 486-496 | drawColorの設定 |
| `metal_draw_glyph` | 814-869 | 頂点カラーとして設定 |
| `metal_draw_image` | 1051-1106 | 頂点カラーとして設定 |
| `metal_draw_quad` | 1203-1258 | 頂点カラーとして設定 |

---

**調査完了**: 2026-02-04
**調査時間**: 15分
**総ファイル数**: 3ファイル
**総行数**: 1349行
**発見された色出力コード**: 5箇所
**黄色生成コードパス**: 2パス（HIGH可能性）
**デバッグコード残存**: 1箇所（未使用）
