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
    double GetTime(void);
    void Exit(void);
    void Restart(void);

    // Window management
    void SetWindowTitle(const char* title);
    void GetScreenSize(int* width, int* height);
    double GetScreenScale(void);
    int GetDPIScaleOverridePercent(void);
    void SetDPIScaleOverridePercent(int percent);
    void SetClearColor(float r, float g, float b, float a);
    void SetViewport(int x, int y, int width, int height);

    // Drawing
    void SetDrawColor(float r, float g, float b, float a);
    void GetDrawColor(float* r, float* g, float* b, float* a);
    void SetDrawLayer(int layer, int subLayer);
    void DrawString(int left, int top, int align, int height, const char* font, const char* text);
    int DrawStringWidth(int height, const char* font, const char* text);
    int DrawStringCursorIndex(int height, const char* font, const char* text, int cursorX, int cursorY);
    const char* StripEscapes(const char* text);
    void DrawImage(void* imageHandle, float left, float top, float width, float height,
                   float tcLeft, float tcTop, float tcRight, float tcBottom);
    void DrawImageQuad(void* imageHandle, float x1, float y1, float x2, float y2,
                      float x3, float y3, float x4, float y4,
                      float s1, float t1, float s2, float t2,
                      float s3, float t3, float s4, float t4);

    // Image management
    void* NewImageHandle(void);
    int ImageHandle_Load(void* handle, const char* filename, int async);
    int ImageHandle_LoadArrayLayer(void* handle, const char* filename, unsigned int layerIndex);
    void ImageHandle_Unload(void* handle);
    int ImageHandle_IsValid(void* handle);
    void ImageHandle_ImageSize(void* handle, int* width, int* height);
    void ImageHandle_SetLoadingPriority(void* handle, int priority);
    int GetAsyncCount(void);

    // Input
    int IsKeyDown(const char* key);
    void GetCursorPos(int* x, int* y);
    int GetMouseWheelDelta(void);
    void SetCursorPos(int x, int y);
    void ShowCursor(int show);

    // Clipboard
    void Copy(const char* text);
    const char* Paste(void);
    void SetClipboard(const char* text);

    // System Integration
    void OpenURL(const char* url);
    int SpawnProcess(const char* command);
    void TakeScreenshot(const char* filename);

    // File System
    const char* GetScriptPath(void);
    const char* GetRuntimePath(void);
    const char* GetUserPath(void);
    const char* GetWorkDir(void);
    void SetWorkDir(const char* path);
    int MakeDir(const char* path);
    int RemoveDir(const char* path);

    // Console
    void ConPrintf(const char* fmt, ...);
    void ConPrintTable(void* luaState, int index);
    void ConExecute(const char* cmd);
    void ConClear(void);

    // Lua Integration
    void SetMainObject(void* luaState);
    int PCall(void* luaState, int nargs, int nresults);
    int LoadModule(const char* moduleName, void* luaState);
    int PLoadModule(const char* moduleName, void* luaState);
    int LaunchSubScript(const char* scriptName, void* luaState);
    void AbortSubScript(int handle);
    int IsSubScriptRunning(int handle);

    // Compression
    const char* Inflate(const char* data, int dataLen, int* outLen);
    const char* Deflate(const char* data, int dataLen, int* outLen);

    // Profiling
    void SetProfiling(int enabled);

    // sleep (POSIX)
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

-- Stage 4: GetVirtualScreenSize stub (same as GetScreenSize for now)
_G.GetVirtualScreenSize = function()
    return _G.GetScreenSize()
end

