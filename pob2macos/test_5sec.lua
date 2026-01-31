#!/usr/bin/env luajit
--[[
   Minimal DrawImage Test for Metal Backend
   This test focuses on the DrawImage function which is currently broken.

   Test Sequence:
   1. Initialize window with black background
   2. Attempt to draw 5 white rectangles using DrawImage with null handle
   3. Expected: White rectangles visible on black background
   4. Actual: No visible rectangles (this is the bug)

   Key observations to look for:
   - Does a solid white rectangle appear at (300, 200)?
   - Do rectangles at different positions all fail or only some?
   - Is there any visual output at all from DrawImage calls?
]]

local ffi = require("ffi")

ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);
    void SetWindowTitle(const char* title);
    void SetClearColor(float r, float g, float b, float a);
    void SetDrawColor(float r, float g, float b, float a);
    void DrawString(int left, int top, int align, int height, const char* font, const char* text);
    void DrawImage(void* handle, float left, float top, float width, float height,
                   float tcLeft, float tcTop, float tcRight, float tcBottom);
    double GetTime(void);
    int usleep(unsigned int usec);
]]

local sg = ffi.load("runtime/SimpleGraphic.dylib")

print("=== DrawImage Minimal Test ===")
print("Testing DrawImage with null handle (solid color rectangles)\n")

-- Initialize
print("1. Initializing SimpleGraphic...")
sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("DrawImage Test - Metal Backend")
print("   ✓ Initialized\n")

-- Main render loop
print("2. Running render loop (10 seconds)...")
print("   Expected: White rectangles on black background")
print("   Actual: [Observing...]\n")

local startTime = sg.GetTime()
local frames = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - startTime) < 5.0 do
    sg.ProcessEvents()

    -- Set black background
    sg.SetClearColor(0.0, 0.0, 0.0, 1.0)

    -- Draw reference text (should work since DrawString works)
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)
    sg.DrawString(10, 10, 0, 16, "VAR", "DrawImage Test - Looking for white rectangles below")

    -- Now test DrawImage with null handle (solid color rectangles)
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)  -- White

    -- Test 1: Center rectangle (primary test)
    -- Coordinates: (300, 200) size (200, 150)
    -- This should be clearly visible in the center-left area
    sg.DrawImage(nil, 300, 200, 200, 150, 0, 0, 1, 1)

    -- Test 2: Top-left rectangle (reference position)
    sg.DrawImage(nil, 50, 50, 100, 100, 0, 0, 1, 1)

    -- Test 3: Red rectangle (different color)
    sg.SetDrawColor(1.0, 0.0, 0.0, 1.0)
    sg.DrawImage(nil, 150, 400, 150, 100, 0, 0, 1, 1)

    -- Test 4: Green rectangle
    sg.SetDrawColor(0.0, 1.0, 0.0, 1.0)
    sg.DrawImage(nil, 650, 50, 100, 100, 0, 0, 1, 1)

    -- Test 5: Blue rectangle
    sg.SetDrawColor(0.0, 0.0, 1.0, 1.0)
    sg.DrawImage(nil, 600, 400, 150, 150, 0, 0, 1, 1)

    -- Print progress every 30 frames
    frames = frames + 1
    if frames % 30 == 0 then
        local elapsed = sg.GetTime() - startTime
        print(string.format("   Frame %d (%.1f/10.0 sec) - Check window for rectangles", frames, elapsed))
    end

    ffi.C.usleep(16666)  -- ~60 FPS
end

print(string.format("\n3. Test completed"))
print(string.format("   Total frames: %d", frames))
print(string.format("   Elapsed time: %.1f seconds\n", sg.GetTime() - startTime))

-- Cleanup
print("4. Shutting down...")
sg.Shutdown()
print("   ✓ Shutdown complete\n")

print("=== Test Summary ===")
print("If you saw colored rectangles on black background, DrawImage is working.")
print("If you saw ONLY text and no rectangles, DrawImage is broken.")
print("(DrawString working = rectangles missing = Metal DrawImage bug confirmed)")
