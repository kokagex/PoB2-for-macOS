-- test/unit/test_dylib_symbols.lua
-- ffi.cdef 宣言と runtime/SimpleGraphic.dylib の export シンボルの乖離検知。
-- 背景: SG_Archive* が cdef に宣言されたが本番 dylib に存在せず、
-- 呼び出し時 dlsym 失敗で毎起動 WARNING が出ていた (2026-06-10 修正)。
-- cdef は宣言するだけでシンボル解決を検証しない (初回呼び出しまで遅延)。
-- このテストは「cdef に追加した関数が dylib に無い」事故を commit 前に検知する。
require("test_helpers")

-- pob2_launch.lua の ffi.cdef ブロックから関数宣言名を抽出
local function cdefFunctions()
    local f = assert(io.open("pob2_launch.lua", "r"))
    local src = f:read("*a")
    f:close()
    local block = src:match("ffi%.cdef%[%[(.-)%]%]")
    assert(block, "ffi.cdef block not found in pob2_launch.lua")
    local names = {}
    -- 戻り値型 + 名前 + ( を関数宣言とみなす (コメント行は除外)
    for line in block:gmatch("[^\n]+") do
        if not line:match("^%s*//") then
            local name = line:match("^%s*[%w_]+[%s%*]+([%w_]+)%s*%(")
            if name then
                names[#names + 1] = name
            end
        end
    end
    assert(#names > 10, "cdef parser extracted too few functions: " .. #names)
    return names
end

-- dylib の export シンボル一覧 (macOS は先頭にアンダースコアが付く)
local function dylibExports()
    local exports = {}
    local p = assert(io.popen("nm -gU runtime/SimpleGraphic.dylib 2>/dev/null"))
    for line in p:lines() do
        local sym = line:match("%s+T%s+_([%w_]+)$")
        if sym then
            exports[sym] = true
        end
    end
    p:close()
    return exports
end

-- dylib 由来でないシンボル (libc / OS 提供)
local LIBC_SYMBOLS = {
    usleep = true,
}

-- dylib に無いことが既知で、Lua 側 capability check でゲート済みのシンボル。
-- ここに追加する場合は pob2_launch.lua 側に pcall probe ガードが必須。
local GUARDED_OPTIONAL = {
    SG_ArchiveOpen = true,
    SG_ArchiveClose = true,
    SG_ArchiveContains = true,
    ImageHandle_LoadFromArchive = true,
}

describe("ffi.cdef vs SimpleGraphic.dylib symbol parity", function()
    local exports = dylibExports()

    it("reads dylib export table", function()
        assert.is_true(exports["ConPrintf"] or false,
            "nm failed to read exports (ConPrintf not found)")
    end)

    it("has every cdef function exported or explicitly guarded", function()
        local missing = {}
        for _, name in ipairs(cdefFunctions()) do
            if not exports[name] and not LIBC_SYMBOLS[name] and not GUARDED_OPTIONAL[name] then
                missing[#missing + 1] = name
            end
        end
        assert.are.equal(0, #missing,
            "cdef declares functions the dylib does not export "
            .. "(add a capability guard + GUARDED_OPTIONAL entry, or fix the cdef):\n  "
            .. table.concat(missing, "\n  "))
    end)

    it("keeps guarded-optional symbols actually absent (else guard can be removed)", function()
        local nowPresent = {}
        for name in pairs(GUARDED_OPTIONAL) do
            if exports[name] then
                nowPresent[#nowPresent + 1] = name
            end
        end
        assert.are.equal(0, #nowPresent,
            "these symbols are now exported — re-enable the feature and prune GUARDED_OPTIONAL:\n  "
            .. table.concat(nowPresent, "\n  "))
    end)
end)
