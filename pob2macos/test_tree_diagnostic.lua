#!/usr/bin/env luajit
-- Passive Tree Rendering Diagnostic Script

print("=== Passive Tree Rendering Diagnostic ===\n")

-- Change to app bundle directory
local appBundleRoot = "/Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos"
package.path = appBundleRoot .. "/src/?.lua;" .. appBundleRoot .. "/?.lua;" .. package.path

-- Save current directory and change to app bundle
local originalDir = io.popen("pwd"):read()
print("Original directory: " .. originalDir)

local function checkFile(path)
    local fullPath = appBundleRoot .. "/" .. path
    local f = io.open(fullPath, "r")
    if f then
        f:close()
        print("✓ Found: " .. path)
        return true
    else
        print("✗ NOT Found: " .. path)
        return false
    end
end

print("\n1. Checking TreeData files:")
local hasTreeData = checkFile("TreeData/0_4/tree.lua")

print("\n2. Checking Assets:")
local hasAssets = true
local testAssets = {
    "Assets/ring.png",
    "Assets/small_ring.png",
    "Assets/PSStartNodeBackgroundInactive.png",
    "Assets/NotableFrameUnallocated.png"
}
for _, asset in ipairs(testAssets) do
    if not checkFile(asset) then
        hasAssets = false
    end
end

print("\n3. Attempting to load tree data:")
if hasTreeData then
    local treeDataPath = appBundleRoot .. "/TreeData/0_4/tree.lua"
    local success, result = pcall(function()
        return dofile(treeDataPath)
    end)

    if success and result then
        print("✓ Tree data loaded successfully")
        print("  - Has classes: " .. (result.classes and "YES" or "NO"))
        print("  - Has assets: " .. (result.assets and "YES" or "NO"))
        print("  - Has ddsCoords: " .. (result.ddsCoords and "YES" or "NO"))

        if result.assets then
            local assetCount = 0
            for _ in pairs(result.assets) do assetCount = assetCount + 1 end
            print("  - Asset count: " .. assetCount)

            if result.assets.Background2 then
                print("  - Background2 asset: FOUND")
                print("    File: " .. (result.assets.Background2[1] or "N/A"))
            end
        end

        if result.nodes then
            local nodeCount = 0
            for _ in pairs(result.nodes) do nodeCount = nodeCount + 1 end
            print("  - Node count: " .. nodeCount)
        end
    else
        print("✗ Tree data load FAILED")
        print("  Error: " .. tostring(result))
    end
else
    print("✗ Skipping tree data load (file not found)")
end

print("\n4. Checking SimpleGraphic library:")
local libPath = appBundleRoot .. "/runtime/SimpleGraphic.dylib"
checkFile("runtime/SimpleGraphic.dylib")

print("\n=== Diagnostic Complete ===")
