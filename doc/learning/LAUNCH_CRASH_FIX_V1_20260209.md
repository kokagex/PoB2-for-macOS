# Launch Crash Fix - ModParser.lua:1957

## Date: 2026-02-09

## 原因分析

### 症状
- アプリが起動しない（ウィンドウが一瞬も表示されない）
- stdout/stderrに出力なし（exec でログにリダイレクトされるため）
- `/tmp/pob_error.txt` なし（OnInit内のクラッシュでLua error handlerに到達しない）

### ログ出力
```
ERROR in OnInit: src/Modules/ModParser.lua:1957: attempt to index field 'skills' (a nil value)
```

### 根本原因
`ModParser.lua:1957`:
```lua
local gemId = data.gemForBaseName[(data.skills[skillId].name .. " Support"):lower()]
```
- `data.skills[skillId]` が特定のskillIdに対してnilを返す
- `data.skills` テーブル自体は存在する（Data.lua:882で初期化）
- 一部のスキルIDがデータファイルに定義されていない（PoE2データの不完全性）

## 修正案

**1行のnilガード追加**:
```lua
-- Before (crashes)
local gemId = data.gemForBaseName[(data.skills[skillId].name .. " Support"):lower()]

-- After (safe)
local skillData = data.skills[skillId]
if not skillData then return end
local gemId = data.gemForBaseName[(skillData.name .. " Support"):lower()]
```

## 実装手順
1. ModParser.lua:1957の前にnilガードを追加
2. バンドルにコピー
3. 起動テスト

## リスク・ロールバック
- **リスク**: Low - nilガードのみ、既存ロジックに変更なし
- **ロールバック**: nilガード行を削除するだけ

## 成功基準
- アプリが起動してBuild Listが表示される
- ログにERROR in OnInitがない

## 6点レビュー
1. ✅ 原因明確: ログに正確なエラー位置
2. ✅ 技術的妥当: nilガードはPoB標準パターン
3. ✅ リスク低い: 1行追加のみ
4. ✅ ロールバック容易: 1行削除
5. ✅ 視覚確認: アプリ起動確認
6. ✅ タイムライン現実的: 5分

**Score: 6/6**
