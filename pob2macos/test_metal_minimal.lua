#!/usr/bin/env lua
--[[
   Minimal Metal Rendering Test
   Tests the most basic Metal drawing functionality

   Stages:
   1. Solid color rectangle (white) using DrawImage with null handle
   2. Colored grid of rectangles
   3. Single textured rectangle (if image available)
]]

-- Initialize SimpleGraphic
local sg = require("simplegraphic")

-- Configuration
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local TEST_STAGE = 1  -- 1: white rect, 2: grid, 3: textured

-- Colors
local RED = {1, 0, 0, 1}
local GREEN = {0, 1, 0, 1}
local BLUE = {0, 0, 1, 1}
local WHITE = {1, 1, 1, 1}
local BLACK = {0, 0, 0, 1}

print("=== Minimal Metal Rendering Test ===")
print(string.format("Window: %dx%d", WINDOW_WIDTH, WINDOW_HEIGHT))

-- Initialize window
if not sg.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Metal Test") then
    print("ERROR: Failed to create window")
    os.exit(1)
end

print("Window created successfully")

-- Test Stage 1: White rectangle at various positions
function TestStage1_WhiteRectangle()
    print("\n--- Stage 1: Solid White Rectangle ---")
    print("Drawing 5 white rectangles at different positions")

    sg.SetClearColor(0, 0, 0, 1)  -- Black background
    sg.SetDrawColor(1, 1, 1, 1)   -- White rectangles

    -- Rectangle 1: Center (most important test)
    print("Drawing rect 1: (300, 200) size (200, 150)")
    sg.DrawImage(nil, 300, 200, 200, 150, 0, 0, 1, 1)

    -- Rectangle 2: Top-left
    print("Drawing rect 2: (50, 50) size (100, 100)")
    sg.DrawImage(nil, 50, 50, 100, 100, 0, 0, 1, 1)

    -- Rectangle 3: Bottom-right
    print("Drawing rect 3: (600, 400) size (150, 150)")
    sg.DrawImage(nil, 600, 400, 150, 150, 0, 0, 1, 1)

    -- Rectangle 4: Red variant
    sg.SetDrawColor(1, 0, 0, 1)
    print("Drawing rect 4: (150, 400) size (150, 100) - RED")
    sg.DrawImage(nil, 150, 400, 150, 100, 0, 0, 1, 1)

    -- Rectangle 5: Green variant
    sg.SetDrawColor(0, 1, 0, 1)
    print("Drawing rect 5: (650, 50) size (100, 100) - GREEN")
    sg.DrawImage(nil, 650, 50, 100, 100, 0, 0, 1, 1)
end

function TestStage2_ColoredGrid()
    print("\n--- Stage 2: Colored Grid ---")
    print("Drawing 3x3 grid of colored rectangles")

    sg.SetClearColor(0.2, 0.2, 0.2, 1)  -- Dark gray background

    local colors = {
        {1, 0, 0, 1},  -- Red
        {0, 1, 0, 1},  -- Green
        {0, 0, 1, 1},  -- Blue
    }

    local cellSize = 200
    local startX = 50
    local startY = 50

    for row = 0, 2 do
        for col = 0, 2 do
            local color = colors[(row * 3 + col) % #colors + 1]
            sg.SetDrawColor(color[1], color[2], color[3], color[4])

            local x = startX + col * cellSize + 10
            local y = startY + row * cellSize + 10

            print(string.format("Grid cell (%d,%d) at (%d,%d)", col, row, x, y))
            sg.DrawImage(nil, x, y, cellSize - 20, cellSize - 20, 0, 0, 1, 1)
        end
    end
end

function TestStage3_TexturedRectangle()
    print("\n--- Stage 3: Textured Rectangle ---")
    print("Attempting to load and render a textured rectangle")

    -- Try to load an image
    local img = sg.LoadImage("test_image.png")
    if not img then
        print("WARNING: test_image.png not found, skipping textured test")
        return
    end

    sg.SetClearColor(0, 0, 0, 1)
    sg.SetDrawColor(1, 1, 1, 1)

    print("Drawing textured rectangle at (100, 100) size (400, 300)")
    sg.DrawImage(img, 100, 100, 400, 300, 0, 0, 1, 1)
end

-- Main render loop
local frameCount = 0
local lastTime = 0

print("\nStarting render loop (press ESC to exit)...")

while not sg.IsWindowClosed() do
    frameCount = frameCount + 1

    -- Render based on stage
    if TEST_STAGE == 1 then
        TestStage1_WhiteRectangle()
    elseif TEST_STAGE == 2 then
        TestStage2_ColoredGrid()
    elseif TEST_STAGE == 3 then
        TestStage3_TexturedRectangle()
    end

    -- Print progress every 30 frames
    if frameCount % 30 == 0 then
        print(string.format("Frame %d - Stage %d running...", frameCount, TEST_STAGE))
    end

    -- Allow switching stages with number keys (in a real app)
    -- For now, just loop the same stage

    -- Sleep briefly to avoid 100% CPU
    os.execute("sleep 0.016")  -- ~60 FPS

    -- Limit to 300 frames for testing
    if frameCount >= 300 then
        print("\nReached 300 frames, closing window...")
        break
    end
end

-- Cleanup
print("\nTest completed")
sg.DestroyWindow()
print("Window destroyed, test finished")
