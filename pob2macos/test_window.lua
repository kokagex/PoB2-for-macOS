#!/usr/bin/env luajit
-- 簡単なウィンドウ表示テスト

local ffi = require("ffi")

ffi.cdef[[
    void RenderInit(const char* flags);
    void SetWindowTitle(const char* title);
    void SetClearColor(float r, float g, float b, float a);
    void ProcessEvents(void);
    int IsUserTerminated(void);
    double GetTime(void);
    void Shutdown(void);
    int usleep(unsigned int usec);
]]

local sg = ffi.load("runtime/SimpleGraphic.dylib")

print("=== Path of Building ウィンドウテスト ===\n")

-- 初期化
sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("Path of Building - macOS版")
sg.SetClearColor(0.1, 0.1, 0.2, 1.0)

print("ウィンドウが表示されました")
print("5秒間表示します（ESCキーで終了）\n")

local start = sg.GetTime()
local frames = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start) < 5.0 do
    sg.ProcessEvents()
    ffi.C.usleep(16666)  -- ~60 FPS
    frames = frames + 1
end

local elapsed = sg.GetTime() - start
print(string.format("\n%d フレーム描画 (%.2f秒, %.1f FPS)", frames, elapsed, frames/elapsed))

sg.Shutdown()
print("完了")
