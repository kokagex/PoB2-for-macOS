#!/usr/bin/env luajit
--[[
    Path of Building - macOS Demo Application
    SimpleGraphic.dylibの動作確認用デモ
]]

local ffi = require("ffi")

-- SimpleGraphic C API 宣言
ffi.cdef[[
    void RenderInit(const char* flags);
    void SetWindowTitle(const char* title);
    void GetScreenSize(int* width, int* height);
    void SetClearColor(float r, float g, float b, float a);
    void SetDrawColor(float r, float g, float b, float a);
    void DrawString(int left, int top, int align, int height,
                    const char* font, const char* text);
    void ProcessEvents(void);
    int IsUserTerminated(void);
    int IsKeyDown(const char* key);
    void GetCursorPos(int* x, int* y);
    double GetTime(void);
    void Shutdown(void);
    int usleep(unsigned int usec);
]]

-- SimpleGraphic.dylibをロード（絶対パスで指定）
local sg = ffi.load("./SimpleGraphic.dylib")

print("========================================")
print("  Path of Building - macOS Edition")
print("  SimpleGraphic.dylib Demo")
print("========================================")
print("")

-- 初期化
print("初期化中...")
sg.RenderInit("DPI_AWARE")
sg.SetWindowTitle("Path of Building (PoE2) - macOS Demo")

-- 画面サイズ取得
local width = ffi.new("int[1]")
local height = ffi.new("int[1]")
sg.GetScreenSize(width, height)
print(string.format("画面サイズ: %dx%d", width[0], height[0]))

-- 背景色設定（Path of Buildingっぽい濃い色）
sg.SetClearColor(0.08, 0.08, 0.12, 1.0)

-- テキスト色設定（白）
sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)

print("")
print("ウィンドウが表示されました")
print("操作方法:")
print("  - ESCキー: 終了")
print("  - マウス移動: カーソル位置を追跡")
print("")

-- メインループ
local start_time = sg.GetTime()
local frame_count = 0
local last_fps_update = start_time
local fps = 0

while sg.IsUserTerminated() == 0 do
    sg.ProcessEvents()

    -- テキスト描画（デモ）
    sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)
    sg.DrawString(50, 50, 0, 32, "Arial", "Path of Building - macOS Edition")

    sg.SetDrawColor(0.7, 0.7, 0.7, 1.0)
    sg.DrawString(50, 100, 0, 20, "Arial", "SimpleGraphic.dylib Demo Application")

    sg.SetDrawColor(0.5, 0.8, 1.0, 1.0)
    sg.DrawString(50, 140, 0, 16, "Arial", "黒い画面問題が解決されました！")

    -- FPS表示
    local current_time = sg.GetTime()
    if current_time - last_fps_update >= 0.5 then
        fps = frame_count / (current_time - start_time)
        last_fps_update = current_time
    end

    sg.SetDrawColor(0.5, 1.0, 0.5, 1.0)
    sg.DrawString(50, 180, 0, 16, "Arial", string.format("FPS: %.1f", fps))

    sg.SetDrawColor(1.0, 1.0, 0.5, 1.0)
    sg.DrawString(50, 210, 0, 16, "Arial", string.format("実行時間: %.1f秒", current_time - start_time))

    -- マウス位置表示
    local mx = ffi.new("int[1]")
    local my = ffi.new("int[1]")
    sg.GetCursorPos(mx, my)
    sg.SetDrawColor(1.0, 0.5, 1.0, 1.0)
    sg.DrawString(50, 240, 0, 16, "Arial", string.format("マウス位置: (%d, %d)", mx[0], my[0]))

    -- 操作説明
    sg.SetDrawColor(0.6, 0.6, 0.6, 1.0)
    sg.DrawString(50, height[0] - 80, 0, 14, "Arial", "ESCキーで終了")

    -- Metal情報
    sg.SetDrawColor(0.4, 0.4, 0.4, 1.0)
    sg.DrawString(50, height[0] - 50, 0, 12, "Arial", "Graphics: Metal (AMD Radeon Pro 5500M)")
    sg.DrawString(50, height[0] - 30, 0, 12, "Arial", "Window System: GLFW 3.4.0")

    -- ESCキーで終了
    if sg.IsKeyDown("escape") ~= 0 then
        print("\nESCキーが押されました。終了します...")
        break
    end

    -- フレームレート制限
    ffi.C.usleep(16666)  -- ~60 FPS
    frame_count = frame_count + 1
end

-- 統計表示
local elapsed = sg.GetTime() - start_time
print("")
print("========================================")
print("  実行統計")
print("========================================")
print(string.format("総フレーム数: %d", frame_count))
print(string.format("実行時間: %.2f秒", elapsed))
print(string.format("平均FPS: %.1f", frame_count / elapsed))
print("")

-- シャットダウン
sg.Shutdown()
print("終了しました")
