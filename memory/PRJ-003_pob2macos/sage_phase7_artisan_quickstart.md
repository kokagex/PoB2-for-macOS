# Phase 7 - Artisan Quick Implementation Guide
## Artisan 向け Phase 7-P1 (3 API) 実装クイックガイド

**対象**: Artisan (実装者)
**対象 API**: SetMainObject, PCall, PLoadModule
**優先度**: CRITICAL (Block resolver)
**推定工数**: 1-2 日

---

## TL;DR - 実装概要

### 実装対象（3 個の API）

| # | API | 場所 | 工数 | 難度 |
|---|-----|------|------|------|
| 1 | **SetMainObject** | C (sg_callbacks.c) | 30分 | ⭐⭐ |
| 2 | **PCall** | Lua ラッパー | 10分 | ⭐ |
| 3 | **PLoadModule** | Lua ラッパー | 20分 | ⭐ |

**総工数**: ~1 時間 (コード + テスト)

---

## 1. SetMainObject - C 実装（30 分）

### 実装ファイル

**新規作成**: `/Users/kokage/national-operations/pob2macos/src/sg_callbacks.c`

### 最小限のコード

```c
#include <lua.h>
#include <lauxlib.h>

// グローバル: メイン UI オブジェクト参照
static lua_State *g_lua = NULL;
static int g_mainObject_ref = LUA_NOREF;

/**
 * SetMainObject(obj: table) -> void
 * メイン UI オブジェクト (launch テーブル) を登録
 */
int lua_SetMainObject(lua_State *L)
{
    if (!lua_istable(L, 1)) {
        luaL_error(L, "SetMainObject requires a table argument");
        return 0;
    }

    // 古い参照を解放
    if (g_mainObject_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, g_mainObject_ref);
    }

    // 新しい参照を保存
    lua_pushvalue(L, 1);
    g_mainObject_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    g_lua = L;

    return 0;
}

/**
 * 内部ヘルパー: メインオブジェクトを取得
 */
int get_mainobject(lua_State *L)
{
    if (g_mainObject_ref == LUA_NOREF) {
        return 0;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, g_mainObject_ref);
    return 1;  // スタックに 1 つ値が追加
}

/**
 * 内部ヘルパー: コールバック実行 (可変長引数)
 * 使用例: run_callback("OnFrame");
 *         run_callback("OnKeyDown", "a", 0);
 */
int run_callback(const char *method_name, int nargs, ...)
{
    if (g_mainObject_ref == LUA_NOREF || g_lua == NULL) {
        return 0;
    }

    // mainObject を取得
    lua_rawgeti(g_lua, LUA_REGISTRYINDEX, g_mainObject_ref);
    if (!lua_istable(g_lua, -1)) {
        lua_pop(g_lua, 1);
        return 0;
    }

    // method_name を取得
    lua_getfield(g_lua, -1, method_name);
    if (!lua_isfunction(g_lua, -1)) {
        lua_pop(g_lua, 2);
        return 0;
    }

    // self を push
    lua_pushvalue(g_lua, -2);

    // 可変長引数を push
    va_list args;
    va_start(args, nargs);

    // [注: 簡略版のため、引数型は固定で実装]
    // 実装例: 文字列と bool のペア
    for (int i = 0; i < nargs; i++) {
        int arg_type = va_arg(args, int);
        if (arg_type == 1) {  // string
            const char *s = va_arg(args, const char *);
            lua_pushstring(g_lua, s);
        } else if (arg_type == 2) {  // bool
            int b = va_arg(args, int);
            lua_pushboolean(g_lua, b);
        } else if (arg_type == 3) {  // number
            double n = va_arg(args, double);
            lua_pushnumber(g_lua, n);
        }
    }
    va_end(args);

    // 呼び出し
    int result = lua_pcall(g_lua, nargs + 1, 0, 0);
    if (result != LUA_OK) {
        fprintf(stderr, "Error in %s: %s\n", method_name, lua_tostring(g_lua, -1));
        lua_pop(g_lua, 1);
    }

    lua_pop(g_lua, 1);  // mainObject をポップ
    return result;
}

// Lua FFI 登録
static const luaL_Reg simplegraphic_funcs[] = {
    { "SetMainObject", lua_SetMainObject },
    // ... 他の関数
    { NULL, NULL }
};
```

