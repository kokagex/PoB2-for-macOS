# Phase I 残作業 - 実装計画 V1

**日付**: 2026-02-08
**タスク**: Phase I 残作業（診断ログクリーンアップ + Tooltip + Heatmap）

---

## 根本原因分析

Phase I-1, I-2の修正で追加された大量の診断ログが毎フレーム出力され、ログファイルが数分で2GB超に膨張。
正常動作が確認されたため、不要なログを削除する必要がある。

---

## 実装ステップ

### Step 1: 診断ログクリーンアップ

**対象ファイル** (5ファイル):
1. `PassiveTreeView.lua` - hover診断ログ、背景描画ログ
2. `PassiveSpec.lua` - BuildPathFromNode詳細ログ
3. `Build.lua` - CallMode、autoStartBuildログ
4. `Main.lua` - DEBUG CallModeログ
5. `TreeTab.lua` - TREETAB-SEL/PCI診断

**方針**: DEBUGプリフィックスのConPrintf行を削除（コメントアウトではなく完全削除）

### Step 2: Tooltip検証

PassiveTreeView.luaのtooltip描画コードの動作確認。
Phase 5で「MINIMAL modeでは非互換」だったが、現在はFull Appモードなので再検証が必要。

### Step 3: Heatmap検証

"Show Node Power"ドロップダウンの動作確認。
TreeTabのheatmap機能が正しく動作するか確認。

### Step 4: 視覚的検証

全修正後にアプリ起動し、スクリーンショットで以下を確認:
- ログが膨張しないこと
- パッシブツリーが正常に動作すること
- ノードクリック→割当が引き続き動作すること

---

## リスク評価

- **低リスク**: ログ削除は機能に影響しない
- **中リスク**: Tooltip/Heatmapは追加検証が必要だが、既存機能に影響しない

## 成功基準

1. ログファイルサイズが安定する（数分で数KB程度）
2. パッシブツリーが引き続き正常動作
3. ノード割当が引き続き動作

## ロールバック

ログ削除のみなので、git stashで即座にロールバック可能。
