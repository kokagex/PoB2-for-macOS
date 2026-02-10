# LIBRARY.md - リファレンスリンク集

## Lua リファレンス
- LuaJIT 5.1 マニュアル: https://www.lua.org/manual/5.1/
- LuaJIT FFI: https://luajit.org/ext_ffi.html

## プロジェクトドキュメント
- `docs/rundown.md` - コードベース概要、モジュール説明
- `docs/addingSkills.md` - スキル追加方法
- `docs/addingMods.md` - Mod追加方法
- `docs/calcOffence.md` - 攻撃計算
- `docs/modSyntax.md` - Modifier構文

## PRJ-003 ドキュメント（`memory/PRJ-003_pob2macos/`）
- `LUA_QUALITY_CHECK_REPORT.md` - Luaコード品質評価
- `CRITICAL_FIXES_REPORT.md` - 13箇所のnil-safety修正
- `PASSIVE_TREE_DIAGNOSTIC.md` - パッシブツリー表示トラブルシュート
- `INSTALLATION_GUIDE.md` - セットアップ手順

## 学習データ（`doc/learning/`）
- `LESSONS_LEARNED.md` - 過去の教訓集
- `CRITICAL_FAILURE_ANALYSIS.md` - 重大失敗分析

## SimpleGraphic API
- ヘッダー: `simplegraphic/include/simplegraphic.h`（48エクスポート関数）
- Metal Backend: `simplegraphic/src/backend/metal/`（1015行）

## キーファイル
| ファイル | 役割 |
|---------|------|
| `pob2_launch.lua` | FFIブリッジ、グローバル関数エクスポート |
| `src/Launch.lua` | アプリケーションエントリーポイント |
| `src/Modules/Main.lua` | コアモジュール、ビルドリスト/ビルド画面管理 |
| `src/Modules/Build.lua` | ビルド画面、タブ管理、セーブ/ロード |
| `src/Modules/Calcs.lua` | ダメージ計算、ステータス算出 |
| `src/Modules/CalcSetup.lua` | Modデータベース、スキルツリー |
| `src/Modules/Data.lua` | ゲームデータ（アイテム、スキル、Mod） |
| `src/Modules/ModParser.lua` | Mod解析、ModCache生成 |
| `src/Classes/PassiveTree.lua` | スキルツリーデータ構造 |
| `src/Classes/PassiveTreeView.lua` | スキルツリー描画 |
| `src/Classes/PassiveSpec.lua` | パッシブツリーパス計算 |
| `src/Classes/TreeTab.lua` | ツリータブUI |
| `src/Classes/Item.lua` | アイテム表現 |
| `src/Classes/ModDB.lua` | Modifierデータベース |
| `src/Classes/ModList.lua` | Modifierリスト |

## SimpleGraphic C++構造
```
simplegraphic/src/
├── core/           - 初期化、状態管理
├── window/         - ウィンドウ作成、入力処理（GLFW）
├── rendering/      - 描画コマンド、画像、テキスト（FreeType）
├── backend/metal/  - Metal実装
├── utilities/      - ファイルシステム、圧縮、クリップボード
└── lua/            - Lua FFIバインディング
```

## 重要な関数（SimpleGraphic）
| 関数 | 用途 |
|------|------|
| `RenderInit()` | グラフィックス初期化（最初に呼ぶ） |
| `ProcessEvents()` | イベントポーリング + フレームライフサイクル |
| `DrawImage()` | 画像描画 |
| `DrawString()` | テキスト描画 |
| `NewImageHandle()` | 画像ハンドル作成 |
| `ImageHandle_Load()` | 画像読み込み |
| `Shutdown()` | クリーンアップ |
