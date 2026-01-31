#!/usr/bin/env luajit
-- Rendering test WITHOUT text (to isolate font issues)

local ffi = require("ffi")

local lib_path = "runtime/SimpleGraphic.dylib"
ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    void ProcessEvents(void);
    void SetClearColor(float r, float g, float b);
    int IsUserTerminated(void);
]]

print("=== No-Text Render Test ===")
print("Loading library...")

local sg = ffi.load(lib_path)

print("Initializing renderer...")
sg.RenderInit("DPI_AWARE")

print("Starting render loop (3 seconds, no text)...")
local startTime = os.clock()
local frameCount = 0

while os.clock() - startTime < 3 and sg.IsUserTerminated() == 0 do
    sg.ProcessEvents()

    -- Cycle through colors
    local t = (os.clock() - startTime) / 3
    sg.SetClearColor(t, 0.2, 1.0 - t)

    frameCount = frameCount + 1
end

print("Shutting down...")
sg.Shutdown()

print("=== Test Complete ===")
print("Frames: " .. frameCount)
print("FPS: " .. string.format("%.1f", frameCount / 3))
