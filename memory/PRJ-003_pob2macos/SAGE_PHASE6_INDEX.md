# Sage Phase 6 - Index and Quick Reference

## Document Location

**Main Analysis Report**:
- File: `/Users/kokage/national-operations/claudecode01/memory/sage_phase6_pob2_analysis.md`
- Size: 27 KB, 911 lines
- Format: Markdown
- Completion: 2026-01-29

**Test Script**:
- File: `/Users/kokage/national-operations/pob2macos/tests/stage1_test.lua`
- Size: 13 KB, 473 lines
- Format: Lua (executable)
- Completion: 2026-01-29

## Quick Navigation

### In sage_phase6_pob2_analysis.md

1. **Launch.lua 起動シーケンス分析** (Line ~30)
   - 7段階フロー図
   - ファイル構成（Main, Export）
   - API呼び出しパターン

2. **SimpleGraphic API 使用状況** (Line ~150)
   - 既実装API (13個) - 表形式
   - 使用実績マッピング
   - API分類（初期化、描画、テキスト、入力、ユーティリティ、画像管理）

3. **不足API仕様書** (Line ~250)
   - カテゴリ1-9 の23個のAPI
   - 各APIの詳細仕様
   - 引数、戻り値、実装要件
   - 優先度表示

4. **Lua モジュール依存関係** (Line ~800)
   - Launch.lua → Main.lua 遷移パス
   - 主要モジュール一覧

5. **Stage 1 テスト設計** (Line ~820)
   - テスト目的
   - テストシーケンス
   - 成功判定基準
   - テストファイル仕様

6. **実装ロードマップ** (Line ~890)
   - Phase 6 (Sage) - 完了
   - Phase 7 (Artisan) - 実装順序
   - Phase 8 (Tester) - テスト計画

### In stage1_test.lua

1. **Test Configuration** (Line 14-18)
   - TEST_VERBOSE = true
   - TEST_RESULTS tracking

2. **Utility Functions** (Line 23-60)
   - log(), success(), failure()
   - assert_*() helpers

3. **API Availability Tests** (Line 65-115)
   - 30個のAPI関数チェック
   - Required APIs list

4. **RenderInit Test** (Line 120-140)

5. **SetWindowTitle Test** (Line 145-160)

6. **GetScreenSize Test** (Line 165-190)

7. **Drawing Tests** (Line 195-240)
   - SetDrawColor, DrawImage
   - SetDrawLayer, SetViewport

8. **Text Rendering Tests** (Line 245-280)
   - DrawString
   - DrawStringWidth

9. **Input Tests** (Line 285-310)
   - IsKeyDown (5 key types)

10. **Utility Tests** (Line 315-360)
    - GetTime
    - GetScreenScale
    - DPI functions

11. **Test Summary** (Line 365-400)
    - Total/Passed/Failed count
    - Success rate percentage
    - Failed test details

## Key API Lists

### Already Implemented (13)
RenderInit, GetScreenSize, SetWindowTitle, SetClearColor, RunMainLoop, 
IsUserTerminated, Shutdown, SetDrawColor, GetDrawColor, DrawImage, 
DrawImageQuad, SetDrawLayer, ImgWidth, ImgHeight, LoadImage, FreeImage, 
LoadFont, DrawString, DrawStringWidth, DrawStringCursorIndex, IsKeyDown, 
GetCursorPos, SetCursorPos, ShowCursor, GetScreenScale, 
GetDPIScaleOverridePercent, SetDPIScaleOverridePercent, GetTime

### P1 Priority (Stage 1 - 8 APIs)
1. ConPrintf - Console output (CRITICAL)
2. ConExecute - Command execution (CRITICAL)
3. SetMainObject - UI framework (CRITICAL)
4. PCall - Protected call (CRITICAL)
5. PLoadModule - Protected load (CRITICAL)
6. LoadModule - Module loading
7. GetScriptPath - Script path
8. GetRuntimePath - Runtime path

### P2 Priority (Stage 2 - 7 APIs)
1. MakeDir - Directory creation
2. Inflate - Zlib decompression
3. GetUserPath - User data path
4. GetWorkDir - Working directory
5. ConClear - Console clear
6. Copy - Copy to clipboard
7. Paste - Paste from clipboard

### P3 Priority (Complete - 8 APIs)
1. GetClipboard, SetClipboard - Clipboard (4 total with Copy/Paste)
2. TakeScreenshot - Screenshot
3. LaunchSubScript - Multithreaded execution
4. Exit - Application exit
5. Restart - Application restart
6. SpawnProcess - Child process
7. SetWindowSize - Window resize
8. GetSubScript, GetAsyncCount - Advanced async

## PoB2 Source Files Reference

**Main Startup Script**:
- `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua` (406 lines)

**Export Startup Script**:
- `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Export/Launch.lua` (199 lines)

**Main Module**:
- `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Modules/Main.lua`

**Module Hierarchy**:
- GameVersions
- Modules/Common
- Modules/Data
- Modules/ModTools
- Modules/ItemTools
- Modules/CalcTools
- Modules/BuildSiteTools

## SimpleGraphic Header

Location: `/Users/kokage/national-operations/pob2macos/src/include/simplegraphic.h`

Current implementation: Pure C header with 33 function declarations
Status: 13 functions are used in PoB2 Launch.lua
Missing: 23 functions needed for full PoB2 compatibility

## Test Execution

To run Stage 1 tests (after Lua bindings are implemented):

```bash
lua /Users/kokage/national-operations/pob2macos/tests/stage1_test.lua
```

Expected output:
- API availability checks
- Individual test results
- Final summary with pass/fail count
- Exit code: 0 (all pass), 1 (any fail)

## Notes for Artisan (Phase 7)

1. Start with ConPrintf - it's used by almost everything for debugging
2. SetMainObject must integrate with event loop - this is the framework
3. PCall/PLoadModule are wrappers - handle exceptions gracefully
4. LoadModule needs path resolution relative to src/
5. See technical section in main report for implementation details

## Notes for Tester (Phase 8)

1. Stage 1 test validates API bindings only
2. Stage 2 requires Artisan to implement P1 APIs first
3. Use exit codes to determine test success
4. Test summary will show which APIs are working
5. Full integration test requires all 23 APIs

## Document Statistics

- Total pages: 911 + 473 = 1384 lines
- Total size: 27 KB + 13 KB = 40 KB
- API specifications: 23 detailed entries
- Test cases: 10+ major categories
- Code examples: 20+ throughout document

## Previous Phases Reference

- Phase 5 (Completed): PoB2 Project Setup
- Phase 6 (Completed): This analysis
- Phase 7 (Pending): Artisan implementation
- Phase 8 (Pending): Tester validation

## Questions or Issues?

Refer to:
1. Main report section "技術的課題と注記" (Technical Issues)
2. Each API specification has "実装要件" (Implementation Requirements)
3. Test script has inline comments for each test section

---

Last Updated: 2026-01-29
Author: Sage (Claude Haiku 4.5)
Status: Complete - Ready for Phase 7
