# Phase 6 タスク実行ガイド
**Skill Validation Protocol - Task Execution Manual**

**Date**: 2026-01-29
**Project**: PRJ-003 PoB2macOS Phase 6
**Document Purpose**: 5人の村人が並列実行するための詳細実行ガイド

---

## 1. 全体構成

### タスク依存関係図

```
Sage Tasks (分析・設計):
  ├─ T6-S1: Launch.lua 詳細分析
  │   └─ 成果: sage_launch_analysis.md
  │       (Artisan の T6-A1-A5 をブロック解除)
  │
  ├─ T6-S2: 不足 API 仕様書
  │   └─ 成果: stub_api_specs.md
  │       (Artisan の T6-A1 をブロック解除)
  │
  └─ T6-S3: STAGE 1 テストスクリプト設計
      └─ 成果: stage1_window_test.lua (template)
          (Artisan の T6-A3 をブロック解除)

Artisan Tasks (実装):
  ├─ T6-A1: 不足 API 実装 (Sage T6-S1, T6-S2 完了後)
  │   ├─ ConExecute, ConClear, Copy, TakeScreenshot
  │   └─ ビルド & MVP テスト再実行
  │       (Merchant の T6-M1-M3 をブロック解除)
  │
  ├─ T6-A2: FreeType 本実装 (並列)
  │   └─ フォントキャッシュ最適化
  │
  ├─ T6-A3: STAGE 2 テスト実装 (Sage T6-S3 完了後)
  ├─ T6-A4: STAGE 3 テスト実装 (Sage T6-S3 完了後)
  ├─ T6-A5: STAGE 4 テスト実装 (Sage T6-S3 完了後)
  │
  └─ T6-A6: テスト結果レポート (T6-A3-A5 完了後)

Merchant Tasks (テスト実行):
  ├─ T6-M1: STAGE 1 実行 (Artisan T6-A1 完了後)
  ├─ T6-M2: STAGE 2-3 実行 (Artisan T6-A3-A4 完了後)
  ├─ T6-M3: STAGE 4 実行 (Artisan T6-A5 完了後)
  ├─ T6-M4: パフォーマンス計測 (Merchant T6-M1-M3 完了後)
  └─ T6-M5: ビルド最適化 (並列)

Paladin Tasks (品質保証):
  ├─ T6-P1: MEDIUM セキュリティ修正 (並列)
  ├─ T6-P2: 新規コード レビュー (Artisan T6-A1 完了後)
  └─ T6-P3: メモリリーク検出 (Merchant T6-M1-M3 完了後)

Bard Tasks (ドキュメント):
  ├─ T6-B1: 進捗ドキュメント (並列・継続)
  ├─ T6-B2: API マトリクス (Artisan T6-A1 完了後)
  ├─ T6-B3: ユーザーガイド (Sage T6-S1-S3 完了後)
  └─ T6-B4: 最終レポート統合 (全タスク完了後)
```

---

## 2. Sage (賢者) 実行ガイド

### 【T6-S1】PoB2 Launch.lua 詳細分析

**実行環境**:
```bash
cd /Users/kokage/national-operations/claudecode01
```

**分析手順**:

1. **PoB2 Launch.lua の完全読み込み**
   ```bash
   cat ~/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua | wc -l
   # 406 行
   ```

2. **実行フロー分析フェーズ** (Line 1-19)
   ```lua
   -- Entry:
   local startTime = GetTime()              -- Line 8
   APP_NAME = "Path of Building (PoE2)"    -- Line 9
   SetWindowTitle(APP_NAME)                -- Line 11
   ConExecute("set vid_mode 8")            -- Line 12
   ConExecute("set vid_resizable 3")       -- Line 13
   launch = { }                            -- Line 15
   SetMainObject(launch)                   -- Line 16
   jit.opt.start(...)                      -- Line 17
   collectgarbage("setpause", 400)         -- Line 18
   ```

   **分析**:
   - [ ] GetTime() の用途確認 (起動時刻記録)
   - [ ] ConExecute() はスタブで十分か確認
   - [ ] SetMainObject() の詳細確認

3. **launch:OnInit() 分析** (Line 20-87)
   ```lua
   function launch:OnInit()
       -- [Line 21-27] 初期化フラグ設定
       -- [Line 29-44] first.run ファイル確認 (初回起動処理)
       -- [Line 45-62] manifest.xml 読み込み (バージョン検出)
       -- [Line 68] RenderInit("DPI_AWARE") ← CRITICAL
       -- [Line 71] PLoadModule("Modules/Main") ← Main.lua 読み込み
       -- [Line 76-80] main:Init() コールバック
   ```

   **確認項目**:
   - [ ] RenderInit() が呼び出される正確な行番号と条件
   - [ ] PLoadModule() のメカニズム (Main.lua 読み込み)
   - [ ] エラーハンドリング (ShowErrMsg, PCall)

