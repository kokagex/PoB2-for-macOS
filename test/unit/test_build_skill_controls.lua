-- test/unit/test_build_skill_controls.lua
-- RefreshSkillSelectControls が「代入・メソッド呼び出し」で触る control が
-- Build.lua の InitMinimal / Init で必ず生成されることを保証する。
-- 背景 (2026-06-19): 上流 sync (Phase 8a) が RefreshSkillSelectControls に
-- `controls.mainSkillBeastLibrary.shown = (...)` を取り込んだが、対応する
-- `self.controls.mainSkillBeastLibrary = new("ButtonControl", ...)` の生成を
-- InitMinimal / Init に追加し忘れ、Companion スキルを main にすると OnFrame で
-- "attempt to index field 'mainSkillBeastLibrary' (a nil value)" でクラッシュした。
-- 上流マージは「参照側」と「生成側」を別箇所で扱うため、片方だけ取り込む事故が
-- 起きやすい。このテストはその参照/生成ペアの取りこぼしを commit 前に検知する。
require("test_helpers")

local BUILD = "src/Modules/Build.lua"

local function readFile(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local src = f:read("*a")
    f:close()
    return src
end

-- RefreshSkillSelectControls の関数本体 (定義行から次の buildMode: 定義の手前まで) を切り出す
local function refreshBody(src)
    local startIdx = src:find("function buildMode:RefreshSkillSelectControls", 1, true)
    assert(startIdx, "RefreshSkillSelectControls definition not found in " .. BUILD)
    -- 開始位置以降で次の "function buildMode:" を探す
    local nextIdx = src:find("\nfunction buildMode:", startIdx + 1, true)
    return src:sub(startIdx, (nextIdx or #src + 1) - 1)
end

-- 関数本体内で「nil だと必ずクラッシュする」形で参照される control 名を収集する。
-- 対象: フィールド代入 LHS (`controls.X.field =`, ただし `==` 比較は除外) と
--       メソッド呼び出し receiver (`controls.X:method`)。
-- 除外: nil ガード付きで読むだけの control (例: `controls.showMinion and ...`) は
--       生成されなくても安全なので対象外。
local function indexedControls(body)
    local names, seen = {}, {}
    local function add(name)
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for line in body:gmatch("[^\n]+") do
        -- 代入: controls.X.field = (次が '=' のときは比較なので除外)
        for name, after in line:gmatch("controls%.([%a]+)%.[%a]+%s*=([^=])") do
            add(name)
        end
        -- メソッド呼び出し: controls.X:method(
        for name in line:gmatch("controls%.([%a]+):") do
            add(name)
        end
    end
    table.sort(names)
    return names
end

-- ファイル全体で self.controls.X = new(...) で生成される control 名を収集する
local function createdControls(src)
    local set = {}
    for name in src:gmatch("self%.controls%.([%a]+)%s*=%s*new%(") do
        set[name] = true
    end
    return set
end

describe("Build.lua skill-select controls", function()
    local src = readFile(BUILD)
    local body = refreshBody(src)
    local referenced = indexedControls(body)
    local created = createdControls(src)

    it("extracts the RefreshSkillSelectControls body and its control references", function()
        assert.is_true(#referenced > 5,
            "parser extracted too few indexed controls: " .. #referenced)
        -- 回帰の当事者が確実に検知対象に含まれていること
        assert.is_true((function()
            for _, n in ipairs(referenced) do
                if n == "mainSkillBeastLibrary" then return true end
            end
            return false
        end)(), "mainSkillBeastLibrary should be detected as an indexed control")
    end)

    it("creates every control it assigns to / calls methods on", function()
        local missing = {}
        for _, name in ipairs(referenced) do
            if not created[name] then
                missing[#missing + 1] = name
            end
        end
        assert.are.equal(0, #missing,
            "RefreshSkillSelectControls indexes controls that InitMinimal/Init never "
            .. "create via `self.controls.X = new(...)` (上流 sync で参照だけ取り込んで "
            .. "生成漏れの可能性):\n  " .. table.concat(missing, "\n  "))
    end)
end)
