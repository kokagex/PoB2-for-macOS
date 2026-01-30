#!/usr/bin/env luajit
--
-- Minimal test - just initialize and show a window for 3 seconds
--

print("=== Minimal PoB2 Test ===")

local ffi = require("ffi")

ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);
    void SetWindowTitle(const char* title);
    void SetDrawColor(float r, float g, float b, float a);
    void DrawString(int left, int top, int align, int height, const char* font, const char* text);
    double GetTime(void);
    int usleep(unsigned int usec);
]]

local sg = ffi.load("runtime/SimpleGraphic.dylib")

-- Initialize
print("Initializing...")
sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("Path of Building - Test")
print("✓ Initialized")

-- Main loop
print("Running for 3 seconds...")
local start = sg.GetTime()
local frames = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start) < 3.0 do
    sg.ProcessEvents()

    -- Draw some test text
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)
    sg.DrawString(100, 100, 0, 48, "VAR", "Path of Building for macOS")
    sg.DrawString(100, 160, 0, 24, "VAR", "FreeType Text Rendering - Test")
    sg.DrawString(100, 200, 0, 18, "VAR", "If you can see this, rendering works!")

    frames = frames + 1
    ffi.C.usleep(16666)
end

print("✓ Rendered " .. frames .. " frames")
print("Shutting down...")
sg.Shutdown()
print("Done!")