4. **launch:OnFrame() 分析** (Line 108-136)
   ```lua
   function launch:OnFrame()
       -- [Line 109-116] main:OnFrame() 呼び出し
       -- [Line 117] IsKeyDown("ALT") 呼び出し
       -- [Line 118-119] SetDrawLayer, SetViewport
       -- [Line 120-123] UI ポップアップ描画
       -- [Line 124-131] Restart() メカニズム
   ```

   **API 呼び出し一覧**:
   - [ ] IsKeyDown() × 2 箇所
   - [ ] SetDrawLayer() × 1
   - [ ] SetViewport() × 1
   - [ ] GetScreenSize() × 1
   - [ ] SetDrawColor() × 3
   - [ ] DrawImage() × 2
   - [ ] DrawString() × 1
   - [ ] GetTime() × 1

5. **入力ハンドラ分析** (Line 138-194)
   ```lua
   function launch:OnKeyDown(key, doubleClick)
       -- [Line 158-159] PRINTSCREEN + CTRL → TakeScreenshot()
       -- [Line 163-169] main:OnKeyDown() デリゲート
   ```

   function launch:OnChar(key)
       -- [Line 184-185] promptMsg 状態確認
       -- [Line 187-192] main:OnChar() デリゲート
   ```

6. **エラーハンドリング分析** (Line 370-405)
   ```lua
   function launch:DrawPopup(r, g, b, fmt, ...)
       -- ポップアップ描画ロジック
       -- GetScreenSize() → DrawString(), DrawImage() チェーン
   ```

7. **API 呼び出し依存グラフ作成**
   ```
   SetMainObject(launch)
       ↓
   launch:OnInit()
       ├─ RenderInit("DPI_AWARE") [CRITICAL]
       ├─ PLoadModule("Modules/Main")
       └─ main:Init()

   [Main Loop]
   while RunMainLoop() do
       launch:OnFrame()
           ├─ main:OnFrame()
           │   ├─ SetDrawColor()
           │   ├─ DrawImage()
           │   ├─ DrawString()
           │   └─ ...
           ├─ IsKeyDown()
           ├─ SetDrawLayer()
           ├─ SetViewport()
           └─ GetScreenSize()
   ```

**成果物チェックリスト**:
- [ ] Launch.lua フロー図 (ASCII art または Markdown 記述)
- [ ] API 呼び出し依存グラフ
- [ ] スタブ実装が必要な API リスト (優先度付き)
  - ConExecute (優先度: HIGH)
  - ConClear (優先度: HIGH)
  - Copy (優先度: MEDIUM)
  - TakeScreenshot (優先度: LOW)
  - Restart (優先度: MEDIUM)
- [ ] リスク分析 (API 未実装時の影響)

**出力ファイル**:
```
/Users/kokage/national-operations/claudecode01/memory/sage_launch_analysis.md
```

**検証方法**:
```bash
# Launch.lua の行数確認
wc -l ~/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua

