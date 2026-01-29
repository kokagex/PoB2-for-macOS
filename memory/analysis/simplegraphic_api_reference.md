# SimpleGraphic API リファレンス
## Path of Building 2 - Lua インターフェース仕様書

**作成日**: 2026-01-28
**作成者**: Sage
**対象**: SimpleGraphic.dll API 完全リスト

---

## API 早見表

### A. 初期化・設定関数（6 個）

```lua
-- 描画システム初期化（フラグは DPI_AWARE 等）
RenderInit(flag: string, ...: any): void

-- 画面解像度取得
GetScreenSize(): (width: int, height: int)

-- スクリーンスケール取得（DPI スケーリング）
GetScreenScale(): (scale: float)

-- DPI スケール オーバーライドパーセント取得
GetDPIScaleOverridePercent(): (percent: float)

-- DPI スケール オーバーライド設定
SetDPIScaleOverridePercent(scale: float): void

-- ウィンドウタイトル設定
SetWindowTitle(title: string): void
```

### B. 描画色・レイヤ制御（4 個）

```lua
-- 背景色設定
SetClearColor(r: float, g: float, b: float, a: float): void

-- 描画色設定（0.0～1.0 または 0～255）
SetDrawColor(r: float, g: float, b: float, a: float): void

-- 現在の描画色取得
GetDrawColor(r: float, g: float, b: float, a: float): (r, g, b, a)

-- 描画レイヤ・サブレイヤ指定
SetDrawLayer(layer: int, subLayer: int): void

-- ビューポート（クリッピング領域）設定
SetViewport(x: int, y: int, width: int, height: int): void
```

### C. 画像描画関数（5 個）

```lua
-- 矩形領域に画像描画
DrawImage(
    imgHandle: ImageHandle,
    left: int, top: int,          -- 描画左上座標
    width: int, height: int,       -- 描画サイズ
    tcLeft: float, tcTop: float,   -- テクスチャ座標
    tcRight: float, tcBottom: float
): void

-- 任意四辺形領域に画像描画（拡大・縮小・回転）
DrawImageQuad(
    imageHandle: ImageHandle,
    x1: float, y1: float,   -- 頂点1（左上）
    x2: float, y2: float,   -- 頂点2（右上）
    x3: float, y3: float,   -- 頂点3（右下）
    x4: float, y4: float,   -- 頂点4（左下）
    s1: float, t1: float,   -- テクスチャ座標1
    s2: float, t2: float,
    s3: float, t3: float,
    s4: float, t4: float
): void

-- 非同期読み込み中の操作数カウント
GetAsyncCount(): (count: int)
```

### D. テキスト描画関数（4 個）

```lua
-- テキスト描画
DrawString(
    left: int, top: int,           -- 描画座標
    align: int,                     -- テキスト整列（0=左, 1=中央, 2=右）
    height: int,                    -- フォント高さ（ピクセル）
    font: string,                   -- フォント名
    text: string                    -- 描画テキスト
): void

-- テキスト幅取得（ピクセル単位）
DrawStringWidth(
    height: int,
    font: string,
    text: string
): (width: int)

-- テキスト内のカーソルインデックス取得
DrawStringCursorIndex(
    height: int,
    font: string,
    text: string,
    cursorX: int,       -- カーソルX座標
    cursorY: int        -- カーソルY座標
): (index: int)

-- エスケープシーケンス削除（カラーコード `^D` `^xRRGGBB` 等）
StripEscapes(text: string): (plainText: string)
```

### E. 入力関数（4 個）

```lua
-- キー押下状態チェック（キー名: "up", "down", "left", "right" など）
IsKeyDown(keyName: string): (isDown: boolean)

-- マウスカーソル位置取得（画面座標）
GetCursorPos(): (x: int, y: int)

-- マウスカーソル位置設定
SetCursorPos(x: int, y: int): void

-- マウスカーソル表示・非表示
ShowCursor(doShow: boolean): void
```

