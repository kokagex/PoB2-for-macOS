# Phase 7 - Sage Callback Mechanism Specification Report
## PoB2 コールバック機構の詳細設計仕様書 + Artisan 向け実装ガイド

**作成日**: 2026-01-29
**分析対象**: PathOfBuilding-PoE2-dev (Launch.lua, HeadlessWrapper.lua)
**対象読者**: Artisan (実装者), Paladin (セキュリティレビュー), Merchant (テスター)
**状態**: 準備完了 → Artisan 実装待機中

---

## 目次

1. [PoB2 コールバック機構の概要](#poб2-コールバック機構の概要)
2. [SetMainObject - メイン UI オブジェクト登録](#setmainobject---メイン-ui-オブジェクト登録)
3. [PCall - 保護付き関数呼び出し](#pcall---保護付き関数呼び出し)
4. [PLoadModule - 保護付きモジュール読み込み](#ploadmodule---保護付きモジュール読み込み)
5. [メインループ統合設計](#メインループ統合設計)
6. [コールバック実行タイミング](#コールバック実行タイミング)
7. [エラーハンドリング機構](#エラーハンドリング機構)
8. [Artisan 向け C 実装仕様](#artisan-向け-c-実装仕様)
9. [テストシナリオ](#テストシナリオ)

---

## PoB2 コールバック機構の概要

### 概念図

```
┌─────────────────────────────────────────────────────────┐
│ SetMainObject(launch)                                   │
│  └─→ メイン UI オブジェクト登録                          │
│      launch = {                                          │
│        OnInit(),     -- 初期化時                        │
│        OnFrame(),    -- 毎フレーム                      │
│        OnKeyDown(), -- キー押下時                       │
│        OnKeyUp(),   -- キー解放時                       │
│        OnChar(),    -- 文字入力時                       │
│        CanExit(),   -- 終了可能判定                     │
│        OnExit(),    -- 終了処理時                       │
│      }                                                   │
└─────────────────────────────────────────────────────────┘
       ↓ C フレームワーク が periodically call
┌─────────────────────────────────────────────────────────┐
│ メインループ                                             │
│  while not terminated:                                   │
│    OnInit()     ← 1回目のフレームで実行                  │
│    OnFrame()    ← 毎フレーム実行                         │
│    OnKeyDown()  ← キー押下イベント                      │
│    OnKeyUp()    ← キー解放イベント                      │
│    OnChar()     ← 文字入力イベント                      │
│    CanExit()    ← 終了前に実行（確認用）                │
│    OnExit()     ← 終了処理                              │
└─────────────────────────────────────────────────────────┘
```

### Phase 7-P1 実装必須 API（3個）

| # | API | 優先度 | 概要 |
|---|-----|--------|------|
| 1 | **SetMainObject** | CRITICAL | メイン UI オブジェクト登録 |
| 2 | **PCall** | CRITICAL | 保護付き関数呼び出し |
| 3 | **PLoadModule** | CRITICAL | 保護付きモジュール読み込み |

---

## SetMainObject - メイン UI オブジェクト登録

### 概要

Launch.lua の `launch` オブジェクトを C フレームワークに登録。フレームワークがこのオブジェクトのメソッドをイベント駆動で呼び出す。

### PoB2 使用例（Launch.lua L16）

```lua
launch = { }
SetMainObject(launch)
```

### Lua の実装（HeadlessWrapper.lua より）

```lua
local mainObject
function SetMainObject(obj)
    mainObject = obj
end

function runCallback(name, ...)
    if callbackTable[name] then
        return callbackTable[name](...)
    elseif mainObject and mainObject[name] then
        return mainObject[name](mainObject, ...)
    end
end
```

### C シグネチャ

```c
/**
 * SimpleGraphic Lua バインディング用関数
 * メイン UI オブジェクト（launch）をフレームワークに登録
 *
 * @param obj: Lua テーブル (launch オブジェクト)
 */
void SetMainObject(lua_State *L)
{
    // Lua スタック:
    // [-1]: obj (メイン UI オブジェクト)

    // C バインディング実装例:
    lua_setfield(L, LUA_REGISTRYINDEX, "mainObject");
    // mainObject をレジストリに格納
    // 後のフレームループでこれを参照して callbacks を呼び出す
}
```

### 仕様詳細

#### 登録オブジェクト構造

```lua
launch = {
    -- [内部フィールド]
    devMode = false,           -- デベロッパーモード
    installedMode = false,     -- インストール済みモード
    versionNumber = "?",       -- バージョン番号
    main = nil,                -- メイン UI ハンドル
    subScripts = {},           -- サブスクリプト管理

    -- [コールバックメソッド] (フレームワークが呼び出し)
    OnInit = function(self) ... end,
    OnFrame = function(self) ... end,
    OnKeyDown = function(self, key, doubleClick) ... end,
    OnKeyUp = function(self, key) ... end,
    OnChar = function(self, char) ... end,
    CanExit = function(self) ... end,
    OnExit = function(self) ... end,

    -- [イベントハンドラ補助]
    OnSubFinished = function(self, id, ...) ... end,
    OnSubError = function(self, id, errMsg) ... end,
    OnSubCall = function(self, func, ...) ... end,
}
```

#### 戻り値

なし（コールバック用に登録のみ）

#### エラーハンドリング

```lua
-- SetMainObject のエラーチェック (Lua側)
if type(obj) ~= "table" then
    error("SetMainObject requires a table argument")
end
```

### 実装上の注意点

1. **参照の永続化**: mainObject はフレームワークが終了まで参照する必要があるため、**Lua GC の対象外に保護** する必要がある
2. **レジストリ保存**: Lua の REGISTRY テーブルに保存し、フレーム処理中に参照を取得する
3. **メソッド存在確認**: 呼び出し前に メソッドの存在を確認（launch.OnFrame など）

---

## PCall - 保護付き関数呼び出し

### 概要

Lua の `pcall()` をラップして、エラー時に例外ではなく戻り値でエラーメッセージを返す。

### PoB2 使用例（Launch.lua L77, L91, L111 等 - 非常に多数）

```lua
-- 例1: 戻り値なし関数呼び出し
errMsg = PCall(self.main.Init, self.main)
if errMsg then
    self:ShowErrMsg("Error loading main script: %s", errMsg)
end

-- 例2: 戻り値あり関数呼び出し
errMsg, ret = PCall(self.main.CanExit, self.main)
if errMsg then
    self:ShowErrMsg("In 'CanExit': %s", errMsg)
    return false
else
    return ret
end

-- 例3: 複数の引数を渡す
errMsg = PCall(self.main.OnKeyDown, self.main, key, doubleClick)
```

### Lua の実装（HeadlessWrapper.lua L143-151）

```lua
function PCall(func, ...)
    local ret = { pcall(func, ...) }
    if ret[1] then
        -- pcall が成功した場合
        table.remove(ret, 1)  -- 成功フラグを削除
        return nil, unpack(ret)  -- (nil, func_return1, func_return2, ...)
    else
        -- pcall が失敗した場合（例外発生）
        return ret[2]  -- (error_message)
    end
end
```

### 戻り値仕様

```
PCall(func, self, ...)
  ↓
成功時: (nil, return1, return2, ...)
        └─ 第1戻り値: nil (成功を示す)
           第2以降: 関数の戻り値

失敗時: (error_message)
        └─ 第1戻り値: エラーメッセージ (文字列)
           第2以降: なし
```

### 実装パターン

#### パターン1: エラーチェックのみ

```lua
local errMsg = PCall(func, obj, arg1, arg2)
if errMsg then
    print("Error:", errMsg)
end
```

#### パターン2: エラーと戻り値両方確認

```lua
local errMsg, result1, result2 = PCall(func, obj, arg1, arg2)
if errMsg then
    print("Error:", errMsg)
    return
else
    print("Success:", result1, result2)
end
```

#### パターン3: self を持つメソッド呼び出し

```lua
local errMsg = PCall(self.main.OnFrame, self.main)
-- 注: self.main.OnFrame は self パラメータを期待
-- PCall の第2引数が self になる
```

### C シグネチャ

```c
/**
 * Lua スタックの状態:
 *   入力: [-n, ... , -1] = args (func, context_self?, arg1, arg2, ...)
 *   出力: [-m, ... , -1] = results
 *
 * Protected function call wrapper using Lua's pcall
 * Returns: (error_message?) or (nil, return_values...)
 */
int lua_pcall_wrapper(lua_State *L)
{
    // スタック解析:
    // 1. 第1引数: func (Lua 関数)
    // 2. 以降: 可変長引数

    // 実装:
    // 1. func を lua_State の "main" スタックに push
    // 2. 全引数を push
    // 3. lua_pcall() 実行
    // 4. 成功時: nil + return_values を push
    // 5. 失敗時: error_message を push
}
```

### PoB2 での使用頻度

**Critical**: Launch.lua 内で 14回以上呼び出される。すべてのメインループコールバックはこれを通してエラーハンドリングされる。

### エラーメッセージ仕様

```lua
-- 例: Main.lua の Init が例外を投げた場合
errMsg, self.main = PLoadModule("Modules/Main")
if errMsg then
    self:ShowErrMsg("Error loading main script: %s", errMsg)
end
-- errMsg = "Modules/Main.lua:100: attempt to index a nil value"
```

---

## PLoadModule - 保護付きモジュール読み込み

### 概要

Lua モジュール（.lua ファイル）を読み込んで実行。PCall でラップしてエラー時に例外を投げない。

### PoB2 使用例（Launch.lua L71）

```lua
errMsg, self.main = PLoadModule("Modules/Main")
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

### Lua の実装（HeadlessWrapper.lua L132-141）

```lua
function PLoadModule(fileName, ...)
    if not fileName:match("%.lua") then
        fileName = fileName .. ".lua"
    end
    local func, err = loadfile(fileName)
    if func then
        return PCall(func, ...)
    else
        error("PLoadModule() error loading '"..fileName.."': "..err)
    end
end
```

### 処理フロー

```
PLoadModule("Modules/Main", arg1, arg2)
  ↓
1. ファイル名に .lua 拡張子がなければ追加
   "Modules/Main" → "Modules/Main.lua"
  ↓
2. loadfile() で Lua コードをコンパイル
   func, err = loadfile("Modules/Main.lua")
  ↓
3. コンパイル成功時:
   func が Lua 関数になる
   ↓ PCall(func, arg1, arg2) でエラーハンドリング付きで実行
   ↓
4. コンパイル失敗時:
   error() で例外を投げる
  ↓
戻り値:
  成功時: (nil, module_result)
  失敗時: (error_message)
```

### 戻り値仕様

```
PLoadModule(moduleName, arg1, arg2, ...)
  ↓
成功時: (nil, module_return_value)
        └─ 第1戻り値: nil (成功)
           第2戻り値: モジュールが返す値（通常はテーブル）

失敗時: (error_message)
        └─ 第1戻り値: エラーメッセージ
```

### 実装パターン

```lua
local errMsg, main = PLoadModule("Modules/Main")
if errMsg then
    -- ロード失敗
    print("Failed to load:", errMsg)
else
    -- ロード成功
    if main then
        -- main がテーブル（モジュール）
        main:Init()
    end
end
```

### Lua 側での LoadModule との違い

| 機能 | LoadModule | PLoadModule |
|------|-----------|-----------|
| エラー時の動作 | `error()` で例外発生 | 戻り値でエラー返却 |
| 戻り値 | モジュール値のみ | (error?, module?) |
| 用途 | 正常系の想定で使用 | エラー可能性が高い場合 |
| PoB2 主要用途 | Main 関数内でのモジュール読み込み | Launch.lua での Main モジュール読み込み |

### PoB2 での使用場所

```lua
-- Launch.lua L71: Main モジュール読み込み（重要）
errMsg, self.main = PLoadModule("Modules/Main")

-- Main.lua L54-55: サブモジュール読み込み（LoadModule 使用）
self.modes["LIST"] = LoadModule("Modules/BuildList")
self.modes["BUILD"] = LoadModule("Modules/Build")
```

---

## メインループ統合設計

### メインループの実行フロー

```
┌──────────────────────────────────────────────────────────────┐
│ main() - C フレームワークのエントリポイント                  │
│ (SimpleGraphic 内で実装)                                     │
└──────────────────────────────┬───────────────────────────────┘
                               ↓
                      ┌─────────────────┐
                      │ RenderInit()    │
                      │ (Lua 呼び出し)  │
                      └────────┬────────┘
                               ↓
                      ┌─────────────────┐
                      │ SetMainObject() │
                      │ (Lua 呼び出し)  │
                      └────────┬────────┘
                               ↓
              ┌────────────────────────────────────┐
              │ RunMainLoop()                      │
              │ (C フレームワーク内部ループ)      │
              │                                    │
              │  while (!glfwWindowShouldClose()) │
              │  {                                 │
              │    [フレーム処理 - 以下参照]       │
              │  }                                 │
              └────────────────────────────────────┘
                               ↓
                    [1フレームの処理内容]
                               ↓
         ┌─────────────────────────────────┐
         │ 1. イベント処理                 │
         │    - ウィンドウイベント取得     │
         │    - キーボード・マウス入力    │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 2. launch:OnFrame()             │
         │    (毎フレーム実行)              │
         │                                  │
         │  runCallback("OnFrame")          │
         │    └─→ launch:OnFrame()          │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 3. launch:OnKeyDown(key, double)│
         │    (キー押下イベント)            │
         │                                  │
         │  for each keypress event:       │
         │    runCallback("OnKeyDown", ...) │
         │      └─→ launch:OnKeyDown()      │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 4. launch:OnKeyUp(key)          │
         │    (キー解放イベント)            │
         │                                  │
         │  for each keyup event:          │
         │    runCallback("OnKeyUp", ...)   │
         │      └─→ launch:OnKeyUp()        │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 5. launch:OnChar(char)          │
         │    (文字入力イベント)            │
         │                                  │
         │  for each char event:           │
         │    runCallback("OnChar", ...)    │
         │      └─→ launch:OnChar()         │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 6. 描画処理                     │
         │    - glClear()                  │
         │    - launch が描画命令実行      │
         │    - glfwSwapBuffers()          │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ 7. launch:CanExit() チェック   │
         │    (終了可能か確認)              │
         │                                  │
         │  if runCallback("CanExit"):      │
         │    ↓ ループ終了へ                │
         │  else:                          │
         │    ↓ ループ継続                 │
         └──────────┬──────────────────────┘
                    ↓
              (ループ繰り返し)
                    ↓
         ┌─────────────────────────────────┐
         │ 8. launch:OnExit()              │
         │    (終了処理)                   │
         │                                  │
         │  runCallback("OnExit")           │
         │    └─→ launch:OnExit()           │
         └──────────┬──────────────────────┘
                    ↓
         ┌─────────────────────────────────┐
         │ Shutdown()                      │
         │ (リソース解放)                  │
         └─────────────────────────────────┘
```

### コールバック呼び出しの C 実装例

```c
// RunMainLoop() の疑似コード

void RunMainLoop(lua_State *L) {
    while (!glfwWindowShouldClose(window)) {
        // 1. イベント処理
        glfwPollEvents();

        // 2. キー入力取得
        for (each key event) {
            if (key_down) {
                runCallback(L, "OnKeyDown", key, doubleClick);
            } else if (key_up) {
                runCallback(L, "OnKeyUp", key);
            }
        }

        // 3. 文字入力イベント
        for (each char input) {
            runCallback(L, "OnChar", char);
        }

        // 4. フレーム更新
        runCallback(L, "OnFrame");

        // 5. 描画
        glClear(GL_COLOR_BUFFER_BIT);
        // (launch が OpenGL コマンドで描画)
        glfwSwapBuffers(window);

        // 6. 終了判定
        bool canExit;
        if (!runCallback(L, "CanExit", &canExit) || !canExit) {
            break;
        }
    }

    // 終了処理
    runCallback(L, "OnExit");
    glShutdown();
}
```

---

## コールバック実行タイミング

### Phase 6 完成による既知の実行タイミング

#### 1. OnInit() - 初期化（1回のみ）

```lua
-- Launch.lua L20-87
function launch:OnInit()
    self.devMode = false
    self.installedMode = false

    -- first.run ファイルチェック
    local firstRunFile = io.open("first.run", "r")
    if firstRunFile then
        -- インストール後の初期化処理
        ConClear()
        ConPrintf("Please wait while we complete installation...\n")
        local updateMode, errMsg = LoadModule("UpdateCheck")
        if updateMode ~= "none" then
            self:ApplyUpdate(updateMode)
            return
        end
    end

    -- manifest.xml 読み込み
    local xml = require("xml")
    local localManXML = xml.LoadXMLFile("manifest.xml")
    -- (バージョン情報抽出)

    -- Main モジュール読み込み
    ConPrintf("Loading main script...")
    local errMsg
    errMsg, self.main = PLoadModule("Modules/Main")
    if errMsg then
        self:ShowErrMsg("Error loading main script: %s", errMsg)
    end

    -- バックグラウンド更新チェック開始
    if not self.devMode then
        self:CheckForUpdate(true)
    end
end
```

**タイミング**: アプリケーション起動直後、最初のフレームの開始前

**重要な機能**:
- Lua モジュール（Main.lua）の読み込み
- 初期状態の設定
- バックグラウンドタスク開始

#### 2. OnFrame() - フレーム更新（毎フレーム）

```lua
-- Launch.lua L108-136
function launch:OnFrame()
    if self.main then
        if self.main.OnFrame then
            local errMsg = PCall(self.main.OnFrame, self.main)
            if errMsg then
                self:ShowErrMsg("In 'OnFrame': %s", errMsg)
            end
        end
    end

    -- デバッグモード Alt キー状態
    self.devModeAlt = self.devMode and IsKeyDown("ALT")

    -- UI 描画
    SetDrawLayer(1000)
    SetViewport()

    -- プロンプト表示（エラーメッセージなど）
    if self.promptMsg then
        local r, g, b = unpack(self.promptCol)
        self:DrawPopup(r, g, b, "^0%s", self.promptMsg)
    end

    -- 再起動表示
    if self.doRestart then
        local screenW, screenH = GetScreenSize()
        SetDrawColor(0, 0, 0, 0.75)
        DrawImage(nil, 0, 0, screenW, screenH)
        SetDrawColor(1, 1, 1)
        DrawString(0, screenH/2, "CENTER", 24, "FIXED", self.doRestart)
        Restart()
    end

    -- 12 時間ごとの更新チェック
    if not self.devMode and (GetTime() - self.lastUpdateCheck) > 1000*60*60*12 then
        self:CheckForUpdate(true)
    end
end
```

**タイミング**: メインループの各イテレーション（毎フレーム、通常 60 FPS）

**重要な機能**:
- メイン UI フレーム更新（Main.lua L54: main:OnFrame()）
- エラーメッセージ表示
- 定期的な更新チェック
- 再起動処理

#### 3. OnKeyDown(key, doubleClick) - キー押下

```lua
-- Launch.lua L138-170
function launch:OnKeyDown(key, doubleClick)
    if key == "F5" and self.devMode then
        self.doRestart = "Restarting..."
    elseif key == "F6" and self.devMode then
        -- メモリ使用量表示
        local before = collectgarbage("count")
        collectgarbage("collect")
        ConPrintf("%dkB => %dkB", before, collectgarbage("count"))
    elseif key == "PAUSE" and self.devMode and profiler then
        -- プロファイラ制御
        if profiling then
            profiler.stop()
        else
            profiler.start()
        end
    elseif key == "u" and IsKeyDown("CTRL") then
        -- Ctrl+U: 更新確認
        if not self.devMode then
            self:CheckForUpdate()
        end
    elseif key == "PRINTSCREEN" and IsKeyDown("CTRL") then
        -- Ctrl+PrintScreen: スクリーンショット
        TakeScreenshot()
    elseif self.promptMsg then
        -- プロンプト表示中はプロンプト処理
        self:RunPromptFunc(key)
    else
        -- メイン UI にイベント転送
        if self.main and self.main.OnKeyDown then
            local errMsg = PCall(self.main.OnKeyDown, self.main, key, doubleClick)
            if errMsg then
                self:ShowErrMsg("In 'OnKeyDown': %s", errMsg)
            end
        end
    end
end
```

**タイミング**: キー押下イベント発生時

**引数**:
- `key`: キー名 (例: "a", "SPACE", "RETURN", "CTRL", "ALT", "SHIFT")
- `doubleClick`: ダブルクリック判定 (論理値)

#### 4. OnKeyUp(key) - キー解放

```lua
-- Launch.lua L172-181
function launch:OnKeyUp(key)
    if not self.promptMsg then
        if self.main and self.main.OnKeyUp then
            local errMsg = PCall(self.main.OnKeyUp, self.main, key)
            if errMsg then
                self:ShowErrMsg("In 'OnKeyUp': %s", errMsg)
            end
        end
    end
end
```

**タイミング**: キー解放イベント発生時

#### 5. OnChar(key) - 文字入力

```lua
-- Launch.lua L183-194
function launch:OnChar(key)
    if self.promptMsg then
        self:RunPromptFunc(key)
    else
        if self.main and self.main.OnChar then
            local errMsg = PCall(self.main.OnChar, self.main, key)
            if errMsg then
                self:ShowErrMsg("In 'OnChar': %s", errMsg)
            end
        end
    end
end
```

**タイミング**: 文字入力イベント発生時（キーボード入力）

#### 6. CanExit() - 終了可能判定

```lua
-- Launch.lua L89-100
function launch:CanExit()
    if self.main and self.main.CanExit and not self.promptMsg then
        local errMsg, ret = PCall(self.main.CanExit, self.main)
        if errMsg then
            self:ShowErrMsg("In 'CanExit': %s", errMsg)
            return false
        else
            return ret
        end
    end
    return true
end
```

**タイミング**: メインループが終了を判定する際（ウィンドウクローズボタン押下時など）

**戻り値**: 終了可能な場合は `true`、保存待ちなど終了できない場合は `false`

#### 7. OnExit() - 終了処理

```lua
-- Launch.lua L102-106
function launch:OnExit()
    if self.main and self.main.Shutdown then
        PCall(self.main.Shutdown, self.main)
    end
end
```

**タイミング**: アプリケーション終了前、最後に実行

**重要な機能**:
- Main の Shutdown() メソッド呼び出し（リソース解放）
- 設定ファイル保存

---

## エラーハンドリング機構

### PoB2 の 3 層エラーハンドリング

```
┌─────────────────────────────────────────┐
│ Lua エラー発生                          │
│ (例: nil table access)                  │
└────────────────────┬────────────────────┘
                     ↓
         ┌───────────────────────┐
         │ pcall() がエラー捕捉  │
         │ (Lua 標準機能)        │
         └────────────┬──────────┘
                      ↓
         ┌───────────────────────┐
         │ PCall() がエラー変換   │
         │ (Lua ラッパー)        │
         │                       │
         │ (error_msg)           │
         │ ↓ 文字列として返却    │
         └────────────┬──────────┘
                      ↓
         ┌───────────────────────┐
         │ Launch.lua が処理     │
         │ (Framework 層)        │
         │                       │
         │ if errMsg then        │
         │   self:ShowErrMsg()   │
         │ end                   │
         └────────────┬──────────┘
                      ↓
         ┌───────────────────────┐
         │ UI に エラー表示       │
         │ (ユーザー通知)        │
         └───────────────────────┘
```

### 実装例

#### 例1: OnFrame エラー

```lua
-- Launch.lua L110-114
if self.main.OnFrame then
    local errMsg = PCall(self.main.OnFrame, self.main)
    if errMsg then
        self:ShowErrMsg("In 'OnFrame': %s", errMsg)
    end
end
```

**流れ**:
1. Main.lua の OnFrame() 実行
2. エラー発生 (例: bad argument to 'DrawString')
3. PCall が例外を捕捉
4. エラーメッセージ文字列を返す
5. launch:ShowErrMsg() でユーザーに通知

#### 例2: Module ロードエラー

```lua
-- Launch.lua L71-79
errMsg, self.main = PLoadModule("Modules/Main")
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

**流れ**:
1. PLoadModule で Main.lua をロード
2. ロード失敗 → エラーメッセージ返却
3. もしロード成功して Init メソッド存在 → Init() 実行
4. Init() でエラー → PCall が捕捉
5. ShowErrMsg() でユーザー通知

### エラーメッセージフォーマット

```lua
function launch:ShowErrMsg(fmt, ...)
    if not self.promptMsg then
        local version = self.versionNumber and
            "^8v"..self.versionNumber..(self.versionBranch and " "..self.versionBranch or "")
            or ""
        self:ShowPrompt(
            1, 0, 0,  -- 赤色
            "^1Error:\n\n^0"..string.format(fmt, ...)
            .."\n"..version.."\n^0Press Enter/Escape to dismiss, or F5 to restart the application."
            .."\nPress CTRL + C to copy error text."
        )
    end
end
```

**特徴**:
- エラーメッセージを赤色で表示
- バージョン情報も表示
- ユーザーに複数の選択肢を提示
- エラーテキストをクリップボードにコピー可能

---

## Artisan 向け C 実装仕様

### 実装対象 API（Phase 7-P1）

#### 1. SetMainObject

**ファイル**: `src/sg_callbacks.c` (新規作成)

**C 実装**:

```c
#include "simplegraphic.h"
#include <lua.h>
#include <lauxlib.h>

// グローバル変数: メイン UI オブジェクト参照
static lua_State *g_lua = NULL;
static int g_mainObject_ref = LUA_NOREF;

/**
 * SetMainObject(obj: table) -> void
 *
 * メイン UI オブジェクト (launch テーブル) をフレームワークに登録
 * フレームワークのメインループがこのオブジェクトのメソッドを呼び出す
 */
int lua_SetMainObject(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);

    // 古い参照を解放
    if (g_mainObject_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, g_mainObject_ref);
    }

    // 新しい参照を保存
    lua_pushvalue(L, 1);  // mainObject を push
    g_mainObject_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    g_lua = L;

    return 0;  // 戻り値なし
}

/**
 * 内部: メインループからのコールバック呼び出し
 * func_name: "OnInit", "OnFrame", "OnKeyDown" など
 * ... : 可変長引数
 */
int runCallback(const char *func_name, ...)
{
    if (g_mainObject_ref == LUA_NOREF) {
        return 0;  // mainObject が未登録
    }

    // レジストリから mainObject を取得
    lua_rawgeti(g_lua, LUA_REGISTRYINDEX, g_mainObject_ref);

    // mainObject[func_name] を取得
    lua_getfield(g_lua, -1, func_name);

    if (lua_isfunction(g_lua, -1)) {
        // メソッド呼び出し
        lua_pushvalue(g_lua, -2);  // self = mainObject

        // 可変長引数をスタックに push
        va_list args;
        va_start(args, func_name);
        // ... (引数の型に応じて push)
        va_end(args);

        // lua_pcall() で実行
        int result = lua_pcall(g_lua, nargs + 1, LUA_MULTRET, 0);

        lua_pop(g_lua, 1);  // mainObject をポップ

        return result;
    }

    lua_pop(g_lua, 2);  // mainObject, func をポップ
    return 0;
}
```

**Lua FFI 登録**:

```c
// simple_graphic_module.c に追加
static const luaL_Reg simplegraphic_funcs[] = {
    { "SetMainObject", lua_SetMainObject },
    // ... 他の関数
    { NULL, NULL }
};

int luaopen_simplegraphic(lua_State *L)
{
    luaL_newlib(L, simplegraphic_funcs);
    return 1;
}
```

---

#### 2. PCall

**実装** (Lua FFI なし - Lua 標準 pcall をラップ)

```lua
-- Lua モジュール: simplegraphic.lua または Launch.lua に追加
function PCall(func, ...)
    local ret = { pcall(func, ...) }
    if ret[1] then
        table.remove(ret, 1)
        return nil, unpack(ret)
    else
        return ret[2]
    end
end
```

**重要**: これは Lua 実装でよい。C 実装は不要。

**理由**:
- pcall() は Lua VM の基本機能
- パフォーマンスに大きな影響なし
- Lua 側でも十分高速

---

#### 3. PLoadModule

**実装** (Lua FFI なし)

```lua
function PLoadModule(fileName, ...)
    if not fileName:match("%.lua") then
        fileName = fileName .. ".lua"
    end

    -- ファイル検索: GetScriptPath() + fileName
    local scriptPath = GetScriptPath()
    local fullPath = scriptPath .. "/" .. fileName

    local func, err = loadfile(fullPath)
    if func then
        return PCall(func, ...)
    else
        return err
    end
end
```

**注意**: GetScriptPath() は Phase 6 で実装済み

---

### メインループ統合実装

**ファイル**: `src/main.c` (既存を修正)

```c
#include "simplegraphic.h"
#include <lua.h>

extern int runCallback(const char *func_name, ...);

void RunMainLoop(lua_State *L)
{
    // OnInit を呼び出し
    runCallback("OnInit");

    while (!glfwWindowShouldClose(window)) {
        // イベント処理
        glfwPollEvents();

        // キー入力処理
        processKeyboardInput(L);  // OnKeyDown, OnKeyUp, OnChar

        // フレーム更新
        runCallback("OnFrame");

        // 描画
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        // (Lua コードが描画命令を実行)

        glfwSwapBuffers(window);

        // 終了判定
        bool canExit;
        if (!runCallback("CanExit", &canExit) || !canExit) {
            break;
        }
    }

    // OnExit を呼び出し
    runCallback("OnExit");

    glShutdown();
}
```

---

### コールバック呼び出しの詳細実装

```c
/**
 * コールバック呼び出し（可変長引数版）
 */
int runCallback_OnKeyDown(const char *key, int doubleClick)
{
    if (g_mainObject_ref == LUA_NOREF) return 0;

    // レジストリから mainObject 取得
    lua_rawgeti(g_lua, LUA_REGISTRYINDEX, g_mainObject_ref);

    // OnKeyDown メソッド取得
    lua_getfield(g_lua, -1, "OnKeyDown");

    if (lua_isfunction(g_lua, -1)) {
        lua_pushvalue(g_lua, -2);  // self = mainObject
        lua_pushstring(g_lua, key);
        lua_pushboolean(g_lua, doubleClick);

        // pcall で実行
        int result = lua_pcall(g_lua, 3, 0, 0);
        if (result != LUA_OK) {
            fprintf(stderr, "Error in OnKeyDown: %s\n", lua_tostring(g_lua, -1));
            lua_pop(g_lua, 1);
        }
    }

    lua_pop(g_lua, 2);  // OnKeyDown, mainObject をポップ
    return 0;
}
```

---

## テストシナリオ

### T7-S1: SetMainObject 機能テスト

**目的**: メイン UI オブジェクト登録が正常に機能するか確認

**テストシーケンス**:

```lua
-- test_phase7_callbacks.lua

-- 1. SetMainObject テスト
launch = {
    initCalled = false,
    frameCalled = false,
    keyDownCalled = false,
}

function launch:OnInit()
    self.initCalled = true
    ConPrintf("OnInit called")
end

function launch:OnFrame()
    self.frameCalled = true
end

function launch:OnKeyDown(key, doubleClick)
    self.keyDownCalled = true
    ConPrintf("Key down: %s (double=%s)", key, tostring(doubleClick))
end

SetMainObject(launch)

-- 2. SetMainObject が正常に登録されたか確認
-- (C フレームワークが自動的にコールバックを呼び出す)

-- 期待結果:
-- - launch.initCalled == true
-- - launch.frameCalled == true
-- - キー押下時に launch.keyDownCalled == true
```

**成功判定基準**:
- SetMainObject が引数を受け入れられる
- C フレームワークが launch:OnInit() を呼び出す
- C フレームワークが launch:OnFrame() を毎フレーム呼び出す
- C フレームワークが launch:OnKeyDown() をキー押下時に呼び出す

---

### T7-S2: PCall エラーハンドリングテスト

**目的**: PCall が例外を正しくキャッチし、エラーメッセージを返すか確認

**テストシーケンス**:

```lua
-- test_pcall.lua

-- 1. 正常系: エラーなし
local function successFunc(x, y)
    return x + y
end

local err, result = PCall(successFunc, 10, 20)
assert(err == nil, "Expected no error")
assert(result == 30, "Expected result = 30, got " .. tostring(result))
ConPrintf("PASS: PCall success case")

-- 2. エラー系: nil インデックス
local function errorFunc()
    local t = nil
    return t.field  -- Error: attempt to index a nil value
end

local err = PCall(errorFunc)
assert(err ~= nil, "Expected error message")
assert(type(err) == "string", "Expected error to be string")
ConPrintf("PASS: PCall error case - %s", err)

-- 3. 複数戻り値
local function multiReturn()
    return "a", "b", "c"
end

local err, a, b, c = PCall(multiReturn)
assert(err == nil and a == "a" and b == "b" and c == "c", "Multi-return failed")
ConPrintf("PASS: PCall multi-return case")
```

**成功判定基準**:
- 正常終了時: (nil, result1, result2, ...) を返す
- エラー発生時: (error_message) を返す
- 複数戻り値の場合も正しく処理される

---

### T7-S3: PLoadModule ロードテスト

**目的**: PLoadModule が Lua ファイルを正しく読み込み、エラーハンドリングするか確認

**テストシーケンス**:

```lua
-- test_ploadmodule.lua

-- 1. 正常なモジュール読み込み
local err, module = PLoadModule("test_module")
if err then
    ConPrintf("FAIL: Failed to load module: %s", err)
else
    assert(module ~= nil, "Expected module to be returned")
    ConPrintf("PASS: PLoadModule success")
end

-- 2. ファイルが見つからない場合
local err, module = PLoadModule("nonexistent_module")
assert(err ~= nil, "Expected error for nonexistent file")
ConPrintf("PASS: PLoadModule correctly handles missing files")

-- 3. モジュールがテーブルを返す
local err, myModule = PLoadModule("Modules/Common")
assert(err == nil and type(myModule) == "table", "Expected module table")
ConPrintf("PASS: PLoadModule returns table module")
```

**成功判定基準**:
- 有効なファイルを読み込める
- ファイルが見つからない場合、エラーを返す
- モジュールが返す値を正しく返す

---

### T7-S4: メインループコールバック統合テスト

**目的**: C メインループが Lua コールバックを正しい順序で呼び出すか確認

**テストシーケンス**:

```lua
-- test_mainloop_callbacks.lua

local callOrder = {}

launch = {}

function launch:OnInit()
    table.insert(callOrder, "OnInit")
    ConPrintf("1. OnInit called")
    self.frameCount = 0
end

function launch:OnFrame()
    self.frameCount = (self.frameCount or 0) + 1
    if self.frameCount == 1 then
        table.insert(callOrder, "OnFrame")
        ConPrintf("2. OnFrame called (frame 1)")
    end
    if self.frameCount == 3 then
        -- 3 フレーム後に終了
        self.shouldExit = true
    end
end

function launch:OnKeyDown(key, doubleClick)
    ConPrintf("OnKeyDown: %s", key)
    table.insert(callOrder, "OnKeyDown")
end

function launch:CanExit()
    return self.shouldExit or false
end

function launch:OnExit()
    table.insert(callOrder, "OnExit")
    ConPrintf("3. OnExit called")
end

SetMainObject(launch)

-- メインループが以下の順序で呼び出すことを期待:
-- 1. OnInit (1回)
-- 2. OnFrame (毎フレーム)
-- 3. OnKeyDown (キー押下時)
-- 4. CanExit (毎フレーム)
-- 5. OnExit (終了時)

-- 期待される callOrder:
-- ["OnInit", "OnFrame", "OnExit"]
```

**成功判定基準**:
- OnInit が最初に呼ばれる
- OnFrame が毎フレーム呼ばれる
- OnExit が最後に呼ばれる
- コールバック中のエラーが ShowErrMsg で表示される

---

## 実装チェックリスト（Artisan 向け）

### Phase 7-P1 実装（必須 3 API）

- [ ] SetMainObject
  - [ ] Lua FFI 登録完了
  - [ ] mainObject レジストリ保存機能
  - [ ] 参照カウント管理実装
  - [ ] テスト実行結果: PASS

- [ ] PCall
  - [ ] Lua 関数としてロード完了
  - [ ] pcall ラッパー実装
  - [ ] エラーメッセージ変換
  - [ ] テスト実行結果: PASS

- [ ] PLoadModule
  - [ ] Lua 関数としてロード完了
  - [ ] GetScriptPath() 統合
  - [ ] ファイル名処理（.lua 拡張子）
  - [ ] PCall との連携
  - [ ] テスト実行結果: PASS

### メインループ統合

- [ ] RunMainLoop() 実装
  - [ ] OnInit() 呼び出し
  - [ ] フレームループ実装
  - [ ] イベント処理
  - [ ] OnKeyDown(), OnKeyUp(), OnChar() 統合
  - [ ] CanExit() チェック
  - [ ] OnExit() 呼び出し

- [ ] エラーハンドリング
  - [ ] コールバック内のエラーをキャッチ
  - [ ] ShowErrMsg() への転送
  - [ ] スタックトレース保存

- [ ] MVP テスト
  - [ ] 全 12 テスト PASS
  - [ ] 新規実装でテスト追加実行
  - [ ] セキュリティチェック実施

---

## 技術的注記と推奨事項

### 1. Lua 参照管理

SetMainObject で mainObject を登録する場合、Lua GC によっていなくなるのを防ぐため、**LUA_REGISTRYINDEX に参照を保存**する必要があります。

```c
// ✓ 正しい実装
lua_pushvalue(L, 1);  // arg をコピー
int ref = luaL_ref(L, LUA_REGISTRYINDEX);  // レジストリに保存

// ✗ 間違った実装
lua_getfield(L, 1, "field");  // 一時的な参照
// (GC の対象になるため危険)
```

### 2. pcall エラーハンドリング

PCall は pcall の戻り値フォーマットを変換します。注意すべき点：

```lua
-- 正常系
local success, result1, result2 = pcall(func, arg)
if success then
    print(result1, result2)
end

-- PCall を使った場合
local err, result1, result2 = PCall(func, arg)
if err then
    print("Error:", err)
else
    print(result1, result2)
end
```

### 3. メインループのパフォーマンス

OnFrame() は毎フレーム呼ばれるため、重い処理は避けるべき：

```lua
-- ✓ 推奨: OnFrame() は軽い処理のみ
function launch:OnFrame()
    if self.main.OnFrame then
        PCall(self.main.OnFrame, self.main)
    end
end

-- ✗ 非推奨: OnFrame() で重い計算
function launch:OnFrame()
    local result = computeExpensiveCalculation()  -- 遅い！
end
```

### 4. コールバック中の例外処理

PCall でラップされたコールバックで例外が発生した場合、launch:ShowErrMsg() で UI に表示されます。この時点でメインループは継続しているため、**追加のエラーが発生しないよう注意**が必要です。

---

## GetScriptPath と GetRuntimePath の仕様

### 重要性

PLoadModule, LaunchSubScript が正しくモジュールを検索するために必須。

### PoB2 での使用パターン

#### GetScriptPath()

```lua
-- Launch.lua L81 (Main.lua でのデバイスモード判定)
if launch.devMode or (GetScriptPath() == GetRuntimePath() and not launch.installedMode) then
    self.userPath = GetScriptPath().."/"
end

-- Modules/Main.lua
self.userPath = GetScriptPath().."/"

-- LaunchSubScript の imports
LaunchSubScript(code, "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir", ...)
```

#### GetRuntimePath()

```lua
-- Launch.lua L325 (Update 適用時)
SpawnProcess(GetRuntimePath()..'/Update', 'UpdateApply.lua Update/opFileRuntime.txt')

-- Launch.lua L344 (更新チェック)
LaunchSubScript(update:read("*a"), "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir", ...)
```

### macOS ディレクトリ構造

```
~/Downloads/PathOfBuilding-PoE2-dev/
  ├─ src/                              ← GetScriptPath() はここ
  │  ├─ Launch.lua
  │  ├─ Modules/
  │  │  ├─ Main.lua
  │  │  ├─ Common.lua
  │  │  ├─ Build.lua
  │  │  └─ ...
  │  ├─ UpdateCheck.lua
  │  └─ ...
  │
  └─ build/                             ← GetRuntimePath() は実行ファイル位置
     ├─ pob2macos (実行ファイル)
     ├─ libsimplegraphic.a
     ├─ Update/                         ← Update サブプロセス
     │  ├─ UpdateApply.lua
     │  └─ ...
     └─ ...
```

### 仕様詳細

#### GetScriptPath() - スクリプト（ソース）ディレクトリ

**戻り値**: スクリプト（Modules など）が置かれているディレクトリのパス

```c
// 推奨実装
char *GetScriptPath() {
    // 方法1: コンパイル時に定義
    return SCRIPT_PATH;  // 例: "/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src"

    // 方法2: argv[0] から推測
    // executable = /Users/kokage/national-operations/pob2macos/build/pob2macos
    // script_path = /Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src
}
```

**macOS での推奨実装**:

```c
const char *GetScriptPath() {
    static char path[PATH_MAX] = {0};
    if (path[0] == 0) {
        // ビルド時に CMakeLists.txt で定義
        #ifdef POB2_SCRIPT_PATH
            strcpy(path, POB2_SCRIPT_PATH);
        #else
            // デフォルト（開発モード）
            strcpy(path, "../src");
        #endif
    }
    return path;
}
```

**CMakeLists.txt での定義**:

```cmake
# CMakeLists.txt
set(SCRIPT_PATH "${POB2_SOURCE_DIR}/src")
add_compile_definitions(POB2_SCRIPT_PATH="${SCRIPT_PATH}")
```

#### GetRuntimePath() - ランタイムディレクトリ

**戻り値**: 実行ファイル（pob2macos）と同じディレクトリのパス

```c
// 推奨実装
char *GetRuntimePath() {
    static char path[PATH_MAX] = {0};
    if (path[0] == 0) {
        // 実行ファイルのディレクトリを取得
        uint32_t size = sizeof(path);
        if (_NSGetExecutablePath(path, &size) == 0) {
            // パスをディレクトリ部分のみにする
            char *lastSlash = strrchr(path, '/');
            if (lastSlash) {
                *lastSlash = '\0';
            }
        }
    }
    return path;
}
```

**macOS 専用注意**:

```c
// macOS では以下を使用
#include <mach-o/dyld.h>

const char *GetRuntimePath() {
    static char path[PATH_MAX] = {0};
    if (path[0] == 0) {
        uint32_t size = sizeof(path);
        _NSGetExecutablePath(path, &size);

        // ディレクトリ部分のみ
        char *dir = dirname(path);
        strcpy(path, dir);
    }
    return path;
}
```

### 使用例（Lua 側での整合性確認）

```lua
-- Launch.lua で確認
local scriptPath = GetScriptPath()
local runtimePath = GetRuntimePath()

ConPrintf("Script path: %s", scriptPath)      -- /Users/.../src
ConPrintf("Runtime path: %s", runtimePath)    -- /Users/.../build

-- devMode と installedMode の判定
if devMode or (scriptPath == runtimePath and not installedMode) then
    -- スタンドアロンモード
    ConPrintf("Running in standalone mode")
else
    -- インストール済みモード
    ConPrintf("Running in installed mode")
end
```

### Phase 6 実装状況

✅ GetScriptPath() - Phase 5 で実装済み
✅ GetRuntimePath() - Phase 5 で実装済み
✅ GetWorkDir() - Phase 5 で実装済み
✅ GetUserPath() - Phase 5 で実装済み

→ Phase 7 では **GetScriptPath / GetRuntimePath が正しく動作することを確認** するのみ

---

## 参考資料

### PoB2 ソースコード

- **Launch.lua**: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua` (406 行)
  - SetMainObject の使用パターン
  - PCall, PLoadModule の使用頻度

- **HeadlessWrapper.lua**: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/HeadlessWrapper.lua` (220 行)
  - PCall, PLoadModule の参考実装
  - runCallback, SetCallback の実装パターン

- **Modules/Main.lua**: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Modules/Main.lua`
  - LoadModule の実装例
  - Main オブジェクトの構造

### 関連ドキュメント

- **Phase 6 分析報告**: `/Users/kokage/national-operations/claudecode01/memory/sage_phase6_pob2_analysis.md`
  - 不足 API 仕様書 (23 個の API 詳細)
  - Stage 1-4 テスト設計

---

## 実装進捗管理（Mayor 向け）

### Phase 7-P1 完了判定基準

```
✅ SetMainObject 実装完了
   └─ Lua FFI 登録: OK
   └─ レジストリ管理: OK
   └─ テスト PASS: OK

✅ PCall 実装完了
   └─ Lua ラッパー: OK
   └─ エラー変換: OK
   └─ テスト PASS: OK

✅ PLoadModule 実装完了
   └─ ファイル読み込み: OK
   └─ PCall 統合: OK
   └─ テスト PASS: OK

✅ メインループ統合
   └─ OnInit, OnFrame, OnExit: OK
   └─ キー入力処理: OK
   └─ エラーハンドリング: OK

✅ MVP テスト 12/12 PASS 維持
   └─ 既存テスト: すべて PASS
   └─ 新規テスト: 追加実行済み

→ Phase 7-P1 : COMPLETE
```

### Timeline

```
2026-01-29: Sage による仕様書作成（本ドキュメント）
2026-01-30: Artisan による実装開始
2026-01-31: Artisan 実装完了、Merchant テスト実行開始
2026-02-01: 統合テスト完了、Phase 8 準備
```

---

**作成者**: Sage (Claude Haiku 4.5)
**分析完了日**: 2026-01-29
**対象**: Artisan (実装者) 向け実装ガイド
**ステータス**: 準備完了 → 実装待機
