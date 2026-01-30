#!/usr/bin/env luajit
--
-- Path of Building 2 macOS Launcher (with logging)
--

-- Open log file
local logfile = io.open("/tmp/pob2_debug.log", "w")
local function log(msg)
    logfile:write(msg .. "\n")
    logfile:flush()
    print(msg)
end

log("=== Path of Building 2 for macOS ===")
log("Loading SimpleGraphic library...")

local ffi = require("ffi")

-- FFI declarations for SimpleGraphic API
ffi.cdef[[
    // Core initialization
    void RenderInit(const char* flags);
    void Shutdown(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);

    // Window management
    void SetWindowTitle(const char* title);
    void GetScreenSize(int* width, int* height);
    void SetClearColor(float r, float g, float b, float a);
    void SetViewport(int x, int y, int width, int height);

    // Drawing
    void SetDrawColor(float r, float g, float b, float a);
    void SetDrawLayer(int layer, int subLayer);
    void DrawString(int left, int top, int align, int height, const char* font, const char* text);
    int DrawStringWidth(int height, const char* font, const char* text);
    void DrawImage(void* imageHandle, float left, float top, float width, float height);
    void DrawImageQuad(void* imageHandle, float x1, float y1, float x2, float y2,
                      float x3, float y3, float x4, float y4,
                      float s1, float t1, float s2, float t2,
                      float s3, float t3, float s4, float t4);

    // Image management
    void* NewImageHandle(void);

    // Input
    int IsKeyDown(int keyCode);
    void GetCursorPos(int* x, int* y);

    // Utility
    double GetTime(void);
    void* LoadModule(const char* fileName, void* luaState);
    void* PLoadModule(const char* fileName, void* luaState);
    void SetMainObject(void* obj);

    // Console
    void ConExecute(const char* cmd);
    void ConPrintf(const char* fmt, ...);
    void ConClear(void);

    // File system
    void* GetScriptPath(void);
    void* GetRuntimePath(void);
    void* GetUserPath(void);

    // sleep
    int usleep(unsigned int usec);
]]

-- Load SimpleGraphic library
local lib_path = "runtime/SimpleGraphic.dylib"
local sg = ffi.load(lib_path)
log("✓ SimpleGraphic loaded from: " .. lib_path)

-- Setup global functions for Path of Building
_G.RenderInit = sg.RenderInit
_G.Shutdown = sg.Shutdown
_G.IsUserTerminated = sg.IsUserTerminated
_G.ProcessEvents = sg.ProcessEvents
_G.SetWindowTitle = sg.SetWindowTitle
_G.GetScreenSize = sg.GetScreenSize
_G.SetClearColor = sg.SetClearColor
_G.SetViewport = sg.SetViewport
_G.SetDrawColor = sg.SetDrawColor
_G.SetDrawLayer = sg.SetDrawLayer
_G.DrawString = sg.DrawString
_G.DrawStringWidth = sg.DrawStringWidth
_G.DrawImage = sg.DrawImage
_G.DrawImageQuad = sg.DrawImageQuad
_G.NewImageHandle = sg.NewImageHandle

-- IsKeyDown: Convert string key names to GLFW key codes
_G.IsKeyDown = function(key)
    local keyMap = {
        ["ESCAPE"] = 256, ["ENTER"] = 257, ["TAB"] = 258, ["BACKSPACE"] = 259,
        ["INSERT"] = 260, ["DELETE"] = 261, ["RIGHT"] = 262, ["LEFT"] = 263,
        ["DOWN"] = 264, ["UP"] = 265, ["PAGEUP"] = 266, ["PAGEDOWN"] = 267,
        ["HOME"] = 268, ["END"] = 269, ["CAPSLOCK"] = 280, ["SCROLLLOCK"] = 281,
        ["NUMLOCK"] = 282, ["PRINTSCREEN"] = 283, ["PAUSE"] = 284,
        ["F1"] = 290, ["F2"] = 291, ["F3"] = 292, ["F4"] = 293,
        ["F5"] = 294, ["F6"] = 295, ["F7"] = 296, ["F8"] = 297,
        ["F9"] = 298, ["F10"] = 299, ["F11"] = 300, ["F12"] = 301,
        ["SHIFT"] = 340, ["CTRL"] = 341, ["ALT"] = 342, ["SUPER"] = 343,
    }
    if type(key) == "string" then
        local code = keyMap[key:upper()]
        if code then return sg.IsKeyDown(code) end
        if #key == 1 then return sg.IsKeyDown(string.byte(key:upper())) end
        return 0
    elseif type(key) == "number" then
        return sg.IsKeyDown(key)
    end
    return 0
