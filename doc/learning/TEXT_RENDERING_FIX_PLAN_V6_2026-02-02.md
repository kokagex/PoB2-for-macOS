# テキストレンダリング修正計画 V6: 根本問題の特定

**日付**: 2026-02-02 19:00
**状態**: Phase 3 - 計画立案
**前回の試行**: V1-V5 すべて失敗または不完全

---

## V1-V5 失敗の総括

### 実施した調査と結果

**V1: Dirty Flag実装** (2026-02-02 00:20)
- 仮説: テクスチャ更新タイミング問題
- 実装: グリフラスタライズ時にdirty flag、end_frame()で一括更新
- 結果: ❌ 視覚的変化なし、タイミングエラー発覚
- 学習: テクスチャ更新タイミングは問題ではない

**V2: 詳細ログ調査** (2026-02-02 00:30-06:00)
- 収集: 7,361行のログ（グリフラスタライズ、テクスチャ更新）
- 結果: ✅ CPU層すべて正常動作
- 学習: CPUレイヤーは問題なし、GPU層を調査すべき

**V3: 頂点バッファ検証** (2026-02-02 06:00-07:00)
- 収集: 31MB、546,868 VERTEX-ADD エントリ
- 結果: ✅ 頂点データ、UV座標すべて正常
- 学習: GPU頂点レイヤーも正常、Fragment Shaderを調査すべき

**V4: Fragment Shader Debug Modification A** (2026-02-02 07:00-08:00)
- 実装: テクスチャアルファ可視化（alpha<0.01 → 赤、else → 緑）
- 試行回数: 3回（デプロイ失敗含む）
- 結果: ❌ オレンジ/黄色のテキスト（期待: 赤または緑）
- 学習: Fragment Shaderデバッグが機能していない

**V4.1: Alpha値修正** (2026-02-02 07:30)
- 実装: 緑色を完全不透明に（alpha=1.0）
- 試行回数: 2回（デプロイ失敗含む）
- 結果: ❌ オレンジ/黄色継続、視覚的変化なし
- 学習: Debug Modificationが反映されていない可能性

**V5: PathOfBuilding.app テスト** (2026-02-02 18:00-18:40)
- 仮説: visual_test.lua と PathOfBuilding.app は異なるコードパス
- 試行: PathOfBuilding.app 起動
- 結果: ❌ アプリ起動失敗（"cannot open src/Launch.lua"）
- 学習: アプリバンドル構造が不完全

### Progressive Elimination の最終結果

```
✅ CPU Layer (Lua DrawString, グリフラスタライズ, テクスチャ更新)
✅ GPU Vertex Layer (頂点バッファ, UV座標)
❓ GPU Fragment Layer (デバッグ修正が反映されず、検証不能)
```

---

## 重大な気づき: なぜV4/V4.1のFragment Shader デバッグが失敗したか

### 問題の症状

**期待される視覚的結果**:
- Debug Mod A: テクスチャアルファ < 0.01 → **赤**
- Debug Mod A: テクスチャアルファ >= 0.01 → **緑**

**実際の視覚的結果**:
- V4: オレンジ/黄色のテキスト（3回のテスト試行すべて）
- V4.1: オレンジ/黄色のテキスト継続（2回のテスト試行すべて）

### 可能な原因（優先度順）

#### 仮説1: シェーダーキャッシュ問題（最も可能性高い）

**証拠**:
- Metal はシェーダーをコンパイルしてキャッシュする
- 埋め込みシェーダーソース（metal_backend.mm）を変更しても、キャッシュが使用される可能性
- V4 + V4.1 = 5回以上のテスト、すべて視覚的変化なし

**検証方法**:
```bash
# Metalシェーダーキャッシュのクリア
rm -rf ~/Library/Caches/com.apple.metal/
rm -rf /Users/kokage/Library/Caches/com.apple.metal/

# または、アプリケーション固有のキャッシュをクリア
rm -rf ~/Library/Caches/PathOfBuilding/
```

#### 仮説2: ビルド/デプロイ問題（中程度の可能性）

**証拠**:
- Artisan がデプロイで `dev/runtime/SimpleGraphic.dylib` を更新し忘れた（V4で2回発生）
- Clean Rebuild を実行していない可能性
- インクリメンタルビルドがシェーダー文字列の変更を検出しない可能性

**検証方法**:
```bash
# Clean Rebuild
cd pob2macos/dev/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build

# タイムスタンプ確認
ls -lh build/libSimpleGraphic.dylib
date  # 同じ時刻なら成功

# 完全デプロイ
cp build/libSimpleGraphic.dylib ../runtime/SimpleGraphic.dylib
ls -lh ../runtime/SimpleGraphic.dylib
```

#### 仮説3: シェーダーコンパイルエラー（低い可能性）

