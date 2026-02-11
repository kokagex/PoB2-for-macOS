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
local bit = require("bit")

-- Export bit operations globally (required by ModList.lua and other modules)
_G.AND64 = bit.band
_G.OR64 = bit.bor

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

    // Internal (for CharInput extension)
    void* sg_get_context(void);

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

-- DPI scale cache (avoids repeated C calls per frame)
local _dpi_scale = nil
local function getDpiScale()
    if not _dpi_scale then
        _dpi_scale = tonumber(sg.GetScreenScale()) or 1.0
        print(string.format("DPI scale detected: %.2f", _dpi_scale))
    end
    return _dpi_scale
end

-- Setup global functions for Path of Building
_G.RenderInit = sg.RenderInit
_G.Shutdown = sg.Shutdown
_G.IsUserTerminated = sg.IsUserTerminated
_G.ProcessEvents = sg.ProcessEvents
_G.SetWindowTitle = sg.SetWindowTitle
-- GetScreenSize: Returns logical pixels (physical / dpi_scale)
_G.GetScreenSize = function()
    local w = ffi.new("int[1]")
    local h = ffi.new("int[1]")
    sg.GetScreenSize(w, h)
    local scale = getDpiScale()
    local logW = math.floor(w[0] / scale)
    local logH = math.floor(h[0] / scale)
    print(string.format("GetScreenSize: physical=%dx%d, scale=%.2f, logical=%dx%d", w[0], h[0], scale, logW, logH))
    return logW, logH
end

-- GetVirtualScreenSize: Same as GetScreenSize (returns logical pixels)
_G.GetVirtualScreenSize = function()
    return _G.GetScreenSize()
end

-- NewFileSearch: File search implementation using shell commands
_G.NewFileSearch = function(pattern, foldersOnly)
    local function shellQuote(value)
        value = tostring(value or "")
        return "'" .. value:gsub("'", "'\\''") .. "'"
    end

    -- Parse the pattern to extract directory and file pattern
    -- Pattern format: "/path/to/dir/*.xml" or "/path/to/dir/*" (for folders)
    local dir = pattern:match("^(.*)/[^/]*$") or "."
    local filePattern = pattern:match("/([^/]*)$") or pattern

    -- Convert wildcard pattern to shell glob
    -- Replace Lua pattern with shell pattern
    filePattern = filePattern:gsub("%*", ".*")

    -- Build find command
    local cmd
    if foldersOnly then
        -- Search for directories only
        cmd = string.format("find %s -maxdepth 1 -type d -not -path %s 2>/dev/null", shellQuote(dir), shellQuote(dir))
    else
        -- Search for files matching pattern
        cmd = string.format("find %s -maxdepth 1 -type f 2>/dev/null", shellQuote(dir))
    end

    -- Execute command and collect results
    local handle = io.popen(cmd)
    if not handle then
        return nil
    end

    local files = {}
    for line in handle:lines() do
        local fileName = line:match("([^/]+)$")
        if fileName then
            -- Apply file pattern filter for files (not folders)
            if foldersOnly or fileName:match(filePattern) then
                table.insert(files, {
                    fullPath = line,
                    fileName = fileName
                })
            end
        end
    end
    handle:close()

    -- Return nil if no files found
    if #files == 0 then
        return nil
    end

    -- Create file search handle object
    local fileSearchHandle = {
        files = files,
        index = 1,
        currentFile = files[1]
    }

    function fileSearchHandle:GetFileName()
        return self.currentFile and self.currentFile.fileName or nil
    end

    function fileSearchHandle:GetFileModifiedTime()
        if not self.currentFile then
            return 0
        end

        -- Get file modification time using stat
        local cmd = string.format("stat -f '%%m' %s 2>/dev/null", shellQuote(self.currentFile.fullPath))
        local handle = io.popen(cmd)
        if handle then
            local result = handle:read("*l")
            handle:close()
            return tonumber(result) or 0
        end
        return 0
    end

    function fileSearchHandle:NextFile()
        self.index = self.index + 1
        if self.index <= #self.files then
            self.currentFile = self.files[self.index]
            return true
        else
            self.currentFile = nil
            return false
        end
    end

    return fileSearchHandle
end

