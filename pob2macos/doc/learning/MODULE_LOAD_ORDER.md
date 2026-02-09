# モジュールロード順序分析

## Executive Summary

Windows版PoB2のモジュールロード順序を分析し、ModList.luaが正常に動作するために必要な依存関係を特定しました。現在のmacOS版Launch.luaには**5つの重要なモジュール**が欠落しており、これがModListエラーの根本原因です。

## Windows版のロード順序

### Launch.lua (エントリーポイント)
```lua
-- Line 71
errMsg, self.main = PLoadModule("Modules/Main")
```

### Main.lua (コアモジュールローダー)
```lua
-- Lines 17-23
LoadModule("GameVersions")          -- 1. ゲームバージョン定数
LoadModule("Modules/Common")        -- 2. 共通ライブラリ、クラスシステム
LoadModule("Modules/Data")          -- 3. ゲームデータ (Global.luaを内包)
LoadModule("Modules/ModTools")      -- 4. modLib (createMod, parseMod, compareModParams)
LoadModule("Modules/ItemTools")     -- 5. itemLib (アイテム処理)
LoadModule("Modules/CalcTools")     -- 6. calcLib (計算ヘルパー)
LoadModule("Modules/BuildSiteTools")-- 7. buildSites (ビルドインポート)
```

### Data.lua (内部依存)
```lua
-- Line 7
LoadModule("Data/Global")  -- ★ AND64, OR64, ModFlag, KeywordFlag を定義
```

### Common.lua (クラスローダー)
```lua
-- Lines 68-74
function getClass(className)
    local class = common.classes[className]
    if not class then
        LoadModule("Classes/"..className)  -- ★ ModStore, ModList を遅延ロード
        class = common.classes[className]
    end
    return class
end
```

## ModList依存関係ツリー

```
ModList.lua (Classes/)
├── ModStore.lua (親クラス) ← newClass("ModStore") が必要
│   ├── modLib.createMod ← ModTools から提供
│   ├── AND64, OR64 ← Data/Global から提供
│   ├── data.highPrecisionMods ← Data から提供
│   └── copyTable ← Common から提供
├── modLib.createMod ← ModTools から提供 (line 17)
├── modLib.compareModParams ← ModTools から提供 (line 51)
├── modLib.formatMod ← ModTools から提供 (line 248)
├── AND64 (bit.band) ← Data/Global から提供 (line 14)
├── OR64 (bit.bor) ← Data/Global から提供 (line 15)
├── MatchKeywordFlags ← Data/Global から提供 (line 82)
└── newClass() ← Common から提供
    └── Classes/ModStore.lua を自動ロード

┌─────────────────────────────────────────┐
│ 依存解決の順序                             │
├─────────────────────────────────────────┤
│ 1. Common (newClass, copyTable)         │
│ 2. Data (Data/Global を内部でロード)      │
│    └── AND64, OR64, ModFlag, KeywordFlag │
│ 3. ModTools (modLib.*)                  │
│ 4. ModStore.lua (CommonがnewClass時に自動) │
│ 5. ModList.lua (上記全てに依存)           │
└─────────────────────────────────────────┘
```

## macOS版Launch.luaの現状

### 現在ロードされているモジュール
```lua
-- Lines 73-74 (PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua)
LoadModule("GameVersions")
LoadModule("Modules/Common")
```

### 欠落しているモジュール (5つ)
```lua
LoadModule("Modules/Data")          -- ❌ 欠落 → AND64, OR64, ModFlag未定義
LoadModule("Modules/ModTools")      -- ❌ 欠落 → modLib未定義
LoadModule("Modules/ItemTools")     -- ❌ 欠落 → itemLib未定義
LoadModule("Modules/CalcTools")     -- ❌ 欠落 → calcLib未定義
LoadModule("Modules/BuildSiteTools")-- ❌ 欠落 → buildSites未定義
```

## エラー原因の技術的分析

### エラーメッセージ
```
attempt to call a nil value (global 'modLib')
```

### 根本原因
1. **ModTools未ロード** → `modLib = {}` が未初期化
2. **Data/Global未ロード** → `AND64`, `OR64`, `ModFlag`, `KeywordFlag` が未定義
3. **ModStore未ロード** → `newClass("ModList", "ModStore")` が親クラスを見つけられない

