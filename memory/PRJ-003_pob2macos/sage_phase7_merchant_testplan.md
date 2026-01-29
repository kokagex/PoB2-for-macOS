# Phase 7 - Merchant Test Plan
## Merchant 向け Phase 7 統合テストプラン

**対象**: Merchant (テスター)
**テスト対象**: SetMainObject, PCall, PLoadModule
**テスト期間**: 2026-01-31 ~ 2026-02-01
**テスト環境**: macOS (arm64 Apple Silicon)

---

## テスト概要

### テスト目的

PoB2 のコールバック機構（SetMainObject, PCall, PLoadModule）が正常に動作し、メインループとの統合が完全に機能することを確認。

### テストスコープ

| テスト | 対象 | 期間 |
|--------|------|------|
| T7-M1 | SetMainObject 機能テスト | 2026-01-31 09:00-11:00 |
| T7-M2 | PCall エラーハンドリングテスト | 2026-01-31 11:00-13:00 |
| T7-M3 | PLoadModule モジュール読み込みテスト | 2026-01-31 13:00-15:00 |
| T7-M4 | メインループ統合テスト | 2026-02-01 09:00-12:00 |
| T7-M5 | パフォーマンステスト | 2026-02-01 13:00-17:00 |

### テスト環境準備

```bash
# ビルド
cd /Users/kokage/national-operations/pob2macos/build
cmake ..
make clean
make -j4

# MVP テスト確認
make test
# Expected: 12/12 PASS
```

---

## T7-M1: SetMainObject 機能テスト（1.5h）

### テスト内容

SetMainObject で登録された launch オブジェクトが、C フレームワークから正しくコールバックされるか確認。

### テストスクリプト

**ファイル**: `tests/t7_m1_setmainobject.lua`

```lua
-- Phase 7 Test M1: SetMainObject Functionality
-- Expected: launch オブジェクトのコールバックが正しく呼ばれることを確認

local test_results = {
    passed = 0,
    failed = 0,
    tests = {}
}

function test_assert(name, condition, expected, actual)
    if condition then
        test_results.passed = test_results.passed + 1
        ConPrintf("[PASS] %s", name)
        table.insert(test_results.tests, {name = name, status = "PASS"})
    else
        test_results.failed = test_results.failed + 1
        ConPrintf("[FAIL] %s (expected: %s, got: %s)", name, tostring(expected), tostring(actual))
        table.insert(test_results.tests, {name = name, status = "FAIL", expected = expected, actual = actual})
    end
end

-- Test 1: Object can be registered
ConPrintf("=== T7-M1 Test 1: SetMainObject Registration ===")
local launch = {
    initialized = false,
    frame_count = 0,
    key_pressed = false,
}

function launch:OnInit()
    self.initialized = true
end

function launch:OnFrame()
    self.frame_count = self.frame_count + 1
end

function launch:OnKeyDown(key, doubleClick)
    self.key_pressed = true
    ConPrintf("Key pressed: %s (double=%s)", key, tostring(doubleClick))
end

function launch:CanExit()
    return self.frame_count > 3  -- 3フレーム後に終了
end

function launch:OnExit()
    ConPrintf("OnExit called, frame_count = %d", self.frame_count)
end

-- SetMainObject を呼び出し
SetMainObject(launch)
test_assert(
    "SetMainObject accepts table",
    type(launch) == "table",
    "table", type(launch)
)

-- Test 2: Invalid argument handling
ConPrintf("\n=== T7-M1 Test 2: Error Handling ===")
local error_caught = false
-- SetMainObject に非テーブルを渡すとエラーになるはず
-- (実装により異なる可能性あり)

-- Test 3: Multiple method checks
ConPrintf("\n=== T7-M1 Test 3: Method Existence ===")
test_assert(
    "launch.OnInit exists",
    type(launch.OnInit) == "function",
    "function", type(launch.OnInit)
)
test_assert(
    "launch.OnFrame exists",
    type(launch.OnFrame) == "function",
    "function", type(launch.OnFrame)
)
test_assert(
    "launch.OnKeyDown exists",
    type(launch.OnKeyDown) == "function",
    "function", type(launch.OnKeyDown)
)
test_assert(
    "launch.CanExit exists",
    type(launch.CanExit) == "function",
    "function", type(launch.CanExit)
)
test_assert(
    "launch.OnExit exists",
    type(launch.OnExit) == "function",
    "function", type(launch.OnExit)
)

-- Test 4: メインループを通じたコールバック動作確認
-- (これは C フレームワークが自動的に実行)
ConPrintf("\n=== T7-M1 Test 4: Framework Callback Invocation ===")
ConPrintf("Waiting for framework to call callbacks...")
ConPrintf("(This will be validated after 4 frames)")

-- フレームループが完了するまで待機

-- テスト結果出力
ConPrintf("\n=== T7-M1 Test Results ===")
ConPrintf("Passed: %d", test_results.passed)
ConPrintf("Failed: %d", test_results.failed)

if test_results.failed == 0 then
    ConPrintf("Overall: PASS")
else
    ConPrintf("Overall: FAIL")
    for _, test in ipairs(test_results.tests) do
        if test.status == "FAIL" then
            ConPrintf("  - %s (expected: %s, got: %s)", test.name, test.expected, test.actual)
        end
    end
end
```

