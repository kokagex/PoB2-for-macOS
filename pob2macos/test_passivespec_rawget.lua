#!/usr/bin/env luajit
-- Test PassiveSpec rawget/rawset implementation
-- This test creates a build to trigger PassiveSpec initialization

local ffi = require("ffi")

-- Load SimpleGraphic library
local sg = ffi.load("runtime/SimpleGraphic.dylib")

-- FFI declarations (minimal set needed for test)
ffi.cdef[[
    void RenderInit(unsigned int flags);
    void ProcessEvents();
    int IsUserTerminated();
    void SetClearColor(float r, float g, float b);
    void Shutdown();
]]

-- Initialize graphics
print("=== PassiveSpec rawget/rawset Test ===")
print("Initializing graphics...")
sg.RenderInit(0x00000001)  -- DPI_AWARE

-- Load Launch.lua
print("Loading Launch.lua...")
package.path = package.path .. ";./src/?.lua;./src/Modules/?.lua;./src/Classes/?.lua"
local launch = require("Launch")

-- Initialize launch
print("Calling launch:OnInit()...")
launch:OnInit()

-- Set clear color
sg.SetClearColor(0.05, 0.05, 0.08)

-- Main loop - run for 5 seconds to trigger PassiveSpec initialization
print("Running main loop (5 seconds)...")
local frameCount = 0
local startTime = os.time()

while sg.IsUserTerminated() == 0 do
    sg.ProcessEvents()

    if launch.OnFrame then
        launch:OnFrame()
    end

    frameCount = frameCount + 1

    -- Exit after 5 seconds
    if os.time() - startTime >= 5 then
        print(string.format("Test complete - ran %d frames", frameCount))
        break
    end
end

-- Shutdown
print("Shutting down...")
sg.Shutdown()

print("=== Test Complete ===")
