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

-- Source: pob2_launch.lua L609-611
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

-- Source: pob2_launch.lua L759-774 (URL validation logic from OpenURL)
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
