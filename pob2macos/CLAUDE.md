# CLAUDE.md

このファイルは、pob2macosプロジェクトで作業する際にClaude Code (claude.ai/code)へのガイダンスを提供します。

---

## 🚨 セッション開始時の必須事項

**PRJ-003 pob2macosプロジェクトで作業する前に、必ず以下を実行してください：**

### 1. マルチエージェントシステムの確認

このプロジェクトはマルチエージェントシステム（Prophet、Mayor、Paladin、Merchant、Sage、Bard、Artisan）で管理されています。

**必ず最初に読むこと**:
```bash
# リポジトリルートから
/Users/kokage/national-operations/agents/00_overview.md
```

**00_overview.mdには以下が記載されています**:
- エージェントシステムの全体構造
- 各エージェントの役割と責任
- コミュニケーションフロー（Prophet → Mayor → 専門エージェント → Mayor → Prophet → God）
- タスク実行時の使用方法
- Memory Management（記憶管理の天啓）

### 2. セッション開始時チェックリスト

- ✅ `/Users/kokage/national-operations/agents/00_overview.md` を読んだ
- ✅ 自分の役割（Prophet/Mayor/専門エージェント）を理解した
- ✅ PRJ-003プロジェクトフォルダ（`/Users/kokage/national-operations/memory/PRJ-003_pob2macos/`）を確認した
- ✅ このCLAUDE.md（技術ドキュメント）を読んだ

### 3. プロジェクト構造

```
/Users/kokage/national-operations/
├── agents/                          # マルチエージェントシステム定義
│   ├── 00_overview.md              # 【必読】システム全体構造
│   ├── 01_prophet.md               # 戦略計画・自動承認権限
│   ├── 02_mayor.md                 # タスク調整・リスク評価
│   ├── 03_paladin.md               # 品質保証・実行検証
│   ├── 04_merchant.md              # 外部リサーチ・市場情報
│   ├── 05_sage.md                  # 技術検証・研究
│   ├── 06_bard.md                  # ドキュメント・コミュニケーション
│   └── 07_artisan.md               # 実装安全性・ビルド
├── memory/PRJ-003_pob2macos/       # プロジェクト固有のメモリ
│   ├── PHASE*.md                   # フェーズドキュメント
│   ├── *_REPORT.md                 # 各種レポート
│   └── ...
└── pob2macos/                      # このプロジェクト
    ├── CLAUDE.md                   # このファイル（技術ガイド）
    ├── src/                        # Luaソースコード
    ├── simplegraphic/              # C++ Metalバックエンド
    └── PathOfBuilding.app/         # macOSアプリバンドル
```

### 4. エージェントシステムとの統合

**作業フロー**:
1. **Prophet**: タスクを計画し、自動承認プロトコルを適用
2. **Mayor**: タスクを分解し、適切なエージェントに割り当て
3. **Sage**: 技術的正確性を検証（このCLAUDE.mdの技術情報を活用）
4. **Artisan**: 実装とファイル同期を実行（ファイル同期セクション参照）
5. **Paladin**: 実行検証と証拠収集（テストセクション活用）
6. **Merchant**: 外部リサーチ（依存関係、ライブラリ調査）
7. **Bard**: ドキュメント作成（ドキュメントセクション参照）

---

## プロジェクト概要

**プロジェクトID**: PRJ-003
**プロジェクト名**: pob2macos
**ステータス**: 進行中
**管理方法**: マルチエージェントシステム（Prophet, Mayor, Paladin, Merchant, Sage, Bard, Artisan）

**pob2macos**は、Path of Exile 2のビルドプランニングツールであるPath of Building 2のネイティブmacOSポートです。Lua + C++/Objective-Cのハイブリッドアプリケーションで、カスタムグラフィックバックエンドを使用しています。

**アーキテクチャ**: Luaアプリケーション層（292 MB）+ SimpleGraphic C++ライブラリ（Metalバックエンド）+ macOSアプリバンドル