# Sage の報告で全 API が正確に記載されているか確認
grep -c "GetTime\|SetWindowTitle\|ConExecute" ~/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua
```

---

### 【T6-S2】不足 API の仕様書作成

**実行手順**:

1. **ConExecute(cmd) の仕様確定**
   ```
   用途:
     - PoB2 コンソールコマンド実行
     - 例: "set vid_mode 8", "set vid_resizable 3"

   パラメータ:
     - cmd: string, コマンド文字列

   戻り値: なし

   実装方針:
     - C コード: printf("[ConExecute] %s\n", cmd);
     - PoB2 ビデオモード設定は無視（グラフィクス設定は SimpleGraphic で制御）

   リスク: なし
     - 呼び出し元: Launch.lua line 12, 13
     - UI 描画に直接影響しないため、スタブで対応可能
   ```

2. **ConClear(), ConPrintf() の仕様**
   ```
   ConClear():
     - コンソール出力クリア
     - 実装: 改行を出力するだけで十分
     - 呼び出し: Launch.lua line 35

   ConPrintf(fmt, ...):
     - printf 互換のコンソール出力
     - 実装: C の printf() をそのまま使用
     - 呼び出し: Launch.lua line 36, 69 等（多数）
   ```

3. **Copy(text) の仕様**
   ```
   用途:
     - テキストをクリップボードにコピー
     - エラーメッセージのコピー機能

   パラメータ:
     - text: string, コピーする文字列

   戻り値: なし

   実装方針:
     - macOS: NSPasteboard API
     - Linux: xclip コマンド
     - Windows: (Phase 6 では不要)

   優先度: MEDIUM

   リスク: 低
     - 呼び出し: Launch.lua line 362 (エラーメッセージコピー)
     - 失敗しても動作に影響なし
   ```

4. **TakeScreenshot() の仕様**
   ```
   用途:
     - スクリーンショット保存
     - Ctrl+PrintScreen キー時に呼び出し

   実装方針:
     - OpenGL バックバッファから PNG 保存
     - または: 簡易版として printf ログのみ

   優先度: LOW

   推奨: Phase 6 ではログ出力のみ、PNG 保存は Phase 7 以降
   ```

5. **Restart(), Exit() の仕様**
   ```
   Restart():
     - アプリケーション再起動要求
     - 実装: Lua スクリプト終了後の自動再実行

   Exit(msg):
     - アプリケーション終了
     - 実装: glfwSetWindowShouldClose(window) → false 返却

   優先度: HIGH (すでに実装済み確認)
   ```

**成果物チェックリスト**:
- [ ] ConExecute: 完全仕様書
- [ ] ConClear, ConPrintf: 仕様確定
- [ ] Copy: macOS/Linux 実装ガイド
- [ ] TakeScreenshot: 実装方針決定
- [ ] Restart, Exit: 仕様確認
- [ ] 実装難易度表 (HIGH/MEDIUM/LOW)
- [ ] 優先度表 (実装順序)

**出力ファイル**:
```
/Users/kokage/national-operations/claudecode01/memory/stub_api_specs.md
```

---

### 【T6-S3】STAGE 1 テストスクリプト設計

**実行手順**:

1. **テストシナリオ確定**
   ```lua
   -- tests/stage1_window_test.lua
   -- 目的: RenderInit + SetWindowTitle + GetScreenSize の動作確認

   -- 期待される実行フロー:
   -- [1] RenderInit("DPI_AWARE") → GLFW ウィンドウ作成
   -- [2] SetWindowTitle("Path of Building (PoE2)") → タイトル設定
   -- [3] GetScreenSize() → 寸法取得
   -- [4] 5秒間ウィンドウ表示
   -- [5] 正常に終了
   ```

2. **テスト実行手順の明確化**
   ```
   前提条件:
     - libsimplegraphic.a ビルド完成
     - Lua インタプリタ動作確認

   実行コマンド:
     cd /Users/kokage/national-operations/pob2macos
     lua tests/stage1_window_test.lua

   期待される出力:
     [RenderInit] Initializing graphics system
     [SetWindowTitle] Setting title: Path of Building (PoE2)
     [GetScreenSize] Screen size: 1920x1080
     [Stage 1] Window displayed for 5 seconds
     [Stage 1] Test completed successfully

   期待される結果:
     - ウィンドウが 1920x1080 サイズで表示される
     - タイトルが "Path of Building (PoE2)" である
     - 5秒後に自動で閉じられる
     - エラーメッセージなし
   ```

3. **失敗パターンの事前想定**
   ```
   失敗パターン A: ウィンドウが表示されない
     原因: GLFW 初期化失敗
     対策: glfw_window_init() の戻り値確認
     確認コマンド: echo $?

   失敗パターン B: "RenderInit is not defined" エラー
     原因: Lua バインディング未登録
     対策: sg_lua_binding.c で RenderInit を lua_register()
     確認コマンド: nm -D build/src/simplegraphic/libsimplegraphic.so | grep RenderInit

   失敗パターン C: タイトルが空白
     原因: SetWindowTitle() が呼び出されていない
     対策: テストスクリプトの順序確認
   ```

4. **テストスクリプト基本骨子作成**
   ```lua
   -- tests/stage1_window_test.lua (Template by Sage)

   -- 簡単なテスト構造
   local stage1_passed = false

   -- API 動作確認
   assert(type(RenderInit) == "function", "RenderInit not found")
   assert(type(SetWindowTitle) == "function", "SetWindowTitle not found")
   assert(type(GetScreenSize) == "function", "GetScreenSize not found")

   -- 実行テスト
   RenderInit("DPI_AWARE")
   SetWindowTitle("Path of Building (PoE2)")

   local w, h = GetScreenSize()
   assert(w > 0 and h > 0, "GetScreenSize() returned invalid values")

   -- フレームループ実行（5秒）
   local start_time = GetTime()
   while RunMainLoop() and (GetTime() - start_time) < 5000 do
       -- フレーム処理
   end

   print("[Stage 1] Test completed successfully")
   stage1_passed = true

   -- 終了
   if stage1_passed then
       os.exit(0)  -- 成功
   else
       os.exit(1)  -- 失敗
   end
   ```

**成果物チェックリスト**:
- [ ] テストシナリオドキュメント完成
- [ ] 実行手順書作成
- [ ] 期待される出力例記載
- [ ] 失敗パターンと対策を記載
- [ ] テストスクリプト基本骨子作成

**出力ファイル**:
```
/Users/kokage/national-operations/claudecode01/memory/stage1_test_design.md
/Users/kokage/national-operations/pob2macos/tests/stage1_window_test.lua (template)
```

---

## 3. Artisan (職人) 実行ガイド

### 【T6-A1】不足 API スタブ実装

**準備**:
- Sage の T6-S1, T6-S2 が完了しており、`stub_api_specs.md` を参照可能

**実装環境**:
```bash
cd /Users/kokage/national-operations/pob2macos
mkdir -p src/simplegraphic
```

**実装手順**:

1. **sg_stubs.c ファイル作成**
   ```bash
   cat > src/simplegraphic/sg_stubs.c << 'EOF'
   #include "SimpleGraphic.h"
   #include <stdio.h>
   #include <string.h>

   // ConExecute - コンソールコマンド実行
   static int lua_ConExecute(lua_State *L)
   {
       const char *cmd = luaL_optstring(L, 1, "");
       printf("[ConExecute] %s\n", cmd);
       return 0;
   }

   // ConClear - コンソールクリア
   static int lua_ConClear(lua_State *L)
   {
       printf("\n");  // 改行のみ
       return 0;
   }

   // Copy - クリップボードコピー (macOS)
   static int lua_Copy(lua_State *L)
   {
       const char *text = luaL_optstring(L, 1, "");
       // 簡易実装: printf ログのみ
       printf("[Copy] Text copied to clipboard: %s\n", text);
       return 0;
   }

   // TakeScreenshot - スクリーンショット
   static int lua_TakeScreenshot(lua_State *L)
   {
       printf("[TakeScreenshot] Saving screenshot...\n");
       return 0;
   }

   // Restart - アプリケーション再起動
   static int lua_Restart(lua_State *L)
   {
       printf("[Restart] Application restart requested\n");
       return 0;
   }

   // Lua バインディング登録関数
   void register_stub_apis(lua_State *L)
   {
       lua_register(L, "ConExecute", lua_ConExecute);
       lua_register(L, "ConClear", lua_ConClear);
       lua_register(L, "Copy", lua_Copy);
       lua_register(L, "TakeScreenshot", lua_TakeScreenshot);
       lua_register(L, "Restart", lua_Restart);
   }
   EOF
   ```

2. **sg_lua_binding.c に登録関数呼び出しを追加**
   ```c
   // sg_lua_binding.c の sg_lua_init() 内に追加:
   extern void register_stub_apis(lua_State *L);
   register_stub_apis(L);  // Lua グローバルに登録
   ```

3. **CMakeLists.txt に sg_stubs.c を追加**
   ```cmake
   # src/simplegraphic/CMakeLists.txt
   add_library(simplegraphic
       sg_core.c
       sg_draw.c
       sg_text.c
       sg_image.c
       sg_input.c
       sg_stubs.c        # ← 追加
       sg_lua_binding.c
       glfw_window.c
       opengl_backend.c
       image_loader.c
   )
   ```

4. **ビルド実行**
   ```bash
   cd /Users/kokage/national-operations/pob2macos/build
   cmake ..
   cmake --build . --config Release
   ```

5. **ビルド確認**
   ```bash
   ls -la build/src/simplegraphic/libsimplegraphic.a
   nm -D build/src/simplegraphic/libsimplegraphic.so | grep -E "ConExecute|ConClear|Copy"
   ```

6. **Lua バインディング動作確認**
   ```bash
   cat > /tmp/test_stubs.lua << 'EOF'
   dofile("tests/test_stubs.lua")
   EOF

   lua /tmp/test_stubs.lua
   ```

**成果物チェックリスト**:
- [ ] sg_stubs.c 実装完成
- [ ] Lua 登録関数 register_stub_apis() 完成
- [ ] CMakeLists.txt 更新
- [ ] ビルド成功 (警告なし)
- [ ] MVP テスト 12/12 PASS 確認

**検証スクリプト**:
```bash
#!/bin/bash
# tests/verify_stub_apis.lua
print("Verifying stub APIs...")
assert(type(ConExecute) == "function", "ConExecute not found")
assert(type(ConClear) == "function", "ConClear not found")
assert(type(Copy) == "function", "Copy not found")
assert(type(TakeScreenshot) == "function", "TakeScreenshot not found")
assert(type(Restart) == "function", "Restart not found")
print("All stub APIs verified!")
```

---

### 【T6-A2】FreeType テキストレンダリング本実装

**現状**: Phase 5 で基本実装済み

**実装内容**:

1. **フォントキャッシュの LRU 実装**
   ```c
   // sg_text.c に追加

   #define MAX_CACHED_FONTS 32
   #define MAX_FONT_SIZE 72

   typedef struct {
       char name[64];
       int size;
       FT_Face face;
       time_t last_used;
   } FontCacheEntry;

   static FontCacheEntry font_cache[MAX_CACHED_FONTS];
   static int font_cache_count = 0;

   // キャッシュサイズ超過時のLRU削除
   void evict_lru_font()
   {
       int lru_idx = 0;
       time_t oldest = font_cache[0].last_used;

       for (int i = 1; i < font_cache_count; i++) {
           if (font_cache[i].last_used < oldest) {
               oldest = font_cache[i].last_used;
               lru_idx = i;
           }
       }

       // フォント削除
       FT_Done_Face(font_cache[lru_idx].face);
       memmove(&font_cache[lru_idx],
               &font_cache[lru_idx + 1],
               (font_cache_count - lru_idx - 1) * sizeof(FontCacheEntry));
       font_cache_count--;
   }
   ```

2. **DrawStringWidth() の精度向上**
   ```c
   // テキスト幅測定の改善
   float calculate_text_width(FT_Face face, const char *text)
   {
       float width = 0.0f;
       for (const unsigned char *p = (const unsigned char *)text; *p; p++) {
           // UTF-8 マルチバイト文字対応
           // 各文字のアドバンス値を合計
       }
       return width;
   }
   ```

3. **パフォーマンス特性ドキュメント**
   ```
   - フォント読み込み時間: ~100ms (初回)
   - フォント読み込み時間: ~1ms (キャッシュヒット)
   - テキスト描画: ~10-50ms (テキスト長に応じた)
   ```

**成果物チェックリスト**:
- [ ] LRU フォントキャッシュ実装完成
- [ ] DrawStringWidth() 精度向上確認
- [ ] UTF-8 マルチバイト対応確認
- [ ] パフォーマンス特性記載

---

### 【T6-A3】STAGE 2 基本描画テスト実装

**準備**: Sage の T6-S3 完了後

**実装**:
```lua
-- tests/stage2_draw_test.lua

