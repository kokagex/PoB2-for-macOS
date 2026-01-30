#!/usr/bin/env luajit
--
-- Test version of PoB2 launcher with debug output
--

print("=== Path of Building 2 for macOS - DEBUG TEST ===")
print("Loading SimpleGraphic library...")

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
    int LoadModule(const char* fileName, void* luaState);
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
print("✓ SimpleGraphic loaded from: " .. lib_path)

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
    -- Key code mapping (GLFW keycodes)
    local keyMap = {
        ["ESCAPE"] = 256,
        ["ENTER"] = 257,
        ["TAB"] = 258,
        ["BACKSPACE"] = 259,
        ["INSERT"] = 260,
        ["DELETE"] = 261,
        ["RIGHT"] = 262,
        ["LEFT"] = 263,
        ["DOWN"] = 264,
        ["UP"] = 265,
        ["PAGEUP"] = 266,
        ["PAGEDOWN"] = 267,
        ["HOME"] = 268,
        ["END"] = 269,
        ["CAPSLOCK"] = 280,
        ["SCROLLLOCK"] = 281,
        ["NUMLOCK"] = 282,
        ["PRINTSCREEN"] = 283,
        ["PAUSE"] = 284,
        ["F1"] = 290, ["F2"] = 291, ["F3"] = 292, ["F4"] = 293,
        ["F5"] = 294, ["F6"] = 295, ["F7"] = 296, ["F8"] = 297,
        ["F9"] = 298, ["F10"] = 299, ["F11"] = 300, ["F12"] = 301,
        ["SHIFT"] = 340,
        ["CTRL"] = 341,
        ["ALT"] = 342,
        ["SUPER"] = 343,
    }

    if type(key) == "string" then
        local code = keyMap[key:upper()]
        if code then
            return sg.IsKeyDown(code)
        end
        -- Try as single character (A-Z, 0-9, etc.)
        if #key == 1 then
            return sg.IsKeyDown(string.byte(key:upper()))
        end
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
    print("DEBUG: LoadModule called with: " .. tostring(moduleName))
    local searchPaths = {
        "src/" .. moduleName .. ".lua",
        "src/Modules/" .. moduleName .. ".lua",
        "runtime/lua/" .. moduleName .. ".lua",
        moduleName .. ".lua"
    }

    for _, path in ipairs(searchPaths) do
        local chunk, err = loadfile(path)
        if chunk then
            print("DEBUG: Loaded module from: " .. path)
            return chunk(...)
        end
    end
    print("DEBUG: Module not found: " .. moduleName)
    return nil, "Module not found: " .. moduleName
end

-- PLoadModule: Protected LoadModule that returns (errMsg, result)
_G.PLoadModule = function(moduleName, ...)
    print("DEBUG: PLoadModule called with: " .. tostring(moduleName))
    local success, result = pcall(_G.LoadModule, moduleName, ...)
    if success then
        return nil, result  -- No error, return result
    else
        return tostring(result), nil  -- Return error message
    end
end

-- PCall: Protected call that returns (errMsg, result)
_G.PCall = function(func, ...)
    local results = {pcall(func, ...)}
    if results[1] then
        -- Success: return nil for error, plus all results
        return nil, select(2, unpack(results))
    else
        -- Failure: return error message
        return tostring(results[2])
    end
end
-- SetMainObject: Override to handle Lua tables (FFI can't pass tables as void*)
_G.SetMainObject = function(obj)
    print("DEBUG: SetMainObject called with type: " .. type(obj))
    -- Store the main object as a global instead of passing to C
    _G.__MAIN_OBJECT = obj
end
_G.ConExecute = function(cmd)
    print("DEBUG: ConExecute: " .. tostring(cmd))
    sg.ConExecute(cmd)
end
_G.ConPrintf = sg.ConPrintf
_G.ConClear = sg.ConClear

print("✓ Global functions registered")

-- Add Path of Building paths to package.path
package.path = package.path .. ";./runtime/lua/?.lua"
package.path = package.path .. ";./src/?.lua"
package.path = package.path .. ";./src/Modules/?.lua"
package.path = package.path .. ";./?.lua"

print("✓ Lua package paths configured")
print("")

-- Initialize graphics
print("Initializing graphics system...")
RenderInit("DPI_AWARE")
print("✓ Graphics initialized")
print("")

-- Load and run Launch.lua
print("Loading Launch.lua...")
local launch_chunk, err = loadfile("src/Launch.lua")
if not launch_chunk then
    print("ERROR: Failed to load Launch.lua: " .. tostring(err))
    Shutdown()
    os.exit(1)
end

print("✓ Launch.lua loaded")
print("")

-- Execute Launch.lua
print("Executing Launch.lua...")
local success, result = pcall(launch_chunk)
if not success then
    print("ERROR: Failed to execute Launch.lua: " .. tostring(result))
    Shutdown()
    os.exit(1)
end

print("✓ Launch.lua executed")
print("✓ Main object set: " .. tostring(_G.__MAIN_OBJECT ~= nil))
print("")

-- Check if OnInit exists
if _G.__MAIN_OBJECT and _G.__MAIN_OBJECT.OnInit then
    print("Calling OnInit...")
    local ok, err = pcall(_G.__MAIN_OBJECT.OnInit, _G.__MAIN_OBJECT)
    if not ok then
        print("ERROR in OnInit: " .. tostring(err))
    else
        print("✓ OnInit completed")
    end
else
    print("WARNING: No OnInit method found")
end
print("")

print("=== Starting main loop (5 seconds) ===")
local start = GetTime()
local frames = 0

while IsUserTerminated() == 0 and (GetTime() - start) < 5.0 do
    ProcessEvents()

    -- Call OnFrame if it exists
    if _G.__MAIN_OBJECT and _G.__MAIN_OBJECT.OnFrame then
        local ok, err = pcall(_G.__MAIN_OBJECT.OnFrame, _G.__MAIN_OBJECT)
        if not ok then
            print("ERROR in OnFrame: " .. tostring(err))
            break
        end
    end

    frames = frames + 1
    ffi.C.usleep(16666)  -- ~60 FPS
end

local elapsed = GetTime() - start
print("")
print("=== Test Complete ===")
print("Frames: " .. frames)
print("Time: " .. string.format("%.2f", elapsed) .. "s")
print("FPS: " .. string.format("%.1f", frames / elapsed))
print("")
print("Shutting down...")
Shutdown()
print("Goodbye!")