### CMakeLists.txt への追加

```cmake
# CMakeLists.txt に追加
add_library(simplegraphic STATIC
    src/simplegraphic.c
    src/sg_callbacks.c   # ← 新規追加
    # ... 他のソースファイル
)
```

### メインループでの使用

```c
// src/main.c に追加
#include "simplegraphic.h"

void RunMainLoop(lua_State *L)
{
    // OnInit を呼び出し
    run_callback("OnInit", 0);

    // フレームループ
    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();

        // イベント処理
        // ... (キー入力処理など)

        // フレーム更新
        run_callback("OnFrame", 0);

        // 描画処理
        glClear(GL_COLOR_BUFFER_BIT);
        // (Lua が描画コマンドを実行)
        glfwSwapBuffers(window);

        // 終了判定
        // CanExit() を呼び出し
        // ...

        // 60 FPS に同期
        glfwWaitEventsTimeout(1.0 / 60.0);
    }

    // OnExit を呼び出し
    run_callback("OnExit", 0);

    glShutdown();
}
```

---

## 2. PCall - Lua 実装（10 分）

### 実装ファイル

**場所**: `src/Launch.lua` の先頭に追加

```lua
-- PCall: Protected function call wrapper
-- pcall をラップして、エラー時に戻り値でエラーメッセージを返す

function PCall(func, ...)
    local ret = { pcall(func, ...) }
    if ret[1] then
        -- 成功: [true, return_val1, return_val2, ...]
        table.remove(ret, 1)  -- true を削除
        return nil, unpack(ret)  -- (nil, return_val1, ...)
    else
        -- 失敗: [false, error_message]
        return ret[2]  -- (error_message)
    end
end
```

### テストコード

```lua
-- テスト用
local err, result = PCall(function() return 10 + 20 end)
assert(err == nil and result == 30, "PCall test failed")
```

---

## 3. PLoadModule - Lua 実装（20 分）

### 実装ファイル

**場所**: `src/Launch.lua` の PCall の直後に追加

```lua
-- PLoadModule: Protected LoadModule
-- モジュール読み込みをエラーハンドリング付きで実行

function PLoadModule(fileName, ...)
    -- .lua 拡張子がなければ追加
    if not fileName:match("%.lua$") then
        fileName = fileName .. ".lua"
    end

    -- GetScriptPath() と組み合わせてファイルパスを構成
    local scriptPath = GetScriptPath()
    local fullPath = scriptPath .. "/" .. fileName

    -- ファイルをコンパイル
    local func, err = loadfile(fullPath)
    if not func then
        -- ロード失敗
        return "PLoadModule error loading '" .. fullPath .. "': " .. (err or "unknown")
    end

    -- コンパイル成功: PCall で実行
    return PCall(func, ...)
end
```

### 使用例

```lua
-- Launch.lua L71 で使用
local errMsg, self.main = PLoadModule("Modules/Main")
if errMsg then
    self:ShowErrMsg("Error loading main script: %s", errMsg)
elseif not self.main then
    self:ShowErrMsg("Error loading main script: no object returned")
elseif self.main.Init then
    errMsg = PCall(self.main.Init, self.main)
    if errMsg then
        self:ShowErrMsg("In 'Init': %s", errMsg)
    end
end
```

---

## 実装チェックリスト

### SetMainObject (C)

- [ ] sg_callbacks.c を新規作成
- [ ] lua_SetMainObject() を実装
- [ ] レジストリ管理を実装
- [ ] get_mainobject() ヘルパー実装
- [ ] run_callback() ヘルパー実装
- [ ] CMakeLists.txt に sg_callbacks.c を追加
- [ ] コンパイル成功
- [ ] 警告なし (compiler warnings)

### PCall (Lua)

- [ ] Launch.lua の先頭に追加
- [ ] 関数シグネチャ確認
- [ ] テスト実行: 正常系 PASS
- [ ] テスト実行: エラー系 PASS
- [ ] テスト実行: 複数戻り値 PASS

### PLoadModule (Lua)

- [ ] Launch.lua に追加
- [ ] GetScriptPath() 統合確認
- [ ] .lua 拡張子処理確認
- [ ] PCall 統合確認
- [ ] テスト実行: 正常系 PASS
- [ ] テスト実行: ファイル未検出 PASS