**主要技術**:
- **グラフィック**: Metal API（メイン）、OpenGL（フォールバック）
- **スクリプティング**: LuaJIT 5.1とFFI（Lua 5.4ではない）
- **ウィンドウ管理**: GLFW3
- **テキストレンダリング**: FreeType2
- **ビルドシステム**: CMake 3.16+

**プロジェクトメモリ**: `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/`

---

## ビルドコマンド

### SimpleGraphicライブラリのビルド

```bash
cd simplegraphic
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
```

出力: `simplegraphic/build/libSimpleGraphic.dylib`

**バックエンドオプション**:
- `-DSG_BACKEND=metal`（デフォルト、推奨）
- `-DSG_BACKEND=opengl`（フォールバック）

**ビルドタイプ**:
- `-DCMAKE_BUILD_TYPE=Release`（デフォルト）
- `-DCMAKE_BUILD_TYPE=Debug`

### アプリバンドルへのデプロイ

SimpleGraphicをビルド後、runtimeとアプリバンドルにコピー：

```bash
# runtimeディレクトリにコピー
cp simplegraphic/build/libSimpleGraphic.dylib runtime/SimpleGraphic.dylib

# アプリバンドルにruntimeをコピー
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

**重要**: 常に両方の場所に変更を同期する必要があります：
1. ソースコード: `src/` → `PathOfBuilding.app/Contents/Resources/pob2macos/src/`
2. ランタイム: `runtime/` → `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`
3. 起動スクリプト: `pob2_launch.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/`

### アプリケーションの実行

```bash
# リポジトリルートから
./run_pob2.sh

# またはアプリバンドルを直接起動
open PathOfBuilding.app

# またはターミナルから実行（ログが表示される）
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding
```

---

## テスト（Paladinの検証責任）

**責任者**: Paladinエージェントは実装後に品質保証と実行検証を実行する責任を負います（agents/03_paladin.md参照）。

### ユニットテスト

**Busted**でLuaユニットテスト（`.busted`に設定）：
```bash
busted spec/
```

### 統合テスト

リポジトリルートにある手動テストスクリプト（すべてLuaJITを使用）：

```bash
# 基本レンダリングテスト（5秒）
luajit test_5sec.lua

# 画像読み込み検証
luajit test_image_loading.lua

# テキストレンダリングテスト
luajit test_text_rendering.lua

# パッシブツリー表示テスト
luajit test_passive_tree_fixed.lua

# 完全アプリケーション起動テスト
luajit test_pob_launch.lua
```

### 回帰テスト

```bash
./tests/regression_test.sh
```

### テスト実行時の注意

**macOSセキュリティ制限**: 一部のテストスクリプトはluajit経由で実行すると「permission denied」で失敗する場合があります。その場合は、アプリバンドルを直接起動してテストしてください。

**Paladinの検証パターン**:
- ログパターン検証: `grep`でエラーパターンを確認
- ビジュアル検証: アプリ起動後にスクリーンショット撮影
- 回帰テスト: 既存機能が壊れていないか確認
- 証拠収集: ログ、メトリクス、システム状態を記録

---

## コードアーキテクチャ

### 実行フロー

```
run_pob2.sh（Bash）
  ↓
pob2_launch.lua（FFIローダー）
  ↓ FFI経由でSimpleGraphic.dylibを読み込み
  ↓ グローバル関数を初期化（_G.RenderInit、_G.DrawImageなど）
  ↓
src/Launch.lua（PoBランチャー）
  ↓ レンダラーを初期化
  ↓ Mainモジュールを読み込み
  ↓
src/Modules/Main.lua（PoBコア）
  ↓ データ、計算、UIを読み込み
  ↓ ビルドリストとビルド画面を管理
  ↓