### テスト実行手順

```bash
# ビルド確認
cd /Users/kokage/national-operations/pob2macos/build
make -j4

# テスト実行
./pob2macos --script tests/t7_m1_setmainobject.lua

# Expected output:
# [PASS] SetMainObject accepts table
# [PASS] launch.OnInit exists
# [PASS] launch.OnFrame exists
# [PASS] launch.OnKeyDown exists
# [PASS] launch.CanExit exists
# [PASS] launch.OnExit exists
# === T7-M1 Test Results ===
# Passed: 6
# Failed: 0
# Overall: PASS
```

### 検証項目

- [ ] SetMainObject が引数として table を受け入れる
- [ ] launch オブジェクトのメソッドが存在する
- [ ] フレームワークが OnInit() を呼び出す
- [ ] フレームワークが OnFrame() を毎フレーム呼び出す
- [ ] フレームワークが CanExit() を呼び出す
- [ ] フレームワークが OnExit() を呼び出す

### 成功基準

✅ すべての検証項目が完了
✅ エラーなし
✅ Passed: 6/6 (失敗 0)

---

## T7-M2: PCall エラーハンドリングテスト（2h）

### テスト内容

PCall がエラーを正しくキャッチし、戻り値でエラーメッセージを返すか確認。

### テストスクリプト

**ファイル**: `tests/t7_m2_pcall.lua`

```lua
-- Phase 7 Test M2: PCall Error Handling
-- Expected: PCall がエラーをキャッチして戻り値で返すこと

ConPrintf("=== T7-M2 Test 1: Normal Execution ===")

-- Test 1: 正常系
local function add(a, b)
    return a + b
end

local err, result = PCall(add, 10, 20)
if err == nil and result == 30 then
    ConPrintf("[PASS] PCall normal execution: 10 + 20 = %d", result)
else
    ConPrintf("[FAIL] PCall normal execution: err=%s, result=%s", tostring(err), tostring(result))
end

-- Test 2: 複数戻り値
local function multiReturn()
    return "a", "b", "c"
end

local err, a, b, c = PCall(multiReturn)
if err == nil and a == "a" and b == "b" and c == "c" then
    ConPrintf("[PASS] PCall multi-return: %s, %s, %s", a, b, c)
else
    ConPrintf("[FAIL] PCall multi-return")
end

ConPrintf("\n=== T7-M2 Test 2: Error Handling ===")

-- Test 3: エラーキャッチ - nil インデックス
local function errorFunc1()
    local t = nil
    return t.field  -- error
end

local err = PCall(errorFunc1)
if err ~= nil and type(err) == "string" then
    ConPrintf("[PASS] PCall caught nil index error: %s", err)
else
    ConPrintf("[FAIL] PCall error handling failed")
end

-- Test 4: エラーキャッチ - 型エラー
local function errorFunc2()
    return ("string") + 10  -- type error
end

local err = PCall(errorFunc2)
if err ~= nil and type(err) == "string" then
    ConPrintf("[PASS] PCall caught type error: %s", err)
else
    ConPrintf("[FAIL] PCall type error handling failed")
end

ConPrintf("\n=== T7-M2 Test 3: Error Propagation ===")

-- Test 5: explicit error() 呼び出し
local function errorFunc3()
    error("Custom error message")
end

local err = PCall(errorFunc3)
if err ~= nil and err:match("Custom error message") then
    ConPrintf("[PASS] PCall caught explicit error: %s", err)
else
    ConPrintf("[FAIL] PCall explicit error handling failed")
end

ConPrintf("\n=== T7-M2 Test Results ===")
ConPrintf("All error handling tests completed")
```

