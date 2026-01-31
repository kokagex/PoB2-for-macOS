-- Test script for image loading with stb_image
-- This verifies that PNG files can be loaded and rendered

print("=== Image Loading Test ===")

-- Load SimpleGraphic
local sg = require("simplegraphic")

-- Initialize
print("Initializing SimpleGraphic...")
sg.Init("")

-- Show window
print("Showing window...")
sg.ShowWindow()

-- Create image handle
print("Creating image handle...")
local imgHandle = sg.NewImageHandle()

-- Try to load a PNG file (using a passive tree node image)
local testImagePath = "PathOfBuilding.app/Contents/Resources/pob2macos/TreeData/0_4/Character_orbit_normal1.png"
print("Loading image: " .. testImagePath)

local success = sg.ImageHandle_Load(imgHandle, testImagePath, 0)
print("Load result: " .. tostring(success))

if success == 1 then
    local width, height = sg.ImageHandle_ImageSize(imgHandle)
    print(string.format("Image loaded successfully: %dx%d", width, height))
    local isValid = sg.ImageHandle_IsValid(imgHandle)
    print("Image valid: " .. tostring(isValid))
else
    print("ERROR: Failed to load image!")
end

-- Main render loop
print("Starting render loop...")
local frameCount = 0
while not sg.IsKeyDown("ESCAPE") do
    sg.SetClearColor(0.2, 0.2, 0.3, 1.0)

    if success == 1 then
        -- Draw the loaded image in the center
        sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)
        sg.DrawImage(imgHandle, 400, 300, 256, 256)
    end

    sg.SwapBuffers()

    frameCount = frameCount + 1
    if frameCount >= 300 then  -- 5 seconds at 60fps
        print("Test complete - 5 seconds rendered")
        break
    end
end

-- Cleanup
print("Cleaning up...")
sg.ImageHandle_Unload(imgHandle)
sg.Shutdown()

print("=== Test Complete ===")