RenderInit("DPI_AWARE")
SetClearColor(0.3, 0.3, 0.3, 1.0)

local start_time = GetTime()
local frame_count = 0

while RunMainLoop() and (GetTime() - start_time) < 10000 do
    -- グリッド描画
    SetDrawColor(0.5, 0.5, 0.5)
    for i = 0, 10 do
        DrawImage(nil, i * 192, 0, 1, 1080)     -- 縦線
        DrawImage(nil, 0, i * 108, 1920, 1)     -- 横線
    end

    -- カラーパレット描画
    local colors = {
        {1.0, 0.0, 0.0, 1.0},  -- 赤
        {0.0, 1.0, 0.0, 1.0},  -- 緑
        {0.0, 0.0, 1.0, 1.0},  -- 青
        {1.0, 1.0, 0.0, 1.0},  -- 黄
    }
    for idx, color in ipairs(colors) do
        SetDrawColor(color[1], color[2], color[3], color[4])
        DrawImage(nil, 100 + idx*200, 100, 100, 100)
    end

    frame_count = frame_count + 1
end

print("[Stage 2] Test completed. Frames: " .. frame_count)
```

**成果物チェックリスト**:
- [ ] stage2_draw_test.lua 実装完成
- [ ] グリッド表示確認
- [ ] カラーパレット表示確認

---

### 【T6-A4】STAGE 3 テキスト描画テスト実装

```lua
-- tests/stage3_text_test.lua

