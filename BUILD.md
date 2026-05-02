# ビルドガイド / Build Guide

## クイックスタート / Quick Start

```bash
# 開発モード (Lua ソースは symlink、編集即反映)
bash scripts/build-app.sh --dev
open dist/PathOfBuilding.app

# リリースビルド (cp + codesign + zip)
VERSION=0.3.0 bash scripts/build-app.sh --release
ls dist/PathOfBuilding-macOS-0.3.0.zip
```

## 必要なもの / Requirements

- macOS (Apple Silicon, ARM64)
- Xcode Command Line Tools (`cmake`, `clang`, `make`, `codesign`)
- LuaJIT (テスト実行用)
- Python 3 (SGPAK アーカイブパッカー)

## ディレクトリ構造 / Layout

```
src/                     上流 PoB と整合する Lua ソース (Modules, Classes, Data, Assets, Locales, Export)
runtime/lua/             Lua ライブラリ (sha1, dkjson, socket, base64, xml)
runtime/fonts/           macOS 専用フォント (LiberationSans 等は別配布)
tree-data/               PoE2 passive tree (バージョン別 0_1〜0_4 + 共通 PNG)
pob2_launch.lua          ルート起動スクリプト (CWD = Contents/Resources/ を仮定した相対参照)
LaunchServer.lua         OAuth 用ローカルサーバー
manifest.xml             マニフェスト (バージョン、ファイル一覧)
changelog.txt
package/                 .app bundle テンプレート (Info.plist, .icns)
pob2macos/simplegraphic/ C++ レンダリングエンジン (CMakeLists.txt, dylib + binary を生成)
pob2macos/tools/         SGPAK パッカー (rebuild_archives.sh)
scripts/build-app.sh     .app 組み立てスクリプト (本ガイド)
dist/                    ビルド出力 (gitignored)
```

## ビルド成果物の流れ / Build Pipeline

`scripts/build-app.sh` が以下を順に実行する:

1. `dist/PathOfBuilding.app/` のスケルトン作成
2. `package/` から `Info.plist` と `.icns` をコピー
3. `pob2macos/simplegraphic/build/` で `cmake .. && make` を実行 → `PathOfBuilding` バイナリと 3 つの `.dylib` を生成し `Contents/{MacOS,Resources/runtime}` へ配置
4. `src/`, `runtime/lua/`, `tree-data/` を `Contents/Resources/` 配下に配置
   - `--dev` mode: `ln -sfn` で symlink (Lua 編集即反映)
   - `--release` mode: `cp -R` でコピー
5. `pob2_launch.lua`, `LaunchServer.lua`, `manifest.xml`, `changelog.txt` を `Contents/Resources/` へコピー
6. `pob2macos/tools/rebuild_archives.sh` を `PATH_OF_BUILDING_RES` を渡して実行 → `Contents/Resources/archives/*.sgpak` を生成
7. `--release` mode のみ: `xattr -cr` → `codesign --deep` → `zip -ryq` で配布用 zip を作成

## 開発時 / Development Loop

```bash
# 初回: dev ビルド (symlink で組み立て)
bash scripts/build-app.sh --dev

# Lua 編集後: アプリ再起動だけで反映 (symlink なので rebuild 不要)
open dist/PathOfBuilding.app

# C++ 変更時のみ: rebuild が必要
bash scripts/build-app.sh --dev
```

## テスト / Testing

```bash
# Lua 単体テスト (busted)
busted

# Visual diff (起動 → スクリーンショット → baseline 比較)
POB_APP_DIR="$PWD/dist/PathOfBuilding.app" bash test/visual/run_visual_test.sh
```
