# Tooltip Background + Average Damage Display Fix Plan V1

## Issue 1: Skill Tooltip White Background

### 原因分析
- `GemSelectControl.lua:817`: 偶数行に `"GemHoverModBg"` 背景を設定
- `Tooltip.lua:481`: `Assets/GemHoverModBg.png` をロード試行
- **アセットファイルが存在しない** → LoadImage失敗
- `Tooltip.lua:491`: `SetDrawColor(1,1,1,1)` → 白色で描画
- 結果: 画像なしで白い矩形が描画される

### 修正案
**GemSelectControl.lua:817** の背景指定を無効化（nilに固定）

```lua
-- 変更前
local bg = (i % 2 == 0) and "GemHoverModBg" or nil
-- 変更後
local bg = nil  -- GemHoverModBg.png asset not available on macOS
```

シンプルで確実。アセットを追加する方法もあるが、元のアセットが手元にないためnil化が安全。

### リスク: LOW
- 見た目のみの変更。機能への影響なし
- ロールバック: 1行戻すだけ

---

## Issue 2: Average Damage Not Showing in Calcs Tab

### 原因分析
- `CalcSections.lua:317`: `flag = "attack"` → 攻撃スキルのみ表示
- `CalcSections.lua:327`: `haveOutput = "enemyHasSpellBlock"` → ブロック持ち敵のみ
- スペル・属性スキルの場合、どちらの条件も満たさない → 表示されない
- `CalcOffence.lua:3475`: `output.AverageDamage` は全スキルで計算済み

### 修正案
`CalcSections.lua:317`の直後に、`hit`フラグ（spell含む）用のAverage Damage行を追加:

```lua
{ label = "Average Damage", flag = "hit", notFlag = "attack", { format = "{1:output:AverageDamage}",
    { breakdown = "AverageDamage" },
}, },
```

`flag = "hit"` はスペルを含むヒット系スキル全般。`notFlag = "attack"` で攻撃スキルとの重複を防止。

### リスク: LOW
- 既存の攻撃スキル表示には影響なし（notFlagで除外）
- 新しい行を追加するだけで既存行は変更なし

---

## 実装手順
1. GemSelectControl.lua:817 修正 (サブエージェント)
2. CalcSections.lua:317付近に行追加 (サブエージェント)
3. ファイル同期 (cp -r)
4. 視覚確認

## 成功基準
1. スキルツールチップに白い背景が表示されない
2. CalcsタブでAverage Damageが表示される

---

## 6点レビュー
1. 原因が明確か？ ✅ アセット欠如 + flag条件
2. 技術的に妥当か？ ✅ 最小限の変更
3. リスクが低い/管理可能か？ ✅ LOW
4. ロールバックが容易か？ ✅ 各1行の変更
5. 視覚確認計画があるか？ ✅ アプリ起動→スクショ
6. タイムラインが現実的か？ ✅ 15分

**Score: 6/6**