RenderInit("DPI_AWARE")

local font_var = LoadFont("VAR", 16)
local font_bold = LoadFont("VAR BOLD", 20)

local start_time = GetTime()
local frame_count = 0

while RunMainLoop() and (GetTime() - start_time) < 10000 do
    SetDrawColor(0.2, 0.2, 0.2)
    DrawImage(nil, 0, 0, 1920, 1080)

    -- テキスト配置テスト
    SetDrawColor(1.0, 1.0, 1.0)
    DrawString(0, 100, "LEFT", 16, font_var, "Left-aligned text")
    DrawString(960, 200, "CENTER", 16, font_var, "Center-aligned text")
    DrawString(1920, 300, "RIGHT", 16, font_var, "Right-aligned text")

    -- フォントサイズテスト
    SetDrawColor(1.0, 0.5, 0.0)
    DrawString(100, 400, "LEFT", 12, font_var, "Font size 12")
    DrawString(100, 450, "LEFT", 16, font_var, "Font size 16")
    DrawString(100, 510, "LEFT", 20, font_bold, "Font size 20 BOLD")

    frame_count = frame_count + 1
end

print("[Stage 3] Test completed. Frames: " .. frame_count)
```

---

### 【T6-A5】STAGE 4 完全統合テスト実装

```lua
-- tests/stage4_full_integration.lua

-- Launch.lua フロー実行
dofile("src/Launch.lua")

-- フレームループは Launch.lua/SetMainObject で管理
```

**成果物チェックリスト**:
- [ ] stage4_full_integration.lua 実装完成
- [ ] Launch.lua との統合確認

---

### 【T6-A6】テスト結果レポート作成

**報告形式**:
```markdown
# Integration Test Report - Phase 6

## STAGE 1: ウィンドウ表示テスト
- Status: PASSED / FAILED
- Execution Date: [date]
- Duration: [duration]
- Screenshot: [path]
- Issues: [issues]

## STAGE 2: 基本描画テスト
...

## STAGE 3: テキスト描画テスト
...

## STAGE 4: 完全統合テスト
...