### ビルド・テスト

- [ ] `cmake` 実行成功
- [ ] `make` ビルド成功
- [ ] MVP テスト 12/12 PASS
- [ ] セキュリティチェック PASS

---

## よくあるエラーと対応

### エラー 1: "undefined reference to `lua_SetMainObject`"

**原因**: CMakeLists.txt に sg_callbacks.c を追加していない

**解決**:

```cmake
# CMakeLists.txt に追加
add_library(simplegraphic STATIC
    src/simplegraphic.c
    src/sg_callbacks.c   # ← これを追加
)
```

### エラー 2: "Lua stack overflow" または segfault

**原因**: lua_rawgeti で間違ったレジストリインデックスを使用

**解決**:

```c
// ✓ 正しい
lua_rawgeti(L, LUA_REGISTRYINDEX, g_mainObject_ref);

// ✗ 間違い
lua_rawgeti(L, 1, g_mainObject_ref);  // LUA_REGISTRYINDEX を指定
```

### エラー 3: "PLoadModule() error loading 'Modules/Main.lua': No such file or directory"

**原因**: GetScriptPath() が正しくない、または .lua ファイルが見つからない

**解決**:

```lua
-- Debug: パスを確認
ConPrintf("Script path: %s", GetScriptPath())
ConPrintf("Try to load: %s/Modules/Main.lua", GetScriptPath())

-- Launch.lua が起動しているディレクトリを確認
-- GetScriptPath() が正しい値を返しているか確認
```

---

## 実装順序（推奨）

```
Day 1 (2026-01-30):
  ┌─ 09:00: PCall を Launch.lua に追加
  │  └─ PLoadModule を Launch.lua に追加
  │  └─ テスト実行
  │
  ├─ 11:00: SetMainObject (C) を実装
  │  └─ sg_callbacks.c 作成
  │  └─ CMakeLists.txt に追加
  │  └─ ビルド
  │
  ├─ 13:00: メインループに統合
  │  └─ RunMainLoop() に run_callback() 追加
  │
  └─ 15:00: MVP テスト実行
     └─ 全テスト PASS → 完了

Day 2 (2026-01-31):
  ├─ 09:00: Merchant がテスト実行開始
  ├─ 問題発見時: 修正・再ビルド
  └─ 完了
```

---

## ファイル一覧（変更・新規作成）

### 新規作成

- ✨ `/Users/kokage/national-operations/pob2macos/src/sg_callbacks.c`

### 修正

- 📝 `/Users/kokage/national-operations/pob2macos/CMakeLists.txt` (sg_callbacks.c 追加)
- 📝 `/Users/kokage/national-operations/pob2macos/src/Launch.lua` (PCall, PLoadModule 追加)
- 📝 `/Users/kokage/national-operations/pob2macos/src/main.c` (RunMainLoop に run_callback 統合)

---

## 成功判定

### コンパイル

```bash
$ cd /Users/kokage/national-operations/pob2macos/build
$ cmake ..
$ make

# 期待結果
# [100%] Built target pob2macos
# (警告なし)
```

### テスト

```bash
$ cd /Users/kokage/national-operations/pob2macos/build
$ ./pob2macos --test-stage1

# 期待結果
# Stage 1 Test: All checks passed!
# MVP Test: 12/12 PASS
```

### MVP テスト

```bash
$ cd /Users/kokage/national-operations/pob2macos
$ make test

# 期待結果
# Test 1: RenderInit ... PASS
# Test 2: SetWindowTitle ... PASS
# ... (全 12 テスト)
# Total: 12/12 PASS
```

---

## 参考リンク

### 仕様書

- 詳細仕様: `/Users/kokage/national-operations/claudecode01/memory/sage_phase7_callback_spec.md`

### 元ソース

- PoB2 Launch.lua: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua`
- PoB2 HeadlessWrapper.lua: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/HeadlessWrapper.lua`

---

**質問がある場合**: Sage に相談してください
**問題が発生した場合**: Mayor にエスカレート
**完了時**: Merchant へ引き継ぎ

---

**更新日**: 2026-01-29
**対象**: Artisan (実装者)
**ステータス**: 準備完了 → 実装待機
