#!/usr/bin/env luajit
-- Simple Tab Test - Runs from app directory
-- Tests tab system accessibility

print("=== Tab System Test ===\n")

-- Load pob2_launch.lua to get full environment
local success, err = pcall(function()
    dofile("pob2_launch.lua")
end)

if not success then
    print("ERROR loading pob2_launch.lua: " .. tostring(err))
    os.exit(1)
end

print("✓ PoB environment loaded")

-- Initialize and wait for app to load
print("\nInitializing (180 frames)...")
for i = 1, 180 do
    if IsUserTerminated() ~= 0 then break end
    ProcessEvents()
    if launch and launch.OnFrame then
        pcall(function() launch:OnFrame() end)
    end
end

print("✓ Initialization complete\n")

-- Check main object
if not main then
    print("ERROR: main object not available")
    Shutdown()
    os.exit(1)
end

print("Current mode: " .. tostring(main.currMode))

-- Test results
local results = {
    mode = main.currMode,
    buildMode = nil,
    tabs = {},
    tabCount = 0
}

-- Get Build mode
if main.modes and main.modes.BUILD then
    results.buildMode = main.modes.BUILD
    print("\n✓ Build mode found")

    -- Check all tabs
    local tabNames = {
        "treeTab",
        "skillsTab",
        "itemsTab",
        "calcsTab",
        "configTab",
        "importTab",
        "notesTab",
        "partyTab"
    }

    print("\nTab System Check:")
    print(string.rep("-", 40))

    for _, tabName in ipairs(tabNames) do
        local tab = results.buildMode[tabName]
        if tab then
            results.tabs[tabName] = {
                exists = true,
                hasDrawMethod = type(tab.Draw) == "function"
            }
            results.tabCount = results.tabCount + 1

            local drawStatus = results.tabs[tabName].hasDrawMethod and "Draw ✓" or "Draw ✗"
            print(string.format("  ✓ %-15s %s", tabName, drawStatus))
        else
            results.tabs[tabName] = { exists = false }
            print(string.format("  ✗ %-15s NOT FOUND", tabName))
        end
    end

    -- Check current viewMode
    if results.buildMode.viewMode then
        print(string.format("\nCurrent viewMode: %s", results.buildMode.viewMode))
    end
else
    print("\n✗ Build mode NOT found in main.modes")
end

-- Summary
print("\n" .. string.rep("=", 50))
print("SUMMARY")
print(string.rep("=", 50))
print(string.format("Tabs found: %d / 8", results.tabCount))

if results.tabCount == 8 then
    print("\n✅ SUCCESS: All 8 tabs are accessible")
    print("✅ Tab system ready for Stage 5")
elseif results.tabCount > 0 then
    print(string.format("\n⚠️  PARTIAL: %d tabs found, %d missing", results.tabCount, 8 - results.tabCount))
else
    print("\n❌ FAILED: No tabs accessible")
end

print("\n" .. string.rep("=", 50))

-- Shutdown
Shutdown()
print("\nTest complete")