## Summary
- Total Tests: 4
- Passed: X
- Failed: Y
```

---

## 4. Merchant (商人) 実行ガイド

### 【T6-M1】STAGE 1 ウィンドウ表示テスト実行

**前提条件**:
- Artisan の T6-A1 完了
- libsimplegraphic.a ビルド成功
- MVP テスト 12/12 PASS 確認

**実行手順**:
```bash
cd /Users/kokage/national-operations/pob2macos
lua tests/stage1_window_test.lua 2>&1 | tee tests/STAGE1_EXECUTION.log
```

**確認項目**:
- [ ] ウィンドウが表示される (黒いウィンドウ)
- [ ] タイトルが "Path of Building (PoE2)" である
- [ ] GetScreenSize() が正しい値を返す
- [ ] 5秒後に自動で閉じられる
- [ ] エラーメッセージなし

**スクリーンショット記録**:
```bash
# macOS: スクリーンショット保存
# 実行中に cmd+shift+4 でウィンドウをキャプチャ
# または内部スクリーンショット機能を実装
```

**レポート作成**:
```markdown
# STAGE 1 - ウィンドウ表示テスト結果

## Execution Details
- Date: 2026-01-29
- Platform: macOS 25.2.0
- Lua Version: [version]
- Duration: 5.2 seconds

## Test Results
- [ ] Window displayed: PASS
- [ ] Window title correct: PASS
- [ ] Screen size reported: PASS (1920x1080)
- [ ] Normal exit: PASS

## Issues Found
- None

## Performance Metrics
- FPS: 60 (vsync enabled)
- Memory usage: ~100MB
```

---

### 【T6-M2】STAGE 2-3 描画・テキストテスト実行

```bash
cd /Users/kokage/national-operations/pob2macos
lua tests/stage2_draw_test.lua 2>&1 | tee tests/STAGE2_EXECUTION.log
lua tests/stage3_text_test.lua 2>&1 | tee tests/STAGE3_EXECUTION.log
```

**確認項目**:
- [ ] グリッド表示確認
- [ ] カラーパレット表示確認 (4色)
- [ ] テキスト表示確認 (3 アラインメント)
- [ ] フォントサイズ表示確認

---

### 【T6-M3】STAGE 4 完全統合テスト実行

```bash
cd /Users/kokage/national-operations/pob2macos
timeout 1800 lua tests/stage4_full_integration.lua 2>&1 | tee tests/STAGE4_EXECUTION.log
# timeout: 30 分間実行制限
```

**確認項目**:
- [ ] Launch.lua 実行成功
- [ ] Main.lua 初期化成功
- [ ] UI 画面表示
- [ ] キー入力反応
- [ ] マウス入力反応
- [ ] メモリリークなし (30分実行後)
- [ ] FPS 60+ 維持

---

### 【T6-M4】パフォーマンスベースライン測定

**計測項目**:

1. **FPS 計測**
   ```bash
   # tests/measure_fps.lua
   local frame_count = 0
   local start_time = GetTime()

   while RunMainLoop() and (GetTime() - start_time) < 5000 do
       frame_count = frame_count + 1
   end

   local elapsed = (GetTime() - start_time) / 1000
   local fps = frame_count / elapsed
   print("FPS: " .. fps)
   ```

2. **メモリ使用量計測** (valgrind / Instruments)
   ```bash
   # macOS
   instruments -t "Allocations" -o instruments_output.trace \
       /usr/local/bin/lua tests/stage1_window_test.lua
   ```

3. **GPU 使用率計測**
   ```bash
   # macOS Activity Monitor または system_profiler
   system_profiler SPDisplaysDataType
   ```

**出力ファイル**:
```
/Users/kokage/national-operations/pob2macos/PERFORMANCE_BASELINE.md
```

---

### 【T6-M5】ビルドシステム最適化

**最適化項目**:

1. **CMakeLists.txt の改善**
   ```cmake
   # プリコンパイル済みヘッダ有効化
   target_precompile_headers(simplegraphic PRIVATE SimpleGraphic.h)

   # LTO 有効化
   set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto")
   ```

2. **ビルド時間計測**
   ```bash
   cd /Users/kokage/national-operations/pob2macos/build

   # クリーンビルド
   time cmake --build . --config Release --clean-first

   # インクリメンタルビルド
   touch src/simplegraphic/sg_core.c
   time cmake --build . --config Release
   ```

3. **ビルド時間レポート**
   ```markdown
   # Build Optimization Report

   ## Before Optimization
   - Clean Build: 45s
   - Incremental Build: 8s

   ## After Optimization
   - Clean Build: 38s (15% reduction)
   - Incremental Build: 5s (37% reduction)

   ## Changes Applied
   - Precompiled headers
   - LTO enabled
   ```

---

## 5. Paladin (聖騎士) 実行ガイド

### 【T6-P1】残存 MEDIUM セキュリティ 4 件対応

**準備**:
- 前フェーズのセキュリティレポート確認
- コード分析ツール (clang-analyzer) インストール

**実行手順**:

1. **問題の再特定**
   ```bash
   # コード分析ツール実行
   scan-build -V
   cd /Users/kokage/national-operations/pob2macos
   scan-build cmake --build build
   ```

2. **各 MEDIUM 問題の修正**
   ```
   問題 1: [問題内容]
   - ファイル: [path]
   - 行番号: [line]
   - 修正方法: [method]
   - 検証: MVP テスト合格

   問題 2: ...
   問題 3: ...
   問題 4: ...
   ```

3. **ビルド確認**
   ```bash
   cd /Users/kokage/national-operations/pob2macos/build
   cmake --build . --config Release

   # 警告なし確認
   cmake --build . 2>&1 | grep -i "warning" | wc -l
   ```

4. **MVP テスト再実行**
   ```bash
   /Users/kokage/national-operations/pob2macos/build/mvp_test
   ```

**成果物チェックリスト**:
- [ ] MEDIUM 4 件全て修正完了
- [ ] ビルド成功 (警告ゼロ)
- [ ] MVP テスト 12/12 PASS

---

### 【T6-P2】Phase 6 新規コードのセキュリティレビュー

**レビュー対象**:
- Artisan の sg_stubs.c (新規)
- Artisan の sg_text.c (拡張)
- 全テストスクリプト (.lua ファイル)

**レビュー項目**:

1. **バッファオーバーフロー検査**
   ```c
   // sg_stubs.c の Copy() 関数
   static int lua_Copy(lua_State *L)
   {
       const char *text = luaL_optstring(L, 1, "");
       // 危険: sprintf を使用した場合
       char buffer[256];
       sprintf(buffer, "[Copy] %s\n", text);  // ❌ 危険

       // 安全: snprintf を使用
       char buffer[256];
       snprintf(buffer, sizeof(buffer), "[Copy] %s\n", text);  // ✅ 安全
   }
   ```

2. **メモリリーク検査**
   ```c
   // sg_text.c の LRU 実装
   // FT_Done_Face() が確実に呼ばれているか確認
   ```

3. **リソース管理検査**
   ```
   - Lua スクリプト: os.exit() の正確性
   - ファイルハンドル: 閉じ忘れ確認
   - メモリ割り当て: 解放漏れ確認
   ```

**出力ファイル**:
```
/Users/kokage/national-operations/claudecode01/memory/phase6_security_review.md
```

---

### 【T6-P3】メモリリーク検出テスト

**実行環境**:
- macOS: Xcode Instruments
- Linux: valgrind

**テスト方法** (macOS):

1. **STAGE 1 メモリチェック**
   ```bash
   cd /Users/kokage/national-operations/pob2macos

   # Instruments with Allocations Profiler
   instruments -t "Allocations" \
       -o memory_test_stage1.trace \
       /usr/local/bin/lua tests/stage1_window_test.lua
   ```

2. **STAGE 4 長時間メモリ監視**
   ```bash
   # 30分実行中のメモリ使用量追跡
   timeout 1800 instruments -t "Allocations" \
       -o memory_test_stage4.trace \
       /usr/local/bin/lua tests/stage4_full_integration.lua
   ```

3. **メモリグラフ生成**
   ```
   Instruments より:
   - Allocations over time グラフ
   - Peak memory usage
   - Memory footprint
   ```

**成功基準**:
```
✅ STAGE 1: 5秒実行でメモリ増加 < 10MB
✅ STAGE 2-3: 10秒実行でメモリ増加 < 20MB
✅ STAGE 4: 30分実行でメモリ増加 < 100MB (許容範囲)
✅ メモリリークなし (Allocations Profiler で未解放メモリ = 0)
```

**出力ファイル**:
```
/Users/kokage/national-operations/claudecode01/memory/memcheck_report_phase6.md
```

---

## 6. Bard (吟遊詩人) 実行ガイド

### 【T6-B1】Phase 6 進捗ドキュメント

**毎日更新**:
```markdown
# Phase 6 Daily Progress