### エラー発生箇所 (ModList.lua)
```lua
-- Line 17: modLibが未定義
local mod_createMod = modLib.createMod  -- ❌ modLib = nil

-- Line 14-15: AND64, OR64が未定義
local band = AND64  -- ❌ AND64 = nil
local bor = OR64    -- ❌ OR64 = nil

-- Line 19: ModStoreクラスが見つからない
local ModListClass = newClass("ModList", "ModStore", function(self, parent)
    self.ModStore(parent)  -- ❌ ModStoreが未ロード
end)
```

## macOS版への実装提案

### Phase 1: 最小限の修正 (ModListのみ動作)

```lua
-- PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua
-- Lines 72-74を以下に置き換え

-- Load core modules (順序重要)
LoadModule("GameVersions")
LoadModule("Modules/Common")        -- newClass(), copyTable()
LoadModule("Modules/Data")          -- Data/Global (AND64, OR64, ModFlag, KeywordFlag)
LoadModule("Modules/ModTools")      -- modLib (createMod, parseMod, compareModParams)
```

**理由**:
- ItemTools, CalcTools, BuildSiteToolsはPassiveTreeView描画に直接必要ない
- 最小限のモジュールでModListを動作させる

### Phase 2: 完全互換 (全機能動作)

```lua
-- Load core modules (Windows版Main.luaと同じ順序)
LoadModule("GameVersions")
LoadModule("Modules/Common")
LoadModule("Modules/Data")
LoadModule("Modules/ModTools")
LoadModule("Modules/ItemTools")     -- アイテム処理が必要な場合
LoadModule("Modules/CalcTools")     -- 計算機能が必要な場合
LoadModule("Modules/BuildSiteTools")-- ビルドインポートが必要な場合
```

**理由**:
- PassiveSpec.luaはアイテムとの相互作用を持つ可能性がある
- TreeTab.luaが将来的に計算機能を使う可能性がある

### Phase 3: データ初期化の追加

```lua
-- PassiveSpec作成前に必要なデータ構造を初期化
data = data or {}
data.highPrecisionMods = data.highPrecisionMods or {}
data.defaultHighPrecision = 2
data.gameConstants = data.gameConstants or {
    PassiveTreeJewelDistanceMultiplier = 1,
}
```

**理由**:
- ModStore.luaのEvalMod()がdata.highPrecisionModsを参照 (line 62)
- Data.luaが完全ロードされない場合のフォールバック

## 推奨実装順序

### Step 1: 既存コードのバックアップ
```bash
cp PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua \
   PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua.backup
```

### Step 2: Launch.luaの修正
```lua
-- Line 72-74を以下に置き換え
LoadModule("GameVersions")
LoadModule("Modules/Common")
LoadModule("Modules/Data")
LoadModule("Modules/ModTools")
```

### Step 3: 同期とテスト
```bash
# ソースを同期
cp src/Launch.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/

# アプリ実行
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_test.log

# エラーログ確認
grep -i "error\|nil" ~/pob_test.log
```

### Step 4: エラーハンドリングの追加 (オプション)
```lua
-- Launch.lua OnInit()内
local modules = {
    "GameVersions",
    "Modules/Common",
    "Modules/Data",
    "Modules/ModTools",
}

for _, modulePath in ipairs(modules) do
    local result = LoadModule(modulePath)
    if not result then
        ConPrintf("CRITICAL: Failed to load %s", modulePath)
        return
    end
    ConPrintf("Loaded: %s", modulePath)
end

-- モジュールが正常にロードされたか検証
if not modLib or not modLib.createMod then
    ConPrintf("ERROR: modLib not initialized")
    return
end
if not AND64 or not OR64 then
    ConPrintf("ERROR: Bitwise operations not available")
    return
end
ConPrintf("All required modules loaded successfully")
```

## 注意事項

### 1. ロード順序の厳守
**絶対に守るべき順序**:
```
Common → Data → ModTools → (他のツール)
```

**理由**:
- Commonがクラスシステムを提供
- DataがData/Globalをロード (AND64, OR64, ModFlag)
- ModToolsがmodLibを初期化 (Dataに依存)

### 2. Data.luaの副作用
Data.luaは以下を**自動的にロード**します:
- `Data/Global.lua` (line 7)
- `Data/Misc.lua` (line 115)
- `Data/ModCache.lua` (Main.luaがロードする場合)

**重要**: Data.luaは292MBのゲームデータをロードします。パフォーマンスに注意。

