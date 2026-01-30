#!/usr/bin/env luajit
--
-- Path of Building 2 macOS Launcher
-- Loads SimpleGraphic.dylib via FFI and launches Path of Building
--

-- Disable output buffering for immediate log output
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

print("=== Path of Building 2 for macOS ===")
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
    void DrawImage(void* imageHandle, float left, float top, float width, float height,
                   float tcLeft, float tcTop, float tcRight, float tcBottom);
    void DrawImageQuad(void* imageHandle, float x1, float y1, float x2, float y2,
                      float x3, float y3, float x4, float y4,
                      float s1, float t1, float s2, float t2,
                      float s3, float t3, float s4, float t4);

    // Image management
    void* NewImageHandle(void);
    int ImageHandle_Load(void* handle, const char* filename, int async);
    void ImageHandle_Unload(void* handle);
    int ImageHandle_IsValid(void* handle);
    void ImageHandle_ImageSize(void* handle, int* width, int* height);
    void ImageHandle_SetLoadingPriority(void* handle, int priority);
    int GetAsyncCount(void);

    // Input
    int IsKeyDown(const char* key);
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

    // File system (return const char*)
    const char* GetScriptPath(void);
    const char* GetRuntimePath(void);
    const char* GetUserPath(void);
    void SetWorkDir(const char* path);
    int MakeDir(const char* path);
    int RemoveDir(const char* path);

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
-- GetScreenSize: Wrapper to handle C pointer arguments
_G.GetScreenSize = function()
    local w = ffi.new("int[1]")
    local h = ffi.new("int[1]")
    sg.GetScreenSize(w, h)
    return w[0], h[0]
end
_G.SetClearColor = sg.SetClearColor
-- SetViewport: Wrapper to handle optional arguments (defaults to full screen)
_G.SetViewport = function(x, y, width, height)
    if not x or not y or not width or not height then
        -- Default to full screen
        local w, h = _G.GetScreenSize()
        sg.SetViewport(0, 0, w, h)
    else
        sg.SetViewport(x, y, width, height)
    end
end
-- SetDrawColor: Wrapper to handle type conversion and optional alpha argument
_G.SetDrawColor = function(r, g, b, a)
    -- Convert all arguments to numbers, handling strings and nil values
    local function toFloat(val, default)
        if val == nil then
            return default
        end
        local num = tonumber(val)
        if num ~= nil then
            return num
        end
        -- If conversion fails, log it and use default
        if type(val) ~= "number" then
            ConPrintf("WARNING: SetDrawColor received non-numeric value: %s (type: %s), using default: %s\n",
                     tostring(val), type(val), tostring(default))
        end
        return default
    end

    local r_float = toFloat(r, 0)
    local g_float = toFloat(g, 0)
    local b_float = toFloat(b, 0)
    local a_float = toFloat(a, 1.0)

    sg.SetDrawColor(r_float, g_float, b_float, a_float)
end
-- SetDrawLayer: Wrapper to handle optional subLayer argument
_G.SetDrawLayer = function(layer, subLayer)
    sg.SetDrawLayer(layer or 0, subLayer or 0)
end
-- DrawString: Wrapper to convert alignment string to int
_G.DrawString = function(left, top, align, height, font, text)
    local alignMap = {
        LEFT = 0,
        CENTER = 1,
        RIGHT = 2
    }
    local alignInt = align
    if type(align) == "string" then
        alignInt = alignMap[align:upper()] or 0
    end
    sg.DrawString(left, top, alignInt, height, font, text)