_G.SetClearColor = sg.SetClearColor
-- Viewport state: coordinate offset for DrawString/DrawImage
local viewportStack = {}
local viewportOffX = 0
local viewportOffY = 0
-- Viewport clip stack (for scissor rect restoration)
local viewportClipStack = {}
-- SetViewport: Translate coordinates + set scissor clipping for all subsequent draw calls
_G.SetViewport = function(x, y, width, height)
    local scale = getDpiScale()
    if not x or not y or not width or not height then
        -- Reset viewport: pop to previous state or (0,0)
        if #viewportStack > 0 then
            local prev = table.remove(viewportStack)
            viewportOffX = prev.x
            viewportOffY = prev.y
        else
            viewportOffX = 0
            viewportOffY = 0
        end
        -- Pop scissor rect
        if #viewportClipStack > 0 then
            local prevClip = table.remove(viewportClipStack)
            sg.SetViewport(prevClip.x, prevClip.y, prevClip.w, prevClip.h)
        else
            -- Reset to full screen
            local sw = ffi.new("int[1]")
            local sh = ffi.new("int[1]")
            sg.GetScreenSize(sw, sh)
            sg.SetViewport(0, 0, sw[0], sh[0])
        end
    else
        -- Push current state and set new viewport offset
        table.insert(viewportStack, { x = viewportOffX, y = viewportOffY })
        -- Push current scissor rect (the absolute clip region we'll restore later)
        if #viewportClipStack > 0 then
            local cur = viewportClipStack[#viewportClipStack]
            table.insert(viewportClipStack, { x = cur.x, y = cur.y, w = cur.w, h = cur.h })
        else
            local sw = ffi.new("int[1]")
            local sh = ffi.new("int[1]")
            sg.GetScreenSize(sw, sh)
            table.insert(viewportClipStack, { x = 0, y = 0, w = sw[0], h = sh[0] })
        end
        viewportOffX = viewportOffX + x
        viewportOffY = viewportOffY + y
        -- Set scissor rect to clip to viewport bounds (in physical pixels)
        sg.SetViewport(
            math.floor(viewportOffX * scale),
            math.floor(viewportOffY * scale),
            math.floor(width * scale),
            math.floor(height * scale)
        )
    end
end
-- ResetViewport: Fully clear viewport stack and offset (use at frame boundaries)
_G.ResetViewport = function()
    viewportStack = {}
    viewportClipStack = {}
    viewportOffX = 0
    viewportOffY = 0
    -- Reset scissor to full screen
    local sw = ffi.new("int[1]")
    local sh = ffi.new("int[1]")
    sg.GetScreenSize(sw, sh)
    sg.SetViewport(0, 0, sw[0], sh[0])
end
-- SetDrawColor: Wrapper to handle type conversion and optional alpha argument
_G.SetDrawColor = function(r, g, b, a)
    -- Handle PoB color code strings like "^xRRGGBB"
    if type(r) == "string" then
        local hex = r:match("^%^x(%x%x%x%x%x%x)")
        if hex then
            local ri = tonumber(hex:sub(1,2), 16) / 255.0
            local gi = tonumber(hex:sub(3,4), 16) / 255.0
            local bi = tonumber(hex:sub(5,6), 16) / 255.0
            sg.SetDrawColor(ri, gi, bi, tonumber(g) or 1.0)
            return
        end
        -- Fallback: try tonumber on the string
        r = tonumber(r) or 0.0
    end

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

local function normalizeTextArg(text)
    if text == nil then
        return ""
    end
    if type(text) ~= "string" then
        return tostring(text)
    end
    return text
end

-- DrawString: Logical→Physical conversion + alignment mapping + viewport offset
_G.DrawString = function(left, top, align, height, font, text)
    local alignMap = {
        LEFT = 0,
        CENTER = 1,
        CENTER_X = 1,
        RIGHT = 2,
        RIGHT_X = 2,
    }
    local alignInt = align
    if type(align) == "string" then
        alignInt = alignMap[align:upper()] or 0
    end
    text = normalizeTextArg(text)
    local scale = getDpiScale()
    sg.DrawString(math.floor((left + viewportOffX) * scale), math.floor((top + viewportOffY) * scale),
                  alignInt, math.floor(height * scale), font, text)
end
-- DrawStringWidth: Scale font height up, scale result back to logical
_G.DrawStringWidth = function(height, font, text)
    text = normalizeTextArg(text)
    local scale = getDpiScale()
    return math.floor(sg.DrawStringWidth(math.floor(height * scale), font, text) / scale)
end
-- DrawStringCursorIndex: Scale font height and cursor coords to physical (viewport-adjusted)
_G.DrawStringCursorIndex = function(height, font, text, cursorX, cursorY)
    text = normalizeTextArg(text)
    local scale = getDpiScale()
    return sg.DrawStringCursorIndex(math.floor(height * scale), font, text,
                                     math.floor((cursorX - viewportOffX) * scale), math.floor((cursorY - viewportOffY) * scale))
end
-- DrawImage: Wrapper to handle wrapped ImageHandle objects
_G.DrawImage = function(imageHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom)
    local handle = imageHandle
    -- Accept all common image table forms:
    -- 1) NewImageHandle wrapper: { _handle = cdata }
    -- 2) Asset table: { handle = NewImageHandle wrapper or raw cdata, ... }
    if type(imageHandle) == "table" then
        if imageHandle._handle then
            handle = imageHandle._handle
        elseif imageHandle.handle then
            local inner = imageHandle.handle
            if type(inner) == "table" and inner._handle then
                handle = inner._handle
            else
                handle = inner
            end
        else
            -- Unknown table shape: draw nothing instead of crashing FFI conversion.
            handle = nil
        end
    end
    -- Final unwrapping guard if nested wrapper leaked through.
    if type(handle) == "table" and handle._handle then
        handle = handle._handle
    end
    -- Absolute safety: never pass Lua tables to FFI void* parameters.
    if type(handle) == "table" then
        handle = nil
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

    local scale = getDpiScale()
    sg.DrawImage(handle, (left + viewportOffX) * scale, (top + viewportOffY) * scale, width * scale, height * scale,
                 tcLeft, tcTop, tcRight, tcBottom)
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
    local scale = getDpiScale()
    sg.DrawImageQuad(handle, (x1+viewportOffX)*scale, (y1+viewportOffY)*scale,
                     (x2+viewportOffX)*scale, (y2+viewportOffY)*scale,
                     (x3+viewportOffX)*scale, (y3+viewportOffY)*scale,
                     (x4+viewportOffX)*scale, (y4+viewportOffY)*scale,
                     s1, t1, s2, t2, s3, t3, s4, t4)
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
-- GetCursorPos: Physical→Logical conversion
_G.GetCursorPos = function()
    local x = ffi.new("int[1]")
    local y = ffi.new("int[1]")
    sg.GetCursorPos(x, y)
    local scale = getDpiScale()
    return math.floor(x[0] / scale), math.floor(y[0] / scale)
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
        "runtime/lua/" .. moduleName .. ".lua",
        moduleName .. ".lua",
        moduleName  -- Try raw moduleName (handles names already ending in .lua)
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
        -- Success: return nil for error, plus all return values from func
        return nil, select(2, unpack(results))
    else
        -- Failure: return error message string
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

