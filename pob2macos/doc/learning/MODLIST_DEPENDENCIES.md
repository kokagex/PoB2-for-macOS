# ModList.lua 依存関係分析

**ファイル**: `/Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/ModList.lua`

**分析日**: 2026-02-04

---

## 概要

ModList.luaは、ModStoreクラスを継承したモディファイアのフラットリストを管理するクラスです。PassiveTreeView.luaの最小実装に必要な依存関係を以下に整理します。

---

## 外部依存関係

### 1. 親クラス

```lua
local ModListClass = newClass("ModList", "ModStore", function(self, parent)
    self.ModStore(parent)
end)
```

**依存**: `ModStore` クラス (src/Classes/ModStore.lua)
- ModStoreは866行の大規模なクラス
- 複雑なmod評価ロジックを含む

### 2. modLib関数

ModList.luaで使用される3つのmodLib関数:

```lua
local mod_createMod = modLib.createMod          -- Line 17
modLib.compareModParams(self[i], mod)           -- Line 51
modLib.formatMod(mod)                           -- Line 248
```

**問題**: modLibは明示的に定義されているファイルが見つからない
- グローバル変数として他のモジュールで初期化されている可能性
- 実装が必要な場合、これらの関数を自作する必要がある

### 3. Lua標準ライブラリ (ローカル最適化済み)

```lua
local ipairs = ipairs
local pairs = pairs
local select = select
local t_insert = table.insert
local m_floor = math.floor
local m_min = math.min
local m_max = math.max
local m_modf = math.modf
```

### 4. ビット演算関数

```lua
local band = AND64  -- bit.band
local bor = OR64    -- bit.bor
```

**実装場所**: src/Data/Global.lua (Line 108, 136)
- LuaJIT 5.1では64ビット整数演算が必要
- AND64, OR64, XOR64, NOT64がGlobal.luaに実装済み

### 5. ユーティリティ関数

#### copyTable
**実装場所**: src/Modules/Common.lua (Line 419)
```lua
function copyTable(tbl, noRecurse)
    local out = {}
    for k, v in pairs(tbl) do
        if not noRecurse and type(v) == "table" then
            out[k] = copyTable(v)
        else
            out[k] = v
        end
    end
    return out
end
```

#### MatchKeywordFlags
**実装場所**: src/Data/Global.lua (Line 311)
```lua
function MatchKeywordFlags(keywordFlags, modKeywordFlags)
    -- 2段階の数値キーキャッシュを使用
    -- "MatchAll"フラグ対応の複雑なロジック
end
```

#### round
**実装場所**: src/Modules/Common.lua (Line 646)
```lua
function round(val, dec)
    if dec then
        local factor = 10 ^ dec
        return math.floor(val * factor + 0.5) / factor
    else
        return select(1, math.modf(val + 0.5))
    end
end
```

#### newClass
**実装場所**: src/Modules/Common.lua (Line 78)
- クラスシステムの基盤関数
- 継承、メタテーブル設定を管理

### 6. グローバルデータ

```lua
data.highPrecisionMods[mod.name]        -- Line 112, 114
```

**依存**: グローバルな`data`テーブル
- highPrecisionModsは特定のmod名に対する精度設定を保持
- ModListとModStoreの両方で使用される

### 7. デバッグ関数

```lua
ConPrintf("%s|%s", modLib.formatMod(mod), mod.source or "?")  -- Line 248
```

**依存**: ConPrintf (コンソール出力関数)

### 8. その他のグローバル

```lua
nullValue  -- Line 182 (ModListClass:ListInternal内で使用)
```

---

## ModStoreクラスの依存関係

ModListはModStoreを継承しているため、ModStoreの全メソッドと依存関係を引き継ぎます。

**ModStore主要メソッド**:
- ScaleAddMod, CopyList, ScaleAddList
- NewMod, ReplaceMod, Combine
- Sum, More, Flag, Override, List, Tabulate
- HasMod, GetCondition, GetMultiplier, GetStat
- **EvalMod** (304行の複雑な評価関数)

**ModStore内部メソッド** (ModListでオーバーライド):
- SumInternal (Line 76)
- MoreInternal (Line 97)
- FlagInternal (Line 131)
- OverrideInternal (Line 152)
- ListInternal (Line 174)
- TabulateInternal (Line 197)
- HasModInternal (Line 227)
- ReplaceModInternal (Line 32)

---

## modLib未実装関数の影響