**証拠**:
- V4/V4.1 のシェーダーコードは構文的に正しい
- クラッシュしていない（シェーダーがコンパイルされている）
- しかし、古いシェーダーが使用されている可能性

**検証方法**:
- metal_backend.mm のシェーダーコンパイルログを確認
- `NSLog(@"Compiling shader: %@", shaderSource)` を追加
- コンパイルエラーログを確認

#### 仮説4: visual_test.lua の制約（最も低い可能性）

**証拠**:
- V5 で PathOfBuilding.app が起動しなかった
- しかし、visual_test.lua は SimpleGraphic.dylib を正しくロードしている
- V1-V4 の調査はすべて visual_test.lua で実施

**検証方法**:
- PathOfBuilding.app の構造を修正し、実際のアプリでテスト
- または、visual_test.lua でシェーダー変更が反映されることを別の方法で確認

---

## V6: シェーダーキャッシュクリア + Clean Rebuild アプローチ

### 戦略

**重要な認識**:
1. V4/V4.1 の失敗原因は、**Fragment Shaderの修正が反映されていない**こと
2. 最も可能性が高い原因は、**シェーダーキャッシュ** または **ビルドキャッシュ**
3. この2つを完全にクリアし、再度 Debug Mod A をテスト

### V6 実装プラン

#### ステップ1: すべてのキャッシュをクリア（Paladin）

**タスク**:
1. Metal シェーダーキャッシュをクリア:
   ```bash
   rm -rf ~/Library/Caches/com.apple.metal/
   rm -rf ~/Library/Caches/PathOfBuilding/
   ```
2. ビルドキャッシュをクリア:
   ```bash
   cd pob2macos/dev/simplegraphic
   rm -rf build
   ```
3. 実行結果をログに記録

**タイムボックス**: 2分

---

#### ステップ2: Clean Rebuild + 完全デプロイ（Artisan）

**タスク**:
1. Clean Rebuild:
   ```bash
   cd pob2macos/dev/simplegraphic
   cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
   make -C build
   ```
2. タイムスタンプ確認:
   ```bash
   ls -lh build/libSimpleGraphic.dylib
   date
   ```
3. 完全デプロイ:
   ```bash
   cp build/libSimpleGraphic.dylib ../runtime/SimpleGraphic.dylib
   ls -lh ../runtime/SimpleGraphic.dylib
   ```

**重要**:
- metal_backend.mm にはすでに Debug Mod A が適用されている（V4.1の状態）
- シェーダーコード（lines 112-124）:
  ```metal
  fragment float4 fragment_main(VertexOut in [[stage_in]],
                                texture2d_array<float> tex [[texture(0)]],
                                sampler sam [[sampler(0)]]) {
      float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));

      // DEBUG MODIFICATION A: Texture Alpha Visualization
      if (texColor.a < 0.01) {
          return float4(1.0, 0.0, 0.0, 1.0);  // RED = alpha is 0
      } else {
          return float4(0.0, 1.0, 0.0, 1.0);  // GREEN (fully opaque)
      }
  }
  ```

**タイムボックス**: 3分

---

#### ステップ3: 視覚的検証（Paladin）

**タスク**:
1. visual_test.lua を起動:
   ```bash
   cd pob2macos/dev
   luajit visual_test.lua
   ```
2. スクリーンショット撮影
3. 視覚的結果を分析:
   - **ケースA: 赤と緑のみ** → Debug Mod A 成功、Fragment Shader調査継続
   - **ケースB: すべて赤** → テクスチャ更新失敗、V2に戻る
   - **ケースC: すべて緑** → テクスチャサンプリング成功、頂点カラー検証へ
   - **ケースD: オレンジ/黄色継続** → キャッシュクリア失敗、別の原因調査
   - **ケースE: 色が変化した** → キャッシュ問題が原因だった、新しい色を分析

**タイムボックス**: 5分

---

#### ステップ4: 結果に基づいた次ステップ決定（Mayor）

**ケースA: 赤と緑のみ**
- 成功: Fragment Shader デバッグが機能開始
- 次ステップ: Phase B（テクスチャサンプリング詳細調査）

**ケースB: すべて赤**
- 失敗: テクスチャアルファが常に0
- 次ステップ: V2のログ分析を再確認、テクスチャ更新問題

**ケースC: すべて緑**
- 部分的成功: テクスチャサンプリングは機能
- 次ステップ: 頂点カラー（in.color）の検証

**ケースD: オレンジ/黄色継続**
- 失敗: キャッシュクリアでも反映されず
- 次ステップ: シェーダーコンパイルログの確認、または visual_test.lua が別のシェーダーを使用している可能性

**ケースE: 色が変化した**
- 部分的成功: キャッシュ問題が原因
- 次ステップ: 新しい色を分析し、Fragment Shader の挙動を理解

**タイムボックス**: 5分

---

## なぜこのアプローチが必要か