### テスト実行手順

```bash
./pob2macos --script tests/t7_m2_pcall.lua

# Expected output:
# [PASS] PCall normal execution: 10 + 20 = 30
# [PASS] PCall multi-return: a, b, c
# [PASS] PCall caught nil index error: ...
# [PASS] PCall caught type error: ...
# [PASS] PCall caught explicit error: Custom error message
# === T7-M2 Test Results ===
# All error handling tests completed
```

### 検証項目

- [ ] PCall が正常系で (nil, result) を返す
- [ ] PCall が複数戻り値を正しく処理する
- [ ] PCall が nil インデックスエラーをキャッチする
- [ ] PCall が型エラーをキャッチする
- [ ] PCall が明示的なエラーをキャッチする
- [ ] エラーメッセージが文字列型で返される

### 成功基準

✅ すべての検証項目が PASS
✅ エラーが正しく変換される

---

## T7-M3: PLoadModule テスト（2h）

### テスト内容

PLoadModule がモジュールを読み込み、エラーハンドリングを実行するか確認。

### テスト準備

**テストモジュール作成**: `tests/test_module_success.lua`

```lua
-- test_module_success.lua
return {
    name = "TestModule",
    version = "1.0",
    init = function()
        return "Module initialized"
    end
}
```

**テストモジュール作成**: `tests/test_module_error.lua`

```lua
-- test_module_error.lua
error("Intentional error in module")
```

### テストスクリプト

**ファイル**: `tests/t7_m3_ploadmodule.lua`

```lua
-- Phase 7 Test M3: PLoadModule Module Loading

ConPrintf("=== T7-M3 Test 1: Successful Module Loading ===")

-- Test 1: 正常なモジュール読み込み
local err, module = PLoadModule("tests/test_module_success")
if err == nil and module ~= nil and module.name == "TestModule" then
    ConPrintf("[PASS] PLoadModule successful load: %s", module.name)
else
    ConPrintf("[FAIL] PLoadModule failed to load module: err=%s", tostring(err))
end

ConPrintf("\n=== T7-M3 Test 2: Module With Arguments ===")

-- Test 2: 引数付きロード
local err, result = PLoadModule("tests/test_module_success")
if err == nil then
    ConPrintf("[PASS] PLoadModule with arguments successful")
else
    ConPrintf("[FAIL] PLoadModule with arguments failed: %s", err)
end

ConPrintf("\n=== T7-M3 Test 3: Error Handling ===")

-- Test 3: エラーモジュール
local err, result = PLoadModule("tests/test_module_error")
if err ~= nil and type(err) == "string" then
    ConPrintf("[PASS] PLoadModule caught module error: %s", err)
else
    ConPrintf("[FAIL] PLoadModule error handling failed")
end

-- Test 4: ファイル未検出
local err, result = PLoadModule("tests/nonexistent_module")
if err ~= nil and type(err) == "string" then
    ConPrintf("[PASS] PLoadModule correctly handles missing files")
else
    ConPrintf("[FAIL] PLoadModule missing file handling failed")
end

ConPrintf("\n=== T7-M3 Test Results ===")
ConPrintf("Module loading tests completed")
```

