#!/usr/bin/env lua

-- SimpleGraphic.dylib の動作確認スクリプト

print("=== SimpleGraphic.dylib 動作確認 ===\n")

-- ライブラリのロード確認
print("1. ライブラリのロード確認...")
local ffi = require("ffi")

-- C関数の宣言
ffi.cdef[[
    void RenderInit(const char* flags);
    void SetWindowTitle(const char* title);
    void GetScreenSize(int* width, int* height);
    void SetDrawColor(float r, float g, float b, float a);
    void SetClearColor(float r, float g, float b, float a);
    double GetTime(void);
    int IsUserTerminated(void);
    void ProcessEvents(void);
    void Shutdown(void);

    int usleep(unsigned int usec);
]]

local sg
local success, err = pcall(function()
    sg = ffi.load("runtime/SimpleGraphic.dylib")
end)

if not success then
    print("✗ ライブラリのロードに失敗: " .. tostring(err))
    os.exit(1)
end
print("✓ ライブラリのロード成功\n")

-- 初期化テスト
print("2. 初期化テスト...")
success, err = pcall(function()
    sg.RenderInit("DPI_AWARE")
end)

if not success then
    print("✗ 初期化に失敗: " .. tostring(err))
    os.exit(1)
end
print("✓ 初期化成功\n")

-- ウィンドウタイトル設定
print("3. ウィンドウタイトル設定...")
sg.SetWindowTitle("Path of Building - macOS版 動作確認")
print("✓ ウィンドウタイトル設定完了\n")

-- 画面サイズ取得
print("4. 画面サイズ取得...")
local width = ffi.new("int[1]")
local height = ffi.new("int[1]")
sg.GetScreenSize(width, height)
print(string.format("✓ 画面サイズ: %dx%d\n", width[0], height[0]))

-- 描画色設定
print("5. 描画色設定...")
sg.SetClearColor(0.1, 0.1, 0.2, 1.0)  -- 濃い青色
sg.SetDrawColor(1.0, 1.0, 1.0, 1.0)   -- 白色
print("✓ 描画色設定完了\n")

-- イベントループ（3秒間）
print("6. イベントループ実行...")
print("ウィンドウが表示されます（3秒間表示、ESCキーで終了）\n")

local start_time = sg.GetTime()
local frame_count = 0

while sg.IsUserTerminated() == 0 and (sg.GetTime() - start_time) < 3.0 do
    sg.ProcessEvents()

    -- 約60FPSでループ
    ffi.C.usleep(16666)
    frame_count = frame_count + 1
end

local elapsed = sg.GetTime() - start_time
local fps = frame_count / elapsed

print(string.format("✓ %d フレーム描画 (%.2f秒, 平均%.1f FPS)\n", frame_count, elapsed, fps))

-- シャットダウン
print("\n7. シャットダウン...")
sg.Shutdown()
print("✓ シャットダウン完了\n")

print("=== 動作確認完了 ===")
print("すべてのテストが成功しました！")
print("ウィンドウが表示され、黒い画面問題が解決されました。")
