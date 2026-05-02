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
- LuaJIT (`/usr/local/bin/luajit` — `package/MacOS/PathOfBuilding` ランチャースクリプトが exec する)
- Python 3 (SGPAK アーカイブパッカー)
- `codesign` (macOS 標準、リリースビルド時のみ)

## ディレクトリ構造 / Layout

```
src/                     上流 PoB と整合する Lua ソース (Modules, Classes, Data, Assets, Locales, Export)
runtime/lua/             Lua ライブラリ (sha1, dkjson, socket, base64, xml)
runtime/fonts/           macOS 専用フォント (LiberationSans 等は別配布)
runtime/*.dylib          SimpleGraphic / libSimpleGraphic / CharInput
                         (固定資産 — pob2macos の Dylib Rule によりリビルド禁止、tracked のまま配布)
tree-data/               PoE2 passive tree (バージョン別 0_1〜0_4 + 共通 PNG)
pob2_launch.lua          ルート起動スクリプト (CWD = Contents/Resources/ を仮定した相対参照)
LaunchServer.lua         OAuth 用ローカルサーバー
manifest.xml             マニフェスト (バージョン、ファイル一覧)
changelog.txt
package/Info.plist       .app bundle テンプレート (top-level)
package/Resources/       Info.plist + *.icns
package/MacOS/PathOfBuilding   起動ランチャー (zsh script、luajit pob2_launch.lua を exec)
pob2macos/tools/         SGPAK パッカー (rebuild_archives.sh)
scripts/build-app.sh     .app 組み立てスクリプト (本ガイド)
dist/                    ビルド出力 (gitignored)
```

## ビルド成果物の流れ / Build Pipeline

`scripts/build-app.sh` が以下を順に実行する:

1. `dist/PathOfBuilding.app/` のスケルトン作成 (`Contents/MacOS/`, `Contents/Resources/`)
2. `package/Info.plist` と `package/Resources/{Info.plist, *.icns}` をコピー
3. `package/MacOS/PathOfBuilding` (起動ランチャー) を `Contents/MacOS/` にコピー
4. `src/`, `runtime/`, `tree-data/` を `Contents/Resources/` 配下に配置
   - `--dev` mode: `ln -sfn` で symlink (Lua 編集即反映)
   - `--release` mode: `cp -R` でコピー
5. `pob2_launch.lua`, `LaunchServer.lua`, `manifest.xml`, `changelog.txt` を `Contents/Resources/` へコピー
6. `pob2macos/tools/rebuild_archives.sh` を `PATH_OF_BUILDING_RES` を渡して実行 → `Contents/Resources/archives/*.sgpak` を生成
7. `--release` mode のみ: `xattr -cr` → `codesign --deep` → `zip -ryq` で配布用 zip を作成

**注**: dylib (`SimpleGraphic.dylib` 他 2 つ) は `runtime/` 配下に tracked binary として持つ。pob2macos プロジェクトのルール (`pob2macos/.claude/CLAUDE.md` の Dylib Rule) により、SimpleGraphic.dylib のリビルドは UI を壊すため禁止。修正は Lua 側ラッパーで対応する建付け。

## 開発時 / Development Loop

```bash
# 初回: dev ビルド (symlink で組み立て)
bash scripts/build-app.sh --dev

# Lua 編集後: アプリ再起動だけで反映 (symlink なので rebuild 不要)
open dist/PathOfBuilding.app
```

## テスト / Testing

```bash
# Lua 単体テスト (busted)
busted

# Visual diff (起動 → スクリーンショット → baseline 比較)
POB_APP_DIR="$PWD/dist/PathOfBuilding.app" bash test/visual/run_visual_test.sh
```