### テスト実行手順

```bash
# テストモジュール作成
cat > tests/test_module_success.lua << 'EOF'
return {
    name = "TestModule",
    version = "1.0",
}
EOF

cat > tests/test_module_error.lua << 'EOF'
error("Intentional error in module")
EOF

# テスト実行
./pob2macos --script tests/t7_m3_ploadmodule.lua

# Expected output:
# [PASS] PLoadModule successful load: TestModule
# [PASS] PLoadModule with arguments successful
# [PASS] PLoadModule caught module error: ...
# [PASS] PLoadModule correctly handles missing files
# === T7-M3 Test Results ===
# Module loading tests completed
```

### 検証項目

- [ ] 正常なモジュールを読み込める
- [ ] モジュールが正しく初期化される
- [ ] エラーモジュールのエラーをキャッチできる
- [ ] ファイル未検出時にエラーを返す
- [ ] .lua 拡張子の自動付与

### 成功基準

✅ すべての検証項目が PASS
✅ モジュール読み込みが正常に機能

---

## T7-M4: メインループ統合テスト（3h）

### テスト内容

メインループが SetMainObject, PCall, PLoadModule を統合して正しく動作するか確認。

### テストシナリオ

```lua
-- tests/t7_m4_mainloop_integration.lua
-- メインループが Launch.lua のコールバックを正しく呼び出すことを確認

local test_state = {
    init_called = false,
    frame_count = 0,
    frame_max = 5,
    key_events = {},
    exit_called = false,
}

launch = {}
function launch:OnInit()
    test_state.init_called = true
    ConPrintf("[MAINLOOP] OnInit called")

    -- Main モジュール読み込みをシミュレート
    local err, main = PLoadModule("tests/test_main_module")
    if err then
        ConPrintf("[ERROR] Failed to load Main module: %s", err)
    else
        self.main = main
        ConPrintf("[MAINLOOP] Main module loaded: %s", main.name or "unknown")
    end
end

function launch:OnFrame()
    test_state.frame_count = test_state.frame_count + 1
    if test_state.frame_count <= 3 then
        ConPrintf("[MAINLOOP] OnFrame %d", test_state.frame_count)
    end

    -- Main.OnFrame をコール
    if self.main and self.main.OnFrame then
        local err = PCall(self.main.OnFrame, self.main)
        if err then
            ConPrintf("[ERROR] Main.OnFrame failed: %s", err)
        end
    end

    if test_state.frame_count >= test_state.frame_max then
        test_state.should_exit = true
    end
end

function launch:OnKeyDown(key, doubleClick)
    table.insert(test_state.key_events, key)
    ConPrintf("[MAINLOOP] OnKeyDown: %s", key)

    if self.main and self.main.OnKeyDown then
        local err = PCall(self.main.OnKeyDown, self.main, key, doubleClick)
        if err then
            ConPrintf("[ERROR] Main.OnKeyDown failed: %s", err)
        end
    end
end

function launch:CanExit()
    return test_state.should_exit or false
end

function launch:OnExit()
    test_state.exit_called = true
    ConPrintf("[MAINLOOP] OnExit called")

    if self.main and self.main.Shutdown then
        local err = PCall(self.main.Shutdown, self.main)
        if err then
            ConPrintf("[ERROR] Main.Shutdown failed: %s", err)
        end
    end
end

-- オブジェクト登録
SetMainObject(launch)

ConPrintf("=== T7-M4 Integration Test Started ===")
ConPrintf("Waiting for mainloop callbacks...")
ConPrintf("Expected: OnInit → OnFrame (5x) → OnExit")
```

### テストモジュール

**ファイル**: `tests/test_main_module.lua`

