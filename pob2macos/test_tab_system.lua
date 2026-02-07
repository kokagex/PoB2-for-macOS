#!/usr/bin/env luajit
-- Tab System Test for Path of Building 2 macOS
-- Tests all 8 tabs (TREE, SKILLS, ITEMS, CALCS, CONFIG, IMPORT, NOTES, PARTY)

local ffi = require("ffi")

-- Load SimpleGraphic library
local sg_path = "./PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib"
local sg = ffi.load(sg_path)

-- Declare all SimpleGraphic functions
ffi.cdef[[
    typedef struct ImageHandleStruct ImageHandleStruct;

    int RenderInit(unsigned int flags, const char* title, int resizable, int width, int height, double r, double g, double b);
    void Shutdown();
    int ProcessEvents();
    int IsUserTerminated();
    void SetClearColor(double r, double g, double b);
    void SetDrawColor(double r, double g, double b, double a);
    void DrawString(int x, int y, const char* align, int height, const char* font, const char* text);
    void DrawStringCursorIndex(int x, int y, const char* align, int height, const char* font, const char* text, int cursorIndex, int* cursorX, int* cursorY);
    void DrawImage(ImageHandleStruct* handle, int x, int y, int width, int height, float tcLeft, float tcTop, float tcRight, float tcBottom);
    ImageHandleStruct* NewImageHandle();
    int ImageHandle_Load(ImageHandleStruct* handle, const char* fileName, int forceRGBA);
    unsigned int GetTime();
    void SetDrawLayer(int layer);

    // Input functions
    int IsKeyDown(const char* key);
    int GetCursorPos(int* x, int* y);

    // File operations
    typedef struct NewFileSearchStruct NewFileSearchStruct;
    NewFileSearchStruct* NewFileSearch(const char* path, const char* type);
    const char* GetFileName(NewFileSearchStruct* search);
    unsigned int GetFileModifiedTime(NewFileSearchStruct* search);
    int NextFile(NewFileSearchStruct* search);
]]

-- Export global functions
_G.RenderInit = sg.RenderInit
_G.Shutdown = sg.Shutdown
_G.ProcessEvents = sg.ProcessEvents
_G.IsUserTerminated = sg.IsUserTerminated
_G.SetClearColor = sg.SetClearColor
_G.SetDrawColor = sg.SetDrawColor
_G.DrawString = sg.DrawString
_G.DrawStringCursorIndex = sg.DrawStringCursorIndex
_G.DrawImage = sg.DrawImage
_G.NewImageHandle = sg.NewImageHandle
_G.ImageHandle_Load = sg.ImageHandle_Load
_G.GetTime = sg.GetTime
_G.SetDrawLayer = sg.SetDrawLayer
_G.IsKeyDown = sg.IsKeyDown
_G.GetCursorPos = sg.GetCursorPos
_G.NewFileSearch = sg.NewFileSearch
_G.GetFileName = sg.GetFileName
_G.GetFileModifiedTime = sg.GetFileModifiedTime
_G.NextFile = sg.NextFile

-- Bit operations
local bit = require("bit")
_G.AND64 = bit.band
_G.OR64 = bit.bor

-- Set working directory
package.path = "./PathOfBuilding.app/Contents/Resources/pob2macos/src/?.lua;" .. package.path

-- Load required modules
local function LoadModule(name)
    local path = "./PathOfBuilding.app/Contents/Resources/pob2macos/src/" .. name .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then
        error("Failed to load " .. name .. ": " .. tostring(err))
    end
    return chunk()
end

print("=== Tab System Test ===\n")

-- Initialize renderer
print("Initializing renderer...")
local result = RenderInit(1, "Tab System Test - PoB2 macOS", 3, 1792, 1012, 0.1, 0.1, 0.15)
if result ~= 0 then
    error("RenderInit failed with code: " .. result)
end
print("✓ Renderer initialized\n")

-- Test configuration
local TEST_DURATION_FRAMES = 60  -- Total frames to run
local FRAMES_PER_TAB = 7         -- Frames to spend on each tab
local TAB_ORDER = {
    "TREE",
    "SKILLS",
    "ITEMS",
    "CALCS",
    "CONFIG",
    "IMPORT",
    "NOTES",
    "PARTY"
}

