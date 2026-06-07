-- test/unit/pob2_testable.lua
-- Pure-Lua functions extracted from pob2_launch.lua for isolated testing.
-- This avoids the FFI dependency that prevents dofile() of pob2_launch.lua.
-- Keep in sync with pob2_launch.lua when modifying the original functions.

local M = {}

-- Source: pob2_launch.lua L166-172
-- Path validation: reject null bytes, directory traversal, and shell metacharacters
M.validatePath = function(path)
    if type(path) ~= "string" then return false end
    if path:find("\0") then return false end
    if path:find("%.%.[\\/]") or path:find("[\\/]%.%.$") then return false end
    if path:find("[;|&$%(%)%{%}%[%]`]") then return false end
    return true
end

-- Source: pob2_launch.lua L396-404
M.normalizeTextArg = function(text)
    if text == nil then
        return ""
    end
    if type(text) ~= "string" then
        return tostring(text)
    end
    return text
end

-- Source: pob2_launch.lua L831-834
-- StripEscapes: Remove color escape codes from text
M.stripEscapes = function(text)
    return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","")
end

-- Source: pob2_launch.lua L177-180 (local inside NewFileSearch)
M.shellQuote = function(value)
    value = tostring(value or "")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Source: pob2_launch.lua L344-373 (color parse logic from SetDrawColor)
-- Extracted as a pure function: returns r, g, b or nil
M.parseColorArg = function(r)
    if type(r) ~= "string" then return nil end
    local hex = r:match("^%^x(%x%x%x%x%x%x)")
    if hex then
        local ri = tonumber(hex:sub(1,2), 16) / 255.0
        local gi = tonumber(hex:sub(3,4), 16) / 255.0
        local bi = tonumber(hex:sub(5,6), 16) / 255.0
        return ri, gi, bi
    end
    local idx = r:match("^%^(%d)")
    if idx then
        local colorTable = {
            [0] = {0.0, 0.0, 0.0},
            [1] = {1.0, 0.0, 0.0},
            [2] = {0.0, 1.0, 0.0},
            [3] = {0.0, 0.0, 1.0},
            [4] = {1.0, 1.0, 0.0},
            [5] = {1.0, 0.0, 1.0},
            [6] = {0.0, 1.0, 1.0},
            [7] = {1.0, 1.0, 1.0},
            [8] = {0.75, 0.75, 0.75},
            [9] = {0.6, 0.6, 0.6},
        }
        local c = colorTable[tonumber(idx)]
        if c then
            return c[1], c[2], c[3]
        end
    end
    return nil
end

-- Source: pob2_launch.lua L184-189 (pattern parse logic from NewFileSearch)
M.parsePattern = function(pattern)
    local dir = pattern:match("^(.*)/[^/]*$") or "."
    local filePattern = pattern:match("/([^/]*)$") or pattern
    filePattern = filePattern:gsub("%*", ".*")
    return dir, filePattern
end

-- ===== UTF-8 sanitiser + glyph→byte caret conversion =====
-- These guard the FFI boundary against sg_utf8_decode's non-advancing 0xFFFD
-- path (sg_text.cpp:23-55), which spins the C draw loops forever on any
-- invalid UTF-8 byte (the support-gem-swap hang).

local s_byte = string.byte

-- Source: pob2_launch.lua L497-515
-- Returns the index just past the valid UTF-8 sequence starting at i, or nil if
-- the byte at i does not start one (strict: rejects stray continuations
-- 0x80-0xBF, overlong leads 0xC0/0xC1, and leads 0xF5-0xFF).
local function utf8SeqEnd(s, i)
    local b = s_byte(s, i)
    if b < 0x80 then return i + 1 end
    local len
    if b >= 0xC2 and b <= 0xDF then
        len = 2
    elseif b >= 0xE0 and b <= 0xEF then
        len = 3
    elseif b >= 0xF0 and b <= 0xF4 then
        len = 4
    else
        return nil
    end
    for k = i + 1, i + len - 1 do
        local c = s_byte(s, k)
        if not c or c < 0x80 or c > 0xBF then return nil end
    end
    return i + len
end
M.utf8SeqEnd = utf8SeqEnd

-- Source: pob2_launch.lua L518-526
-- Returns the byte index of the first invalid UTF-8 byte, or nil if valid.
local function utf8FirstInvalid(s)
    local i, n = 1, #s
    while i <= n do
        local j = utf8SeqEnd(s, i)
        if not j then return i end
        i = j
    end
    return nil
end
M.utf8FirstInvalid = utf8FirstInvalid

-- Source: pob2_launch.lua L529-565 (_G.__sanitiseUTF8; the /tmp log block is
-- elided here -- the replacement algorithm is identical)
-- Replaces each invalid byte ONE-FOR-ONE with '?' (byte count preserved --
-- callers index their original string with byte positions computed against
-- the sanitised one).
M.sanitiseUTF8 = function(s)
    if not s:find("[\128-\255]") then return s end
    local firstBad = utf8FirstInvalid(s)
    if not firstBad then return s end
    local parts = { s:sub(1, firstBad - 1), "?" }
    local count = 2
    local n = #s
    local i = firstBad + 1
    local runStart = i
    while i <= n do
        local j = utf8SeqEnd(s, i)
        if j then
            i = j
        else
            count = count + 1
            parts[count] = s:sub(runStart, i - 1)
            count = count + 1
            parts[count] = "?"
            i = i + 1
            runStart = i
        end
    end
    parts[count + 1] = s:sub(runStart)
    return table.concat(parts)
end

-- Source: pob2_launch.lua L575-621
-- Converts the 0-based glyph index returned by sg.DrawStringCursorIndex into
-- the 1-based byte insertion position callers expect. Walks the string exactly
-- like the C loop (sg_text.cpp:597-645). Contract: input must be sanitised.
M.cursorGlyphToBytePos = function(text, glyphIndex)
    local pos, n, glyphs = 1, #text, 0
    while pos <= n do
        local b = s_byte(text, pos)
        local consumed = false
        if b == 94 then -- '^': sg_parse_escape_code (sg_text.cpp:59-109)
            local b2 = s_byte(text, pos + 1)
            if b2 and b2 >= 48 and b2 <= 57 then -- ^0-^9: skip 2
                pos = pos + 2
                consumed = true
            elseif b2 == 120 and pos + 7 <= n then
                local hex6 = text:sub(pos + 2, pos + 7)
                if not hex6:find("\0", 1, true) and hex6:match("^%s*%x") then
                    pos = pos + 8
                    consumed = true
                end
            end
            -- any other '^' falls through and renders as a normal glyph
        end
        if not consumed then
            if glyphs >= glyphIndex then
                return pos
            end
            if b == 0 then
                return pos
            end
            glyphs = glyphs + 1
            if b < 0x80 then
                pos = pos + 1
            elseif b < 0xE0 then
                pos = pos + 2
            elseif b < 0xF0 then
                pos = pos + 3
            elseif b < 0xF8 then
                pos = pos + 4
            else
                pos = pos + 1
            end
        end
    end
    return n + 1
end

-- Source: pob2_launch.lua L990-1005 (URL validation logic from OpenURL)
-- Returns sanitized URL string ready for use, or nil if invalid
M.validateURL = function(url)
    if url == nil then
        return nil
    end
    local text = tostring(url)
    -- Only allow http/https protocols to prevent file:// or other protocol injection
    if not text:match("^https?://") then
        return nil
    end
    -- Prevent shell breakouts in C-side implementation that wraps URL in single quotes.
    text = text:gsub("'", "%%27")
    if text:find("[%z\r\n]") then
        return nil
    end
    return text
end

return M
