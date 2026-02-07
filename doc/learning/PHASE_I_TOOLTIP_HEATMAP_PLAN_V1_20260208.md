# Phase I 残作業 - Tooltip & Heatmap 実装計画 V1

**日付**: 2026-02-08
**タスク**: Tooltip有効化 + Heatmap動作確認

---

## 現状分析

### Tooltip
- **コード状態**: 完全なコードが存在（PassiveTreeView.lua:1176-1196, Tooltip.lua:505行）
- **問題**: `if false and node == hoverNode` で**無効化済み**（line 1176）
- **コメント**: "Still requires deeper infrastructure" "tooltip still crashes at native layer"
- **インフラ**: `self.tooltip = new("Tooltip")` は line 31 で初期化済み
- **pcall保護**: 既にDraw呼び出しはpcallでラップ済み（crash safe）
- **推定**: 以前のMINIMAL modeでbuild.calcsTabが無かった時にクラッシュ → 無効化 → 現在はFull Appモードで calcsTab は存在する

### Heatmap
- **コード状態**: 完全なコードが存在
  - PassiveTreeView.lua: showHeatMap toggle('p'キー), 色計算(line 962-995)
  - TreeTab.lua: UIコントロール(checkbox, stat select, power report)
  - CalcsTab.lua: BuildPower() / PowerBuilder() (line 500-637)
- **依存**: `build.calcsTab` が必要 → Full Appモードで存在
- **トリガー**: 'p'キー押下 or TreeTabのチェックボックス

---

## 実装ステップ

### Step 1: Tooltip有効化（低リスク）

**変更**: PassiveTreeView.lua line 1176
```lua
-- BEFORE:
if false and node == hoverNode ...

-- AFTER:
if node == hoverNode ...
```

**根拠**:
- pcallで保護済み → クラッシュしない
- build.calcsTab は Full App モードで存在する
- AddNodeTooltip() メソッドは完全に実装済み
- 最悪でもERRORログが出るだけ（pcall保護）

### Step 2: Heatmap動作確認（変更なし）

Heatmapは既に有効なはず。確認のみ：
- 'p'キーでトグル
- CalcsTab.BuildPower()が動作するか
- ノードに色が付くか

### Step 3: 視覚的検証

アプリ起動して以下を確認：
1. ノードホバー → ツールチップ表示
2. 'p'キー → ヒートマップ色付け
3. 通常操作が引き続き動作

---

## リスク評価

- **Tooltip**: 低リスク（pcall保護済み、最悪でもERRORログのみ）
- **Heatmap**: 低リスク（変更なし、確認のみ）
- **ロールバック**: `if false and` を戻すだけ（1行変更）

## 成功基準

1. ノードホバー時にツールチップが表示される
2. 'p'キーでヒートマップが切り替わる（ベストエフォート）
3. 既存機能（ノード割当、タブ切替）が引き続き動作

## 所要時間

- Step 1: 5分（1行変更 + ファイル同期）
- Step 2: 0分（変更なし）
- Step 3: 5分（起動 + スクリーンショット）
- **合計: 10分**
