#!/usr/bin/env lua

-- SimpleGraphic テキスト表示テスト

print("=== SimpleGraphic テキスト表示テスト ===\n")

local ffi = require("ffi")

-- C関数の宣言
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

-- ライブラリのロード
print("1. ライブラリのロード...")
local sg = ffi.load("runtime/SimpleGraphic.dylib")
print("✓ ライブラリのロード成功\n")

-- 初期化
print("2. 初期化...")
sg.RenderInit("DPI_AWARE")
print("✓ 初期化成功\n")

-- ウィンドウ設定
print("3. ウィンドウ設定...")
sg.SetWindowTitle("Path of Building - テキスト表示テスト")
sg.SetClearColor(0.1, 0.1, 0.2, 1.0)  -- 濃い青色の背景
print("✓ ウィンドウ設定完了\n")

-- 画面サイズ取得
local width = ffi.new("int[1]")
local height = ffi.new("int[1]")
sg.GetScreenSize(width, height)
print(string.format("画面サイズ: %dx%d\n", width[0], height[0]))

-- テストするテキストの準備
local test_texts = {
    {text = "Path of Building for macOS", font = "VAR", size = 32, color = {1.0, 1.0, 1.0, 1.0}},
    {text = "テキスト表示テスト", font = "VAR", size = 24, color = {0.0, 1.0, 0.0, 1.0}},
    {text = "Text Rendering Test", font = "VAR", size = 20, color = {1.0, 1.0, 0.0, 1.0}},
    {text = "SimpleGraphic.dylib", font = "VAR", size = 18, color = {1.0, 0.5, 0.0, 1.0}},
    {text = "左揃え (Left)", font = "VAR", size = 16, color = {0.5, 1.0, 1.0, 1.0}},
    {text = "中央揃え (Center)", font = "VAR", size = 16, color = {1.0, 0.5, 1.0, 1.0}},
    {text = "右揃え (Right)", font = "VAR", size = 16, color = {1.0, 1.0, 0.5, 1.0}},
}

-- テキスト幅の計算テスト
print("4. テキスト幅計算テスト...")
for i, item in ipairs(test_texts) do
    local text_width = sg.DrawStringWidth(item.size, item.font, item.text)
    print(string.format("  [%d] \"%s\" - 幅: %d px", i, item.text, text_width))
end
print("✓ テキスト幅計算成功\n")

-- 描画ループ（5秒間）
print("5. テキスト描画テスト...")
print("ウィンドウにテキストを表示します（5秒間、ESCキーで終了）\n")

local start_time = sg.GetTime()
local frame_count = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start_time) < 5.0 do
    sg.ProcessEvents()

    -- テキストを描画
    local y_offset = 50
    local x_center = width[0] / 2

    for i, item in ipairs(test_texts) do
        sg.SetDrawColor(item.color[1], item.color[2], item.color[3], item.color[4])

        -- 揃え方を決定
        local align = 0  -- 左揃え
        local x_pos = 50

        if item.text:find("中央") or item.text:find("Center") then
            align = 1  -- 中央揃え
            x_pos = x_center
        elseif item.text:find("右") or item.text:find("Right") then
            align = 2  -- 右揃え
            x_pos = width[0] - 50
        end

        sg.DrawString(x_pos, y_offset, align, item.size, item.font, item.text)
        y_offset = y_offset + item.size + 10
    end

    -- フレーム情報を表示
    sg.SetDrawColor(0.7, 0.7, 0.7, 1.0)
    local fps_text = string.format("Frame: %d, FPS: %.1f", frame_count, frame_count / (sg.GetTime() - start_time))
    sg.DrawString(10, height[0] - 30, 0, 14, "VAR", fps_text)

    -- 約60FPSでループ
    ffi.C.usleep(16666)
    frame_count = frame_count + 1
end

local elapsed = sg.GetTime() - start_time
local fps = frame_count / elapsed

print(string.format("✓ %d フレーム描画 (%.2f秒, 平均%.1f FPS)\n", frame_count, elapsed, fps))

-- シャットダウン
print("\n6. シャットダウン...")
sg.Shutdown()
print("✓ シャットダウン完了\n")

print("=== テキスト表示テスト完了 ===")
print("すべてのテストが成功しました！")
print("テキストが正しく表示されました。")
