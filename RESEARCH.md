# PathOfBuilding.app 内部システム 詳細調査レポート

**調査日**: 2026-02-15
**対象**: `PathOfBuilding.app/Contents/Resources/src/` 以下の全Luaソースコード
**ブランチ**: feature/japanese-localization

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [通知システム (Notification System)](#2-通知システム)
3. [タスクスケジューリング (Task Scheduling)](#3-タスクスケジューリング)
4. [イベント処理 & 状態管理](#4-イベント処理--状態管理)
5. [発見されたバグ一覧](#5-発見されたバグ一覧)
6. [推奨修正 (優先度順)](#6-推奨修正)

---

## 1. アーキテクチャ概要

### メインループ構造

```
PathOfBuilding (C++ / Metal)
  → pob2_launch.lua (FFI Bridge: 48+ C関数をLuaに公開)
    → Launch.lua (アプリケーションライフサイクル管理)
      → Main.lua (UIモード管理、フレームループ)
        → Build.lua / BuildList.lua (モード固有ロジック)
          → 各タブ (TreeTab, SkillsTab, ItemsTab, CalcsTab, ConfigTab, NotesTab, PartyTab)
```

### フレーム実行順序 (`Launch.lua:OnFrame` → `Main.lua:OnFrame`)

```
1. GetScreenSize() / DPI計算
2. モード遷移処理 (while self.newMode do ... end)
3. 入力イベントディスパッチ
   ├─ ポップアップ有 → popups[1]:ProcessInput() (全イベント消費)
   └─ ポップアップ無 → ProcessControlsInput() (コントロールへ配信)
4. モード固有描画 (Build/List)
5. onFrameFuncs 実行 (バックグラウンドタスク)
6. collectgarbage("step", 10)
7. トースト通知アニメーション
8. ボトムバー描画 (58px)
9. tooltipQueue フラッシュ (Z-order ワークアラウンド)
10. ポップアップオーバーレイ描画
11. イベントプール解放
```

---

## 2. 通知システム

PoBには **3つの独立した通知メカニズム** がある。

### 2.1 トーストメッセージ (非モーダル通知)

**場所**: `Modules/Main.lua`

#### データ構造
- `self.toastMessages = {}` — メッセージキュー (配列、FIFO)
- `self.toastMode` — 状態マシン (`nil` / `"SHOWING"` / `"SHOWN"` / `"HIDING"`)
- `self.toastStart` — アニメーション開始時刻 (ms)
- `self.toastHeight` — 計算された表示高さ (px)

#### 状態マシン

```
nil (待機)
 ↓ toastMessages[1] が存在する場合
"SHOWING" (250ms スライドイン)
 ↓ 250ms 経過
"SHOWN" (静的表示、Dismissボタン待ち)
 ↓ ユーザーがDismissクリック
"HIDING" (75ms スライドアウト)
 ↓ 75ms 経過
nil (t_remove(toastMessages, 1) → 次のメッセージがあればSHOWINGへ)
```

#### 高さ計算 (Main.lua:459)
```lua
self.toastHeight = #self.toastMessages[1]:gsub("[^\n]","") * 16 + 20 + 40
-- = (改行数) * 16 + 60
```

#### 描画 (Main.lua:481-491)
- **位置**: 画面左下 (312px幅)
- **背景**: 薄灰色 (0.85) + 暗灰色 (0.1) の二重ボックス
- **テキスト**: 1行目 = タイトル (20px)、2行目以降 = 本文 (16px)
- **Dismissボタン**: `toastMode == "SHOWN"` 時のみ表示

#### トリガー元
| トリガー | 条件 | メッセージ内容 |
|---------|------|--------------|
| devMode警告 | `launch.devMode` かつ起動15秒以内 | "Warning: Developer Mode active!" |
| アップデートチェック失敗 | `launch.updateErrMsg` 設定時 | "Update check failed!\n{エラー}" |
| アップデートなし | `launch.updateAvailable == "none"` | "No update available" |
| アップデート利用可能 | `launch.updateAvailable` (1回のみ) | "Update Available\nAn update has been downloaded..." |

---

### 2.2 エラープロンプト (モーダルオーバーレイ)

**場所**: `Launch.lua`

#### データ構造
- `self.promptMsg` — メッセージ文字列 (nil = 非表示)
- `self.promptCol` — RGB色タプル `{r, g, b}`
- `self.promptFunc` — キー入力コールバック関数

#### 表示関数

**`launch:ShowErrMsg(fmt, ...)`** (Launch.lua:406-417)
```lua
function launch:ShowErrMsg(fmt, ...)
    if not self.promptMsg then  -- 既存プロンプトがない場合のみ
        local fullError = string.format(fmt, ...)
        local version = self.versionNumber and
            "^8v"..self.versionNumber..(self.versionBranch and " "..self.versionBranch or "")
            or ""
        self:ShowPrompt(1, 0, 0,  -- 赤色
            "^1Error:\n\n^0"..fullError.."\n"..version..
            "\nPress Enter/Escape to dismiss, or F5 to restart the application.\n" ..
            "Press CTRL + C to copy error text.")
    end
end
```

**`launch:ShowPrompt(r, g, b, str, func)`** (Launch.lua:390-404)
- `promptMsg`, `promptCol`, `promptFunc` を設定
- デフォルト `promptFunc`: Enter/Escape → dismiss、Ctrl+C → コピー、F5 → 再起動

#### 描画 (`launch:DrawPopup`)
- **半透明オーバーレイ**: 黒 0.5α で画面全体をカバー
- **中央ボックス**: 白外枠 + 色付き内枠 + テキスト
- **入力ブロック**: `promptMsg` 設定中は全キー入力がPromptFuncに渡される

#### エラー発生元
| 発生元 | 場所 | 条件 |
|-------|------|------|
| モジュール読み込み失敗 | Launch.lua:74-80 | Main.lua, Init失敗 |
| OnFrame実行時エラー | Launch.lua:118-128 | PCall(main.OnFrame)がエラー返却 |
| OnKeyDown/Up/Char | Launch.lua:179-205 | 入力ハンドラ内エラー |
| アップデートスレッド | Launch.lua:233 | SubScriptエラー |
| ダウンロードコールバック | Launch.lua:238-256 | コールバック内エラー |

---

### 2.3 ポップアップダイアログ (モーダルUI)

**場所**: `Classes/PopupDialog.lua` + `Modules/Main.lua`

#### クラス構造
```lua
newClass("PopupDialog", "ControlHost", "Control", function(self, width, height, title,
    controls, enterControl, defaultControl, escapeControl, scrollBarFunc, resizeFunc)
```

#### ポップアップスタック
- `main.popups` — LIFO配列 (最前面 = index 1)
- `main:OpenPopup(...)` → `t_insert(self.popups, 1, popup)` (先頭に挿入)
- `main:ClosePopup()` → `t_remove(self.popups, 1)` (先頭を削除)

#### 描画 (Main.lua:509-514)
```lua
if self.popups[1] then
    SetDrawLayer(10)  -- Z-order 10
    SetDrawColor(0, 0, 0, 0.5)  -- 半透明背景
    DrawImage(nil, 0, 0, self.screenW, self.screenH)
    self.popups[1]:Draw(self.viewPort)
    SetDrawLayer(0)
end
```

#### 提供されるダイアログ一覧

| 関数 | 用途 | ボタン |
|------|------|--------|
| `OpenMessagePopup(title, msg)` | 情報表示 | [OK] |
| `OpenConfirmPopup(title, msg, label, onConfirm, ...)` | 確認ダイアログ | [Confirm] [Cancel] or 3-button |
| `OpenUpdatePopup()` | アップデート通知 + changelog | [Update] [Cancel] |
| `OpenAboutPopup(section)` | ヘルプ/バージョン情報 | タブUI |
| `OpenCloudErrorPopup(fileName)` | クラウドストレージエラー | [Help] [OK] |
| `OpenChangeUserPathPopup()` | 設定パス変更 | [Save] [Cancel] |
| `OpenOptionsPopup()` | 設定 (言語、スケール等) | [Save] [Cancel] |
| `OpenNewFolderPopup(path, onClose)` | フォルダ作成 | [Create] [Cancel] |

---

### 2.4 通知タイミング定数

| 定数 | 値 | 用途 |
|------|-----|------|
| トーストSHOWINGアニメーション | 250ms | スライドイン |
| トーストHIDINGアニメーション | 75ms | スライドアウト |
| アップデートチェック間隔 | 12時間 | 定期バックグラウンドチェック |
| devMode警告表示条件 | 起動後15秒以内 | GetTime() < 15000 |

---

## 3. タスクスケジューリング

PoBには **3つの独立したバックグラウンド処理メカニズム** がある。

### 3.1 SubScriptシステム (C++ FFIベースのマルチスレッド)

**場所**: `pob2_launch.lua` (FFI宣言) + `Launch.lua` (管理)

#### FFI関数
```lua
-- pob2_launch.lua:106-108
int LaunchSubScript(const char* scriptName, void* luaState);
void AbortSubScript(int handle);
int IsSubScriptRunning(int handle);
```

#### タスクライフサイクル

```
1. 作成: id = LaunchSubScript(script, imports, callbacks, ...)
2. 登録: self.subScripts[id] = { type = "UPDATE"/"DOWNLOAD"/"CUSTOM", callback = func }
3. 実行: C++が別スレッドでLuaスクリプトを実行
4. 完了: C++がLuaの OnSubFinished(id, ...) を呼び出し
5. コールバック: PCall(sub.callback, ...) で結果を処理
6. クリーンアップ: self.subScripts[id] = nil
```

#### SubScriptの種類

| タイプ | 用途 | 場所 | コールバック |
|--------|------|------|-------------|
| `UPDATE` | アップデートチェック | Launch.lua:367-388 | updateAvailable/updateErrMsg設定 |
| `DOWNLOAD` | Webページダウンロード | Launch.lua:282-351 | レスポンス処理コールバック |
| `CUSTOM` | 汎用 (TreeLink解決等) | Launch.lua:269-276 | RegisterSubScript経由 |

#### 使用箇所

| 呼び出し元 | ファイル | 用途 |
|-----------|--------|------|
| `CheckForUpdate()` | Launch.lua:367 | アップデートマニフェストのダウンロード・検証 |
| `DownloadPage()` | Launch.lua:282 | 任意URLのcurlダウンロード |
| `GetRecommendations()` | PoBArchivesProvider.lua:49 | Similar Builds API呼び出し |
| `TreeTab` PoEURL解決 | TreeTab.lua:727 | PoEURLリダイレクト解決 |
| `UploadBuild()` | BuildSiteTools.lua:37 | ビルドのPOST送信 |

#### OnSubFinished (Launch.lua:244-267)
```lua
function launch:OnSubFinished(id, ...)
    local sub = self.subScripts[id]
    if not sub then return end

    if sub.type == "UPDATE" then
        self.updateAvailable, self.updateErrMsg = ...
        self.updateCheckRunning = false
    elseif sub.type == "DOWNLOAD" then
        PCall(sub.callback, ...)
    elseif sub.type == "CUSTOM" then
        if sub.callback then PCall(sub.callback, ...) end
    end
    self.subScripts[id] = nil
end
```

#### OnExit (Launch.lua:103-113)
```lua
function launch:OnExit()
    for id, _ in pairs(self.subScripts) do
        AbortSubScript(id)  -- C++にスレッド終了を通知
    end
    wipeTable(self.subScripts)  -- テーブル即座にクリア
    if self.main and self.main.Shutdown then
        PCall(self.main.Shutdown, self.main)
    end
end
```

---

### 3.2 コルーチンシステム (Luaベースの協調マルチタスク)

**場所**: `Modules/Common.lua` + `Modules/Main.lua`

#### コルーチン追跡 (Common.lua:45-56)
```lua
local co_create = coroutine.create
local active_coroutines = setmetatable({}, { __mode = "k" })  -- 弱参照キー → GC自動クリーンアップ

function coroutine.create(func)
    local co = co_create(func)
    active_coroutines[co] = true
    return co
end
```

#### pairsYield — 時間ベースのイールド関数 (Common.lua:583-595)
```lua
function pairsYield(t)
    local k
    local start = GetTime()
    return function()
        if coroutine.running() and GetTime() - start > 5 then
            coroutine.yield()  -- 5ms経過でイールド → フレームを譲る
            start = GetTime()
        end
        local v
        k, v = next(t, k)
        return k, v
    end
end
```

**目的**: 大きなテーブルの反復処理中にUIスレッドへ制御を返す。ユニークアイテムDB (~数百アイテム) は約50フレームに分散してロードされ、UIが固まらない。

#### ユニーク/レアアイテムDB読み込み (Main.lua:183-226)
```lua
local function loadItemDBs()
    for type, typeList in pairsYield(data.uniques) do
        for _, raw in pairs(typeList) do
            local ok, result = pcall(new, "Item", raw, "UNIQUE", true)
            if ok then
                newItem = result
                if newItem.base then
                    self.uniqueDB.list[newItem.name] = newItem
                end
            end
        end
    end
    self.uniqueDB.loading = nil
    -- ... rareDB loading 同様 ...
end
```

#### コルーチン駆動 (Main.lua:312-323)
```lua
local itemsCoroutine = coroutine.create(loadItemDBs)
self.onFrameFuncs["LoadItems"] = function()
    local res, errMsg = coroutine.resume(itemsCoroutine)
    if coroutine.status(itemsCoroutine) == "dead" then
        self.onFrameFuncs["LoadItems"] = nil  -- 完了時に自動除去
    end
    if not res then error(errMsg) end
end
```

---

### 3.3 OnFrameファンクションキュー (フレームベース遅延実行)

**場所**: `Modules/Main.lua`

#### 構造
```lua
self.onFrameFuncs = {
    ["FirstFrame"] = function() ... end,       -- 1回のみ実行 (起動時間ログ)
    ["LoadItems"] = coroutine_wrapper,          -- コルーチン駆動 (完了で自動除去)
    ["TradeQueryRequests"] = function() ... end -- 毎フレーム実行 (レート制限チェック)
}
```

#### 実行 (Main.lua:565-568)
```lua
-- TODO: this pattern may pose memory management issues for classes
-- that don't exist for the lifetime of the program
for _, onFrameFunc in pairs(self.onFrameFuncs) do
    onFrameFunc()
end
```

**既知の問題**: コード内のTODOコメントが既にメモリ管理の問題を認識している。

---

### 3.4 トレードクエリシステム (マルチステージパイプライン)

**場所**: `Classes/TradeQuery.lua` + `Classes/TradeQueryRequests.lua` + `Classes/TradeQueryRateLimiter.lua`

#### リクエストパイプライン

```
ユーザーがトレード検索実行
 ↓
TradeQuery:SearchWithQuery(league, queryJson, callback)
 ↓ リクエストをキューに追加
TradeQueryRequests.requestQueue["search"][N] = request
 ↓ 毎フレーム ProcessQueue() がチェック
レートリミッター確認 → 許可ならdownload開始
 ↓
launch:DownloadPage(url, onComplete) → LaunchSubScript(curl)
 ↓ C++スレッドでHTTPリクエスト実行
OnSubFinished → onComplete コールバック
 ↓ レスポンスパース → レートリミット状態更新
FetchResults(itemIds) → 次のリクエストキューへ
```

#### レートリミッター状態マシン
```lua
self.policies = {}        -- {[policyName]: {[ruleName]: {limits, state}}}
self.pendingRequests = {}  -- インフライトリクエスト追跡
self.requestHistory = {}   -- リクエスト履歴タイムスタンプ
self.retryAfter = {}       -- サーバー指定のリトライ時間
```

- `UpdateFromHeader()`: X-Rate-Limit-* ヘッダーからサーバー状態を同期
- `NextRequestTime()`: 次のリクエスト許可時刻を計算
- `InsertRequest()` / `FinishRequest()`: インフライト追跡
- 429レスポンス → 指数バックオフ (2^attempts 秒、最大60秒、最大5リトライ)

---

### 3.5 アップデートチェック & ダウンロードシステム

#### フロー

```
起動時
├─ first.runファイル存在 → 即座にCheckForUpdate
├─ 通常起動 → バックグラウンドCheckForUpdate
└─ 12時間ごと → バックグラウンドCheckForUpdate

手動 (Ctrl+U)
└─ CheckForUpdate(background=false)

CheckForUpdate:
├─ LaunchSubScript(UpdateCheck.lua)
│  ├─ manifest.xml ダウンロード
│  ├─ SHA1整合性チェック
│  ├─ 更新ファイルのダウンロード (5回リトライ)
│  └─ return updateMode ("none"/"normal"/"basic")
└─ OnSubFinished → self.updateAvailable 設定
   └─ Main.lua がトースト表示

ApplyUpdate:
├─ "normal" → UpdateApply.lua 読み込み → Restart()
└─ "basic" → UpdateApply.lua 読み込み → SpawnProcess() + Exit()
```

---

## 4. イベント処理 & 状態管理

### 4.1 入力イベントパイプライン

#### イベント取得
- `Launch.lua` の `OnKeyDown()`, `OnKeyUp()`, `OnChar()` がC++から呼ばれる
- イベントはプール管理 (`eventPool`) でGC圧力を軽減
- `main.inputEvents` 配列にキューイング

#### イベント処理 (ControlHost.lua:ProcessControlsInput:35-125)
- **2パス処理**:
  1. マウスボタンダウン → フォーカス設定
  2. その他イベント → selControl に配信
- **消費フラグ**: `event.consumed = true` で以降の処理をスキップ
- **戻り値セマンティクス**: `OnKeyDown`/`OnChar` → 新しいフォーカスコントロールを返す (nil = deselect)

### 4.2 モード遷移

```lua
function main:SetMode(newMode, ...)
    self.newMode = newMode        -- 遅延遷移 (次フレーム実行)
    self.newModeArgs = {...}
end

-- OnFrame内で処理
while self.newMode do
    if self.mode then self:CallMode("Shutdown") end  -- 旧モードクリーンアップ
    self.mode = self.newMode
    self.newMode = nil
    self:CallMode("Init", unpack(self.newModeArgs))   -- 新モード初期化
end
```

**モード**: `"LIST"` (ビルド選択) / `"BUILD"` (ビルド編集)

### 4.3 ビルドライフサイクル

```
Open: main:SetMode("BUILD", buildFile, ...)
  ↓
Init: Build.lua:Init()
  ├─ XML解析 → Load() (レベル、クラス、mainSocketGroup等復元)
  ├─ タブ生成 (Tree, Skills, Items, Calcs, Config, Notes, Party)
  ├─ configTab:BuildModList()
  └─ calcsTab:BuildOutput() [PCallラップ]
  ↓
Frame Loop: Build.lua:OnFrame()
  ├─ buildFlag チェック (UI変更時にセット)
  ├─ buildFlag あり → wipeGlobalCache() → calcsTab:BuildOutput() → RefreshStatList()
  └─ タブ描画
  ↓
Save: SaveDBFile()
  ├─ XML構築 → ファイル書き込み
  └─ modFlags全リセット
  ↓
Close: CloseBuild() → main:SetMode("LIST", ...)
  ↓
Shutdown: Build.lua:Shutdown() (次フレームで旧モードInit前に実行)
```

### 4.4 PCallエラーラッピング (3層構造)

```
Layer 1: PCall(main.OnFrame)          ← Launch.lua:118 (フレーム全体)
Layer 2: PCall(mode.OnFrame)          ← Main.lua:438 (モードハンドラ)
Layer 3: PCall(calcsTab.BuildOutput)  ← Build.lua:114,321 (再計算)
```

- Layer 1失敗 → エラープロンプト表示 (赤いモーダル) + `/tmp/lua_*` にログ
- Layer 2失敗 → Layer 1に伝播
- Layer 3失敗 → フォールバック出力生成、フレームは継続

### 4.5 安全に動作しているパターン

- **コルーチン + pairsYieldによる遅延ロード**: シングルスレッド、レース条件なし。GCで自動クリーンアップ。
- **RegisterSubScriptのコールバック登録解除**: 実行後に `self.subScripts[id] = nil`。正しい。
- **イベントプール再利用**: 10-20 events/frameをアロケーションなしで再利用。GC圧力低減。
- **遅延モード遷移**: フレーム境界で実行。関心の分離が明確。
- **buildFlagによる遅延再計算**: Frame N でセット → Frame N+1 で実行。UIの不整合は知覚されない。

---

## 5. 発見されたバグ一覧

### バグサマリーテーブル

| ID | システム | 深刻度 | 概要 |
|----|---------|--------|------|
| RC-1 | SubScript | **CRITICAL** | OnExitがコールバック配信前にテーブルをクリア |
| RC-2 | SubScript | **CRITICAL** | モード変更で破壊されたオブジェクトへのコールバック実行 |
| RC-3 | SubScript | **HIGH** | PoBArchivesProviderのキャンセル漏れ |
| RC-5 | OnFrame | **CRITICAL** | TradeQueryRequestsがオブジェクト破壊後も実行 |
| RC-8 | TradeQuery | **CRITICAL** | ProcessQueueのインフライトコールバックが破壊済みオブジェクト参照 |
| S-1 | SubScript | **HIGH** | updateCheckRunningフラグの早すぎる設定 |
| RC-7 | ImageLoad | **HIGH** | PassiveTree破壊中のC++画像ロード継続 |
| S-2 | SubScript | **MEDIUM** | DownloadPageの成功/失敗パスでコールバック引数不整合 |
| U-1 | UpdateCheck | **MEDIUM** | グローバルリトライカウンターが全ファイル共有 |
| C-1 | Coroutine | **MEDIUM** | pairsYieldの内側ループでイールドチェックなし |
| B-4 | BuildSite | **LOW** | UploadBuildのSubScript完了が未処理 |

---

### 5.1 RC-1: OnExitがコールバック配信前にテーブルをクリア [CRITICAL]

**場所**: Launch.lua:103-113

```
タイムライン:
  Frame N-1: UpdateSubScript実行中
  Frame N: ユーザーがアプリを閉じる
    1. OnExit() → AbortSubScript(id) (C++にシグナル送信、非同期)
    2. wipeTable(self.subScripts) → テーブル即座にクリア
    3. OnExit() 完了
  Frame N+1: C++がクリーンアップ完了、OnSubFinished(id, ...) を呼び出し
    → self.subScripts[id] = nil (テーブルは空)
    → コールバック実行されず
    → Luaステートが部分的に破壊された状態でC++がコールバックを呼ぶとクラッシュの可能性
```

**再現条件**: ネットワークリクエスト実行中にアプリを閉じる
**影響**: クラッシュまたはサイレントなリソースリーク

---

### 5.2 RC-2: モード変更で破壊されたオブジェクトへのコールバック [CRITICAL]

**場所**: TreeTab.lua:727-761, PoBArchivesProvider.lua:49-87

```
タイムライン (例: TreeTab のPoEURL解決):
  Frame 1: PoEURL解決開始
    → LaunchSubScript(resolve_script) → id=5
    → RegisterSubScript(5, callback_closure)
         callback内で controls.msg, controls.import を参照
  Frame 2-N: ネットワークリクエスト実行中
    → ユーザーがBUILDモードから離脱 (または別タブへ)
    → TreeTab:Shutdown() 実行
    → controls テーブルがGC対象に
  Frame N+1: C++が OnSubFinished(5, redirect_url) を呼び出し
    → subScripts[5] のコールバッククロージャを実行
    → controls.msg → nilアクセスエラー
```

**根本原因**: コールバッククロージャが親オブジェクトの有効性を検証しない
**再現条件**: PoEURL解決中にモード切替

---

### 5.3 RC-5: onFrameFuncsのクリーンアップ不足 [CRITICAL]

**場所**: Main.lua:565-568, TradeQuery.lua:53-55

```
タイムライン:
  Frame 1: ItemsTabオープン → TradeQuery作成
    → main.onFrameFuncs["TradeQueryRequests"] = function()
        self.tradeQueryRequests:ProcessQueue()  -- selfをクロージャで捕捉
      end
  Frame N: ユーザーがItemsTabから離脱
    → ItemsTab:Shutdown() 実行
    → TradeQuery / TradeQueryRequests 破壊
    → main.onFrameFuncs["TradeQueryRequests"] は**登録されたまま**
  Frame N+1: OnFrame で onFrameFuncs["TradeQueryRequests"] 実行
    → self.tradeQueryRequests → nil
    → :ProcessQueue() → nil method call → クラッシュ
```

**コードの証拠**: Main.lua のTODOコメントが既に問題を認識:
```lua
-- TODO: this pattern may pose memory management issues for classes
-- that don't exist for the lifetime of the program
```

**これがユーザーが報告した「キャンセルされるべきタスクが実行される」バグの最も可能性の高い原因。**

---

### 5.4 RC-8: ProcessQueueのインフライトコールバック [CRITICAL]

**場所**: TradeQueryRequests.lua:24-82

```
タイムライン:
  Frame 1: トレード検索 → DownloadPage() → SubScript起動
    → onComplete クロージャが self (TradeQueryRequests) を参照
  Frame N: ユーザーがモード切替
    → TradeQueryRequests 破壊
    → SubScriptはキャンセルされない (AbortSubScript未呼び出し)
  Frame N+M: ダウンロード完了 → OnSubFinished → onComplete 実行
    → self (TradeQueryRequests) は破壊済み → クラッシュ
```

**二重の問題**:
1. onFrameFuncsの登録解除なし (RC-5と同じ)
2. インフライトSubScriptのキャンセルなし (RC-3と同パターン)

---

### 5.5 S-1: updateCheckRunningフラグの早すぎる設定 [HIGH]

**場所**: Launch.lua:367-388

```lua
function launch:CheckForUpdate(inBackground)
    if self.updateCheckRunning then return end
    -- ... (省略) ...
    self.updateCheckRunning = true  -- ← LaunchSubScript呼び出し前に設定

    local id = LaunchSubScript(...)
    if id then
        self.subScripts[id] = { type = "UPDATE" }
    end
    -- LaunchSubScriptがnilを返した場合:
    -- updateCheckRunning = true のまま永久に固着
    -- → 以後のアップデートチェックが全てブロックされる
end
```

**再現条件**: LaunchSubScriptが失敗した場合 (メモリ不足、スレッド制限等)
**影響**: アプリ再起動までアップデートチェック不可

---

### 5.6 RC-3: PoBArchivesProviderのキャンセル漏れ [HIGH]

**場所**: PoBArchivesProvider.lua:49-87

```lua
function PoBArchivesProviderClass:GetRecommendations(buildCode, postURL)
    local id = LaunchSubScript([[...]], ...)
    if id then
        launch:RegisterSubScript(id, function(response, errMsg)
            self:ParseBuilds(response)  -- selfはPoBArchivesProviderインスタンス
        end)
    end
end
-- ↑ オブジェクト破壊時にAbortSubScript(id)を呼ぶ機構がない
```

**根本原因**: オブジェクトが保持するSubScript IDを追跡していない

---

### 5.7 RC-7: PassiveTree破壊中のC++画像ロード [HIGH]

**場所**: PassiveTree.lua:743-764

```
タイムライン:
  Frame 1: PassiveTreeView作成 → 300+画像を非同期ロード開始
  Frame 2-100: C++バックグラウンドスレッドで画像ロード中
  Frame 101: ユーザーがモード切替
    → PassiveTreeView破壊 → treeImages テーブルGC
    → C++画像ロードスレッドはまだ実行中
  Frame 102: C++がロード完了 → テクスチャキャッシュに書き込み試行
    → ハンドルが無効 → メモリ破壊の可能性
```

**緩和**: C++側がImageHandleの参照カウントで安全に処理している可能性あり (要確認)

---

### 5.8 S-2: DownloadPageの成功/失敗パス不整合 [MEDIUM]

**場所**: Launch.lua:282-351

```lua
if id then
    self.subScripts[id] = {
        type = "DOWNLOAD",
        callback = function(responseBody, errMsg, responseHeader)
            callback({header=responseHeader, body=responseBody}, errMsg)  -- ラッパー経由
        end
    }
else
    PCall(callback, {header="", body=""}, "Failed to launch download")  -- 直接呼び出し
end
```

**問題**: 成功パスはラッパー関数経由、失敗パスは直接呼び出し。現在は引数形式が一致しているが、ラッパー変更時に不整合のリスク。

---

### 5.9 U-1: グローバルリトライカウンター共有 [MEDIUM]

**場所**: UpdateCheck.lua

```lua
local globalRetryLimit = 10  -- 全downloadFileText呼び出しで共有

local function downloadFileText(source, file)
    for i = 1, 5 do
        if globalRetryLimit == 0 or i == 5 then return nil, error:msg() end
        globalRetryLimit = globalRetryLimit - 1
    end
end
```

**問題**: 最初のファイルが3回失敗 → 残り7回。接続回復しても枠不足の可能性。

---

### 5.10 C-1: pairsYieldの内側ループでイールドなし [MEDIUM]

**場所**: Common.lua:583-595, Main.lua:184-197

```lua
for type, typeList in pairsYield(data.uniques) do     -- ← ここでイールドチェック
    for _, raw in pairs(typeList) do                    -- ← ここはチェックなし
        local ok, result = pcall(new, "Item", raw, "UNIQUE", true)
        -- ... item processing ...
    end
end
```

**問題**: `typeList` が大きい場合 (例: body.lua に50+エントリ)、内側ループが5msを大幅超過してもイールドされない。フレームスタッターの原因。

---

### 5.11 B-4: UploadBuildのレスポンス未処理 [LOW]

**場所**: BuildSiteTools.lua:37

```lua
local response = LaunchSubScript([[...]])
-- ↑ idを取得するが RegisterSubScript しない
-- → SubScript完了時のコールバックがない → 成否不明
```

**影響**: ユーザーへのフィードバックなし (成功/失敗が不明)

---

## 6. 推奨修正 (優先度順)

### CRITICAL (即座に対応)

#### 1. onFrameFuncs のShutdownフック追加 (RC-5, RC-8)

各オブジェクトの `Shutdown()` で登録解除:

```lua
-- TradeQuery.lua
function TradeQueryClass:Shutdown()
    main.onFrameFuncs["TradeQueryRequests"] = nil
end
```

**影響範囲**: TradeQuery, その他onFrameFuncs登録者全て

#### 2. SubScriptコールバックの有効性チェック (RC-2, RC-3)

コールバック内でオブジェクトの有効性を確認:

```lua
launch:RegisterSubScript(id, function(...)
    if not self or not self.controls then return end  -- 有効性チェック
    -- ... 元の処理 ...
end)
```

#### 3. OnExitのSubScript待機 (RC-1)

AbortSubScript後にコールバック配信の猶予を与える:

```lua
function launch:OnExit()
    for id, _ in pairs(self.subScripts) do
        AbortSubScript(id)
    end
    -- タイムアウト付き待機
    local timeout = GetTime() + 2000
    while next(self.subScripts) and GetTime() < timeout do
        -- C++がOnSubFinishedを呼ぶ余裕を与える
    end
    wipeTable(self.subScripts)
end
```

### HIGH (次フェーズ)

#### 4. updateCheckRunningフラグ修正 (S-1)

```lua
local id = LaunchSubScript(...)
if id then
    self.subScripts[id] = { type = "UPDATE" }
    self.updateCheckRunning = true  -- ← if id then の内側に移動
end
```

#### 5. SubScript IDの体系的追跡 (RC-3)

各オブジェクトが保持するSubScript IDを追跡し、破壊時に一括キャンセル:

```lua
function SomeClass:Destroy()
    if self._subScriptId then
        AbortSubScript(self._subScriptId)
        launch.subScripts[self._subScriptId] = nil
    end
end
```

### MEDIUM (改善)

#### 6. グローバルリトライカウンターをファイル単位に変更 (U-1)
#### 7. pairsYieldの内側ループにもイールドチェック追加 (C-1)
#### 8. DownloadPageの失敗パスをラッパー経由に統一 (S-2)

---

## 付録: ファイルリファレンス

| コンポーネント | ファイル | 重要行 |
|-------------|--------|--------|
| トーストシステム | Modules/Main.lua | 278-284, 287, 440-452, 454-491 |
| エラープロンプト | Launch.lua | 135-137, 390-417, 430-446 |
| PopupDialogクラス | Classes/PopupDialog.lua | 8-93 |
| ポップアップ管理 | Modules/Main.lua | 420-423, 509-514, 1662-1787 |
| SubScript管理 | Launch.lua | 103-113, 229-267, 269-388 |
| FFI宣言 | pob2_launch.lua | 106-108, 807-809 |
| コルーチン追跡 | Modules/Common.lua | 45-56, 583-595 |
| アイテムDB読み込み | Modules/Main.lua | 183-226, 304-323 |
| onFrameFuncs | Modules/Main.lua | 301-323, 565-568 |
| トレードクエリ | Classes/TradeQuery.lua | 53-55 |
| リクエスト処理 | Classes/TradeQueryRequests.lua | 24-82 |
| レートリミッター | Classes/TradeQueryRateLimiter.lua | 113-148 |
| ビルドライフサイクル | Modules/Build.lua | 749-847, 1641, 2681-2792 |
| PCallエラーラップ | HeadlessWrapper.lua | 142-150 |
| イベント処理 | Classes/ControlHost.lua | 35-125 |
| モード遷移 | Modules/Main.lua | 398-416, 593-606 |
| PoBArchives | Classes/PoBArchivesProvider.lua | 49-87 |
| TreeLink解決 | Classes/TreeTab.lua | 727-761 |
| ビルドアップロード | Modules/BuildSiteTools.lua | 37 |
| アップデートチェック | UpdateCheck.lua | 全体 |
| 画像ロード | Classes/PassiveTree.lua | 743-764 |

---

## 7. アイテム作成 Prefix/Suffix 即確定バグ調査

**調査日**: 2026-02-15
**報告**: プレフィックス/サフィックスを選ぶと一覧が出る前に確定されて入力ができないままアイテム一覧に登録される

### 7.1 アイテム作成フロー

```
1. ユーザーが「カスタム作成」クリック
   → ItemsTab:CraftItem() → main:OpenPopup() (ItemsTab.lua:1993-2099)

2. ポップアップでレアリティ・タイプ・ベースを選択
   → 「作成」クリック → makeItem() → SetDisplayItem(item) (Line 2085-2088)

3. SetDisplayItem() (Line 1496-):
   a. self.displayItem = item
   b. UpdateDisplayItemTooltip() (Line 1500)
   c. 各コントロール初期化 (Variant, Alt等)
   d. item.crafted → UpdateAffixControls() (Line 1531-1532)
   e. Catalyst: SetSel((item.catalyst or 0) + 1) (Line 1536) ← ★重要
   f. UpdateCustomControls(), UpdateRuneControls() 等

4. displayItemエリアが表示
   → Prefix/Suffix DropDownControl が表示 (Line 608-782)

5. ユーザーがPrefix/Suffix ドロップダウンをクリック
   → ★ここでバグ発生？
```

### 7.2 候補原因分析

#### 候補A: Catalyst SetSel による連鎖的selFunc呼び出し (確度: 中)

**場所**: ItemsTab.lua:1536 + 451-456

SetDisplayItem (Line 1536):
```lua
self.controls.displayItemCatalyst:SetSel((item.catalyst or 0) + 1)
```

Catalyst の selFunc (Line 441-460):
```lua
function(index, value)
    self.displayItem.catalyst = index - 1
    ...
    if self.displayItem.crafted then
        for i = 1, self.displayItem.affixLimit do
            local drop = self.controls["displayItemAffix"..i]
            drop.selFunc(drop.selIndex, drop.list[drop.selIndex])  -- ★全affixのselFuncを強制呼び出し
        end
    end
    self.displayItem:BuildAndParseRaw()
end
```

SetSel → catalyst selFunc → 全affix dropdown の selFunc を直接呼び出し。
affix selFunc (Line 608-623) は:
```lua
function(index, value)
    local affix = { modId = "None" }
    ...
    self.displayItem[drop.outputTable][drop.outputIndex] = affix
    self.displayItem:Craft()        -- ★アイテム確定
    self:UpdateDisplayItemTooltip()
    self:UpdateAffixControls()       -- ★全dropdown再構築
end
```

**問題点**: `drop.selFunc()` を直接呼ぶのは、DropDownControl.SetSel() を経由しない。SetSel には `noCallSelFunc` ガードがあるが、直接呼び出しではバイパスされる。

**ただし**: これはアイテム初期化時の問題で、ドロップダウンクリック時の問題とは直接関係ない可能性がある。

#### 候補B: RETURN キーショートカットの誤発火 (確度: 高)

**場所**: ItemsTab.lua:1163-1164

```lua
elseif self.displayItem and IsKeyDown("RETURN") then
    self:AddDisplayItem()
```

**問題点**:
1. `IsKeyDown("RETURN")` は **キー状態** を確認（イベントキーではない）
2. この条件は `event.key == "RETURN"` ではなく、ANY KeyDown イベントで発火可能
3. `not textInputActive` ガードが**ない**（他の全ショートカットにはある）
4. `event.consumed` が設定されない → 同イベントが2回処理される可能性

**具体的シナリオ**:
```
1. ユーザーがアイテム作成ポップアップで「作成」をEnterで確定
2. ポップアップが閉じる → displayItem が表示される
3. 同フレーム内でRETURN キー状態がまだ true
4. 次の InputEvents 処理で:
   - event.type == "KeyDown" (マウスクリックなど別のイベント)
   - self.displayItem は true (ステップ2で設定)
   - IsKeyDown("RETURN") は true (ステップ1のキーがまだ押下中)
   → self:AddDisplayItem() が実行 → アイテムがビルドに追加
```

**あるいは IME シナリオ**:
```
1. 日本語IME がアクティブ
2. IME の変換確定で Enter が使われる
3. IsKeyDown("RETURN") が true のまま残る
4. 次のフレームで displayItem を操作しようとクリック
   → LEFTBUTTON の KeyDown イベントが発生
   → elseif 条件に到達
   → IsKeyDown("RETURN") が true → AddDisplayItem() 実行
```

#### 候補C: DropDownControl のイベント処理タイミング問題 (確度: 低)

**場所**: ControlHost.lua:50-61

```lua
if self.selControl then
    self:SelectControl(self.selControl:OnKeyDown(event.key, event.doubleClick))
    event.consumed = true
    if not self.selControl and event.key:match("BUTTON") then
        self:SelectControl()
        if isMouseInRegion(viewPort) then
            local mOverControl = self:GetMouseOverControl()
            if mOverControl and mOverControl.OnKeyDown then
                self:SelectControl(mOverControl:OnKeyDown(event.key, event.doubleClick))
            end
        end
    end
end
```

DropDownが開いている状態で、クリックした場所がドロップダウンのBODY外の場合:
1. OnKeyDown returns nil (dropped=false) → selControl = nil
2. Line 53: `not self.selControl` → true, `event.key:match("BUTTON")` → true
3. Line 56: `GetMouseOverControl()` → 別のコントロール（例: AddToBuiltボタン）を返す可能性
4. → 別コントロールの OnKeyDown が呼ばれる

**ただし**: ドロップダウンがまだ開かれていない状態（初回クリック）でこれが起きるのは考えにくい。

### 7.3 結論と推奨調査手順

**最有力仮説: 候補B (RETURNキーの誤発火)**

理由:
1. `IsKeyDown("RETURN")` は他のショートカット（v,e,z,y,f,d）と異なり `event.key` をチェックしていない
2. `not textInputActive` ガードがない（他の全ショートカットにはある）
3. アイテム作成ポップアップの「Create」ボタンは Enter キーで確定可能
4. IME 使用時に Enter の状態が残る可能性がある
5. 「アイテム一覧に登録される」（AddDisplayItem が呼ばれる）という症状と一致

**修正案**:
```lua
-- 現在 (Line 1163)
elseif self.displayItem and IsKeyDown("RETURN") then

-- 修正後
elseif self.displayItem and event.key == "RETURN" and not textInputActive then
```

**副次的修正**: Catalyst selFunc での直接的な affix selFunc 呼び出し（Line 451-456, 467-471）も `noCallSelFunc` パターンに変更すべき。

---

## 8. テスト・品質保証 調査レポート

**調査日**: 2026-02-17
**実装完了日**: 2026-02-17
**対象**: test.md 3セクション実行結果のレビュー → 全Phase実装完了
**コミット**: `52bf858` (テスト基盤+防御コード), `bc24e0d` (GitHub Actions CI)

---

### 8.1 実装成果サマリー

| Phase | 内容 | 状態 | コミット |
|-------|------|------|---------|
| 1 | pob2_launch.lua 防御コード (3件) | **完了** | `52bf858` |
| 2 | Bustedテスト基盤 (71テスト) | **完了** | `52bf858` |
| 3 | ビジュアル回帰テストツール | **完了** | `52bf858` |
| 4 | ディレクトリ整理 + CI | **完了** | `52bf858`, `bc24e0d` |

#### テストスイート構成
```
test/
  unit/                           ← Busted (LuaJIT 5.1)
    busted_setup.lua              ← package.path設定
    test_helpers.lua              ← 共通モック・スタブ (170行)
    pob2_testable.lua             ← FFI非依存の純Lua関数7個
    test_pob2_launch.lua          ← 31テスト
    test_modtools.lua             ← 18テスト
    test_common.lua               ← 22テスト
  visual/                         ← ビジュアル回帰 (ローカル専用)
    visual_diff.py                ← SSIM + pixel diff (Python 3.9互換)
    run_visual_test.sh            ← screencaptureベースの自動テスト
    baselines/                    ← ベースライン画像格納
.busted                           ← プロジェクトルート設定
.github/workflows/test.yml       ← CI: macos-14 + LuaJIT + busted
```

---

### 8.2 Phase 1: pob2_launch.lua 防御コード — 実装結果

#### 1.1 DrawImage nilハンドルガード

**元の計画**: `if handle == nil then return end` を追加
**実際の結果**: **リグレッション発生 → 修正**

- PoBは `DrawImage(nil, x, y, w, h)` を単色矩形描画に広く使用（Launch.lua, ItemSlotControl, CalcSectionControl等、数百箇所）
- nilガードで早期returnするとフレーム枠・ポップアップ背景・区切り線が全て消失
- **最終修正**: `sg.DrawImage(handle or ffi.cast("void*", 0), ...)` — NULLポインタとして渡し、SimpleGraphicに単色矩形として描画させる

**教訓**: `DrawImage(nil, ...)` はPoBの仕様上の正常呼び出し。FFI関数のnilガードは呼び出し元の使用パターンを調査してから適用すべき。

#### 1.2 ImageHandle二重Unload防止

**実装**: `Unload()` 冒頭に `if self._handle == nil then return end`、Unload後に `self._handle = nil` を設定。
**結果**: 問題なし。

#### 1.3 normalizeTextArg適用

**元の計画**: `SetWindowTitle`, `Copy`, `SetClipboard` にラッパー追加
**実際の結果**: **起動不能バグ発生 → 修正**

- `normalizeTextArg` は `local function` としてL396で定義
- `SetWindowTitle` のクロージャはL146で定義
- Luaのスコープ規則: `local`変数は宣言位置より後のコードからのみ参照可能
- L146のクロージャは `normalizeTextArg` を捕捉できず `nil` 参照 → 起動時クラッシュ
- **最終修正**: L141に `local normalizeTextArg` の前方宣言を追加、L396を `normalizeTextArg = function(text)` (代入式) に変更

**教訓**: Luaの `local function` は宣言位置がスコープ開始点。クロージャの前方参照には前方宣言が必須。

---

### 8.3 Phase 2: テスト基盤 — 実装結果

#### 解決した課題

| 元ID | 課題 | 解決方法 |
|------|------|---------|
| T1-1 | stub依存の複雑さ | `test_helpers.lua` で `package.loaded` プリセット + グローバルstub一元管理 |
| T1-3 | pob2_launch.luaの手動コピー | `pob2_testable.lua` にFFI非依存関数7個を抽出 |
| T1-6 | .busted未作成 | プロジェクトルートに `.busted` + `busted_setup.lua` (package.path設定) |
| TX-2 | ドライラン未実施 | 71/71テストPASS確認済み |

#### テストカバレッジ詳細

```
test_pob2_launch.lua (31テスト):
  validatePath       14件 — 正常パス、traversal攻撃、メタ文字、null byte
  normalizeTextArg    5件 — nil→"", number→tostring, boolean, string, 空文字
  stripEscapes        4件 — ^0-9色コード, ^xHEXカラー, 混合, エスケープなし
  shellQuote          3件 — 通常, シングルクォート含, nil
  parseColorArg       4件 — ^xHEX RGB, ^digit テーブル参照, 無効入力
  parsePattern        2件 — ディレクトリ分離, ワイルドカード→正規表現変換
  validateURL         7件 — http/https許可, file://拒否, 改行拒否, クォートエスケープ

test_modtools.lua (18テスト):
  createMod           5件 — 基本mod, フラグ付き, タグ付き, ソース指定
  parseTags           7件 — 単一タグ, 複合タグ, 否定タグ, 空文字
  parseFormattedSrc   3件 — 正常パース, 不正形式(フィールド不足)
  compareModParams    3件 — 完全一致, 値不一致, タイプ不一致

test_common.lua (22テスト):
  prerequire          3件 — 成功, 失敗, 型チェック
  coroutine wrapper   2件 — 追跡テーブル登録, 弱参照
  copyTable           2件 — 浅いコピー, 独立性
  wipeTable           2件 — テーブルクリア, 配列クリア
  round               2件 — 整数近傍, 負数
  codePointToUTF8     3件 — ASCII, CJK(3バイト), サロゲート拒否
  その他              8件 — formatNumSep, naturalSortCompare等
```

#### ディレクトリ移動時の問題

- `Resources/tests/` → `test/unit/` に移動時、`require("test_helpers")` がパス解決に失敗
- **原因**: Bustedの `ROOT` はテストファイル探索用で、`package.path` には追加されない
- **解決**: `busted_setup.lua` をhelperとしてロードし、`package.path` に `test/unit/?.lua` を追加

---

### 8.4 Phase 3: ビジュアル回帰テスト — 実装結果

#### TakeScreenshot検証結果 (Step 3.1)

| 実行方法 | 結果 | 原因 |
|---------|------|------|
| ターミナル直接実行 (`../MacOS/PathOfBuilding`) | **動作せず** | GUIウィンドウ非表示、レンダリングループ未到達 |
| `open --env POB_VISUAL_TEST=1` | **環境変数届かず** | macOSの `open` コマンドは `--env` を子プロセスに渡さない |
| `screencapture -x` (アプローチB) | **正常動作** | PNG 3584x2240 RGBA、即座に生成 |

**結論**: TakeScreenshot (アプローチA) はGUI起動+ユーザー操作が前提でCI自動化に不向き。`screencapture` (アプローチB) をメインとする。

#### POB_VISUAL_TESTフラグ

- `pob2_launch.lua` L1287-1297: 環境変数検出 + screenshotsディレクトリ作成 + フレーム番号ベースの自動撮影定義
- L1360-1370: メインループ内スクリーンショットフック + frame 310後の自動終了
- **動作未確認**: ターミナル実行ではレンダリングループに到達しないため、GUI起動時のみ有効

#### visual_diff.py

- SSIM (構造類似性) + pixel diff (ピクセル差分) のデュアル比較
- Python 3.9互換 (`Optional[str]` 使用)
- CLI: `--threshold`, `--diff-output` オプション対応

---

### 8.5 Phase 4: 統合 & CI — 実装結果

#### GitHub Actions (`test.yml`)

- **ランナー**: `macos-14` (Apple Silicon)
- **ステップ**: brew install luajit → brew install luarocks → luarocks install busted → busted --verbose
- **トリガー**: push (pob2macos_stage2, feature/*), PR (pob2macos_stage2)
- **ビジュアルテスト**: CIでは実行不可（ヘッドレス環境でscreencapture不可）、ローカル専用

---

### 8.6 発見されたリグレッションと教訓

| # | 症状 | 原因 | 修正 | 教訓 |
|---|------|------|------|------|
| R1 | アプリ起動不能 | `normalizeTextArg` の前方参照 (L146 < L396) | L141に前方宣言追加 | Luaの `local` スコープは宣言位置依存。クロージャは定義時のスコープを捕捉 |
| R2 | 背景・フレーム・ツールチップ消失 | `DrawImage(nil,...)` の早期return | `ffi.cast("void*",0)` でNULLポインタ渡し | PoBは `DrawImage(nil,...)` を単色矩形描画に使用。FFI nilガードは使用パターン調査が必須 |

---

### 8.7 未解決の改善候補

| ID | 問題 | 優先度 | 状態 |
|----|------|--------|------|
| T1-2 | ModTools `parseMod` のモック不足 | 中 | 未着手 — 現テストは parseMod 非依存の関数のみカバー |
| T1-4 | `newClass` 継承テスト欠如 | 低 | 未着手 |
| T1-5 | `sanitiseText` テストの実在未確認 | 低 | 未着手 |
| T2-3 | ImagePool (リソースプール) 過剰設計 | 低 | 保留 — 現時点で不要 |
| T2-4 | NULバイト警告のログスパム | 低 | 未着手 |
| T2-5 | collectgarbage step最適化 | 低 | 未着手 |
| T3-5 | DPI別ベースライン自動判定 | 低 | 未着手 |
| T3-6 | CI上のRenderInit動作検証 | 低 | 不要と判断 — CIはユニットテストのみ |
| NEW-1 | POB_VISUAL_TESTフラグのGUI起動検証 | 中 | 未検証 — ターミナル実行では動作しない |
| NEW-2 | ベースライン画像の初回生成 | 中 | 未着手 — `run_visual_test.sh --update-baselines` で生成予定 |
| NEW-3 | pob2_testable.luaとpob2_launch.luaの同期チェック | 中 | 未着手 — 関数変更時に乖離するリスク |