end
_G.DrawStringWidth = sg.DrawStringWidth
-- DrawImage: Wrapper to handle wrapped ImageHandle objects
_G.DrawImage = function(imageHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
    local handle = imageHandle
    -- If it's a wrapped ImageHandle object, extract the raw C handle
    if type(imageHandle) == "table" and imageHandle._handle then
        handle = imageHandle._handle
    end
    -- Provide default texture coordinates if not specified (full texture 0,0 to 1,1)
    if tcLeft == nil then tcLeft = 0.0 end
    if tcTop == nil then tcTop = 0.0 end
    if tcRight == nil then tcRight = 1.0 end
    if tcBottom == nil then tcBottom = 1.0 end

    sg.DrawImage(handle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
end
-- DrawImageQuad: Wrapper to handle wrapped ImageHandle objects
_G.DrawImageQuad = function(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4)
    local handle = imageHandle
    -- If it's a wrapped ImageHandle object, extract the raw C handle
    if type(imageHandle) == "table" and imageHandle._handle then
        handle = imageHandle._handle
    end
    -- Provide defaults for any nil texture coordinates
    s1 = s1 or 0.0
    t1 = t1 or 0.0
    s2 = s2 or 1.0
    t2 = t2 or 0.0
    s3 = s3 or 1.0
    t3 = t3 or 1.0
    s4 = s4 or 0.0
    t4 = t4 or 1.0
    sg.DrawImageQuad(handle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4)
end

-- Image handle wrapper class to match PassiveTree.lua expectations
local imageHandleMT = {}
imageHandleMT.__index = imageHandleMT

function imageHandleMT:Load(fileName, ...)
    -- Convert Lua varargs to async flag (MIPMAP flag in original code)
    local async = 0
    if ... == "MIPMAP" then
        async = 1
    end
    return sg.ImageHandle_Load(self._handle, fileName, async)
end

function imageHandleMT:ImageSize()
    local w = ffi.new("int[1]")
    local h = ffi.new("int[1]")
    sg.ImageHandle_ImageSize(self._handle, w, h)
    return w[0], h[0]
end

function imageHandleMT:Unload()
    sg.ImageHandle_Unload(self._handle)
end

function imageHandleMT:IsValid()
    return sg.ImageHandle_IsValid(self._handle) ~= 0
end

function imageHandleMT:SetLoadingPriority(priority)
    sg.ImageHandle_SetLoadingPriority(self._handle, priority)
end

_G.NewImageHandle = function()
    local handle = sg.NewImageHandle()
    return setmetatable({ _handle = handle }, imageHandleMT)
end

_G.GetAsyncCount = function()
    return sg.GetAsyncCount()
end

-- StripEscapes: Remove color escape codes from text
_G.StripEscapes = function(text)
    return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","")
end

-- IsKeyDown: Pass key name directly to C (sg_map_key_name handles mapping)
_G.IsKeyDown = function(key)
    if type(key) == "string" then
        -- Pass the key name string directly to C
        return sg.IsKeyDown(key)
    elseif type(key) == "number" then
        -- For numeric codes, map back to key names
        -- This is a fallback for legacy code
        return 0  -- Not supported yet
    end
    return 0
end
-- GetCursorPos: Wrapper to handle C pointer arguments
_G.GetCursorPos = function()
    local x = ffi.new("int[1]")
    local y = ffi.new("int[1]")
    sg.GetCursorPos(x, y)
    return x[0], y[0]
end
_G.GetTime = sg.GetTime
-- LoadModule: Load a Lua module and return its result
_G.LoadModule = function(moduleName, ...)
    local searchPaths = {
        "src/" .. moduleName .. ".lua",
        "src/" .. moduleName,  -- Try without .lua extension
        "src/Modules/" .. moduleName .. ".lua",
        "runtime/lua/" .. moduleName .. ".lua",
        moduleName .. ".lua"
    }

    local last_error = nil
    for _, path in ipairs(searchPaths) do
        local chunk, err = loadfile(path)
        if chunk then
            -- Successfully loaded, execute and return result
            local results = {pcall(chunk, ...)}
            if results[1] then
                return select(2, unpack(results))  -- Return all results except status
            else
                error("Error executing " .. path .. ": " .. tostring(results[2]))
            end
        else
            last_error = err
        end
    end
    error("Module not found: " .. moduleName .. " (last error: " .. tostring(last_error) .. ")")
end

-- PLoadModule: Protected LoadModule that returns (errMsg, result)
_G.PLoadModule = function(moduleName, ...)
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
    -- Store the main object as a global instead of passing to C
    _G.__MAIN_OBJECT = obj
end
_G.ConExecute = sg.ConExecute
_G.ConPrintf = sg.ConPrintf
_G.ConClear = sg.ConClear
_G.GetScriptPath = function()
    return ffi.string(sg.GetScriptPath())
end
_G.GetRuntimePath = function()
    return ffi.string(sg.GetRuntimePath())
end
_G.GetUserPath = function()
    return ffi.string(sg.GetUserPath())
end
_G.SetWorkDir = sg.SetWorkDir
_G.MakeDir = sg.MakeDir
_G.RemoveDir = sg.RemoveDir

print("✓ Global functions registered")

-- Add Path of Building paths to package.path
package.path = package.path .. ";./runtime/lua/?.lua"
package.path = package.path .. ";./runtime/lua/?/init.lua"  -- For sha1 module
package.path = package.path .. ";./src/?.lua"
package.path = package.path .. ";./src/Modules/?.lua"
package.path = package.path .. ";./?.lua"

-- Add LuaRocks paths for modules like lcurl.safe
local home = os.getenv("HOME")
if home then
    package.path = package.path .. ";" .. home .. "/.luarocks/share/lua/5.1/?.lua"
    package.path = package.path .. ";" .. home .. "/.luarocks/share/lua/5.1/?/init.lua"
    package.cpath = package.cpath .. ";" .. home .. "/.luarocks/lib/lua/5.1/?.so"
end

print("✓ Lua package paths configured")
print("")

-- Don't call RenderInit here - let Launch.lua do it
-- This prevents double initialization
print("Skipping early RenderInit - Launch.lua will initialize")
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
local success, result = pcall(launch_chunk)
if not success then
    print("ERROR: Failed to execute Launch.lua: " .. tostring(result))
    Shutdown()
    os.exit(1)
end

print("✓ Launch.lua executed")
print("")

-- Get the launch object that Launch.lua created
local launch = _G.launch or _G.__MAIN_OBJECT
if not launch then
    print("ERROR: Launch.lua did not create a launch object")
    Shutdown()
    os.exit(1)
end

print("✓ Launch object found")
print("")

-- Call OnInit
if launch.OnInit then
    print("Calling launch:OnInit()...")
    local success, err = pcall(function() launch:OnInit() end)
    if not success then
        print("ERROR in OnInit: " .. tostring(err))
        Shutdown()
        os.exit(1)
    end
    print("✓ OnInit completed")
else
    print("WARNING: launch.OnInit not found")
end

print("")
print("=== Path of Building is running ===")
print("")

-- Main loop
local frame_count = 0
local last_log_time = 0
while IsUserTerminated() == 0 do
    ProcessEvents()

    -- Call OnFrame
    if launch.OnFrame then
        local success, err = pcall(function() launch:OnFrame() end)
        if not success then
            print("")
            print("=====================================")
            print("ERROR in OnFrame:")
            print(tostring(err))
            print("=====================================")
            print("")
            print("Frame count: " .. frame_count)
            print("Debug info:")
            print("  launch = " .. tostring(launch))
            print("  launch.OnFrame = " .. tostring(launch.OnFrame))
            print("")
            break
        end
    end

    frame_count = frame_count + 1

    -- Log progress every 60 frames (once per second at 60 FPS)
    if frame_count % 60 == 0 then
        print(string.format("Frame %d - App running (%.1f seconds)",
                           frame_count, frame_count / 60.0))
    end

    ffi.C.usleep(16666)  -- ~60 FPS
end

print("")
print("Shutting down...")
Shutdown()
print("Goodbye!")