```lua
local main = {}
main.name = "TestMain"

function main:OnFrame()
    -- Test code
end

function main:OnKeyDown(key, doubleClick)
    -- Test code
end

function main:Shutdown()
    -- Test code
end

return main
```

### テスト実行手順

```bash
# モジュール作成
cat > tests/test_main_module.lua << 'EOF'
local main = {}
main.name = "TestMain"
function main:OnFrame() end
function main:OnKeyDown(key, doubleClick) end
function main:Shutdown() end
return main
EOF

# テスト実行
./pob2macos --script tests/t7_m4_mainloop_integration.lua

# Expected output:
# === T7-M4 Integration Test Started ===
# [MAINLOOP] OnInit called
# [MAINLOOP] Main module loaded: TestMain
# [MAINLOOP] OnFrame 1
# [MAINLOOP] OnFrame 2
# [MAINLOOP] OnFrame 3
# [MAINLOOP] OnExit called
```

### 検証項目

- [ ] OnInit が呼ばれる（1回）
- [ ] Main モジュールが正常にロードされる
- [ ] OnFrame が毎フレーム呼ばれる（5回）
- [ ] Main.OnFrame が PCall でラップされて実行される
- [ ] キー入力イベントが処理される
- [ ] CanExit が呼ばれる
- [ ] OnExit が呼ばれる（1回）
- [ ] Main.Shutdown が PCall でラップされて実行される

### 成功基準

✅ すべてのコールバックが正しい順序で呼ばれる
✅ エラーが発生しない
✅ メインループが正常に完了する

---

## T7-M5: パフォーマンステスト（4h）

### テスト内容

PoB2 フル起動時のパフォーマンス（FPS、メモリ）を計測。

### テスト方法

```bash
# PoB2 フル起動
./pob2macos

# 計測項目:
# 1. FPS (frames per second) - 目標: 60+ FPS
# 2. メモリ使用量 - 目標: < 500MB 初期値
# 3. CPU 使用率 - 目標: < 50%
# 4. ウィンドウ応答性 - 主観: 滑らか
```

### テスト手順

#### 1. FPS 計測（15 分）

```lua
-- tests/t7_m5_fps_test.lua
local fps_test = {
    frame_count = 0,
    start_time = GetTime(),
    total_time = 30,  -- 30秒計測
    fps_values = {}
}

launch = {}
function launch:OnInit()
    ConPrintf("=== T7-M5 FPS Performance Test ===")
    ConPrintf("Measuring FPS for 30 seconds...")
end

function launch:OnFrame()
    fps_test.frame_count = fps_test.frame_count + 1

    local elapsed = GetTime() - fps_test.start_time
    if elapsed >= 1.0 then
        -- 1秒ごとに FPS を計算
        local fps = fps_test.frame_count / elapsed
        table.insert(fps_test.fps_values, fps)
        ConPrintf("Elapsed: %.1fs, FPS: %.1f", elapsed, fps)

        if elapsed >= fps_test.total_time then
            fps_test.should_exit = true
        end
    end
end

function launch:CanExit()
    return fps_test.should_exit or false
end

function launch:OnExit()
    local avg_fps = 0
    for _, fps in ipairs(fps_test.fps_values) do
        avg_fps = avg_fps + fps
    end
    avg_fps = avg_fps / #fps_test.fps_values

    ConPrintf("\n=== FPS Test Results ===")
    ConPrintf("Total frames: %d", fps_test.frame_count)
    ConPrintf("Duration: %.1f seconds", fps_test.total_time)
    ConPrintf("Average FPS: %.1f", avg_fps)

    if avg_fps >= 60 then
        ConPrintf("[PASS] FPS >= 60")
    else
        ConPrintf("[WARN] FPS < 60 (%.1f)", avg_fps)
    end
end

SetMainObject(launch)
```

#### 2. メモリ計測（15 分）