end

_G.GetCursorPos = sg.GetCursorPos
_G.GetTime = sg.GetTime

-- LoadModule: Load a Lua module and return its result
_G.LoadModule = function(moduleName, ...)
    local searchPaths = {
        "src/" .. moduleName .. ".lua",
        "src/Modules/" .. moduleName .. ".lua",
        "runtime/lua/" .. moduleName .. ".lua",
        moduleName .. ".lua"
    }
    for _, path in ipairs(searchPaths) do
        local chunk, err = loadfile(path)
        if chunk then
            return chunk(...)
        end
    end
    return nil, "Module not found: " .. moduleName
end

-- PLoadModule: Protected LoadModule that returns (errMsg, result)
_G.PLoadModule = function(moduleName, ...)
    local success, result = pcall(_G.LoadModule, moduleName, ...)
    if success then
        return nil, result
    else
        return tostring(result), nil
    end
end

-- PCall: Protected call that returns (errMsg, result)
_G.PCall = function(func, ...)
    local results = {pcall(func, ...)}
    if results[1] then
        return nil, select(2, unpack(results))
    else
        return tostring(results[2])
    end
end

-- SetMainObject: Override to handle Lua tables
_G.SetMainObject = function(obj)
    _G.__MAIN_OBJECT = obj
end

_G.ConExecute = sg.ConExecute
_G.ConPrintf = sg.ConPrintf
_G.ConClear = sg.ConClear

log("✓ Global functions registered")

-- Add Path of Building paths to package.path
package.path = package.path .. ";./runtime/lua/?.lua"
package.path = package.path .. ";./src/?.lua"
package.path = package.path .. ";./src/Modules/?.lua"
package.path = package.path .. ";./?.lua"

log("✓ Lua package paths configured")

-- Initialize graphics
log("Initializing graphics system...")
RenderInit("DPI_AWARE")
log("✓ Graphics initialized")

-- Load and run Launch.lua
log("Loading Launch.lua...")
local launch_chunk, err = loadfile("src/Launch.lua")
if not launch_chunk then
    log("ERROR: Failed to load Launch.lua: " .. tostring(err))
    Shutdown()
    os.exit(1)
end

log("✓ Launch.lua loaded")

-- Execute Launch.lua
local success, result = pcall(launch_chunk)
if not success then
    log("ERROR: Failed to execute Launch.lua: " .. tostring(result))
    Shutdown()
    os.exit(1)
end

log("✓ Launch.lua executed")
log("=== Path of Building is starting ===")

-- Main loop with error catching
local frame_count = 0
local start_time = GetTime()
local last_log = start_time

while IsUserTerminated() == 0 do
    local ok, err = pcall(ProcessEvents)
    if not ok then
        log("ERROR in ProcessEvents: " .. tostring(err))
        break
    end

    -- Log progress every second
    local now = GetTime()
    if now - last_log >= 1.0 then
        log(string.format("Running... Frame %d, FPS: %.1f", frame_count, frame_count / (now - start_time)))
        last_log = now
    end

    frame_count = frame_count + 1
    ffi.C.usleep(16666)

    -- Auto-exit after 10 seconds for testing
    if now - start_time > 10.0 then
        log("Auto-exit after 10 seconds")
        break
    end
end

log("")
log("Shutting down...")
log(string.format("Total frames: %d", frame_count))
log(string.format("Total time: %.2fs", GetTime() - start_time))
log(string.format("Average FPS: %.1f", frame_count / (GetTime() - start_time)))

Shutdown()
log("Goodbye!")
logfile:close()
