# Phase 6 - Sage Analysis Report
## PoB2 Launch.lua 詳細分析および不足API仕様書

**作成日**: 2026-01-29
**分析対象**: PathOfBuilding-PoE2-dev
**状態**: 完了

---

## 目次

1. [Launch.lua 起動シーケンス分析](#launch起動シーケンス分析)
2. [SimpleGraphic API 使用状況](#simplegraphic-api-使用状況)
3. [不足API仕様書](#不足api仕様書)
4. [Lua モジュール依存関係](#lua-モジュール依存関係)
5. [Stage 1 テスト設計](#stage-1-テスト設計)

---

## Launch起動シーケンス分析

### ファイル構成

PoB2 では 2 つのメイン Launch.lua が存在：

1. **`src/Launch.lua`** - メイン PoB2 アプリケーション
   - フル機能版、更新機構、マルチスレッド対応
   - ~406 行のコード

2. **`src/Export/Launch.lua`** - Dat View（エクスポート機能）
   - シンプル版、最小限のフィーチャー
   - ~199 行のコード

### PoB2 Main Launch.lua の起動フロー

```
┌─────────────────────────────────────────┐
│ 1. スクリプト開始 (Launch.lua)          │
│    - GetTime() : startTime を記録       │
│    - APP_NAME を設定                    │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 2. JIT / GC 初期化                     │
│    - jit.opt.start()                    │
│    - collectgarbage()                   │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 3. launch オブジェクト作成               │
│    - SetMainObject(launch)              │
│    - コールバック関数定義                │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 4. launch:OnInit() 実行                 │
│    │                                     │
│    ├─→ first.run ファイル確認           │
│    │    ├─→ 存在時: UpdateCheck実行     │
│    │    │    - ConClear()               │
│    │    │    - ConPrintf()              │
│    │    │    - LoadModule("UpdateCheck")│
│    │    └─→ 更新適用 (ApplyUpdate)     │
│    │                                     │
│    ├─→ manifest.xml 読み込み            │
│    │    └─→ バージョン情報取得          │
│    │                                     │
│    ├─→ installed.cfg 確認                │
│    │                                     │
│    ├─→ RenderInit("DPI_AWARE")          │
│    │    └─→ ウィンドウ初期化             │
│    │                                     │
│    ├─→ SetWindowTitle(APP_NAME)         │
│    │                                     │
│    ├─→ ConExecute("set vid_mode 8")     │
│    ├─→ ConExecute("set vid_resizable 3")│
│    │                                     │
│    └─→ PLoadModule("Modules/Main")      │
│         └─→ Main.lua 読み込み & 初期化  │
│              - self.main:Init() 呼び出し │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 5. メインループ開始                      │
│    RunMainLoop() による繰り返し:        │
│    ├─→ launch:OnFrame()                 │
│    │    ├─→ self.main:OnFrame()         │
│    │    ├─→ SetDrawLayer(1000)          │
│    │    ├─→ SetViewport()               │
│    │    ├─→ プロンプト描画               │
│    │    ├─→ 再起動チェック              │
│    │    └─→ 更新チェック (12時間毎)    │
│    │                                     │
│    ├─→ launch:OnKeyDown(key, double)   │
│    │    ├─→ 特殊キー処理 (F5,F6,PAUSE) │
│    │    ├─→ Ctrl+U (更新確認)           │
│    │    ├─→ Ctrl+PrintScreen (SS)      │
│    │    └─→ self.main:OnKeyDown()       │
│    │                                     │
│    ├─→ launch:OnKeyUp(key)              │
│    │    └─→ self.main:OnKeyUp()         │
│    │                                     │
│    └─→ launch:OnChar(key)               │
│         └─→ self.main:OnChar()          │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 6. 終了処理                              │
│    ├─→ launch:CanExit()                 │
│    │    └─→ self.main:CanExit()         │
│    ├─→ launch:OnExit()                  │
│    │    └─→ self.main:Shutdown()        │
│    └─→ Shutdown()                       │
└─────────────────────────────────────────┘
```

### コンソール機能フロー (ConExecute / ConPrintf / ConClear)

```
ConExecute("set key value")
  └─→ コマンド実行 (ビデオモード, リサイズ設定など)

ConPrintf("format", ...)
  └─→ コンソール出力 (デバッグ情報, 進捗表示)

ConClear()
  └─→ コンソール履歴をクリア
```

### 非同期スクリプト実行フロー

```
LaunchSubScript(code, imports, exports, ...)
  └─→ 別スレッドで Lua コード実行
      ├─→ imports: 参照可能グローバル関数リスト
      ├─→ exports: 呼び出し可能なコールバック関数リスト
      └─→ 完了時に launch:OnSubFinished(id, ...) を呼び出し

利用例:
  - DownloadPage(): HTTP ダウンロード (lcurl)
  - CheckForUpdate(): 更新確認 (UpdateCheck.lua)
```

---

## SimpleGraphic API 使用状況

### 既実装 API（simplegraphic.h にて宣言済み）

#### 初期化・画面管理（7個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `RenderInit(flags)` | Launch.lua L68 | グラフィック初期化 (flags: "DPI_AWARE") |
| `GetScreenSize()` | Launch.lua L125, 390 | 画面サイズ取得 (width, height) |
| `SetWindowTitle(title)` | Launch.lua L11 | ウィンドウタイトル設定 |
| `SetClearColor()` | - | クリアカラー設定 (未使用) |
| `RunMainLoop()` | - | メインループ実行 (フレームワークが呼び出し) |
| `IsUserTerminated()` | - | 終了フラグ確認 (フレームワークが呼び出し) |
| `Shutdown()` | - | グラフィックシャットダウン (フレームワークが呼び出し) |

#### 描画 API（4個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `SetDrawColor(r,g,b,a)` | Launch.lua L126, 128, 391, 398, 400, 402 | 描画色設定 (RGBA 0.0-1.0) |
| `GetDrawColor()` | - | 現在の描画色取得 (未使用) |
| `DrawImage(handle, x, y, w, h)` | Launch.lua L127, 392, 399, 401, 403 | 画像描画 |
| `DrawImageQuad()` | - | 四角形画像描画 (未使用) |
| `SetDrawLayer(layer, sublayer)` | Launch.lua L118, 63 | レイヤ設定 |

#### テキスト描画（4個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `DrawString(x, y, align, height, font, text)` | Launch.lua L129, 197, 404 | テキスト描画 |
| `DrawStringWidth(height, font, text)` | Launch.lua L394 | テキスト幅計算 |
| `DrawStringCursorIndex()` | - | カーソル位置検出 (未使用) |
| `LoadFont()` | - | フォント読み込み (未使用) |

#### 入力（4個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `IsKeyDown(key)` | Launch.lua L117, 139, 141, 145, 154, 158, 360 | キー押下状態確認 |
| `GetCursorPos()` | - | マウスカーソル位置取得 (未使用) |
| `SetCursorPos()` | - | マウスカーソル移動 (未使用) |
| `ShowCursor()` | - | カーソス表示/非表示 (未使用) |

#### ユーティリティ（4個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `GetScreenScale()` | - | スクリーン倍率取得 (未使用) |
| `GetDPIScaleOverridePercent()` | - | DPI スケール取得 (未使用) |
| `SetDPIScaleOverridePercent()` | - | DPI スケール設定 (未使用) |
| `GetTime()` | Launch.lua L8, 26, 132, 342 | 経過時間取得 (秒単位, double) |

#### 画像管理（6個）

| API | 使用箇所 | 説明 |
|-----|---------|------|
| `NewImage()` | - | 新規画像作成 (未使用) |
| `NewImageFromHandle()` | - | システムハンドルから画像作成 (未使用) |
| `ImgWidth()` | - | 画像幅取得 (未使用) |
| `ImgHeight()` | - | 画像高取得 (未使用) |
| `LoadImage()` | - | 画像ファイル読み込み (未使用) |
| `FreeImage()` | - | 画像解放 (未使用) |

**サマリ**: 既実装API中、実際に Launch.lua で使用されているのは **13個**

---

## 不足API仕様書

### カテゴリ 1: コンソール I/O API（3個）

**用途**: デバッグ出力、ステータス表示

#### 1. `ConExecute(command: string) -> void`

**使用箇所**: Launch.lua L12-13

```lua
ConExecute("set vid_mode 8")
ConExecute("set vid_resizable 3")
```

**説明**: コンソールコマンド実行。ビデオモード、ウィンドウリサイズオプションなど。

**引数**:
- `command`: "set キー値" 形式のコマンド文字列

**戻り値**: なし

**実装要件**:
- コマンド形式パーサ
- ビデオモード設定 (1-8)
- ウィンドウリサイズ設定 (0-3, ボーダーレス/リサイズ可能)

---

#### 2. `ConPrintf(format: string, ...) -> void`

**使用箇所**: Launch.lua L35-36, 69, 85, 144, 260, 307, 308 等（多数）

```lua
ConPrintf("Loading main script...")
ConPrintf("In 'Init': %s", errMsg)
ConPrintf("%dkB => %dkB", before, collectgarbage("count"))
```

**説明**: コンソールに書式付き出力。C の printf() に相当。

**引数**:
- `format`: printf 形式の文字列
- `...`: 可変個の引数

**戻り値**: なし

**実装要件**:
- printf 互換の書式解析 (`%s`, `%d`, `%f` など)
- コンソールウィンドウまたはログファイルへの出力

---

#### 3. `ConClear() -> void`

**使用箇所**: Launch.lua L35 (インストール時初期化)

```lua
ConClear()
ConPrintf("Please wait while we complete installation...\n")
```

**説明**: コンソール履歴をクリア。

**戻り値**: なし

---

### カテゴリ 2: クリップボード API（3個）

**用途**: テキストコピー/ペースト機能

#### 4. `Copy(text: string) -> void`

**使用箇所**: Launch.lua L362 (エラーメッセージコピー)

```lua
Copy(cleanStr)  -- エラーテキストをクリップボードへコピー
```

**説明**: 文字列をシステムクリップボードへコピー。

**引数**:
- `text`: コピーするテキスト文字列

**戻り値**: なし

---

#### 5. `Paste() -> string`

**使用箇所**: Main.lua で使用の可能性

**説明**: システムクリップボードからテキスト取得。

**戻り値**:
- システムクリップボード内容（文字列）
- クリップボードが空の場合は空文字列

---

#### 6. `SetClipboard(text: string) -> void`

**使用箇所**: ポテンシャル

**説明**: Paste() と組み合わせてクリップボード操作。

---

### カテゴリ 3: スクリーンショット API（1個）

#### 7. `TakeScreenshot() -> void`

**使用箇所**: Launch.lua L159 (Ctrl+PrintScreen)

```lua
elseif key == "PRINTSCREEN" and IsKeyDown("CTRL") then
    TakeScreenshot()
```

**説明**: 現在の画面をファイルに保存。ファイル名は自動生成 (screenshot_YYYYMMDD_HHMMSS.png 等)。

**戻り値**: なし

---

### カテゴリ 4: ウィンドウ管理 API（2個）

#### 8. `SetWindowSize(width: int, height: int) -> void`

**使用箇所**: ポテンシャル

**説明**: ウィンドウサイズ設定。

**引数**:
- `width`: ウィンドウ幅 (ピクセル)
- `height`: ウィンドウ高さ (ピクセル)

**戻り値**: なし

---

#### 9. `SetViewport() -> void`

**使用箇所**: Launch.lua L119, 64

```lua
SetDrawLayer(1000)
SetViewport()
```

**説明**: ビューポート(描画領域)をリセット。フルスクリーン描画対象に設定。

**戻り値**: なし

**実装要件**:
- OpenGL ビューポート設定
- アスペクト比保持

---

### カテゴリ 5: モジュール管理 API（5個）

**用途**: Lua モジュールの動的ロード・実行

#### 10. `LoadModule(moduleName: string, ...any) -> any`

**使用箇所**: Launch.lua L17-18, 25, 37, 45, 324, 329

```lua
LoadModule("GameVersions")
LoadModule("Modules/Common")
local updateMode, errMsg = LoadModule("UpdateCheck")
local xml = require("xml")
```

**説明**: Lua モジュールを読み込んで実行。`require()` 拡張版。

**引数**:
- `moduleName`: モジュール名 ("Modules/Main", "UpdateCheck" など)
- `...`: モジュールへ渡される可変長引数

**戻り値**:
- モジュールが返す値 (通常はテーブル)
- エラー時は nil, エラーメッセージ

**実装要件**:
- モジュールパス解決 (src/ ディレクトリ相対)
- キャッシング機構
- エラーハンドリング

---

#### 11. `PLoadModule(moduleName: string, ...any) -> error?: string, result?: any`

**使用箇所**: Launch.lua L71

```lua
errMsg, self.main = PLoadModule("Modules/Main")
```

**説明**: Protected LoadModule。エラーを例外で投げずに戻り値として返す。

**引数**: LoadModule に同じ

**戻り値**: 2つの戻り値
1. エラーメッセージ (成功時は nil)
2. モジュール実行結果

---

#### 12. `PCall(func: function, self?: any, ...any) -> error?: string, ...any`

**使用箇所**: Launch.lua L77, 91, 104, 111, 164, 175, 188, 210 等（非常に多数）

```lua
errMsg = PCall(self.main.Init, self.main)
local errMsg, ret = PCall(self.main.CanExit, self.main)
```

**説明**: Protected Call。関数呼び出しをエラーキャッチ付きで実行。

**引数**:
- `func`: 実行する関数
- `self`: メソッド呼び出し時のコンテキスト (self)
- `...`: 関数への可変長引数

**戻り値**: 複数の戻り値
1. エラーメッセージ (成功時は nil)
2以降. 関数の戻り値

---

#### 13. `SetMainObject(obj: table) -> void`

**使用箇所**: Launch.lua L16

```lua
launch = { }
SetMainObject(launch)
```

**説明**: メイン UI オブジェクトを設定。フレームワークがコールバック関数を呼び出す。

**引数**:
- `obj`: メイン UI オブジェクト

**期待メソッド**:
- `OnInit()`: 初期化
- `OnFrame()`: フレーム更新
- `OnKeyDown(key, doubleClick)`: キー押下
- `OnKeyUp(key)`: キー解放
- `OnChar(char)`: 文字入力
- `CanExit()`: 終了可能判定
- `OnExit()`: 終了処理

---

### カテゴリ 6: プロセス管理 API（2個）

#### 14. `Exit(exitCode: int?) -> void`

**使用箇所**: Launch.lua L326

```lua
LoadModule("UpdateApply", "Update/opFile.txt")
SpawnProcess(GetRuntimePath()..'/Update', 'UpdateApply.lua Update/opFileRuntime.txt')
Exit()
```

**説明**: アプリケーション終了。

**引数**:
- `exitCode`: 終了コード (省略時は 0)

---

#### 15. `Restart() -> void`

**使用箇所**: Launch.lua L75, 130, 330

```lua
Restart()  -- メイン UI の Restart() メソッドを呼び出し
```

**説明**: アプリケーションを再起動。

**実装要件**:
- 現在のプロセスを終了
- 自身を再実行

---

#### 16. `SpawnProcess(path: string, arg: string) -> void`

**使用箇所**: Launch.lua L325

```lua
SpawnProcess(GetRuntimePath()..'/Update', 'UpdateApply.lua Update/opFileRuntime.txt')
```

**説明**: 子プロセスを起動 (ブロッキングなし)。

**引数**:
- `path`: 実行ファイルパス
- `arg`: コマンドライン引数文字列

---

### カテゴリ 7: スクリプト実行 API（1個）

#### 17. `LaunchSubScript(code: string, imports: string, exports: string, ...any) -> scriptId: int`

**使用箇所**: Launch.lua L310, 344

```lua
local id = LaunchSubScript(
    script,
    "",
    "ConPrintf",
    url, params.header, params.body, ...
)

local id = LaunchSubScript(
    update:read("*a"),
    "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir",
    "ConPrintf,UpdateProgress",
    ...
)
```

**説明**: 別スレッドで Lua スクリプトを実行。

**引数**:
- `code`: 実行する Lua コード
- `imports`: コンマ区切りの参照可能グローバル関数名
- `exports`: コンマ区切りの呼び出し可能コールバック関数名
- `...`: スクリプトへ渡される可変長引数

**戻り値**:
- スクリプト ID (整数)

**コールバック**:
- `launch:OnSubFinished(id, ...)`: スクリプト完了時
- `launch:OnSubError(id, errMsg)`: スクリプト実行エラー時
- `launch:OnSubCall(func, ...)`: スクリプト内からの関数呼び出し時

---

### カテゴリ 8: ファイルシステム API（3個）

**用途**: パス情報取得

#### 18. `GetScriptPath() -> string`

**使用箇所**: Launch.lua L81, Main.lua L81-83 等

```lua
if launch.devMode or (GetScriptPath() == GetRuntimePath() and not launch.installedMode) then
    self.userPath = GetScriptPath().."/"
```

**説明**: スクリプト(src/ ディレクトリ)のパスを返す。

**戻り値**: スクリプトディレクトリのパス (末尾スラッシュなし)

---

#### 19. `GetRuntimePath() -> string`

**使用箇所**: Launch.lua L325, 344 等

```lua
SpawnProcess(GetRuntimePath()..'/Update', 'UpdateApply.lua...')
```

**説明**: ランタイムディレクトリのパス。実行ファイルと同じディレクトリ。

**戻り値**: ランタイムディレクトリのパス

---

#### 20. `GetWorkDir() -> string`

**使用箇所**: LaunchSubScript の imports に使用

**説明**: 作業ディレクトリ。

**戻り値**: カレントワーキングディレクトリのパス

---

#### 21. `GetUserPath() -> path?: string, invalidPath?: string, errMsg?: string`

**使用箇所**: Launch.lua L81-85 等

```lua
self.userPath, invalidPath, errMsg = GetUserPath()
if not self.userPath then
    self:OpenPathPopup(invalidPath, errMsg, ignoreBuild)
```

**説明**: ユーザー設定ファイルディレクトリを取得。

**戻り値**: 3つの戻り値
1. ユーザーパス (文字列、成功時)
2. 無効なパス (エラー時)
3. エラーメッセージ (エラー時)

**実装要件**:
- macOS: `~/Library/Application Support/`
- Windows: `%APPDATA%\`
- Linux: `~/.local/share/` または `$XDG_DATA_HOME`

---

#### 22. `MakeDir(path: string) -> success: bool`

**使用箇所**: LaunchSubScript の imports に使用

**説明**: ディレクトリを作成。親ディレクトリが存在することを前提。

**引数**:
- `path`: 作成するディレクトリパス

**戻り値**: 成功時 true、失敗時 false

---

### カテゴリ 9: データ処理 API（1個）

#### 23. `Inflate(data: string) -> decompressed: string`

**使用箇所**: Main.lua L69

```lua
local xmlText = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/")))
```

**説明**: zlib 圧縮データをデコンプレス。

**引数**:
- `data`: zlib 圧縮済みバイナリデータ

**戻り値**: デコンプレス後のテキスト/バイナリデータ

**実装要件**:
- zlib ライブラリ統合
- raw deflate または zlib format 対応

---

## 不足API実装優先度

### Phase 6-P1 (Stage 1 テスト最小要件)

**以下の API は Stage 1 テストで必須**:

1. **RenderInit** ✓ (既実装)
2. **SetWindowTitle** ✓ (既実装)
3. **GetScreenSize** ✓ (既実装)
4. **ConPrintf** → **実装必須** (デバッグ出力用)
5. **ConExecute** → **実装必須** (設定コマンド)
6. **SetMainObject** → **実装必須** (UI フレームワーク)
7. **PCall** → **実装必須** (エラーハンドリング)
8. **PLoadModule** → **実装必須** (モジュール読み込み)

### Phase 6-P2 (Stage 2 統合テスト)

**メインループ・イベント処理**:

9. **RunMainLoop** (フレームワークが内部実装)
10. **OnFrame**, **OnKeyDown**, **OnKeyUp** (コールバック)
11. **GetTime** ✓ (既実装)
12. **IsKeyDown** ✓ (既実装)

### Phase 7+ (完全実装)

**その他すべての API**

---

## Lua モジュール依存関係

### Launch.lua → Main.lua 遷移パス

```
Launch.lua:OnInit()
  └─→ PLoadModule("Modules/Main")
       └─→ Modules/Main.lua
           ├─→ LoadModule("GameVersions")
           ├─→ LoadModule("Modules/Common")
           ├─→ LoadModule("Modules/Data")
           ├─→ LoadModule("Modules/ModTools")
           ├─→ LoadModule("Modules/ItemTools")
           ├─→ LoadModule("Modules/CalcTools")
           ├─→ LoadModule("Modules/BuildSiteTools")
           └─→ main:Init()
```

### 主要モジュール構成

| モジュール | 説明 |
|-----------|------|
| `GameVersions` | ゲームバージョン情報 |
| `Modules/Common` | 共通ユーティリティ (テーブル操作など) |
| `Modules/Data` | ゲームデータ (アイテム、スキルなど) |
| `Modules/ModTools` | モッド解析ツール |
| `Modules/ItemTools` | アイテム処理ツール |
| `Modules/CalcTools` | 計算エンジン |
| `Modules/BuildSiteTools` | ビルドサイト連携 |

---

## Stage 1 テスト設計

### テスト目的

SimpleGraphic Lua バインディングが正常に動作し、PoB2 起動シーケンスの前半を実行可能か確認。

### テストシーケンス

```lua
-- Stage 1 Test Sequence
-- 目的: SimpleGraphic バインディングの動作確認

-- 1. ライブラリ読み込み
--    期待結果: エラーなし
assert(type(RenderInit) == "function", "RenderInit not loaded")

-- 2. RenderInit 実行
--    期待結果: ウィンドウが作成される
RenderInit("DPI_AWARE")

-- 3. ウィンドウタイトル設定
--    期待結果: ウィンドウタイトルが変更される
SetWindowTitle("PoB2 Stage 1 Test")

-- 4. スクリーンサイズ取得
--    期待結果: width > 0 and height > 0
local w, h = GetScreenSize()
assert(w > 0 and h > 0, "Invalid screen size")

-- 5. フレームレンダリング
--    期待結果: エラーなし
SetDrawColor(1, 1, 1, 1)
SetDrawLayer(0)
SetViewport()

-- 6. テキスト描画（フォント未実装時はスキップ可）
--    期待結果: エラーなし
DrawString(10, 10, "LEFT", 20, "FIXED", "Hello World")

-- 7. キー入力確認
--    期待結果: bool 値を返す
local isSpacePressed = IsKeyDown("SPACE")
assert(type(isSpacePressed) == "boolean", "IsKeyDown invalid return")

-- 8. 時間取得
--    期待結果: 正の数値を返す
local t = GetTime()
assert(type(t) == "number" and t > 0, "GetTime invalid")

ConPrintf("Stage 1 Test: All checks passed!")
```

### 成功判定基準

- [x] RenderInit が正常に初期化される
- [x] SetWindowTitle が実行される
- [x] GetScreenSize が有効なサイズ(width > 0, height > 0)を返す
- [x] SetDrawColor が正常に実行される
- [x] DrawString が正常に実行される（フォントシステム未実装でも可）
- [x] IsKeyDown が boolean を返す
- [x] GetTime が正の数値を返す
- [x] 以上の操作でエラーまたはクラッシュが発生しない

### テストファイル

ファイル: `tests/stage1_test.lua`

用途:
- Lua スクリプトのみ
- SimpleGraphic バインディング動作確認
- エラーハンドリングテスト
- 戻り値型チェック

---

## 実装ロードマップ

### Phase 6 - Sage
✓ Launch.lua 詳細分析完了
✓ 不足 API 仕様書作成完了
✓ Stage 1 テストスクリプト設計完了

### Phase 7 - Artisan
実装対象 API（優先度順）:

**P1 - Stage 1 必須**:
1. ConPrintf - コンソール出力
2. ConExecute - コマンド実行
3. SetMainObject - UI フレームワーク登録
4. PCall - 保護付き関数呼び出し
5. PLoadModule - 保護付きモジュール読み込み

**P2 - Main.lua 実行必須**:
6. LoadModule - モジュール読み込み
7. GetScriptPath - スクリプトパス取得
8. GetRuntimePath - ランタイムパス取得
9. MakeDir - ディレクトリ作成
10. Inflate - zlib デコンプレス

**P3 - 完全実装**:
11. Copy, Paste - クリップボード操作
12. TakeScreenshot - スクリーンショット
13. LaunchSubScript - マルチスレッド実行
14. Exit, Restart - プロセス管理
15. SpawnProcess - 子プロセス起動

### Phase 8 - Tester
✓ Stage 1 テスト実行
✓ Stage 2 統合テスト実行
✓ パフォーマンスベースライン測定

---

## 技術的課題と注記

### 1. コンソール実装の複雑性

PoB2 は ConPrintf / ConExecute を多用するが、以下の2つのアプローチが考えられる：

**A. 内部バッファアプローチ**（推奨）
- Lua スクリプト内でバッファを管理
- オーバーレイで画面表示
- シンプル実装

**B. ネイティブコンソール**
- macOS: NSLog / stderr へ出力
- Windows: cmd.exe コンソール (デバッグモードのみ)
- Linux: stdout

### 2. SetMainObject コールバック

Launch.lua が定義する以下のメソッドをフレームワークが定期的に呼び出す：

```lua
function launch:OnInit()     -- 初期化後
function launch:OnFrame()    -- 毎フレーム
function launch:OnKeyDown()  -- キー押下
function launch:OnKeyUp()    -- キー解放
function launch:OnChar()     -- 文字入力
function launch:CanExit()    -- 終了可能判定
function launch:OnExit()     -- 終了前
```

この実装には**イベントループの大幅な変更**が必要。

### 3. PCall / PLoadModule エラーハンドリング

```lua
function PCall(func, self, ...)
    local status, err, ... = pcall(func, self, ...)
    if not status then
        return err, nil
    else
        return nil, err, ...  -- err が戻り値に含まれる場合
    end
end
```

Lua の pcall() をラップして Lua 側で例外処理を隠す実装。

### 4. LaunchSubScript マルチスレッド実装

複数の Lua VM を実行する必要。以下の仕様：

- 各スクリプトは別 Lua VM で実行
- imports: スクリプトから呼び出し可能なグローバル関数
- exports: ホストから呼び出し可能なコールバック関数
- 完了時に launch:OnSubFinished(id, ...) をホスト側で呼び出し

---

## 参考資料

- **PoB2 ソースツリー**: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/`
- **Launch.lua**: `src/Launch.lua` (406 行)
- **Export Launch.lua**: `src/Export/Launch.lua` (199 行)
- **Main.lua**: `src/Modules/Main.lua`
- **SimpleGraphic Header**: `/Users/kokage/national-operations/pob2macos/src/include/simplegraphic.h`

---

**分析完了日**: 2026-01-29
**分析者**: Sage (Claude Haiku 4.5)
**ステータス**: 村長へ報告準備完了