## 2026-01-29 (Day 1)

### Completed Tasks
- Sage: T6-S1 Launch.lua 分析 - 50% 完了
- Artisan: T6-A1 API 実装 - 開始
- Merchant: T6-M1 準備 - 開始

### In Progress
- Paladin: T6-P1 セキュリティ修正 - 進行中
- Bard: T6-B1 進捗記録 - 継続中

### Blockers
- なし

### Risks
- GLFW ウィンドウ作成失敗リスク (Merchant が監視)

## 2026-01-30 (Day 2)
...
```

---

### 【T6-B2】API 互換性マトリクス更新

**マトリクス形式**:
```markdown
| API | 実装状況 | Launch.lua | Main.lua | テスト段階 | 備考 |
|-----|--------|-----------|---------|----------|------|
| RenderInit | ✅ | ✅ | N/A | STAGE 1 | Phase 4 完成 |
| SetWindowTitle | ✅ | ✅ | N/A | STAGE 1 | Phase 4 完成 |
| GetScreenSize | ✅ | N/A | ✅ | STAGE 2 | Phase 4 完成 |
| SetDrawColor | ✅ | N/A | ✅ | STAGE 2 | Phase 4 完成 |
| DrawImage | ✅ | N/A | ✅ | STAGE 2 | Phase 4 完成 |
| DrawString | ✅ | N/A | ✅ | STAGE 3 | Phase 4 完成 |
| LoadFont | ✅ | N/A | ✅ | STAGE 3 | Phase 4 完成 |
| ConExecute | ✅ | ✅ | N/A | STAGE 1 | Phase 6 実装 |
| ConClear | ✅ | ✅ | N/A | STAGE 1 | Phase 6 実装 |
| Copy | ✅ | N/A | ✅ | STAGE 4 | Phase 6 実装 |
| TakeScreenshot | ✅ | N/A | ✅ | STAGE 4 | Phase 6 実装 (スタブ) |
| ... | ... | ... | ... | ... | ... |
```

---

### 【T6-B3】ユーザーガイド更新

**目次**:
```markdown
# PoB2macOS Getting Started Guide

