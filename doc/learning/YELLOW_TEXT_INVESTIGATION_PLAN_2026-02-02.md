# V6 黄色テキスト原因調査計画

**日付**: 2026-02-02
**Prophet**: V6調査継続タスク
**状態**: Phase 3 - 計画立案完了

---

## エグゼクティブサマリー

**目的**: V6で発見された「黄色テキスト」の原因を特定する

**背景**:
- V6実装後、Text #1が黄色、Text #2が赤で表示
- Debug Mod Aは赤(alpha<0.01)または緑(alpha≥0.01)のみを出力するはず
- 黄色は理論上Debug Mod Aから出力されない色（赤+緑が必要）

**根本原因仮説**:
visual_test.luaの分析により、**SetDrawColor()で明示的に黄色(1.0, 1.0, 0.0, 1.0)を指定していることが判明**

**推定作業時間**: 15分（調査5分、確認10分）

---

## 根本原因分析（Root Cause Analysis）

### 現在の観察結果（V6）

**視覚的結果**: `/Users/kokage/Desktop/スクリーンショット 2026-02-02 18.52.23.png`

| 要素 | 観察された色 | 期待される色（Debug Mod A） |
|------|------------|---------------------------|
| Text #1（上部） | 黄色 | 赤または緑 |
| Text #2（中部） | 赤 | 赤または緑 |
| Background | 青 | 青 ✅ |

### Debug Mod A の仕様（復習）

**ファイル**: `simplegraphic/src/backend/metal/metal_backend.mm` (V4.1)

```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 texColor = tex.sample(sam, in.texCoord);

    // DEBUG MODIFICATION A: Texture Alpha Visualization
    if (texColor.a < 0.01) {
        return float4(1.0, 0.0, 0.0, 1.0);  // RED = alpha is 0
    } else {
        return float4(0.0, 1.0, 0.0, texColor.a);  // GREEN with alpha
    }
}
```

**可能な出力**:
- RED (1.0, 0.0, 0.0, 1.0) - alpha < 0.01
- GREEN (0.0, 1.0, 0.0, α) - alpha ≥ 0.01
- **YELLOW は理論上出力されない** (赤+緑の両方が必要)

### visual_test.lua のコード分析

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/visual_test.lua`

**重要な発見** (Lines 92-100):

```lua
-- Draw text (white)
sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)  -- 白色設定
sg.DrawString(50, 50, 0, 24, "", "VISUAL TEST - Metal Fragment Shader Fix")
sg.DrawString(50, 90, 0, 16, "", "If you can see this text AND the image below, the fix works!")

-- Draw text (yellow)
sg.SetDrawColor(1.0, 1.0, 0.0, 1.0)  -- 黄色設定！
sg.DrawString(50, 130, 0, 20, "", string.format("Frame: %d", frame))
sg.DrawString(50, 160, 0, 16, "", "Text rendering: WORKING")
```

**発見事項**:
1. Lines 92-95: 白色(1.0, 1.0, 1.0, 1.0)を設定してテキスト描画
2. **Lines 98-100: 黄色(1.0, 1.0, 0.0, 1.0)を設定してテキスト描画**

### 根本原因の特定

**仮説1（最も可能性高い）**: **頂点カラーとの乗算が復活している**

#### 証拠:

1. **visual_test.lua の意図**:
   - 黄色テキストを描画したい（Line 98: SetDrawColor yellow）
   - 実際に黄色が表示されている ✅

2. **Debug Mod A との整合性**:
   - Debug Mod A (V4.1): テクスチャ色のみを返す（頂点カラー無視）
   - 現実: 黄色が表示されている
   - **矛盾**: Debug Mod Aが無効化されているか、頂点カラーが乗算されている

3. **可能性の分析**:
   - **可能性A**: V6のクリーンビルドで、Debug Mod Aが元のコードに戻された
   - **可能性B**: 複数のフラグメントシェーダーが存在し、テキストは別のシェーダーを使用

#### 検証方法:

**Step 1**: 現在のフラグメントシェーダーコードを確認
- ファイル: `pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
- 確認: Lines 112-117 のフラグメントシェーダー定義

**Step 2**: ビルドされたバイナリのタイムスタンプ確認
- `pob2macos/dev/runtime/SimpleGraphic.dylib` のタイムスタンプ
- V6のビルド時刻と一致するか確認

**Step 3**: visual_test.lua の実行結果と照合
- 黄色が表示される = 頂点カラー乗算が機能
- Debug Mod A が無効化されている可能性

