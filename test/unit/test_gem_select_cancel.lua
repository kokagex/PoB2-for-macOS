-- test/unit/test_gem_select_cancel.lua
-- 回帰テスト: サポートジェム選択ポップアップを「一覧外クリック / ESCAPE」でキャンセルした際、
-- 既設ジェムが消えるバグ (非英語ロケール限定) を防ぐ。
--
-- 根本原因: GemSelectControl:UpdateGem の bufMatchesGem が英語名 gemData.name のみで
-- 比較していたため、edit buffer が翻訳表示名 (translateGemName) を保持する ja ロケールでは
-- 常に false → focus-lost 経路 (SkillsTab changeFunc: focusLost and not bufMatchesGem → deleteGem)
-- で削除されていた。OnFocusGained は両名照合済みだったので非対称だった。
--
-- 修正: bufMatchesGemData ヘルパーで英語名 OR 表示名を照合し、両サイトで使用。
--
-- 実ソース src/Classes/GemSelectControl.lua を sandbox に load し、捕捉したクラスの
-- UpdateGem を直接呼んで gemChangeFunc に渡る bufMatchesGem を検証する (ロジックの複製ではない)。

-- 実ソースを load してクラステーブルを捕捉する。
-- newClass は class テーブルを返すだけのスタブ。constructor は instantiate しない限り走らない。
-- i18n は gems.<英語名> → 表示名 の最小マップ。
local function loadGemSelectClass(displayNameMap)
    local captured
    local env = setmetatable({
        newClass = function(_name, _parent, _ctor)
            captured = {}
            return captured
        end,
        i18n = {
            t = function(key)
                return displayNameMap[key] or key
            end,
            lookup = function() return nil end,
        },
    }, { __index = _G })

    local chunk = assert(loadfile("src/Classes/GemSelectControl.lua"),
        "GemSelectControl.lua not loadable")
    setfenv(chunk, env)
    chunk()
    assert(captured and captured.UpdateGem, "UpdateGem not captured from class")
    return captured
end

-- UpdateGem を 1 回呼び、gemChangeFunc に渡された (gemId, addUndo, focusLost, bufMatchesGem) を返す。
local function runUpdateGem(class, gemEnglishName, gemId, buf, setText, addUndo, focusLost)
    local recorded
    local self = {
        list = { gemId },
        selIndex = 1,
        gems = { [gemId] = { name = gemEnglishName } },
        buf = buf,
        initialBuf = buf,
        SetText = function(s, text) s._text = text end,
        gemChangeFunc = function(id, undo, lost, matches)
            recorded = { gemId = id, addUndo = undo, focusLost = lost, bufMatchesGem = matches }
        end,
    }
    class.UpdateGem(self, setText, addUndo, focusLost)
    return recorded, self
end

describe("GemSelectControl cancel does not delete a set gem (i18n)", function()
    local GEM_ID = "Default:AddedColdDamageSupport"
    local GEM_EN = "Added Cold Damage Support"
    local GEM_JA = "冷気ダメージ追加サポート"
    local displayMap = { ["gems." .. GEM_EN] = GEM_JA }

    it("ja: buffer holds the translated display name -> bufMatchesGem is true (no delete)", function()
        local class = loadGemSelectClass(displayMap)
        -- 一覧外クリックでキャンセル = OnFocusLost が UpdateGem(true, true, true) を呼ぶ経路
        local rec = runUpdateGem(class, GEM_EN, GEM_ID, GEM_JA, true, true, true)
        -- bufMatchesGem=true なら changeFunc の deleteGem 分岐 (focusLost and not bufMatchesGem) に入らない
        assert.is_true(rec.bufMatchesGem)
        assert.is_true(rec.focusLost)
        assert.are.equal(GEM_ID:gsub("%w+:", ""), rec.gemId)
    end)

    it("en: buffer holds the English name -> bufMatchesGem is true (no regression)", function()
        local class = loadGemSelectClass({}) -- 翻訳なし: 表示名 == 英語名
        local rec = runUpdateGem(class, GEM_EN, GEM_ID, GEM_EN, true, true, true)
        assert.is_true(rec.bufMatchesGem)
    end)

    it("genuine mismatch: garbage buffer -> bufMatchesGem is false (delete guard still fires)", function()
        local class = loadGemSelectClass(displayMap)
        local rec = runUpdateGem(class, GEM_EN, GEM_ID, "zzz no such gem", true, true, true)
        assert.is_false(rec.bufMatchesGem)
    end)
end)
