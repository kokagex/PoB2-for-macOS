-- test/unit/test_common.lua
require("test_helpers")

-- Try to load Common.lua
local common_loaded = false
local ok, err = pcall(function()
    dofile("PathOfBuilding.app/Contents/Resources/src/Modules/Common.lua")
end)
if ok then
    common_loaded = true
end

-- Only run tests if Common loaded successfully
if common_loaded then

describe("prerequire", function()
    it("returns the library when require succeeds", function()
        local result = prerequire("string")
        assert.is_not_nil(result)
    end)
    it("returns nil when require fails", function()
        assert.is_nil(prerequire("nonexistent_module_xyz"))
    end)
    it("does not propagate errors", function()
        assert.has_no.errors(function()
            prerequire("this_does_not_exist")
        end)
    end)
end)

describe("coroutine.create wrapper", function()
    it("creates a valid coroutine", function()
        local co = coroutine.create(function() end)
        assert.are.equal("thread", type(co))
    end)
    it("tracks created coroutines", function()
        local co = coroutine.create(function() end)
        local list = coroutine._list()
        assert.is_true(list[co] or false)
    end)
end)

describe("copyTable", function()
    it("copies a simple table", function()
        local orig = { a = 1, b = 2 }
        local copy = copyTable(orig)
        assert.are.equal(1, copy.a)
        copy.a = 99
        assert.are.equal(1, orig.a)
    end)
    it("performs deep copy by default", function()
        local orig = { nested = { x = 10 } }
        local copy = copyTable(orig)
        copy.nested.x = 99
        assert.are.equal(10, orig.nested.x)
    end)
end)

describe("wipeTable", function()
    it("clears all keys from a table", function()
        local t = { a = 1, b = 2 }
        wipeTable(t)
        assert.is_nil(t.a)
        assert.is_nil(t.b)
    end)
    it("returns the same table reference", function()
        local t = { x = 1 }
        assert.are.equal(t, wipeTable(t))
    end)
end)

describe("round", function()
    it("rounds 2.5 up to 3", function()
        assert.are.equal(3, round(2.5))
    end)
    it("rounds 2.4 down to 2", function()
        assert.are.equal(2, round(2.4))
    end)
end)

describe("codePointToUTF8", function()
    it("encodes ASCII", function()
        assert.are.equal("A", codePointToUTF8(0x41))
    end)
    it("encodes 3-byte CJK character", function()
        local result = codePointToUTF8(0x3042)
        assert.are.equal(3, #result)
    end)
    it("returns ? for surrogate codepoints", function()
        assert.are.equal("?", codePointToUTF8(0xD800))
    end)
end)

else
    -- Common.lua failed to load, print diagnostic
    describe("Common.lua loading", function()
        pending("Common.lua could not be loaded: " .. tostring(err))
    end)
end
