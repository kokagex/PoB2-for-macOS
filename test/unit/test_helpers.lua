-- test/unit/test_helpers.lua
-- Common test stubs and mocks for pob2 Busted tests
-- LuaJIT 5.1 compatible

-- Add test/unit/ to package.path so require("test_helpers") works from project root
if not package.path:find("test/unit/%?%.lua") then
    package.path = "test/unit/?.lua;" .. package.path
end

local M = {}

-- ===== External library mocks =====
-- These must be set BEFORE dofile() loads any module

-- lcurl.safe: HTTP client (not needed in tests)
package.loaded["lcurl.safe"] = {
    easy = function() return {
        setopt_url = function() end,
        perform = function() end,
        close = function() end,
    } end,
}

-- xml: XML parser
package.loaded["xml"] = {
    LoadXMLFile = function() return nil end,
    SaveXMLFile = function() return true end,
}

-- base64: encoding
package.loaded["base64"] = {
    encode = function(s) return s end,
    decode = function(s) return s end,
}

-- sha1: hashing
package.loaded["sha1"] = function(s) return s end

-- lua-utf8: UTF-8 string operations
package.loaded["lua-utf8"] = {
    reverse = string.reverse,
    gsub = string.gsub,
    find = string.find,
    sub = string.sub,
    len = string.len,
    char = string.char,
    byte = string.byte,
}

-- lua-profiler: optional profiler
package.loaded["lua-profiler"] = nil

-- ===== Global stubs =====

-- Console output (suppress in tests)
_G.ConPrintf = function(...) end
_G.ConPrintTable = function() end
_G.ConExecute = function() end
_G.ConClear = function() end

-- Time functions
_G.GetTime = function() return os.clock() * 1000 end

-- Module loading stubs
_G.LoadModule = function(name, ...)
    if name == "Modules/ModParser" then
        return function() return nil end, {}
    end
    return nil
end

_G.PLoadModule = function(name, ...)
    return nil, nil
end

_G.PCall = function(func, ...)
    local ok, result = pcall(func, ...)
    if ok then return nil, result end
    return result
end

-- Window/rendering stubs (no-ops for tests)
_G.RenderInit = function() end
_G.Shutdown = function() end
_G.IsUserTerminated = function() return 0 end
_G.ProcessEvents = function() end
_G.SetWindowTitle = function() end
_G.GetScreenSize = function() return 1920, 1080 end
_G.GetVirtualScreenSize = function() return 1920, 1080 end
_G.SetDrawColor = function() end
_G.SetDrawLayer = function() end
_G.SetClearColor = function() end
_G.SetViewport = function() end
_G.DrawString = function() end
_G.DrawStringWidth = function() return 0 end
_G.DrawStringCursorIndex = function() return 0 end
_G.DrawImage = function() end
_G.DrawImageQuad = function() end
_G.StripEscapes = function(text) return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","") end
_G.NewImageHandle = function()
    return { Load = function() return 1 end, Unload = function() end, IsValid = function() return true end, ImageSize = function() return 0, 0 end }
end
_G.GetAsyncCount = function() return 0 end
_G.ShowCursor = function() end
_G.IsKeyDown = function() return 0 end
_G.GetCursorPos = function() return 0, 0 end
_G.SetCursorPos = function() end
_G.Copy = function() end
_G.Paste = function() return "" end
_G.SetClipboard = function() end
_G.OpenURL = function() end
_G.SpawnProcess = function() return 0 end
_G.TakeScreenshot = function() end
_G.GetScreenScale = function() return 1.0 end
_G.MakeDir = function() return 1 end
_G.RemoveDir = function() return 1 end
_G.GetScriptPath = function() return "." end
_G.GetRuntimePath = function() return "./runtime" end
_G.GetUserPath = function() return "." end
_G.GetWorkDir = function() return "." end
_G.SetWorkDir = function() end
_G.SetMainObject = function() end
_G.Exit = function() end
_G.Restart = function() end

-- ===== Application stubs =====

-- launch object (required by Common.lua and others)
_G.launch = {
    devMode = false,
    installedMode = false,
    versionNumber = "test",
    versionBranch = "test",
    versionPlatform = "test",
    subScripts = {},
    startTime = 0,
}

-- main object (required by formatting functions)
_G.main = {
    showThousandsSeparators = false,
    decimalSeparator = ".",
    thousandsSeparator = ",",
    screenW = 1920,
    screenH = 1080,
    popups = {},
    modes = {},
}

-- GlobalCache (required by Build.lua etc)
_G.GlobalCache = {
    cachedData = { MAIN = {}, CALCS = {}, CALCULATOR = {} },
}

-- buildSites
_G.buildSites = { websiteList = {} }

-- ===== Bit library =====
-- LuaJIT's bit module should be available, but ensure it's loaded
local bit = require("bit")
_G.AND64 = bit.band
_G.OR64 = bit.bor

-- ===== Helper functions =====

-- Reset all global state (call between test suites if needed)
function M.reset()
    _G.launch.devMode = false
    _G.main.showThousandsSeparators = false
    _G.main.decimalSeparator = "."
    _G.main.thousandsSeparator = ","
end

return M
