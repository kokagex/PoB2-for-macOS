# WORKFLOW.md - マルチステップ手順

## C++変更ワークフロー

1. `simplegraphic/src/` のコード修正
2. ビルド:
   ```bash
   cd simplegraphic && make -C build
   ```
3. ランタイムにコピー:
   ```bash
   cp simplegraphic/build/libSimpleGraphic.dylib runtime/SimpleGraphic.dylib
   ```
4. アプリバンドルにデプロイ:
   ```bash
   cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
   ```
5. テスト: `./run_pob2.sh`

## Lua変更ワークフロー

1. `src/` のLuaコード修正（**サブエージェント経由**）
2. アプリバンドルに同期:
   ```bash
   # 単一ファイル
   cp src/Classes/TargetFile.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

   # 全体同期
   cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/
   ```
3. テスト: `./run_pob2.sh`
4. 変更反映確認: アプリバンドル内のファイルを直接確認

## SimpleGraphic初回ビルド

```bash
cd simplegraphic
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
```

オプション:
- Backend: `-DSG_BACKEND=metal`（推奨）/ `-DSG_BACKEND=opengl`
- Build Type: `Release`（推奨）/ `Debug`

## テストワークフロー

### ユニットテスト
```bash
busted spec/
```

### 統合テスト（LuaJIT）
```bash
luajit test_5sec.lua          # 基本描画（5秒）
luajit test_image_loading.lua # 画像読み込み
luajit test_text_rendering.lua # テキスト描画
luajit test_passive_tree_fixed.lua # パッシブツリー
luajit test_pob_launch.lua    # フル起動
```

### リグレッションテスト
```bash
./tests/regression_test.sh
```

注意: macOSセキュリティ制限でluajitテストが失敗する場合、アプリバンドルから直接起動。

## 視覚確認ワークフロー

1. ユーザーにアプリ起動を依頼
2. ユーザーが「撮った」と報告
3. 自動実行:
   ```bash
   pkill -f PathOfBuilding
   ```
4. スクリーンショットをReadツールで読み込み
5. 分析・結果報告
6. スクリーンショット削除

## アプリ実行方法

```bash
# シェルスクリプト経由
./run_pob2.sh

# アプリバンドル直接起動
open PathOfBuilding.app

# ターミナルからログ付き起動
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding

# ログキャプチャ
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_debug.log
```

## Metal Render Pipeline順序（厳守）

```
1. RenderInit()           → Metal初期化
2. ProcessEvents()        → begin_frame() → renderEncoder作成
3. SetClearColor()        → 背景色設定
4. DrawString/DrawImage() → 描画コマンドキュー
5. ProcessEvents()        → end_frame() → バッチフラッシュ → present → 新フレーム開始
6. ステップ3に戻る
```

**重要**: `DrawImage()`/`DrawString()` を最初の `ProcessEvents()` 前に呼ぶとNULL renderEncoderエラー。