---

## 仮説2: 複数のレンダリングパス

**理論**: Text #1とText #2が異なるレンダリングパスを使用

**証拠**:
- Text #1: 黄色（頂点カラー反映）
- Text #2: 赤（Debug Mod A 反映）

**検証方法**:
- Metal バックエンドのコードを確認
- DrawString() と DrawImage() が同じフラグメントシェーダーを使用しているか確認

**可能性**: MEDIUM
- SimpleGraphic の設計上、単一のフラグメントシェーダーを使用するはず
- しかし検証が必要

---

## 仮説3: V6とV4.1の混在

**理論**: V6のクリーンビルドが完全に反映されていない

**証拠**:
- V4.1: Debug Mod A実装
- V6: シェーダーキャッシュクリア
- 現実: 黄色テキスト（V4.1以前の挙動？）

**検証方法**:
- V6実装時のシェーダーコードを確認
- ビルドログで "metal_backend.mm" のコンパイル確認

**可能性**: LOW
- V6実装レポートではキャッシュクリア成功と記載
- しかし完全には排除できない

---

## 調査計画（Phase B）

### 目標

1. 現在のフラグメントシェーダーコードを確認
2. ビルド状態を検証
3. 黄色テキストの原因を特定
4. 次のアクションを決定

### Step 1: フラグメントシェーダーコード確認（2分）

**実行者**: Sage

**タスク**:
```bash
# 現在のシェーダーコードを確認
cat /Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm | grep -A 20 "fragment float4 fragment_main"
```

**期待結果**:
- Debug Mod A のコード（V4.1）
- または元のコード（頂点カラー乗算あり）
- またはDebug Mod B/C（V7計画）

**判定**:
- Debug Mod A → 仮説2（複数レンダリングパス）の可能性
- 元のコード → 仮説1（V6で元に戻された）
- Debug Mod B/C → V7が既に実装済み

---

### Step 2: ビルドタイムスタンプ確認（1分）

**実行者**: Sage

**タスク**:
```bash
# ビルド時刻確認
ls -lh /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib
ls -lh /Users/kokage/national-operations/pob2macos/dev/runtime/SimpleGraphic.dylib
date
```

**判定**:
- タイムスタンプが古い → V6ビルドが反映されていない
- タイムスタンプが最近 → V6ビルドは成功

---

### Step 3: visual_test.lua 詳細分析（2分）

**実行者**: Sage

**タスク**: visual_test.lua のレンダリングコールを分析

**確認事項**:
1. SetDrawColor() の呼び出し回数と色
2. DrawString() の呼び出し回数
3. Text #1 と Text #2 の描画関数が同じか

**期待結果**:
```lua
-- Text #1 (lines 92-95): WHITE text
SetDrawColor(1.0, 1.0, 1.0, 1.0)
DrawString(..., "VISUAL TEST - Metal Fragment Shader Fix")
DrawString(..., "If you can see this text AND the image below, the fix works!")

-- Text #2 (lines 98-100): YELLOW text
SetDrawColor(1.0, 1.0, 0.0, 1.0)  -- 黄色！
DrawString(..., string.format("Frame: %d", frame))
DrawString(..., "Text rendering: WORKING")
```

**判定**:
- 黄色が表示されている = 頂点カラー乗算が機能
- 赤が表示されている = Debug Mod A が機能（一部のみ？）

---

### Step 4: Metal バックエンドのパイプライン確認（5分）

**実行者**: Sage

**タスク**: metal_backend.mm のレンダリングパイプライン状態（render pipeline state）を確認

**確認事項**:
1. フラグメントシェーダー関数が1つのみか
2. テキストと画像で異なるパイプラインを使用しているか
3. 頂点カラーの設定方法