modLib関数が未定義の場合、以下のModListメソッドが動作不可:

### 1. modLib.createMod
**影響メソッド**:
- MergeNewMod (Line 71-73)
- NewMod (ModStore経由)
- ReplaceMod (ModStore経由)

### 2. modLib.compareModParams
**影響メソッド**:
- MergeMod (Line 48-61)

### 3. modLib.formatMod
**影響メソッド**:
- Print (Line 246-250)

---

## 必要な最小実装

PassiveTreeView.luaで最小限の動作を実現するための優先順位:

### レベル1: 必須 (動作不可になる)

1. **newClass関数**
   - 理由: ModListクラス自体を定義できない
   - 実装: Common.lua全体をロード、または最小限のnewClassを実装

2. **ModStoreクラス**
   - 理由: ModListの親クラス
   - 実装: ModStore.luaをロード、またはスタブ実装

3. **AND64関数**
   - 理由: 全ての*Internal関数でフラグ比較に使用
   - 実装: Global.luaからAND64をインポート

4. **MatchKeywordFlags関数**
   - 理由: 全ての*Internal関数でキーワードマッチングに使用
   - 実装: Global.luaからインポート

5. **copyTable関数**
   - 理由: MergeMod内でmodのコピーに使用
   - 実装: Common.luaからインポート

### レベル2: 推奨 (機能制限あり)

6. **round関数**
   - 理由: MoreInternal内でMOREモディファイアの精度処理に使用
   - 回避策: 精度処理をスキップ (結果が不正確になる)
   - 実装: Common.luaからインポート

7. **data.highPrecisionMods**
   - 理由: MoreInternalとScaleAddModで高精度計算に使用
   - 回避策: nil許容で処理 (既存コードはnil対応済み)
   - 実装: 空テーブル `data = { highPrecisionMods = {} }` で十分

8. **modLib.createMod**
   - 理由: MergeNewMod, NewMod, ReplaceModで使用
   - 回避策: これらのメソッドを呼び出さない
   - 実装: 最小スタブ `function(name, type, value, ...) return {name=name, type=type, value=value} end`

### レベル3: オプション (デバッグのみ)

9. **modLib.compareModParams**
   - 理由: MergeMod内でmod比較に使用
   - 回避策: MergeModを使わず、AddModのみ使用

10. **modLib.formatMod**
    - 理由: Printメソッドのみで使用 (デバッグ用)
    - 回避策: Printメソッドを呼び出さない
    - 実装: スタブ `function(mod) return tostring(mod.name) end`

11. **ConPrintf**
    - 理由: Printメソッドのみで使用
    - 回避策: print()で代替

12. **nullValue**
    - 理由: ListInternal内のnil回避に使用
    - 回避策: nil許容で処理

---

## 実装戦略

### フェーズ1: スタブ実装 (最速で動作確認)

PassiveTreeView.luaの前に最小限のスタブを配置:

```lua
-- 最小限のスタブ実装
data = { highPrecisionMods = {}, defaultHighPrecision = 2 }
modLib = {}

function modLib.createMod(name, type, value, source, ...)
    return {
        name = name,
        type = type,
        value = value,
        source = source,
        flags = 0,
        keywordFlags = 0
    }
end

function modLib.compareModParams(mod1, mod2)
    return mod1.name == mod2.name
        and mod1.type == mod2.type
        and mod1.flags == mod2.flags
        and mod1.keywordFlags == mod2.keywordFlags
        and mod1.source == mod2.source
end

function modLib.formatMod(mod)
    return string.format("%s %s %s", mod.name or "?", mod.type or "?", tostring(mod.value or 0))
end

-- ConPrintfスタブ
function ConPrintf(fmt, ...)
    print(string.format(fmt, ...))
end

-- nullValueスタブ
nullValue = {}

-- ModStoreスタブ (最小限のダミー実装)
local ModStoreClass = newClass("ModStore", function(self, parent)
    self.parent = parent or false
    self.actor = parent and parent.actor or {}
    self.multipliers = {}
    self.conditions = {}
end)

function ModStoreClass:AddMod(mod)
    -- ModListでオーバーライドされるため空実装
end

function ModStoreClass:ReplaceModInternal(mod)
    return false
end
```

### フェーズ2: 必須関数のインポート

Common.luaとGlobal.luaから実関数をロード:

```lua
-- Common.lua から必要な関数をロード
dofile("src/Modules/Common.lua")
-- これで newClass, copyTable, round が利用可能

-- Global.lua から必要な関数をロード
dofile("src/Data/Global.lua")
-- これで AND64, OR64, MatchKeywordFlags, ModFlag, KeywordFlag が利用可能
```

**注意**: dofileすると大量の依存関係が読み込まれる可能性あり

### フェーズ3: 段階的な完全実装

必要に応じて実際のModStoreクラスをロード:

```lua
dofile("src/Classes/ModStore.lua")
dofile("src/Classes/ModList.lua")
```

---

## PassiveTreeView.luaでの使用パターン

PassiveTreeView.luaでModListがどう使われているか確認が必要:

**推測される使用例**:
```lua
-- パッシブノードのモディファイアをModListに追加
local modList = new("ModList")
for _, mod in ipairs(node.modList) do
    modList:AddMod(mod)
end

-- モディファイアの合計値を取得
local value = modList:Sum("INC", nil, "Life")
```

**確認コマンド**:
```bash
grep -n "ModList\|modList" /path/to/PassiveTreeView.lua
```

---

## 推奨アプローチ

### アプローチA: 完全ロード (推奨)

最も安全で確実な方法:

```lua
-- 1. 基盤モジュールをロード
dofile("src/Modules/Common.lua")
dofile("src/Data/Global.lua")

-- 2. modLibを適切に初期化 (初期化コードを探す)
-- または最小スタブで代替

-- 3. ModStoreとModListをロード
dofile("src/Classes/ModStore.lua")
dofile("src/Classes/ModList.lua")
```

**メリット**:
- 完全な互換性
- 将来的な拡張に対応

**デメリット**:
- 多数の依存関係を引き込む可能性
- 初期化順序の問題が発生しやすい

### アプローチB: 最小スタブ (高速プロトタイピング)

PassiveTreeView.luaが実際に使用するメソッドのみ実装:

```lua
-- 最小限のModListスタブ
local ModListClass = {}
ModListClass.__index = ModListClass

function ModListClass.new()
    return setmetatable({}, ModListClass)
end

function ModListClass:AddMod(mod)
    table.insert(self, mod)
end

function ModListClass:Print()
    for _, mod in ipairs(self) do
        print(mod.name, mod.type, mod.value)
    end
end

return ModListClass
```

**メリット**:
- 依存関係ゼロ
- 問題の切り分けが容易

**デメリット**:
- 機能が大幅に制限される
- 後でリファクタリングが必要

### アプローチC: 選択的ロード (バランス型)

実際に使用される機能のみを段階的にロード:

1. PassiveTreeView.luaでModListの使用箇所を特定
2. 必要なメソッドのみ実装
3. 不足する依存関係を追加

**ステップ**:
```bash
# 1. PassiveTreeView.luaの分析
grep -n "ModList\|modList" PassiveTreeView.lua

# 2. 使用メソッドの特定
grep -n ":AddMod\|:Sum\|:More\|:Flag" PassiveTreeView.lua

# 3. 必要最小限の実装を追加
```

---

## 次のステップ

1. **PassiveTreeView.luaの依存関係分析**
   ```bash
   grep -rn "ModList\|modList" /path/to/PassiveTreeView.lua > modlist_usage.txt
   ```

2. **modLibの定義場所を特定**
   ```bash
   grep -rn "^modLib\s*=" /path/to/src/
   grep -rn "LoadModule.*Mod" /path/to/src/
   ```

3. **最小実装のテスト**
   - スタブModListを作成
   - PassiveTreeView.luaで読み込みテスト
   - エラーを確認して段階的に依存関係を追加

4. **完全実装への移行**
   - スタブで動作確認後、実際のModList.luaをロード
   - 依存関係の初期化順序を調整

---

## まとめ

**ModList.luaの依存関係の複雑さ**: ★★★★☆ (高い)

**主要な課題**:
1. ModStoreクラスの866行の複雑な実装
2. modLibの定義場所が不明 (要調査)
3. 64ビット整数演算 (AND64, OR64) の必要性
4. グローバルな`data`テーブルの初期化

**推奨戦略**:
- **短期**: スタブ実装で動作確認 (フェーズ1)
- **中期**: 必須関数のみロード (フェーズ2)
- **長期**: 完全なModList/ModStoreをロード (フェーズ3)

**次の分析対象**:
- PassiveTreeView.luaでのModList使用パターン
- modLibの実装場所と初期化方法
- PassiveSpec.luaとPassiveTree.luaの依存関係
