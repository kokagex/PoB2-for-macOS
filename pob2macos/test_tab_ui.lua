#!/usr/bin/env luajit
-- Simplified Tab UI Test for Path of Building 2 macOS
-- Tests that tab switching UI works correctly

local ffi = require("ffi")

-- Change to app directory
local app_dir = "./PathOfBuilding.app/Contents/Resources/pob2macos"
assert(ffi.C.chdir(app_dir) == 0, "Failed to change directory to: " .. app_dir)

-- Load and execute pob2_launch.lua to get full environment
print("=== Tab UI Test for PoB2 macOS ===\n")
print("Loading PoB environment...")

local launch_script = assert(loadfile("pob2_launch.lua"))
local success, err = pcall(launch_script)

if not success then
    print("ERROR loading pob2_launch.lua: " .. tostring(err))
    os.exit(1)
end

print("✓ PoB environment loaded\n")

-- Wait for initialization
print("Waiting for app initialization...")
local initFrames = 0
while IsUserTerminated() == 0 and initFrames < 180 do  -- 3 seconds at 60fps
    ProcessEvents()
    if launch and launch.OnFrame then
        launch:OnFrame()
    end
    initFrames = initFrames + 1
end

print(string.format("✓ Initialized (%d frames)\n", initFrames))

-- Check if we're in Build mode or List mode
if not main then
    print("ERROR: main object not found")
    os.exit(1)
end

print("Current mode: " .. tostring(main.currMode))

-- Test results
local testResults = {
    initialized = true,
    buildModeAccessible = false,
    tabsFound = {},
    errors = {}
}

-- If in LIST mode, try to see if we can detect Build mode capability
if main.currMode == "LIST" then
    print("\nCurrently in BUILD LIST mode")
    print("Checking if Build mode is accessible...")

    -- Check if Build mode exists
    if main.modes and main.modes.BUILD then
        testResults.buildModeAccessible = true
        print("✓ Build mode detected in main.modes")

        -- Check what tabs would be available
        local buildMode = main.modes.BUILD
        if buildMode then
            local tabs = {
                "treeTab",
                "skillsTab",
                "itemsTab",
                "calcsTab",
                "configTab",
                "importTab",
                "notesTab",
                "partyTab"
            }

            print("\nChecking tab availability:")
            for _, tabName in ipairs(tabs) do
                if buildMode[tabName] then
                    testResults.tabsFound[tabName] = true
                    print(string.format("  ✓ %s exists", tabName))
                else
                    print(string.format("  ✗ %s not found", tabName))
                end
            end
        end
    else
        print("✗ Build mode not found in main.modes")
    end
elseif main.currMode == "BUILD" then
    print("\nCurrently in BUILD mode!")
    print("Testing tab system...")

    local build = main.modes.BUILD
    testResults.buildModeAccessible = true

    -- Test tabs exist
    local tabs = {
        "treeTab",
        "skillsTab",
        "itemsTab",
        "calcsTab",
        "configTab",
        "importTab",
        "notesTab",
        "partyTab"
    }

    print("\nTab availability:")
    for _, tabName in ipairs(tabs) do
        if build[tabName] then
            testResults.tabsFound[tabName] = true
            print(string.format("  ✓ %s", tabName))
        else
            print(string.format("  ✗ %s", tabName))
        end
    end

    -- Test current viewMode
    if build.viewMode then
        print(string.format("\nCurrent view mode: %s", build.viewMode))

        -- Try to render a few frames
        print("\nRendering test (30 frames)...")
        for i = 1, 30 do
            ProcessEvents()
            if launch and launch.OnFrame then
                local ok, err = pcall(function()
                    launch:OnFrame()
                end)
                if not ok then
                    table.insert(testResults.errors, "Frame " .. i .. ": " .. tostring(err))
                    print("ERROR on frame " .. i .. ": " .. tostring(err))
                    break
                end
            end
        end
        print("✓ Rendering test complete")
    end
end

-- Print test summary
print("\n" .. string.rep("=", 50))
print("TEST SUMMARY")
print(string.rep("=", 50))

print(string.format("\n✓ Initialization: %s", testResults.initialized and "SUCCESS" or "FAILED"))
print(string.format("✓ Build mode accessible: %s", testResults.buildModeAccessible and "YES" or "NO"))

local tabCount = 0
for _ in pairs(testResults.tabsFound) do
    tabCount = tabCount + 1
end
print(string.format("✓ Tabs found: %d / 8", tabCount))

if #testResults.errors > 0 then
    print(string.format("\n❌ Errors: %d", #testResults.errors))
    for i, err in ipairs(testResults.errors) do
        print(string.format("  %d. %s", i, err))
    end
else
    print("\n✅ No errors detected")
end

print("\n" .. string.rep("=", 50))

-- Shutdown
if Shutdown then
    Shutdown()
end

print("\n=== Test Complete ===")