メインゲームループ（ProcessEvents → Draw → ProcessEvents）
```

### SimpleGraphic C++ライブラリの構造

**ソース**: `simplegraphic/src/`
```
core/           - 初期化、状態管理
window/         - ウィンドウ作成、入力処理（GLFW）
rendering/      - 描画コマンド、画像、テキスト（FreeType）
backend/metal/  - Metalレンダリング実装（1015行）
utilities/      - ファイルシステム、圧縮、クリップボード、コンソール
lua/            - Lua FFIバインディング（プレースホルダー）
```

**パブリックAPI**: `simplegraphic/include/simplegraphic.h`（48のエクスポート関数）

**重要な関数**:
- `RenderInit()` - グラフィック初期化（最初に呼び出す）
- `ProcessEvents()` - イベントポーリングANDフレームライフサイクル管理（begin_frame/end_frame）
- `DrawImage()`、`DrawString()` - レンダリングコマンド
- `NewImageHandle()`、`ImageHandle_Load()` - 画像管理
- `Shutdown()` - クリーンアップ（終了時に呼び出す）

### Metalバックエンドレンダーパイプライン

**重要なシーケンス**（厳密に従う必要があります）：

```
1. RenderInit()           - Metalを初期化
2. ProcessEvents()        - begin_frame() → renderEncoderを作成
3. SetClearColor()        - 背景色を設定
4. DrawString/DrawImage() - 描画コマンドをキューイング
5. ProcessEvents()        - end_frame() → バッチをフラッシュ、表示、新しいフレーム開始
6. ステップ3にループ
```

**絶対に**最初の`ProcessEvents()`の前に`DrawImage()`や`DrawString()`を呼び出さないでください - これはNULL renderEncoderエラーを引き起こします。

`pob2_launch.lua`の414-434行の正しいパターン：
```lua
while IsUserTerminated() == 0 do
    ProcessEvents()          -- 最初に呼び出す必要がある
    if launch.OnFrame then
        launch:OnFrame()     -- 描画コマンドはここで実行
    end
    ...
end
```

### Lua FFIブリッジ

**ファイル**: `pob2_launch.lua`
- FFI経由で48のSimpleGraphic C関数を宣言
- ImageHandleをLuaクラスとしてラップ
- グローバルをエクスポート（_G.RenderInit、_G.DrawImageなど）
- Lua型をC型に変換（文字列 → char*、数値 → float）

### Path of Building Luaコード

**エントリーポイント**: `src/Launch.lua`
- 初回起動時に更新
- devモードを検出
- レンダラーを初期化
- `Main`モジュールを読み込み
- フレームコールバックとキー処理を提供

**メインモジュール**: `src/Modules/Main.lua`
- ゲームバージョン、データ、計算モジュールを読み込み
- 2つのモードを管理：ビルドリストとビルド画面
- modキャッシュ、パッシブツリー、アイテムを読み込み

**主要モジュール**:
- `Build.lua` - ビルド画面コントロール、保存/読み込み、タブ
- `Calcs.lua` - ダメージ計算、ステータス計算
- `CalcSetup.lua` - modデータベース、スキルツリー、ジュエル
- `Data.lua` - ゲームデータ（アイテム、スキル、mod）
- `ModParser.lua` - modを解析してModCacheを生成

**主要クラス**:
- `PassiveTree.lua` / `PassiveTreeView.lua` - スキルツリーレンダリング
- `PassiveSpec.lua` - パッシブツリーデータとパス探索
- `TreeTab.lua` - ツリータブUI
- `Item.lua` - アイテム表現
- `ModDB.lua` / `ModList.lua` - 修飾子データベース

詳細なモジュール説明は`docs/rundown.md`を参照してください。

---

## 重要なコーディングパターン

### LuaJIT 5.1互換性

**重要**: このプロジェクトはLuaJIT 5.1を使用しており、Lua 5.4ではありません。Luaのベストプラクティスを確認する際は：
- 参照: https://www.lua.org/manual/5.1/
- Lua 5.2+の機能を避ける（ビット演算子、goto、_ENV）
- CインターオペラビリティにはLuaJIT FFIを使用
- `table.move()`よりも`table.insert()`を優先

### Nil安全パターン

PRJ-003で13の重要なnil安全修正があったため、アクセス前に常に検証してください：

**配列/テーブル**:
```lua
-- 悪い例
local value = node.nodesInRadius[3][nodeId]

-- 良い例
if node.nodesInRadius and node.nodesInRadius[3] then
    local value = node.nodesInRadius[3][nodeId]