-- Stage 4: NewFileSearch stub - returns nil (no files found)
_G.NewFileSearch = function(path, ext)
    -- Stub implementation - returns nil to indicate no files found
    -- This prevents BuildList from trying to iterate over non-existent builds
    return nil
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
    -- Force conversion to number with explicit tonumber() and fallback to 0
    local r_num = tonumber(r) or 0.0
    local g_num = tonumber(g) or 0.0
    local b_num = tonumber(b) or 0.0
    local a_num = tonumber(a) or 1.0

    -- Ensure values are in valid range [0, 1]
    r_num = math.max(0.0, math.min(1.0, r_num))
    g_num = math.max(0.0, math.min(1.0, g_num))
    b_num = math.max(0.0, math.min(1.0, b_num))
    a_num = math.max(0.0, math.min(1.0, a_num))

    sg.SetDrawColor(r_num, g_num, b_num, a_num)
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
_G.DrawStringCursorIndex = sg.DrawStringCursorIndex
-- DrawImage: Wrapper to handle wrapped ImageHandle objects
_G.DrawImage = function(imageHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
    local handle = imageHandle
    -- If it's a wrapped ImageHandle object, extract the raw C handle
    if type(imageHandle) == "table" and imageHandle._handle then
        handle = imageHandle._handle
        -- Debug: Log if handle is nil after extraction
        if not handle then
            print(string.format("WARNING: DrawImage called with table but _handle is nil at pos(%.0f,%.0f)", left or 0, top or 0))
        end
    end
    -- If tcLeft is a non-numeric (e.g., asset filename), ignore UV arguments
    if tcLeft ~= nil and type(tcLeft) ~= "number" then
        tcLeft, tcTop, tcRight, tcBottom = nil, nil, nil, nil
    end
    -- Provide default texture coordinates if not specified (full texture 0,0 to 1,1)
    -- Special case: if only tcLeft is provided, treat it as a texture-array layer index
    if tcLeft == nil then
        tcLeft = 0.0
        tcTop = 0.0
        tcRight = 1.0
        tcBottom = 1.0
    elseif tcTop == nil and tcRight == nil and tcBottom == nil then
        tcTop = 0.0
        tcRight = 0.0
        tcBottom = 0.0
    else
        if tcTop == nil then tcTop = 0.0 end
        if tcRight == nil then tcRight = 1.0 end
        if tcBottom == nil then tcBottom = 1.0 end
    end

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

-- Load DrawImage parameter test module (enabled for debugging)
local ENABLE_DRAW_PARAM_TEST = true  -- Always enabled for now
if ENABLE_DRAW_PARAM_TEST then
    local test_module = loadfile("test_draw_params.lua")
    if test_module then
        _G.draw_param_test = test_module()
        _G.draw_param_test.intercept()
        print("✓ DrawImage parameter testing enabled")
    end
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

function imageHandleMT:LoadArrayLayer(fileName, layerIndex)
    if fileName == nil then
        print("ERROR: ImageHandle:LoadArrayLayer - fileName is nil")
        return 0
    end
    return sg.ImageHandle_LoadArrayLayer(self._handle, fileName, layerIndex)
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
_G.GetMouseWheelDelta = function()
    return sg.GetMouseWheelDelta()
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
_G.GetWorkDir = function()
    return ffi.string(sg.GetWorkDir())
end
_G.SetWorkDir = sg.SetWorkDir
_G.MakeDir = sg.MakeDir
_G.RemoveDir = sg.RemoveDir

-- System lifecycle
_G.Exit = sg.Exit
_G.Restart = sg.Restart

-- Window & DPI management
_G.GetScreenScale = sg.GetScreenScale
_G.GetDPIScaleOverridePercent = sg.GetDPIScaleOverridePercent
_G.SetDPIScaleOverridePercent = sg.SetDPIScaleOverridePercent

-- Drawing state queries
_G.GetDrawColor = function()
    local r = ffi.new("float[1]")
    local g = ffi.new("float[1]")
    local b = ffi.new("float[1]")
    local a = ffi.new("float[1]")
    sg.GetDrawColor(r, g, b, a)
    return r[0], g[0], b[0], a[0]
end

-- Text rendering
-- Note: StripEscapes already implemented as Lua function above

-- Input management
_G.SetCursorPos = sg.SetCursorPos
_G.ShowCursor = sg.ShowCursor

-- Clipboard operations
_G.Copy = sg.Copy
_G.Paste = function()
    local result = sg.Paste()
    return result ~= nil and ffi.string(result) or ""
end
_G.SetClipboard = sg.SetClipboard

-- System integration
_G.OpenURL = sg.OpenURL
_G.SpawnProcess = sg.SpawnProcess
_G.TakeScreenshot = sg.TakeScreenshot

-- Console
_G.ConPrintTable = function(tbl, indent)
    -- Lua implementation since ConPrintTable needs Lua state access
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    if type(tbl) ~= "table" then
        ConPrintf("%s%s", prefix, tostring(tbl))
        return
    end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            ConPrintf("%s%s:", prefix, tostring(k))
            _G.ConPrintTable(v, indent + 1)
        else
            ConPrintf("%s%s: %s", prefix, tostring(k), tostring(v))
        end
    end
end

-- Lua integration (sub-scripts)
_G.LaunchSubScript = sg.LaunchSubScript
_G.AbortSubScript = sg.AbortSubScript
_G.IsSubScriptRunning = sg.IsSubScriptRunning

-- Compression
_G.Inflate = function(data, dataLen)
    local outLen = ffi.new("int[1]")
    local result = sg.Inflate(data, dataLen or #data, outLen)
    if result ~= nil then
        return ffi.string(result, outLen[0])
    end
    return nil
end
_G.Deflate = function(data, dataLen)
    local outLen = ffi.new("int[1]")
    local result = sg.Deflate(data, dataLen or #data, outLen)
    if result ~= nil then
        return ffi.string(result, outLen[0])
    end
    return nil
end

-- Profiling
_G.SetProfiling = sg.SetProfiling

-- ImageHandle methods (export to global for direct access)
_G.ImageHandle_Load = function(handle, filename, async)
    if type(handle) == "table" and handle._handle then
        return sg.ImageHandle_Load(handle._handle, filename, async or 0)
    end
    return sg.ImageHandle_Load(handle, filename, async or 0)
end
_G.ImageHandle_LoadArrayLayer = function(handle, filename, layerIndex)
    if type(handle) == "table" and handle._handle then
        return sg.ImageHandle_LoadArrayLayer(handle._handle, filename, layerIndex)
    end
    return sg.ImageHandle_LoadArrayLayer(handle, filename, layerIndex)
end
_G.ImageHandle_Unload = function(handle)
    if type(handle) == "table" and handle._handle then
        sg.ImageHandle_Unload(handle._handle)
    else
        sg.ImageHandle_Unload(handle)
    end
end
_G.ImageHandle_IsValid = function(handle)
    if type(handle) == "table" and handle._handle then
        return sg.ImageHandle_IsValid(handle._handle) ~= 0
    end
    return sg.ImageHandle_IsValid(handle) ~= 0
end
_G.ImageHandle_ImageSize = function(handle)
    local w = ffi.new("int[1]")
    local h = ffi.new("int[1]")
    if type(handle) == "table" and handle._handle then
        sg.ImageHandle_ImageSize(handle._handle, w, h)
    else
        sg.ImageHandle_ImageSize(handle, w, h)
    end
    return w[0], h[0]
end
_G.ImageHandle_SetLoadingPriority = function(handle, priority)
    if type(handle) == "table" and handle._handle then
        sg.ImageHandle_SetLoadingPriority(handle._handle, priority)
    else
        sg.ImageHandle_SetLoadingPriority(handle, priority)
    end
end

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

-- Set working directory to script path (pob2macos directory)
-- Use Lua's arg[0] to get actual script path instead of GetScriptPath() which returns luajit binary path
local script_file = arg[0]
local script_path
if script_file then
    -- Extract directory from script file path
    script_path = script_file:match("(.*/)")
    if not script_path then
        -- If no directory separator found, use current directory
        script_path = "."
    end
    -- Remove trailing slash if present
    script_path = script_path:gsub("/$", "")
    print("Script file: " .. script_file)
else
    -- Fallback to GetScriptPath() if arg[0] is not available
    script_path = GetScriptPath()
    print("Using GetScriptPath() fallback")
end
print("Script path: " .. script_path)
SetWorkDir(script_path)
print("Working directory set to: " .. script_path)
print("")

-- Don't call RenderInit here - let Launch.lua do it
-- This prevents double initialization
print("Skipping early RenderInit - Launch.lua will initialize")
print("")

-- Stage 4: Define global constants required by Main.lua
_G.APP_NAME = "Path of Building"
_G.APP_VERSION = "PoE2-macOS-0.4"

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

-- Input polling (generates OnKeyDown/OnKeyUp events from IsKeyDown)
local input_prev = { }
local last_click_time = 0
local last_click_x = 0
local last_click_y = 0
local DOUBLE_CLICK_TIME = 0.30
local DOUBLE_CLICK_DIST = 4
local wheel_accum = 0

local input_keys = {
    "LEFTBUTTON", "RIGHTBUTTON", "MIDDLEBUTTON",
    "SHIFT", "CTRL", "ALT",
    "TAB", "SPACE", "RETURN", "ESCAPE", "BACKSPACE", "DELETE",
    "PAGEUP", "PAGEDOWN", "HOME", "END", "INSERT",
    "UP", "DOWN", "LEFT", "RIGHT",
}

for i = 1, 12 do
    table.insert(input_keys, "F" .. i)
end
for c = string.byte("a"), string.byte("z") do
    table.insert(input_keys, string.char(c))
end
for c = string.byte("0"), string.byte("9") do
    table.insert(input_keys, string.char(c))
end

local function dispatch_key_event(key, is_down, double_click)
    if is_down then
        if launch and launch.OnKeyDown then
            launch:OnKeyDown(key, double_click)
        end
    else
        if launch and launch.OnKeyUp then
            launch:OnKeyUp(key)
        end
    end
end

local function poll_input_events()
    if not launch then
        return
    end

    local cursorX, cursorY = GetCursorPos()

    for _, key in ipairs(input_keys) do
        local down = IsKeyDown(key) == 1
        local was_down = input_prev[key] and true or false
        if down ~= was_down then
            local double_click = false
            if down and key == "LEFTBUTTON" then
                local now = GetTime()
                if (now - last_click_time) <= DOUBLE_CLICK_TIME and
                    math.abs(cursorX - last_click_x) <= DOUBLE_CLICK_DIST and
                    math.abs(cursorY - last_click_y) <= DOUBLE_CLICK_DIST then
                    double_click = true
                    last_click_time = 0
                else
                    last_click_time = now
                    last_click_x = cursorX
                    last_click_y = cursorY
                end
            end
            dispatch_key_event(key, down, double_click)
            input_prev[key] = down
        end
    end

    -- Mouse wheel events are delivered as KeyUp (matching existing handlers)
    wheel_accum = wheel_accum + GetMouseWheelDelta()
    if wheel_accum >= 1 then
        if launch and launch.OnKeyUp then
            launch:OnKeyUp("WHEELUP")
        end
        wheel_accum = wheel_accum - 1
    elseif wheel_accum <= -1 then
        if launch and launch.OnKeyUp then
            launch:OnKeyUp("WHEELDOWN")
        end
        wheel_accum = wheel_accum + 1
    end
end

-- Main loop
local frame_count = 0
local last_log_time = 0
print("")
print("=====================================")
print("Starting main event loop...")
print("=====================================")
print("")
while IsUserTerminated() == 0 do
    frame_count = frame_count + 1

    -- Debug: Log every frame for first 10 frames, then every 10 frames
    if frame_count <= 10 or frame_count % 10 == 0 then
        print(string.format("Frame %d: IsUserTerminated() = 0, calling ProcessEvents()...", frame_count))
    end

    ProcessEvents()

    if frame_count <= 10 or frame_count % 10 == 0 then
        print(string.format("Frame %d: ProcessEvents() complete, polling input...", frame_count))
    end

    poll_input_events()

    -- Call OnFrame
    if launch.OnFrame then
        if frame_count <= 10 or frame_count % 10 == 0 then
            print(string.format("Frame %d: Calling launch:OnFrame()...", frame_count))
        end

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

        if frame_count <= 10 or frame_count % 10 == 0 then
            print(string.format("Frame %d: OnFrame() complete", frame_count))
        end
    end

    -- Log progress every 60 frames (once per second at 60 FPS)
    if frame_count % 60 == 0 then
        print(string.format("Frame %d - App running (%.1f seconds)",
                           frame_count, frame_count / 60.0))
    end

    ffi.C.usleep(16666)  -- ~60 FPS

    -- Output test results after first 3 seconds
    if ENABLE_DRAW_PARAM_TEST and _G.draw_param_test and frame_count == 180 then
        print("")
        print("=====================================")
        _G.draw_param_test.analyze()
        print("=====================================")
        print("")
    end
end

-- Debug: Log why loop exited
print("")
print("=====================================")
print("Main event loop EXITED")
print("  Total frames: " .. frame_count)
print("  IsUserTerminated() = " .. tostring(IsUserTerminated()))
print("  Reason: " .. (IsUserTerminated() ~= 0 and "User terminated" or "Unknown (break?)"))
print("=====================================")

-- Output final test results if enabled
if ENABLE_DRAW_PARAM_TEST and _G.draw_param_test then
    print("")
    print("=====================================")
    print("=== Final DrawImage Parameter Test ===")
    _G.draw_param_test.analyze()
    print("=====================================")
    print("")
end

print("")
print("Shutting down...")
Shutdown()
print("Goodbye!")