## 1. Installation & Setup
- Requirements
- Build Instructions
- Run Instructions

## 2. First Run
- Window Display
- Basic Operations

## 3. Troubleshooting
- Common Issues
- Error Messages
- Resolution Steps

## 4. API Reference
- SimpleGraphic API Overview
- Function Signatures
- Usage Examples

## 5. Advanced Topics
- Performance Tuning
- Custom Modifications
```

---

### 【T6-B4】最終レポート統合

**構成**:
```markdown
# Phase 6 - PoB2macOS Integration Test Final Report

## Executive Summary
- Phase 6 は [成功/失敗]
- 主要な達成:
  - 統合テスト 4 段階全て実施
  - セキュリティレビュー完了
  - パフォーマンスベースライン確立

## Detailed Results
- Sage: 分析完了 (Launch.lua フロー理解度 100%)
- Artisan: 実装完了 (5 API + テストスクリプト 4 個)
- Paladin: セキュリティレビュー完了 (MEDIUM 4 件修正)
- Merchant: テスト実行完了 (FPS 60+ 達成)
- Bard: ドキュメント完成 (ユーザーガイド作成)

## Next Steps (Phase 7 推奨)
- UI 機能補完
- パフォーマンス最適化
- リリース準備
```

---

## 7. Skill Validation Protocol 最終チェックリスト

### Sage (知識者) の報告品質基準

```
✅ 完全性:
  - Launch.lua 全 406 行の理解確認
  - API 呼び出し依存グラフ完成
  - スタブ仕様書は Artisan が直接実装可能

✅ 深さ:
  - 各 API の用途を正確に説明
  - リスク分析を含む
  - テストスクリプト基本骨子を提供

Validation:
  □ sage_launch_analysis.md 作成確認
  □ 図表・フロー図を含む確認
  □ スタブ API 5 個を正確に特定確認
```

### Artisan (職人) の実装品質基準

```
✅ 完全性:
  - 5 個の API スタブ実装完成
  - 4 個のテストスクリプト実装完成
  - ビルド成功 (警告ゼロ)

✅ 動作確認:
  - MVP テスト 12/12 PASS
  - Lua バインディング動作確認
  - テストスクリプト実行確認

Validation:
  □ sg_stubs.c ビルド成功確認
  □ stage1-4_test.lua 実装確認
  □ MVP テスト PASS 確認
```

### Paladin (聖騎士) の品質保証基準

```
✅ セキュリティ:
  - MEDIUM 4 件全て修正
  - 新規コード 0 件のクリティカル
  - メモリリーク検出テスト完成

✅ 報告品質:
  - 修正の理由と効果を明示
  - グラフ・統計情報を含む

Validation:
  □ security_fixes_phase6.md 作成確認
  □ memcheck_report_phase6.md 作成確認
  □ MVP テスト PASS 確認
```

### Merchant (商人) のテスト品質基準

```
✅ テスト実施:
  - 4 段階テスト全て実施
  - スクリーンショット記録
  - パフォーマンス計測完成

✅ 報告品質:
  - ユーザーが理解可能
  - 問題は詳細に記録
  - グラフを含む

Validation:
  □ STAGE1-4_RESULTS.md 作成確認
  □ PERFORMANCE_BASELINE.md 作成確認
  □ FPS 60+ 達成確認
```

### Bard (吟遊詩人) の統合品質基準

```
✅ ドキュメント:
  - 進捗記録完成
  - API マトリクス完成
  - ユーザーガイド完成
  - 最終レポート統合完成

✅ 観点の使い分け:
  - 技術者向け: API マトリクス詳細
  - ユーザー向け: ユーザーガイド簡潔
  - 経営層向け: エグゼクティブサマリー

Validation:
  □ phase6_progress.md 作成確認
  □ api_compatibility_matrix.md 作成確認
  □ GETTING_STARTED.md 作成確認
  □ phase6_final_report.md 作成確認
```

---

**End of Execution Guide**

このガイドに従い、5人の村人が並列実行します。

Mayor (村長) は各タスクの進捗を監視し、ブロッカーが発生した場合は即座に調整します。