### 3. MINIMAL_PASSIVE_TEST モード
現在のLaunch.luaは`_G.MINIMAL_PASSIVE_TEST = true`を設定しています。これにより:
- 完全なModList機能は動作しない可能性がある
- テスト用の簡易ModListが使われる可能性がある

**対策**:
- Phase 1の実装後、`MINIMAL_PASSIVE_TEST`フラグを削除
- フル機能のModListを使用

### 4. ModCacheの扱い
Main.luaは条件付きでModCacheをロードします:
```lua
-- Main.lua lines 121-128
if launch.devMode and IsKeyDown("CTRL") or os.getenv("REGENERATE_MOD_CACHE") == "1" then
    self.saveNewModCache = true
else
    LoadModule("Data/ModCache", modLib.parseModCache)
end
```

**macOS版の対応**:
- 最初は`Data/ModCache.lua`をスキップ (LoadModuleを呼ばない)
- ModCacheなしでもmodLib.parseMod()は動作する (遅いが機能する)

### 5. テスト時の確認ポイント
```lua
-- PassiveSpec作成後に以下を確認
ConPrintf("DEBUG: spec.nodes count = %d", spec.nodes and #spec.nodes or 0)
ConPrintf("DEBUG: spec.allocNodes count = %d", spec.allocNodes and tableCount(spec.allocNodes) or 0)

-- 各ノードのmodListを確認
for nodeId, node in pairs(spec.nodes) do
    if node.modList then
        ConPrintf("Node %s has %d mods", nodeId, #node.modList)
        break  -- 1つ確認できればOK
    end
end
```

## 動作検証チェックリスト

- [ ] `modLib` がグローバルに定義されている
- [ ] `AND64`, `OR64` が関数として定義されている
- [ ] `ModFlag`, `KeywordFlag` がテーブルとして定義されている
- [ ] `common.classes["ModStore"]` が存在する
- [ ] `common.classes["ModList"]` が存在する
- [ ] PassiveSpec作成時にエラーが出ない
- [ ] `spec.nodes[nodeId].modList` が存在する
- [ ] PassiveTreeView描画でクラッシュしない

## トラブルシューティング

### エラー: "attempt to call a nil value (global 'modLib')"
**原因**: ModToolsが未ロード
**対策**: LoadModule("Modules/ModTools")を追加

### エラー: "attempt to call a nil value (global 'AND64')"
**原因**: Data/Globalが未ロード
**対策**: LoadModule("Modules/Data")を追加

### エラー: "Class 'ModStore' not defined in class file"
**原因**: Commonが自動ロードする前にModListが呼ばれた
**対策**: newClass("ModList", "ModStore")を呼ぶ前にCommonをロード

### エラー: "attempt to index a nil value (global 'data')"
**原因**: Dataモジュール未ロードまたは初期化されていない
**対策**: LoadModule("Modules/Data")の後にdataテーブルを確認

## 参考情報

### Windows版ファイル構造
```
/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/
├── Launch.lua                      (エントリーポイント)
├── GameVersions.lua
├── Modules/
│   ├── Main.lua                    (モジュールローダー)
│   ├── Common.lua                  (クラスシステム)
│   ├── Data.lua                    (ゲームデータ)
│   ├── ModTools.lua                (modLib)
│   ├── ItemTools.lua               (itemLib)
│   ├── CalcTools.lua               (calcLib)
│   └── BuildSiteTools.lua          (buildSites)
├── Data/
│   ├── Global.lua                  (AND64, OR64, ModFlag, KeywordFlag)
│   └── ...
└── Classes/
    ├── ModStore.lua                (親クラス)
    ├── ModList.lua                 (ModStoreを継承)
    └── ...
```

### macOS版ファイル構造
```
/Users/kokage/national-operations/pob2macos/
├── src/Launch.lua                  (テスト用エントリーポイント)
└── PathOfBuilding.app/
    └── Contents/Resources/pob2macos/
        └── src/
            ├── Launch.lua          (実際のエントリーポイント)
            ├── (Windows版と同じ構造)
            └── ...
```

### 関連ドキュメント
- `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/PASSIVE_TREE_DIAGNOSTIC.md`
- `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/CRITICAL_FIXES_REPORT.md`
- `/Users/kokage/national-operations/pob2macos/.claude/CLAUDE.md`

---

**作成日**: 2026-02-04
**分析対象**: PathOfBuilding PoE2 dev (Windows版)
**対象プラットフォーム**: macOS (pob2macos)
**分析者**: Claude Sonnet 4.5