**ファイル**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`

**検索キーワード**:
- `MTLRenderPipelineState`
- `fragmentFunction`
- `vertexFunction`

**期待結果**:
- 単一のパイプライン状態 → 仮説1（元のコードに戻った）
- 複数のパイプライン状態 → 仮説2（複数レンダリングパス）

---

### Step 5: 総合判定と次ステップ決定（5分）

**実行者**: Mayor

**タスク**: Step 1-4の結果を統合し、次のアクションを決定

**判定ロジック**:

#### ケースA: Debug Mod A が残っている
- **原因**: 複数のレンダリングパスまたはブレンディング
- **次ステップ**: Debug Mod B（全てマゼンタ）で検証

#### ケースB: 元のコードに戻っている
- **原因**: V6のクリーンビルドでDebug Mod Aが失われた
- **次ステップ**: Debug Mod を再実装（V7計画実行）

#### ケースC: V7が既に実装済み
- **原因**: 誤解または状態の混乱
- **次ステップ**: V7の結果を分析

---

## エージェント割り振り

### Sage（技術調査）

**タスク**:
1. Step 1: フラグメントシェーダーコード確認
2. Step 2: ビルドタイムスタンプ確認
3. Step 3: visual_test.lua 詳細分析
4. Step 4: Metal バックエンドのパイプライン確認

**成功基準**:
- すべてのStep完了
- 各Stepの結果を構造化されたYAMLで報告
- 次ステップの推奨を明記

**推定時間**: 10分

---

### Mayor（統合とリスク評価）

**タスク**:
1. Sageの報告を受領
2. 総合判定（ケースA/B/C）
3. 次ステップの推奨
4. Prophetへのリスク評価レポート送信

**成功基準**:
- 根本原因の特定（ケースA/B/C）
- 次ステップの明確化
- リスク評価完了（LOW_RISK or REQUIRES_DIVINE_APPROVAL）

**推定時間**: 5分

---

## タイムライン

- Step 1: フラグメントシェーダー確認（2分）
- Step 2: ビルドタイムスタンプ確認（1分）
- Step 3: visual_test.lua 分析（2分）
- Step 4: Metalパイプライン確認（5分）
- Step 5: 総合判定（5分）
- **合計: 約15分**

---

## リスク評価

### リスク1: 複数のレンダリングパスが存在

**影響**: MEDIUM
**確率**: MEDIUM
**対策**: Step 4で確認、必要に応じてDebug Mod を全パスに適用

### リスク2: V6ビルドが反映されていない

**影響**: LOW
**確率**: LOW（V6成功レポートあり）
**対策**: Step 2で確認、必要に応じて再ビルド

### リスク3: 調査結果が予期しない

**影響**: LOW
**確率**: LOW
**対策**: ケースA/B/Cの条件分岐で対応、Prophetへエスカレーション

---

## 成功基準

### Phase B 成功基準

1. ✅ 黄色テキストの原因を特定（ケースA/B/C）
2. ✅ 現在のシェーダー状態を確認
3. ✅ 次ステップを明確化
4. ✅ リスク評価完了

### 最終成功基準（Phase B以降）

1. ✅ すべてのテキストが正しく表示される
2. ✅ 画像が正しく表示される
3. ✅ Debug Mod を除去し、本番コードで動作確認
4. ✅ ユーザー視覚的確認済み

---

## CRITICAL LESSONS の適用

### ルール1: ログは参考、視覚的結果が真実

**適用**:
- ビルドログではなく、実際のシェーダーコードを確認
- タイムスタンプで実際のビルド時刻を検証

### ルール2: すべての実装後、必ず視覚的検証（15分以内）

**適用**:
- Phase B タイムライン: 15分
- 視覚的検証は既に実施済み（V6スクリーンショット）

### ルール3: Occam's Razor - 最もシンプルな説明

**適用**:
- 仮説1（元のコードに戻った）が最もシンプル
- しかし証拠ベースで判定（仮定ではなく確認）

### ルール4: 階層構造の厳守

**適用**:
- Prophet は調査を実行しない
- Sage に技術調査を委譲
- Mayor がリスク評価を実施

### Learning Protocol

**適用**:
- 調査結果を LESSONS_LEARNED.md に記録
- 新しいパターンがあれば追加

---

## 次ステップの条件分岐

### ケースA: Debug Mod A が残っている

**次ステップ**: Debug Mod B 実装（全てマゼンタ）

**理由**:
- 複数のレンダリングパスを完全に特定
- すべての描画がマゼンタになるか確認
- テキスト/画像の描画パスを分離

**実装**: V7計画の戦略A（既にレビュー済み）

---

### ケースB: 元のコードに戻っている

**次ステップ**: Debug Mod C 実装（生のテクスチャ色）

**理由**:
- 頂点カラー乗算が機能している
- テクスチャ自体の内容を確認
- RGBAマッピングの検証

**実装**: V7計画のDebug Mod C

---

### ケースC: V7が既に実装済み

**次ステップ**: V7の結果を分析

**理由**:
- 状態の混乱を解消
- 現在の実装を正確に把握

**実装**: V7レビューの再実行

---

**計画書ステータス**: Phase 3 完了 - Phase 4（レビュー）に進む