### V4/V4.1 の失敗原因の特定

**問題**:
- Fragment Shader を5回以上修正したが、視覚的変化なし
- これは修正が反映されていないことを意味する

**Occam's Razor**:
- 最もシンプルな説明: **キャッシュ問題**
- Metal はシェーダーをキャッシュする
- ビルドシステムは文字列リテラルの変更を検出しない場合がある

**V6 の目標**:
- キャッシュをすべてクリアし、Clean Rebuild
- Debug Mod A が正しく反映されることを確認
- Fragment Shader 調査を再開

---

## タイムライン

- ステップ1: キャッシュクリア（2分）
- ステップ2: Clean Rebuild + デプロイ（3分）
- ステップ3: 視覚的検証（5分）
- ステップ4: 結果分析・次ステップ決定（5分）
- **合計: 約15分**

---

## リスク評価

### リスク1: キャッシュクリアでも変化なし

**影響**: MEDIUM
**確率**: MEDIUM（V4/V4.1 で5回失敗）
**対策**:
- シェーダーコンパイルログの確認
- visual_test.lua が使用しているシェーダーの特定
- 別のデバッグ方法の検討

### リスク2: Clean Rebuild 失敗

**影響**: LOW
**確率**: LOW（標準的なビルド手順）
**対策**:
- ビルドエラーログの確認
- CMake設定の確認
- 依存関係の確認

### リスク3: visual_test.lua が起動しない

**影響**: LOW
**確率**: LOW（V1-V4 で正常動作）
**対策**:
- 別のテストプログラムを使用
- または PathOfBuilding.app の構造を修正

---

## 成功基準

### V6 成功基準

1. ✅ すべてのキャッシュをクリア（Metal、ビルド）
2. ✅ Clean Rebuild 完了（タイムスタンプ確認）
3. ✅ 完全デプロイ完了（runtime/ 更新確認）
4. ✅ 視覚的結果に**何らかの変化**が発生（色が変わる）
5. ✅ ケースA-E のいずれかに分類、次ステップを決定

### 最終成功基準（Phase B以降）

1. ✅ パッシブツリーが正しく表示される
2. ✅ すべてのテキストが正しく表示される
3. ✅ 画像が正しく表示される
4. ✅ ユーザー確認済み

---

## CRITICAL LESSONS の適用

### ルール1: ログは参考、視覚的結果が真実

**適用**:
- ビルドログではなく、**視覚的結果**（スクリーンショット）で判定
- 色が変われば成功、変わらなければ失敗

### ルール2: すべての実装後、必ず視覚的検証（15分以内）

**適用**:
- V6 タイムライン: 15分
- ステップ3 で必ず視覚的検証

### ルール3: Occam's Razor - 最もシンプルな説明

**適用**:
- V4/V4.1 失敗の最もシンプルな説明: キャッシュ問題
- 複雑な仮説（visual_test.lua 固有の問題）ではなく、シンプルな仮説を優先

### ルール5: 視覚的変化がなければ「失敗」と認める

**適用**:
- V4/V4.1 で5回視覚的変化なし → 失敗と認める
- V6 でも変化なければ、別のアプローチを検討

### ルール6: 3日間進展なし = プロジェクト失敗、即座にリセット提案

**適用**:
- V1-V5 で約1日経過（2026-02-02 00:20-19:00）
- V6 で進展なければ、根本的なアプローチ変更を提案

---

## V6 後の条件分岐

### ケースA: 赤と緑のみ → Phase B

**Phase B: テクスチャサンプリング詳細調査**
- なぜ一部のグリフは赤（alpha=0）で、一部は緑（alpha>0）か？
- UV座標とテクスチャアトラスの対応を検証
- テクスチャ更新が正しく行われているか再確認

### ケースB: すべて赤 → V2 再確認

**V2 ログ分析の再検証**
- テクスチャ更新ログが「正常」でも、実際には失敗している可能性
- テクスチャアトラスの内容をダンプして確認
- グリフラスタライズの出力を検証

### ケースC: すべて緑 → 頂点カラー検証

**頂点カラー（in.color）の調査**
- Debug Mod C: `return in.color;` を試して頂点カラーを可視化
- 頂点カラーが正しく設定されているか確認
- テクスチャとカラーの乗算結果を検証

### ケースD: オレンジ/黄色継続 → シェーダーコンパイルログ

**シェーダーコンパイル検証**
- metal_backend.mm に `NSLog(@"Compiling shader...")` を追加
- コンパイルエラーログの確認
- visual_test.lua が実際に使用しているシェーダーの特定

### ケースE: 色が変化した → 新しい色の分析

**新しい視覚的結果の分析**
- どのような色に変わったか？
- Debug Mod A の挙動から何が分かるか？
- 次のデバッグステップを決定

---

**状態**: Phase 3 完了 - Phase 4（レビュー）に進む