### F. クリップボード・URL関数（4 個）

```lua
-- テキストをクリップボードにコピー
Copy(text: string): void

-- クリップボードからテキスト取得
Paste(): (text: string)

-- クリップボード内容設定
SetClipboard(text: string): void

-- URL をブラウザで開く
OpenURL(url: string): void
```

### G. ファイル・ディレクトリ関数（7 個）

```lua
-- スクリプト配置ディレクトリ取得
GetScriptPath(): (path: string)

-- ランタイムディレクトリ取得（DLL 等の場所）
GetRuntimePath(): (path: string)

-- ユーザーデータディレクトリ取得
GetUserPath(): (path: string)

-- 現在の作業ディレクトリ取得
GetWorkDir(): (path: string)

-- 作業ディレクトリ変更
SetWorkDir(path: string): void

-- ディレクトリ作成
MakeDir(path: string): void

-- ディレクトリ削除
RemoveDir(path: string): void
```

### H. モジュール・スクリプト関数（6 個）

```lua
-- Lua モジュール読み込み（エラーは例外発生）
LoadModule(fileName: string, ...: any): (module: table)

-- 保護された Lua モジュール読み込み（エラーはタプル返却）
PLoadModule(fileName: string, ...: any): (error: string | nil, module: table)

-- 保護された関数呼び出し（エラーハンドリング付き）
PCall(func: function, ...: any): (error: string | nil, result...: any)

-- サブスクリプト起動（マルチスレッド実行）
LaunchSubScript(
    scriptText: string,             -- スクリプトコード
    funcList: table,                -- 公開関数リスト
    subList: table,                 -- サブリスト
    ...: any                        -- 追加引数
): (ssID: int)

-- サブスクリプト中止
AbortSubScript(ssID: int): void

-- サブスクリプト実行状態チェック
IsSubScriptRunning(ssID: int): (isRunning: boolean)
```

### I. ファイルサーチ・リソース関数（1+ 個）

```lua
-- ファイルサーチハンドル作成（ディレクトリ走査用）
NewFileSearch(): (handle: FileSearchHandle)
```

### J. 画像リソース管理（ImageHandle クラス）

```lua
-- 画像ハンドル作成
NewImageHandle(): (handle: ImageHandle)

-- メソッド:
handle:Load(fileName: string, ...): (success: boolean)
handle:Unload(): void
handle:IsValid(): (valid: boolean)
handle:SetLoadingPriority(priority: int): void
handle:ImageSize(): (width: int, height: int)
```

### K. デバッグ・コンソール関数（6 個）

```lua
-- コンソール出力（printf 形式）
ConPrintf(fmt: string, ...: any): void

-- テーブル内容をコンソール出力
ConPrintTable(tbl: table, noRecurse: boolean): void

-- コマンド実行（例: "set vid_mode 8"）
ConExecute(cmd: string): void

-- コンソールクリア
ConClear(): void

-- プロファイリング有効化・無効化
SetProfiling(isEnabled: boolean): void

-- コンソール出力バッファ読み込み（GetAsyncCount と連携）
GetAsyncCount(): (count: int)
```

### L. システム制御関数（3 個）

```lua
-- プロセス起動
SpawnProcess(cmdName: string, args: string): void

-- アプリケーション再起動
Restart(): void

-- アプリケーション終了
Exit(): void
```

### M. その他関数（4 個）

```lua
-- 現在時刻取得（秒単位）
GetTime(): (timestamp: float)

-- スクリーンショット撮影
TakeScreenshot(): void

-- zlib 圧縮（バイナリデータ）
Deflate(data: string): (compressed: string)

-- zlib 展開
Inflate(data: string): (decompressed: string)

-- クラウドストレージ情報取得
GetCloudProvider(fullPath: string): (
    provider: string | nil,   -- "OneDrive", "GoogleDrive" など
    version: string | nil,
    status: int | nil         -- 0=ローカル, 1=同期中, etc
)
```

### N. 内部コールバックシステム（4 個）

