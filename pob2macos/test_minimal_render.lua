#!/usr/bin/env luajit
-- Minimal rendering test to verify SimpleGraphic functionality

local ffi = require("ffi")

-- Load SimpleGraphic library
local lib_path = "runtime/SimpleGraphic.dylib"
ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    void ProcessEvents(void);
    void SetClearColor(float r, float g, float b);
    void DrawString(float left, float top, const char* align, float height, const char* font, const char* text);
    int IsUserTerminated(void);
]]

print("=== Minimal SimpleGraphic Render Test ===")
print("1. Loading library: " .. lib_path)

local success, sg = pcall(ffi.load, lib_path)
if not success then
    print("ERROR: Failed to load SimpleGraphic library")
    print("  " .. tostring(sg))
    os.exit(1)
end

print("2. Initializing renderer...")
sg.RenderInit("DPI_AWARE")

print("3. Starting render loop (5 seconds)...")
local startTime = os.clock()
local frameCount = 0

while os.clock() - startTime < 5 and sg.IsUserTerminated() == 0 do
    -- CRITICAL: ProcessEvents MUST be called FIRST
    sg.ProcessEvents()

    -- Clear screen to dark blue
    sg.SetClearColor(0.1, 0.1, 0.3)

    -- Draw text with proper font name
    sg.DrawString(100, 100, "LEFT", 16, "VAR", "SimpleGraphic Test - Frame: " .. frameCount)
    sg.DrawString(100, 130, "LEFT", 14, "VAR", string.format("Time: %.1fs", os.clock() - startTime))

    frameCount = frameCount + 1
end

print("4. Shutting down...")
sg.Shutdown()

print("=== Test Complete ===")
print("Total frames rendered: " .. frameCount)
print("Average FPS: " .. string.format("%.1f", frameCount / 5))