-- Input management: Logical→Physical conversion
_G.SetCursorPos = function(x, y)
    local scale = getDpiScale()
    sg.SetCursorPos(math.floor(x * scale), math.floor(y * scale))
end
_G.ShowCursor = sg.ShowCursor

-- Clipboard operations
_G.Copy = sg.Copy
_G.Paste = function()
    local result = sg.Paste()
    return result ~= nil and ffi.string(result) or ""
end
_G.SetClipboard = sg.SetClipboard

-- System integration
_G.OpenURL = function(url)
    if url == nil then
        return
    end
    local text = tostring(url)
    -- Prevent shell breakouts in C-side implementation that wraps URL in single quotes.
    text = text:gsub("'", "%%27")
    if text:find("[%z\r\n]") then
        return
    end
    sg.OpenURL(text)
end
_G.SpawnProcess = function(command, ...)
    if command == nil then
        return -1
    end

    local function shellEscape(value)
        local text = tostring(value or "")
        return "'" .. text:gsub("'", "'\\''") .. "'"
    end

    local cmd = shellEscape(command)

    local argCount = select("#", ...)
    for i = 1, argCount do
        local value = select(i, ...)
        if value ~= nil then
            cmd = cmd .. " " .. shellEscape(value)
        end
    end
    return sg.SpawnProcess(cmd)
