# Phase 5 統合テスト - クイックレファレンス

**作成**: 2026-01-29 Sage
**詳細ドキュメント**: sage_pob2_integration_plan.md

---

## 1分で分かる Phase 5

### 目的
PoB2 が SimpleGraphic API で完全に動作することを確認

### 現状
- Phase 4: SimpleGraphic API 18個 + バックエンド実装完了 ✅
- 今からやること: 実際に PoB2 Lua で動作確認

### テスト戦略
```
STAGE 1 (1日)  → ウィンドウ表示テスト
STAGE 2 (2日)  → 基本描画テスト
STAGE 3 (2日)  → テキスト描画テスト
STAGE 4 (3-4日) → 完全PoB2統合テスト
```

### 全体スケジュール
- 1月29-30: STAGE 1
- 2月1-5: STAGE 2-3
- 2月6-9: STAGE 4
- 2月10-12: バグ修正
- 2月13: 完了

---

## 必須 API リスト（全18個、全て Phase 4 で実装済み）

### ウィンドウ表示 (5個)
```c
RenderInit("DPI_AWARE")        // 初期化
SetWindowTitle(str)             // タイトル設定
GetScreenSize(w, h)             // 画面寸法取得
SetClearColor(r, g, b, a)      // 背景色設定
RunMainLoop()                    // フレームループ
```

### 描画基本 (4個)
```c
SetDrawColor(r, g, b, a)       // 描画色設定
DrawImage(img, x, y, w, h)     // 矩形描画
SetDrawLayer(layer, sub)        // レイヤ管理
SetViewport()                    // ビューポート設定
```

### 画像処理 (4個)
```c
NewImage()                       // 画像ハンドル作成
LoadImage(img, filename)         // 画像読み込み
ImgWidth(img)                    // 画像幅取得
ImgHeight(img)                   // 画像高さ取得
```

### テキスト (3個)
```c
LoadFont(name, size)             // フォント読み込み
DrawString(x, y, align, h, f, t) // テキスト描画
DrawStringWidth(h, font, text)  // テキスト幅測定
```

### 入力・ユーティリティ (2個)
```c
IsKeyDown(keyname)              // キー確認
GetCursorPos(x, y)              // マウス位置取得
GetTime()                        // 時刻取得
```

---

## 予想される問題 TOP 5

### 1. Lua FFI バインディングエラー
**症状**: `attempt to call undefined function RenderInit`
**解決**: RenderInit 実行前に `type(RenderInit)` で確認

### 2. ウィンドウが表示されない
**症状**: `glfwCreateWindow returned NULL`
**解決**: GLFW インストール確認 (`brew install glfw3`)

### 3. 描画が黒い
**症状**: OpenGL エラー
**解決**: シェーダコンパイル確認、正射影マトリックス確認

### 4. テキストが表示されない
**症状**: FreeType 初期化失敗
**解決**: FreeType インストール確認、フォント キャッシュ確認

### 5. キー入力が反応しない
**症状**: IsKeyDown() が常に false
**解決**: イベントポーリング実行確認 (glfw_window_poll_events)

---

## 実装タスク（Artisan 向け）

### T5-A1: ウィンドウ表示テスト
```lua
-- tests/stage1_window_test.lua
-- RenderInit, SetWindowTitle, GetScreenSize の確認
```
目標: 1月30日

### T5-A2: 基本描画テスト
```lua
-- tests/stage2_draw_test.lua
-- SetDrawColor, DrawImage, グリッド描画の確認
```
目標: 2月2日

### T5-A3: テキスト描画テスト
```lua
-- tests/stage3_text_test.lua
-- LoadFont, DrawString, 配置・サイズ確認
```
目標: 2月5日

### T5-A4: 完全統合テスト
```lua
-- tests/stage4_full_integration.lua
-- Launch.lua + Main.lua 実行確認
```
目標: 2月9日

### T5-A5: スタブ実装
```c
// src/simplegraphic/sg_stubs.c
// ConExecute, ConClear, Copy, TakeScreenshot, Restart
```
目標: 随時

---

## 確認項目チェックリスト

### STAGE 1 チェック
- [ ] ウィンドウ表示される
- [ ] タイトル正しい
- [ ] GetScreenSize() 値正しい
- [ ] 5秒後に終了可能

### STAGE 2 チェック
- [ ] 背景色表示される
- [ ] 矩形描画される
- [ ] 色指定反映される
- [ ] アルファブレンディング動作

### STAGE 3 チェック
- [ ] テキスト表示される
- [ ] 配置 (LEFT/CENTER/RIGHT) 正しい
- [ ] サイズ変更反映される
- [ ] テキスト幅測定正確

### STAGE 4 チェック
- [ ] Launch.lua 実行成功
- [ ] Main.lua 初期化成功
- [ ] UI 画面表示される
- [ ] キー入力反応する
- [ ] マウス入力反応する
- [ ] ボタン操作可能
- [ ] 30分連続実行でメモリ安定
- [ ] FPS 60+ 維持

---

## 環境確認コマンド

```bash
# ビルド確認
cd /Users/kokage/national-operations/pob2macos/build
cmake .. && cmake --build .

# 依存関係確認
pkg-config --modversion glfw3
pkg-config --modversion freetype2
system_profiler SPDisplaysDataType | grep -A 5 "Display"

# Lua 環境確認
lua -e "print(_VERSION)"

# テスト実行準備
cd /Users/kokage/national-operations/pob2macos
export LUA_CPATH="./build/src/simplegraphic/?.so;./build/src/simplegraphic/?/?.so;$LUA_CPATH"
```

---

## 詳細ドキュメント参照

| 項目 | ファイル | セクション |
|------|---------|-----------|
| PoB2 起動フロー | sage_pob2_integration_plan.md | 1.1 |
| 必須 API リスト | sage_pob2_integration_plan.md | 2 |
| テスト詳細 | sage_pob2_integration_plan.md | 3 |
| 問題対処法 | sage_pob2_integration_plan.md | 4 |
| スタブ実装 | sage_pob2_integration_plan.md | 8 |
| スケジュール | sage_pob2_integration_plan.md | 10 |

---

## 連絡先・責任者

- **分析**: Sage (知識者)
- **実装**: Artisan (職人)
- **監督**: Mayor (村長)
- **プロジェクト**: PRJ-003 PoB2macOS Phase 5

---

**Last Updated**: 2026-01-29
**Status**: 準備完了 - 実装開始待機中