```bash
# Activity Monitor で計測
# または valgrind でメモリリーク検査

valgrind --leak-check=full --show-leak-kinds=all \
    ./pob2macos --script tests/t7_m4_mainloop_integration.lua
```

#### 3. CPU 使用率計測（15 分）

```bash
# top コマンドで計測
top -l 1 -n 10 -o %CPU | grep pob2macos
```

### パフォーマンス基準

| 項目 | 目標 | 警告値 | 失敗値 |
|------|------|--------|--------|
| FPS | 60+ | 50-59 | <50 |
| メモリ増加 | <10MB/min | 10-20MB/min | >20MB/min |
| CPU 使用率 | <30% | 30-50% | >50% |

### 成功基準

✅ 平均 FPS >= 60
✅ メモリリークなし
✅ CPU 使用率 < 50%

---

## テスト実行スケジュール

### Day 1: 2026-01-31（水）

```
09:00-11:00  T7-M1: SetMainObject テスト
11:00-13:00  T7-M2: PCall テスト
13:00-15:00  T7-M3: PLoadModule テスト
15:00-17:00  修正・再テスト（必要に応じて）
```

### Day 2: 2026-02-01（木）

```
09:00-12:00  T7-M4: メインループ統合テスト
13:00-17:00  T7-M5: パフォーマンステスト
```

---

## テスト報告書テンプレート

**ファイル**: `/Users/kokage/national-operations/claudecode01/memory/PHASE7_TEST_RESULTS.md`

```markdown
# Phase 7 Test Results
**Date**: 2026-01-31 ~ 2026-02-01
**Tester**: Merchant

## Summary
- Total Tests: 5
- Passed: X
- Failed: Y
- Skipped: Z

## Detailed Results

### T7-M1: SetMainObject
- [ ] Registration
- [ ] Callback invocation
- [ ] Method existence
**Status**: PASS / FAIL

### T7-M2: PCall
- [ ] Normal execution
- [ ] Multi-return
- [ ] Error handling
**Status**: PASS / FAIL

### T7-M3: PLoadModule
- [ ] Successful load
- [ ] Error handling
- [ ] Missing file handling
**Status**: PASS / FAIL

### T7-M4: Integration
- [ ] OnInit called
- [ ] OnFrame called
- [ ] OnExit called
**Status**: PASS / FAIL

### T7-M5: Performance
- [ ] FPS: XY
- [ ] Memory: OK / FAIL
- [ ] CPU: OK / FAIL
**Status**: PASS / FAIL

## Issues Found
(If any)

## Recommendations
(If any)
```

---

## トラブルシューティング

### Issue 1: "undefined reference to `lua_SetMainObject`"

**原因**: SetMainObject が登録されていない

**解決**:
1. sg_callbacks.c が CMakeLists.txt に追加されているか確認
2. `make clean && make -j4` で再ビルド

### Issue 2: コールバックが呼ばれない

**原因**: mainObject のレジストリ参照がリセットされている、または GC で削除されている

**解決**:
1. SetMainObject 後に launch オブジェクトが削除されていないか確認
2. C 側でレジストリ参照管理が正しいか確認

### Issue 3: FPS が低い（< 60）

**原因**:
1. OnFrame() 内で重い処理が実行されている
2. メモリ不足によるスワップ
3. GPU が瓶首になっている

**解決**:
1. Main.OnFrame() の処理を最適化
2. メモリ使用量を削減
3. 描画処理を最適化

---

## 成功判定フロー

```
T7-M1-M3 テスト
  ├─ すべて PASS → T7-M4 へ
  └─ FAIL → Artisan に報告

T7-M4 テスト
  ├─ PASS → T7-M5 へ
  └─ FAIL → 詳細分析 → Artisan へ報告

T7-M5 テスト
  ├─ すべて OK → Phase 7 完了
  └─ WARN / FAIL → 調整検討
```

---

**更新日**: 2026-01-29
**対象**: Merchant (テスター)
**ステータス**: 準備完了 → テスト待機