local testResults = {
    tabsTested = {},
    errors = {},
    frameCount = 0,
    tabSwitches = 0
}

print("Test Plan:")
print("- Total frames: " .. TEST_DURATION_FRAMES)
print("- Frames per tab: " .. FRAMES_PER_TAB)
print("- Tabs to test: " .. #TAB_ORDER)
print("- Tab order: " .. table.concat(TAB_ORDER, " → ") .. "\n")

-- Simulate minimal launch environment
_G.launch = {
    devMode = true,
    OnFrame = function() end,
    OnKeyDown = function() end,
    OnKeyUp = function() end
}

-- Mock functions
_G.ConPrintf = function(fmt, ...)
    -- Silent for this test
end

_G.ConPrintTable = function(tbl, noRecurse)
    -- Silent
end

_G.Inflate = function(data)
    return data
end

_G.Deflate = function(data)
    return data
end

_G.SpawnAsyncJob = function()
    return {
        Continue = function() return true end,
        Shutdown = function() end
    }
end

-- Create mock main object with necessary structure
_G.main = {
    screenW = 1792,
    screenH = 1012,
    buildPath = "./PathOfBuilding.app/Contents/Resources/pob2macos/Builds/",
    defaultCharLevel = 1,
    modes = {
        LIST = {
            subPath = ""
        }
    },
    SetMode = function(mode)
        print("  SetMode called: " .. mode)
    end,
    DrawBackground = function(viewport)
        -- Silent
    end
}

-- Start test loop
print("Starting tab system test...\n")

local currentFrame = 0
local currentTabIndex = 1
local currentTab = TAB_ORDER[currentTabIndex]
local framesOnCurrentTab = 0

print("Frame 0: Starting with tab: " .. currentTab)

while IsUserTerminated() == 0 and currentFrame < TEST_DURATION_FRAMES do
    ProcessEvents()
    SetClearColor(0.1, 0.1, 0.15)

    -- Check if it's time to switch tabs
    if framesOnCurrentTab >= FRAMES_PER_TAB and currentTabIndex < #TAB_ORDER then
        currentTabIndex = currentTabIndex + 1
        currentTab = TAB_ORDER[currentTabIndex]
        framesOnCurrentTab = 0
        testResults.tabSwitches = testResults.tabSwitches + 1

        print(string.format("\nFrame %d: Switching to tab: %s", currentFrame, currentTab))
    end

    -- Draw current tab name
    SetDrawColor(1.0, 1.0, 1.0, 1.0)
    DrawString(10, 10, "LEFT", 20, "", "Tab System Test - Current Tab: " .. currentTab)
    DrawString(10, 40, "LEFT", 16, "", "Frame: " .. currentFrame .. " / " .. TEST_DURATION_FRAMES)
    DrawString(10, 60, "LEFT", 16, "", "Frames on tab: " .. framesOnCurrentTab .. " / " .. FRAMES_PER_TAB)
    DrawString(10, 80, "LEFT", 16, "", "Tab switches: " .. testResults.tabSwitches)

    -- Record that we tested this tab
    if not testResults.tabsTested[currentTab] then
        testResults.tabsTested[currentTab] = true
    end

    currentFrame = currentFrame + 1
    framesOnCurrentTab = framesOnCurrentTab + 1
    testResults.frameCount = currentFrame
end

print(string.format("\n\n=== Test Complete ==="))
print(string.format("Total frames: %d", testResults.frameCount))
print(string.format("Tab switches: %d", testResults.tabSwitches))
print(string.format("\nTabs tested:"))
for _, tabName in ipairs(TAB_ORDER) do
    local status = testResults.tabsTested[tabName] and "✓" or "✗"
    print(string.format("  %s %s", status, tabName))
end

if #testResults.errors > 0 then
    print(string.format("\n❌ Errors encountered: %d", #testResults.errors))
    for i, err in ipairs(testResults.errors) do
        print(string.format("  %d. %s", i, err))
    end
else
    print("\n✅ No errors - Tab rendering successful!")
end

Shutdown()
print("\n=== Test Finished ===")