end
```

**深いチェーン**:
```lua
-- 悪い例
local item = self.build.itemsTab.items[itemId]

-- 良い例
local itemsTab = self.build and self.build.itemsTab
local item = itemsTab and itemsTab.items[itemId]
```

**オプショナルフィールド**:
```lua
-- 欠落している重要なフィールドは常に初期化
if not node.pathDist then
    node.pathDist = 1000  -- デフォルト値
    ConPrintf("WARNING: Node %s had no pathDist, initialized to 1000", tostring(node.id))
end
```

### ProcessEvents()の呼び出し

各フレームで`Draw*()`コマンドの前に常に`ProcessEvents()`を呼び出してください：

```lua
-- 正しい
ProcessEvents()
DrawString(100, 100, "LEFT", 16, "", "Hello")
DrawImage(imageHandle, 0, 0, 64, 64, 0, 0, 1, 1)

-- 間違い（NULL renderEncoderを引き起こす）
DrawString(100, 100, "LEFT", 16, "", "Hello")
ProcessEvents()  -- 遅すぎる！
```

---

## ファイル同期（Artisanの重要責任）

**🔴 CRITICAL**: アプリバンドルはソースコードと自動的に同期されません。

**責任者**: Artisanエージェントは実装後に必ずファイル同期を実行する責任を負います（agents/07_artisan.md参照）。

### 同期が必要なファイル

以下のファイルを変更した後、**必ず**アプリバンドルにコピー：

1. **Luaソースコード**: `src/**/*.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/src/`
2. **起動スクリプト**: `pob2_launch.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/`
3. **ランタイムライブラリ**: `runtime/SimpleGraphic.dylib` → `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`

### 同期コマンド

```bash
# Luaファイルを個別に同期（例）
cp src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# srcディレクトリ全体を同期
cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/

# 起動スクリプトを同期
cp pob2_launch.lua PathOfBuilding.app/Contents/Resources/pob2macos/

# ランタイムライブラリを同期
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

### 同期検証

**必ず実行**: ファイル同期後、差分がないことを確認
```bash
diff src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveSpec.lua
```

---

## デバッグ

### コンソール出力

Luaデバッグ：
```lua
ConPrintf("DEBUG: value = %s", tostring(value))
print("Debug message")  -- 標準出力
```

C++デバッグ（Metalバックエンド）：
```objc
NSLog(@"DEBUG: renderEncoder = %@", renderEncoder);
printf("Debug message\n");  -- 標準出力
```

### アプリケーションログのキャプチャ

```bash
# ターミナルから実行してすべてのログを表示
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_debug.log

# システムログを確認
tail -f ~/Library/Logs/PathOfBuilding.log
```

### よくある問題

**luajitテスト実行時に「permission denied」**:
- 原因: macOSセキュリティ制限
- 修正: 代わりにアプリバンドルを直接起動

**「renderEncoder is NULL」警告**:
- 原因: ProcessEvents()の前にDrawImage/DrawStringが呼び出された
- 修正: ゲームループでProcessEvents()が最初であることを確認

**パッシブツリーが表示されない**:
- 確認: `Assets/`にアセットファイルが存在するか
- 確認: TreeTab.lua OnFrame()に描画呼び出しがあるか
- 確認: 描画コマンドの前にProcessEvents()が呼び出されているか
- 参照: `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/PASSIVE_TREE_DIAGNOSTIC.md`

**修正が反映されない**:
- 確認: ファイルがアプリバンドルにコピーされているか（ソースだけでなく）
- 検証: `PathOfBuilding.app/Contents/Resources/pob2macos/src/`に変更があるか

---

## ドキュメント（Bardの責任領域）

**責任者**: Bardエージェントはドキュメント作成とコミュニケーションを担当します（agents/06_bard.md参照）。

### リポジトリ内ドキュメント（技術仕様）

- `docs/rundown.md` - コードベース概要、モジュール説明
- `docs/addingSkills.md` - 新しいスキルの追加
- `docs/addingMods.md` - 修飾子の追加
- `docs/calcOffence.md` - 攻撃計算
- `docs/modSyntax.md` - 修飾子構文

