# CLAUDE.md

このファイルは、このリポジトリで作業する際にClaude Code (claude.ai/code)へのガイダンスを提供します。

## プロジェクト概要

**pob2macos**は、Path of Exile 2のビルドプランニングツールであるPath of Building 2のネイティブmacOSポートです。Lua + C++/Objective-Cのハイブリッドアプリケーションで、カスタムグラフィックバックエンドを使用しています。

**アーキテクチャ**: Luaアプリケーション層（292 MB）+ SimpleGraphic C++ライブラリ（Metalバックエンド）+ macOSアプリバンドル

**主要技術**:
- **グラフィック**: Metal API（メイン）、OpenGL（フォールバック）
- **スクリプティング**: LuaJIT 5.1とFFI（Lua 5.4ではない）
- **ウィンドウ管理**: GLFW3
- **テキストレンダリング**: FreeType2
- **ビルドシステム**: CMake 3.16+

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

## テスト

### テストフレームワーク

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

**重要**: macOSのセキュリティ制限により、一部のテストスクリプトはluajit経由で実行すると「permission denied」で失敗する場合があります。その場合は、アプリバンドルを直接起動してテストしてください。

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

## ファイル同期

**重要**: アプリバンドルはソースコードと自動的に同期されません。

以下のファイルを変更した後：
- `src/**/*.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/src/`にコピー
- `pob2_launch.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/`にコピー
- `runtime/SimpleGraphic.dylib` → `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`にコピー

**同期コマンド**:
```bash
# Luaファイルをアプリバンドルに同期（例）
cp src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# srcディレクトリ全体を同期
cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/
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

## ドキュメント

**リポジトリドキュメント**:
- `docs/rundown.md` - コードベース概要、モジュール説明
- `docs/addingSkills.md` - 新しいスキルの追加
- `docs/addingMods.md` - 修飾子の追加
- `docs/calcOffence.md` - 攻撃計算
- `docs/modSyntax.md` - 修飾子構文

**PRJ-003ドキュメント**（`/Users/kokage/national-operations/memory/PRJ-003_pob2macos/`内）:
- `LUA_QUALITY_CHECK_REPORT.md` - Luaコード品質評価
- `CRITICAL_FIXES_REPORT.md` - 重要なnil安全修正
- `PASSIVE_TREE_DIAGNOSTIC.md` - パッシブツリー表示トラブルシューティング
- `INSTALLATION_GUIDE.md` - セットアップ手順

**重要なコンテキスト**:
- 5つのファイルに13の重要なnil安全修正を適用（Main.lua、PassiveSpec.lua、PassiveTreeView.lua、Launch.lua、TreeTab.lua）
- MetalバックエンドレンダーパイプラインはProcessEvents()の厳密な順序を要求
- アプリバンドルのデプロイは手動（自動同期なし）

---

## 開発ワークフロー

1. **C++コードを修正**: `simplegraphic/src/`内
2. **ライブラリを再ビルド**: `cd simplegraphic && make -C build`
3. **runtimeにコピー**: `cp simplegraphic/build/libSimpleGraphic.dylib runtime/`
4. **アプリにデプロイ**: `cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`
5. **テスト**: `./run_pob2.sh`または`open PathOfBuilding.app`

Lua変更の場合：
1. **Luaコードを修正**: `src/`内
2. **アプリバンドルに同期**: `cp src/path/to/file.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/path/to/`
3. **テスト**: `./run_pob2.sh`

常にアプリバンドルファイルを直接確認して、変更が反映されたことを検証してください。
