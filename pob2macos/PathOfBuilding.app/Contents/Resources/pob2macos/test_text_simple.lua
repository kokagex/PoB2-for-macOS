#!/usr/bin/env lua

-- Simple text rendering verification test

print("=== Simple Text Rendering Test ===\n")

local ffi = require("ffi")

ffi.cdef[[
    void RenderInit(const char* flags);
    void SetWindowTitle(const char* title);
    void SetDrawColor(float r, float g, float b, float a);
    void SetClearColor(float r, float g, float b, float a);
    void DrawString(int left, int top, int align, int height,
                    const char* font, const char* text);
    double GetTime(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);
    void Shutdown(void);
    int usleep(unsigned int usec);
]]

local sg = ffi.load("runtime/SimpleGraphic.dylib")

sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("FreeType Text Test - Look for white text!")
sg.SetClearColor(0.0, 0.0, 0.0, 1.0)  -- Black background

print("Window should show white text on black background")
print("Press ESC or close window to exit\n")

local start_time = sg.GetTime()
local frame_count = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start_time) < 10.0 do
    sg.ProcessEvents()

    -- Draw some test text
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)  -- White
    sg.DrawString(100, 100, 0, 48, "VAR", "Hello, FreeType!")

    sg.SetDrawColor(1.0, 0.0, 0.0, 1.0)  -- Red
    sg.DrawString(100, 160, 0, 32, "VAR", "Red Text")

    sg.SetDrawColor(0.0, 1.0, 0.0, 1.0)  -- Green
    sg.DrawString(100, 220, 0, 32, "VAR", "Green Text")

    sg.SetDrawColor(0.0, 0.5, 1.0, 1.0)  -- Blue
    sg.DrawString(100, 280, 0, 32, "VAR", "Blue Text")

    sg.SetDrawColor(1.0, 1.0, 0.0, 1.0)  -- Yellow
    sg.DrawString(100, 340, 0, 24, "VAR", "Japanese: テキスト表示テスト")

    ffi.C.usleep(16666)  -- 60 FPS
    frame_count = frame_count + 1
end

local elapsed = sg.GetTime() - start_time
print(string.format("Rendered %d frames in %.2f seconds (%.1f FPS)", frame_count, elapsed, frame_count / elapsed))

sg.Shutdown()
print("Test complete!")