### PRJ-003プロジェクトドキュメント

**場所**: `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/`

**技術レポート**:
- `LUA_QUALITY_CHECK_REPORT.md` - Luaコード品質評価
- `CRITICAL_FIXES_REPORT.md` - 重要なnil安全修正（13件）
- `PASSIVE_TREE_DIAGNOSTIC.md` - パッシブツリー表示トラブルシューティング
- `INSTALLATION_GUIDE.md` - セットアップ手順

**フェーズドキュメント**:
- `PHASE*.md` - 各フェーズの計画、実装、完了報告

**村の通信ログ**:
- `village_communications/*.yaml` - エージェント間の通信記録

### エージェントシステムドキュメント

**場所**: `/Users/kokage/national-operations/agents/`

- `00_overview.md` - **【必読】** マルチエージェントシステム全体構造
- `01-07_*.md` - 各エージェントの詳細定義

### 重要なコンテキスト（必読）

1. **Nil安全修正**: 5つのファイルに13の重要なnil安全修正を適用
   - Main.lua、PassiveSpec.lua、PassiveTreeView.lua、Launch.lua、TreeTab.lua

2. **Metal レンダーパイプライン**: ProcessEvents()の厳密な順序を要求
   - 必ず `ProcessEvents()` → `Draw*()` → `ProcessEvents()` の順序

3. **ファイル同期**: アプリバンドルのデプロイは手動（自動同期なし）
   - src/ → PathOfBuilding.app/Contents/Resources/pob2macos/src/
   - runtime/ → PathOfBuilding.app/Contents/Resources/pob2macos/runtime/

---

## 開発ワークフロー（エージェント統合版）

### マルチエージェントワークフロー

```
Prophet (計画立案)
  ↓
Mayor (タスク割り振り)
  ↓
Merchant (外部リサーチ) + Sage (技術検証) [並列実行可能]
  ↓
Artisan (実装・ファイル同期) [以下のワークフローを実行]
  ↓
Paladin (品質保証・実行検証) [テスト実行]
  ↓
Mayor (リスク評価・承認推奨)
  ↓
Prophet (最終承認・神への報告)
```

### C++変更ワークフロー（Artisan実行）

1. **技術検証（Sage）**: Metal API使用方法、パフォーマンス影響を確認
2. **C++コードを修正**: `simplegraphic/src/`内
3. **ライブラリを再ビルド**: `cd simplegraphic && make -C build`
4. **runtimeにコピー**: `cp simplegraphic/build/libSimpleGraphic.dylib runtime/`
5. **アプリにデプロイ**: `cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`
6. **ファイル同期検証**: `diff`で差分がないことを確認
7. **実行検証（Paladin）**: `./run_pob2.sh`または`open PathOfBuilding.app`でテスト

### Lua変更ワークフロー（Artisan実行）

1. **技術検証（Sage）**: Nil安全性、LuaJIT 5.1互換性を確認
2. **Luaコードを修正**: `src/`内
3. **アプリバンドルに同期**: `cp src/path/to/file.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/path/to/`
4. **ファイル同期検証**: `diff`で差分がないことを確認
5. **実行検証（Paladin）**: `./run_pob2.sh`でテスト、ログ収集、証拠記録

### ワークフロー完了時

**Artisan報告（YAML）**:
```yaml
artisan_implementation:
  status: COMPLETED
  files_modified: ["src/Classes/PassiveSpec.lua"]
  files_synced: ✅
  build_executed: ✅
  ready_for_verification: true
```

**Paladin検証（YAML）**:
```yaml
paladin_verification:
  status: APPROVED
  test_results: ["test_5sec.lua: PASS", "logs: no errors"]
  evidence_gathered: ["~/pob_debug.log", "screenshot.png"]
  acceptance_judgment: "実装は正常に動作、本番投入可"
```

**重要**: 常にアプリバンドルファイルを直接確認して、変更が反映されたことを検証してください。
