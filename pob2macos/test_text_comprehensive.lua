#!/usr/bin/env luajit

-- Comprehensive FreeType Text Rendering Test
-- Tests all features: UTF-8, colors, alignment, sizes, escape codes

print("=== Comprehensive FreeType Test ===\n")

local ffi = require("ffi")

ffi.cdef[[
    void RenderInit(const char* flags);
    void SetWindowTitle(const char* title);
    void GetScreenSize(int* width, int* height);
    void SetDrawColor(float r, float g, float b, float a);
    void SetClearColor(float r, float g, float b, float a);
    void DrawString(int left, int top, int align, int height,
                    const char* font, const char* text);
    int DrawStringWidth(int height, const char* font, const char* text);
    double GetTime(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);
    void Shutdown(void);
    int usleep(unsigned int usec);
]]

local sg = ffi.load("runtime/SimpleGraphic.dylib")

-- Initialize
sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("FreeType Comprehensive Test - All Features")
sg.SetClearColor(0.05, 0.05, 0.1, 1.0)

local width = ffi.new("int[1]")
local height = ffi.new("int[1]")
sg.GetScreenSize(width, height)

print(string.format("Screen: %dx%d\n", width[0], height[0]))

-- Test data
local tests = {
    {y = 50, size = 48, align = 0, text = "FreeType Text Rendering"},
    {y = 120, size = 32, align = 0, text = "UTF-8 Test: こんにちは 世界 テキスト"},
    {y = 170, size = 24, align = 0, text = "Emoji Support: 🎮 🔥 ⚡ (if font has them)"},
    {y = 210, size = 20, align = 0, text = "Mixed: English 日本語 123 !@#$%"},
    {y = 250, size = 18, align = 0, text = "Left Aligned Text (default)"},
    {y = 290, size = 18, align = 1, text = "Center Aligned Text"},
    {y = 330, size = 18, align = 2, text = "Right Aligned Text"},
    {y = 380, size = 16, align = 0, text = "Font sizes: 14 16 18 20 24 32 48"},
}

-- Color test text with escape codes
local color_tests = {
    {y = 430, text = "^0White ^1Red ^2Green ^3Blue ^4Yellow"},
    {y = 460, text = "^5Magenta ^6Cyan ^7Gray ^8Orange ^9Purple"},
    {y = 490, text = "^xFF0000Red ^x00FF00Green ^x0000FFBlue"},
}

print("Running 10-second visual test...")
print("Look for:\n")
print("✓ Multiple font sizes (14-48px)")
print("✓ Japanese characters (UTF-8)")
print("✓ Left/Center/Right alignment")
print("✓ Color escape codes (^0-9, ^xRRGGBB)")
print("✓ Smooth rendering at ~60 FPS\n")

local start = sg.GetTime()
local frame = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start) < 10.0 do
    sg.ProcessEvents()

    -- Draw header
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)
    for _, t in ipairs(tests) do
        local x = 50
        if t.align == 1 then
            x = width[0] / 2
        elseif t.align == 2 then
            x = width[0] - 50
        end
        sg.DrawString(x, t.y, t.align, t.size, "VAR", t.text)
    end

    -- Draw color tests (escape codes)
    for _, t in ipairs(color_tests) do
        sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)  -- Default white
        sg.DrawString(50, t.y, 0, 16, "VAR", t.text)
    end

    -- Draw FPS counter
    local fps = frame / (sg.GetTime() - start)
    local fps_text = string.format("Frame: %d | FPS: %.1f", frame, fps)
    sg.SetDrawColor(0.5, 1.0, 0.5, 1.0)
    sg.DrawString(50, height[0] - 50, 0, 14, "VAR", fps_text)

    ffi.C.usleep(16666)  -- ~60 FPS
    frame = frame + 1
end

local elapsed = sg.GetTime() - start
local avg_fps = frame / elapsed

print(string.format("\n✅ Test Complete!"))
print(string.format("   Frames: %d", frame))
print(string.format("   Time: %.2fs", elapsed))
print(string.format("   Average FPS: %.1f", avg_fps))

if avg_fps >= 55 then
    print("   Performance: ✅ PASS (≥55 FPS)")
else
    print("   Performance: ⚠️  WARN (<55 FPS)")
end

sg.Shutdown()
print("\n=== All Tests Complete ===")