```lua
-- コールバック関数登録
SetCallback(name: string, func: function): void

-- コールバック関数取得
GetCallback(name: string): (func: function | nil)

-- メインオブジェクト設定
SetMainObject(obj: table): void

-- コールバック実行（内部用）
runCallback(name: string, ...: any): (result: any)
```

---

## API グループ別統計

| グループ | 関数数 | 優先度 | 実装難度 |
|---------|-------|--------|---------|
| 描画基本（色・レイヤ・ビューポート） | 5 | HIGH | 低 |
| 画像描画 | 5 | HIGH | 中 |
| テキスト描画 | 4 | HIGH | 高 |
| 入力処理 | 4 | HIGH | 中 |
| ファイル・パス | 7 | HIGH | 低 |
| リソース管理 | 6 | HIGH | 中 |
| クリップボード | 4 | MEDIUM | 低 |
| システム制御 | 3 | LOW | 低 |
| デバッグ | 6 | LOW | 低 |
| 圧縮・クラウド | 4 | LOW | 低 |
| **合計** | **48** | - | - |

---

## キー設定リスト（IsKeyDown で使用）

```
キー名:
"up", "down", "left", "right"    -- 矢印キー
"w", "a", "s", "d"               -- WASD
"space", "return", "escape"       -- 制御キー
"lshift", "rshift", "ctrl", "alt" -- 修飾キー
"0"～"9", "a"～"z"               -- 英数キー
"f1"～"f12"                       -- ファンクションキー
"pageup", "pagedown"              -- ページキー
"home", "end", "insert", "delete" -- 編集キー
```

---

## テキスト整列値（align パラメータ）

```
0: 左揃え（LEFT）
1: 中央揃え（CENTER）
2: 右揃え（RIGHT）
```

---

## カラーコード形式（テキスト内のエスケープ）

```lua
-- 単色カラーコード
"^0" = Dark Color 0
"^1" = Color 1
...
"^9" = Color 9

-- RGB カラーコード
"^xRRGGBB" = RGB 16進色
例: "^xFF0000" = 赤色

-- StripEscapes で削除される
local text = "^xFFFF00Hello^x00FF00World"
local plain = StripEscapes(text)  -- "HelloWorld"
```

---

## ImageHandle 使用例

```lua
-- 画像読み込み
local img = NewImageHandle()
img:Load("path/to/image.png")

-- 画像描画
if img:IsValid() then
    local w, h = img:ImageSize()
    DrawImage(img, 100, 100, w, h, 0, 0, 1, 1)
    img:Unload()
end
```

---

## Launch.lua との連携

```lua
-- Launch.lua が定義するイベント
launch:OnInit()   -- 初期化時（最初に1回）
launch:OnFrame()  -- フレーム更新時（毎フレーム）
launch:CanExit()  -- 終了可能判定

-- HeadlessWrapper.lua が呼び出す
RenderInit("DPI_AWARE")
runCallback("OnInit")
runCallback("OnFrame")
```

---

## 移植チェックリスト

macOS 移植実装時のチェックリスト:

- [ ] RenderInit: Metal/OpenGL 初期化
- [ ] DrawImage/DrawImageQuad: テクスチャ描画実装
- [ ] DrawString: FreeType テキスト描画実装
- [ ] IsKeyDown: GLFW キー入力映射
- [ ] GetCursorPos/SetCursorPos: GLFW マウス連携
- [ ] Copy/Paste: Cocoa クリップボード
- [ ] GetScriptPath/GetUserPath: macOS パス対応
- [ ] LoadModule: Lua モジュール読み込み
- [ ] GetTime: mach_absolute_time() または clock_gettime()
- [ ] OpenURL: NSWorkspace で URL オープン
- [ ] ConPrintf: 標準出力に出力
- [ ] Deflate/Inflate: zlib ライブラリ統合
- [ ] GetCloudProvider: iCloud/Dropbox 検出（オプション）

---

**End of API Reference**