end
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

-- Compression (using macOS system zlib via FFI)
do
    local ok, err = pcall(function()
    local zlib = ffi.load("z")
    ffi.cdef[[
        typedef unsigned long uLong;
        typedef unsigned int uInt;
        typedef unsigned char Byte;
        typedef Byte* Bytef;
        typedef void* voidpf;
        typedef uLong uLongf;

        typedef struct z_stream_s {
            const Bytef* next_in;
            uInt avail_in;
            uLong total_in;
            Bytef* next_out;
            uInt avail_out;
            uLong total_out;
            const char* msg;
            void* state;
            voidpf zalloc;
            voidpf zfree;
            voidpf opaque;
            int data_type;
            uLong adler;
            uLong reserved;
        } z_stream;

        int inflateInit2_(z_stream* strm, int windowBits, const char* version, int stream_size);
        int inflate(z_stream* strm, int flush);
        int inflateEnd(z_stream* strm);

        int deflateInit2_(z_stream* strm, int level, int method, int windowBits, int memLevel, int strategy, const char* version, int stream_size);
        int deflate(z_stream* strm, int flush);
        int deflateEnd(z_stream* strm);

        uLong compressBound(uLong sourceLen);
        const char* zlibVersion(void);
    ]]

    local Z_OK = 0
    local Z_STREAM_END = 1
    local Z_NO_FLUSH = 0
    local Z_FINISH = 4
    local Z_DEFLATED = 8
    local MAX_WBITS = 15

    local zlibVer = zlib.zlibVersion()
    local streamSize = ffi.sizeof("z_stream")

    _G.Inflate = function(data, dataLen)
        if not data then return nil end
        dataLen = dataLen or #data
        if dataLen == 0 then return nil end

        local strm = ffi.new("z_stream")
        ffi.fill(strm, streamSize)
        strm.next_in = ffi.cast("const Bytef*", data)
        strm.avail_in = dataLen

        -- Auto-detect format (zlib/gzip/raw) with MAX_WBITS + 32
        local ret = zlib.inflateInit2_(strm, MAX_WBITS + 32, zlibVer, streamSize)
        if ret ~= Z_OK then return nil end

        local bufSize = dataLen * 4
        if bufSize < 1024 then bufSize = 1024 end
        local buf = ffi.new("uint8_t[?]", bufSize)
        local chunks = {}
        local totalOut = 0

        repeat
            strm.next_out = ffi.cast("Bytef*", buf)
            strm.avail_out = bufSize
            ret = zlib.inflate(strm, Z_NO_FLUSH)
            if ret ~= Z_OK and ret ~= Z_STREAM_END then
                zlib.inflateEnd(strm)
                return nil
            end
            local have = bufSize - strm.avail_out
            if have > 0 then
                chunks[#chunks + 1] = ffi.string(buf, have)
                totalOut = totalOut + have
            end
        until ret == Z_STREAM_END

        zlib.inflateEnd(strm)
        return table.concat(chunks)
    end

    _G.Deflate = function(data, dataLen)
        if not data then return nil end
        dataLen = dataLen or #data
        if dataLen == 0 then return nil end

        local strm = ffi.new("z_stream")
        ffi.fill(strm, streamSize)
        strm.next_in = ffi.cast("const Bytef*", data)
        strm.avail_in = dataLen

        -- Raw deflate (-MAX_WBITS) to match PoB format
        local ret = zlib.deflateInit2_(strm, 6, Z_DEFLATED, -MAX_WBITS, 8, 0, zlibVer, streamSize)
        if ret ~= Z_OK then return nil end

        local bufSize = tonumber(zlib.compressBound(dataLen))
        local buf = ffi.new("uint8_t[?]", bufSize)
        strm.next_out = ffi.cast("Bytef*", buf)
        strm.avail_out = bufSize

        ret = zlib.deflate(strm, Z_FINISH)
        if ret ~= Z_STREAM_END then
            zlib.deflateEnd(strm)
            return nil
        end

        local outLen = bufSize - strm.avail_out
        zlib.deflateEnd(strm)
        return ffi.string(buf, outLen)
    end
    end) -- end pcall
    if not ok then
        _G.Inflate = function() return nil end
        _G.Deflate = function() return nil end
    end
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

-- Set installedMode to suppress developer mode warning
launch.installedMode = true
print("✓ installedMode set to true")
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

-- Load CharInput extension for text field support
local char_input_lib
do
    local ci_ok, ci = pcall(ffi.load, "runtime/CharInput.dylib")
    if ci_ok then
        ffi.cdef[[
            void CharInput_Init(void* glfw_window);
            int GetCharInput(void);
        ]]
        -- Get GLFW window from SimpleGraphic context
        -- sg_get_context() returns SGContext*, first field is void* window
        local ctx = sg.sg_get_context()
        if ctx ~= nil then
            local window = ffi.cast("void**", ctx)[0]
            if window ~= nil then
                ci.CharInput_Init(window)
                char_input_lib = ci
                print("CharInput extension loaded successfully")
            else
                print("WARNING: CharInput - window handle is NULL")
            end
        else
            print("WARNING: CharInput - sg_get_context returned NULL")
        end
    else
        print("WARNING: CharInput extension not found, text input disabled")
    end
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

-- Map GLFW key names to PoB key names
local key_name_map = {
    BACKSPACE = "BACK",
}

local debug_char_file = io.open("/tmp/pob_char_debug.txt", "w")
local function debug_char(msg)
    if debug_char_file then
        debug_char_file:write(msg .. "\n")
        debug_char_file:flush()
    end
end

local function dispatch_key_event(key, is_down, double_click)
    local mapped_key = key_name_map[key] or key
    if mapped_key == "BACK" or mapped_key == "DELETE" or #key == 1 then
        debug_char(string.format("DEBUG KEY: %s (%s) %s", mapped_key, key, is_down and "DOWN" or "UP"))
    end
    if is_down then
        if launch and launch.OnKeyDown then
            launch:OnKeyDown(mapped_key, double_click)
        end
    else
        if launch and launch.OnKeyUp then
            launch:OnKeyUp(mapped_key)
        end
    end
end

local function poll_input_events()
    if not launch then
        return
    end

    local cursorX, cursorY = GetCursorPos()

    -- Key events
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

    -- Mouse wheel events
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

    -- Character input (only printable characters, filter control chars)
    if char_input_lib then
        while true do
            local ch = char_input_lib.GetCharInput()
            if ch == 0 then break end
            debug_char(string.format("DEBUG CHAR: codepoint=%d (0x%02X)", ch, ch))
            if ch >= 32 and ch ~= 127 then
                local char_str
                if ch < 128 then
                    char_str = string.char(ch)
                elseif ch < 2048 then
                    char_str = string.char(192 + math.floor(ch / 64), 128 + (ch % 64))
                elseif ch < 65536 then
                    char_str = string.char(224 + math.floor(ch / 4096), 128 + math.floor((ch % 4096) / 64), 128 + (ch % 64))
                else
                    char_str = string.char(240 + math.floor(ch / 262144), 128 + math.floor((ch % 262144) / 4096), 128 + math.floor((ch % 4096) / 64), 128 + (ch % 64))
                end
                debug_char(string.format("DEBUG CHAR: dispatching OnChar('%s')", char_str))
                if launch and launch.OnChar then
                    launch:OnChar(char_str)
                end
            else
                debug_char(string.format("DEBUG CHAR: FILTERED control char %d", ch))
            end
        end
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

-- Set window title to Path of Building
SetWindowTitle("Path of Building (PoE2)")

while IsUserTerminated() == 0 do
    frame_count = frame_count + 1

    -- Debug: Log every frame for first 10 frames, then every 10 frames
    if frame_count <= 10 or frame_count % 10 == 0 then
        print(string.format("Frame %d: IsUserTerminated() = 0, calling ProcessEvents()...", frame_count))
    end

    -- Debug: Print error message if present
    if frame_count == 1 and launch and launch.promptMsg then
        print("===============================================")
        print("ERROR MESSAGE DETECTED:")
        print(launch.promptMsg)
        print("===============================================")
    end

    ProcessEvents()

    if frame_count <= 10 or frame_count % 10 == 0 then
        print(string.format("Frame %d: ProcessEvents() complete, polling input...", frame_count))
    end

    poll_input_events()

    -- Reset viewport state at start of each frame (prevents cross-frame leaks)
    ResetViewport()

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
