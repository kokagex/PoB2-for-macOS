-- test/unit/test_i18n_keys.lua
-- i18n キー整合性テスト: src 内の i18n.t("...") リテラルキーが
-- en / ja 両ロケールに存在することを保証する。
-- 背景: en.lua に 67 キー欠落 → 英語モードで生キーパス表示 (2026-06-10 修正)。
-- 翻訳追加時に片方のロケールだけ更新する事故をここで検知する。
require("test_helpers")

local function loadLocale(path)
    local chunk = assert(loadfile(path), "locale file not loadable: " .. path)
    local data = chunk()
    assert(type(data) == "table", "locale did not return a table: " .. path)
    return data
end

local function resolve(tbl, keyPath)
    local cur = tbl
    for part in keyPath:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

-- src 内の i18n.t("...") リテラルキーを収集 (コメント行は除外)
local function collectKeys()
    local keys, seen = {}, {}
    local p = io.popen([[find src -name '*.lua' -not -path 'src/Export/*' 2>/dev/null]])
    assert(p, "failed to enumerate src files")
    for path in p:lines() do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                if not line:match("^%s*%-%-") then
                    for k in line:gmatch('i18n%.t%("([^"]+)"') do
                        if not seen[k] then
                            seen[k] = true
                            keys[#keys + 1] = k
                        end
                    end
                end
            end
            f:close()
        end
    end
    p:close()
    table.sort(keys)
    return keys
end

describe("i18n locale key integrity", function()
    local en = loadLocale("src/Locales/en.lua")
    local ja = loadLocale("src/Locales/ja.lua")
    local keys = collectKeys()

    it("collects a sane number of keys", function()
        -- 2026-06-10 時点で 538 キー。激減したら抽出ロジックの退行を疑う
        assert.is_true(#keys > 400, "expected >400 i18n.t keys, got " .. #keys)
    end)

    for _, locale in ipairs({ { name = "en", data = en }, { name = "ja", data = ja } }) do
        it("has every i18n.t key in " .. locale.name .. " locale", function()
            local missing = {}
            for _, k in ipairs(keys) do
                if type(resolve(locale.data, k)) ~= "string" then
                    missing[#missing + 1] = k
                end
            end
            assert.are.equal(0, #missing,
                locale.name .. " locale missing keys:\n  " .. table.concat(missing, "\n  "))
        end)
    end

    it("has matching string.format placeholders between en and ja", function()
        -- string.format(i18n.t(key), ...) パターンで en/ja の %指定子が
        -- 食い違うと実行時エラーになるため、数と型の一致を検証する
        local function specs(s)
            s = s:gsub("%%%%", "")  -- リテラル %% を除去 ("100%% of" の誤マッチ防止)
            local out = {}
            for spec in s:gmatch("%%[%-%+#0]*%d*%.?%d*[diouxXeEfgGqcs]") do
                out[#out + 1] = spec:gsub("[%-%+#0]", ""):gsub("%d*%.?%d*", "", 1)
            end
            return table.concat(out, ",")
        end
        local mismatched = {}
        for _, k in ipairs(keys) do
            local e, j = resolve(en, k), resolve(ja, k)
            if type(e) == "string" and type(j) == "string" then
                local se, sj = specs(e), specs(j)
                if se ~= sj then
                    mismatched[#mismatched + 1] = k .. " (en: [" .. se .. "] ja: [" .. sj .. "])"
                end
            end
        end
        assert.are.equal(0, #mismatched,
            "placeholder mismatch:\n  " .. table.concat(mismatched, "\n  "))
    end)
end)
