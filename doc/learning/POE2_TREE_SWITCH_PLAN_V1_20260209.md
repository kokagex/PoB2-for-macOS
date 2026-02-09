# PoE2パッシブツリー切り替え計画

**Date**: 2026-02-09
**Task**: PoE1→PoE2パッシブツリー切り替え
**Version**: V1

---

## 1. 原因分析

**症状**: アプリがPoE1のパッシブツリー（3_27）を表示する
**根本原因**: `latestTreeVersion = "3_27"` → PoE2データ（TreeData/0_1〜0_4）は存在するが `GameVersions.lua` に未登録

**連鎖的問題**:
- PassiveTree.lua の `versionNum >= 3.10` チェックがPoE2 (0.04) でFALSE → 旧フォーマット扱い
- Line 460: `versionNum < 3.10` がTRUE → 新フォーマットを旧フォーマットに変換しようとする（逆方向）
- classArt テーブルにPoE2クラスなし

---

## 2. 修正案

### File 1: `src/GameVersions.lua`
- `treeVersionList` 末尾に `"0_1", "0_2", "0_3", "0_4"` 追加
- `treeVersions` に4エントリ追加（display, num, url）
- `latestTreeVersion` は自動的に `"0_4"` に（リスト末尾参照）

### File 2: `src/Classes/PassiveTree.lua`
**変更A**: `isNewFormat` フラグ導入（line 54付近）
```lua
local isNewFormat = versionNum >= 3.10 or versionNum < 1.0
```

**変更B**: 全14箇所の `versionNum >= 3.10` / `< 3.10` を `isNewFormat` / `not isNewFormat` に置換

**変更C**: クラス移行ループをPoE2対応（動的上限）

**変更D**: PoE2 `classesStart` → `classStartIndex` 変換

**変更E**: classArt テーブルにPoE2クラス追加

### File 3: `src/Modules/Data.lua`
- `setJewelRadiiGlobally`: PoE2 (major < 1) → 3_16 radii をデフォルトに

---

## 3. 実装手順

| Step | File | Agent | Dependency |
|------|------|-------|-----------|
| 1 | GameVersions.lua | SubAgent A | None |
| 2 | PassiveTree.lua | SubAgent B | None (独立) |
| 3 | Data.lua | SubAgent C | None (独立) |
| 4 | Bundle copy | Main | Steps 1-3 |
| 5 | Launch test | User | Step 4 |

Step 1-3 は並列実行可能。

---

## 4. リスク・ロールバック

**リスク**: Medium
- PassiveTree.lua の変更箇所が多い（14箇所）→ 1箇所でもミスるとツリー表示崩壊
- PoE2クラスデータの実際の構造が予測と異なる可能性

**ロールバック**:
```bash
git checkout -- src/GameVersions.lua src/Classes/PassiveTree.lua src/Modules/Data.lua
cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/
```

**緩和策**:
- 禁止パターン遵守: 1ファイルずつテストしたいが、3ファイル同時変更が必要（GameVersions未登録だとPTロード不可）
- pcall で囲まれたツリーロードは非致命的エラーになる

---

## 5. 成功基準

1. アプリ起動成功（クラッシュなし）
2. パッシブツリーが表示される（PoE2のノード配置）
3. PoE2クラス名がクラスドロップダウンに表示される
4. ノードクリック→アロケート動作
5. `passive_tree_app.log` に `ERROR in OnInit` なし

---

## 6点レビュー

| # | Question | Answer | Score |
|---|----------|--------|-------|
| 1 | 原因が明確か？ | ✅ GameVersions未登録 + versionNum条件分岐 | ✓ |
| 2 | 技術的に妥当か？ | ✅ isNewFormatフラグで既存ロジック活用 | ✓ |
| 3 | リスクが低い/管理可能か？ | ⚠️ 14箇所変更だが全て同パターン、ロールバック容易 | ✓ |
| 4 | ロールバックが容易か？ | ✅ git checkout で即復元 | ✓ |
| 5 | 視覚確認計画があるか？ | ✅ ツリー表示 + クラス名 + ノードクリック | ✓ |
| 6 | タイムラインが現実的か？ | ✅ 3並列サブエージェント + テスト = ~30min | ✓ |

**Score: 6/6** → 自動承認推奨

---

## 適用した教訓TOP3

1. **PassiveTree ClassStart接続ロジック**: classesStart の AND/OR 条件に注意（LESSONS_LEARNED）
2. **Nil-Safety必須**: PoE2データ構造の全チェーンを検証（LESSONS_LEARNED）
3. **ConPrintf %s+tostring()**: デバッグ出力は安全フォーマット使用（MEMORY.md）
