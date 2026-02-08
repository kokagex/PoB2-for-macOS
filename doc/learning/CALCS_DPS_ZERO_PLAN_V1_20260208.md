# Calcsタブ DPS 0.0 診断・修正 計画 V1

**Date**: 2026-02-08
**Task**: Bowを装備してもCalcsタブでDPS=0.0と表示される問題の修正

---

## 原因分析

### 症状
- ItemsタブでBow（弓）を装備済み
- CalcsタブでDPS関連の値が全て0.0
- セクション（Speed, Crit, Damage等）自体は表示される → BuildOutputは実行されている

### データフロー
```
ItemsTab: items[slotId] → CalcSetup:1397 → env.player.weaponData1
→ CalcOffence:1904 → source = copyTable(actor.weaponData1)
→ CalcOffence:3057 → source.PhysicalMin/Max → DPS
```

### 仮説（3つ）

**仮説A（最有力）: BuildOutput PCallがエラーを握り潰している**
- Build.lua:113 `PCall(self.calcsTab.BuildOutput, self.calcsTab)` がエラーキャッチ
- エラー発生時、fallbackでDPS=0のまま表示
- CalcSetup/CalcOffenceのどこかでnilアクセスエラーの可能性

**仮説B: item.weaponDataが未生成**
- ItemsTabからbow選択時、weaponDataはBuildAndParseRaw()実行時のみ生成
- DBからの参照がraw parsingを経由していない場合、weaponData=nil → unarmed fallback

**仮説C: weaponData2の空テーブル問題**
- CalcSetup.lua:1410,1412で `weaponData2 = {}` (空テーブル)
- PhysicalMin/PhysicalMaxが欠落 → CalcOffence:3057で `(source[key] or 0)` = 0
- ただしこれはweaponData2（オフハンド）の問題でweaponData1（メインハンド）には影響しないはず

---

## 修正案

### Step 1: 仮説Aの検証（ターミナルログ確認）
ユーザーにターミナルから起動を依頼し、BuildOutputのエラーメッセージを確認。

**テスト手順**:
1. ターミナルで `./PathOfBuilding.app/Contents/MacOS/PathOfBuilding` を起動
2. ビルドを開き、Itemsタブでbowを装備
3. Calcsタブに切り替え
4. ターミナル出力に `WARNING: BuildOutput failed` があるか確認
5. **やらないこと**: スクリーンショット不要、操作は最小限

### Step 2: エラーがある場合
スタックトレースから特定のnilアクセス箇所を修正。サブエージェントに委譲。

### Step 3: エラーがない場合（仮説B/C）
CalcSetup.lua:1397付近に1行の診断ログを追加して確認。

---

## 実装手順

| # | 内容 | 担当 | 依存 |
|---|------|------|------|
| 1 | ターミナルログ確認 | ユーザー | なし |
| 2 | エラー箇所特定・修正 | サブエージェント | Step 1 |
| 3 | バンドル同期 | メインエージェント | Step 2 |
| 4 | 再テスト | ユーザー | Step 3 |

---

## リスク・ロールバック

- **リスク**: Low - 診断→修正のアプローチ、破壊的変更なし
- **ロールバック**: git checkout で対象ファイルを戻す
- **影響範囲**: CalcSetup.lua / CalcOffence.lua / Build.lua のみ

---

## 成功基準

1. ターミナルに `WARNING: BuildOutput failed` が出ない
2. Bow装備後、CalcsタブでDPS > 0 が表示される
3. 既存機能（パッシブツリー、タブ切替等）に影響なし

---

## 6点レビュー

| # | 質問 | 評価 |
|---|------|------|
| 1 | 原因が明確か？ | ✓ 3仮説を優先順位付けで提示 |
| 2 | 技術的に妥当か？ | ✓ ターミナルログ→消去法は確実 |
| 3 | リスクが低い/管理可能か？ | ✓ 診断優先、最小限の変更 |
| 4 | ロールバックが容易か？ | ✓ git checkout で即戻し |
| 5 | 視覚確認計画があるか？ | ✓ DPS > 0 の表示確認 |
| 6 | タイムラインが現実的か？ | ✓ Step 1で30分以内に方向決定 |

**Score: 6/6** → 自動承認推奨
