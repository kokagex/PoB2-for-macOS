# Path of Building - macOS Demo Application

## 概要

SimpleGraphic.dylibの動作確認用デモアプリケーションです。
黒い画面問題が解決され、正常にウィンドウが表示されることを確認できます。

## 起動方法

### 方法1: Finderから起動（推奨）

1. Finderで `PathOfBuilding.app` を探す
2. ダブルクリックして起動

または、ターミナルから：
```bash
open /Users/kokage/national-operations/pob2macos/PathOfBuilding.app
```

### 方法2: ターミナルから直接起動

```bash
cd /Users/kokage/national-operations/pob2macos
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding
```

## 表示内容

アプリを起動すると、以下が表示されます：

- **タイトル**: "Path of Building - macOS Edition"
- **サブタイトル**: "SimpleGraphic.dylib Demo Application"
- **ステータス**: "黒い画面問題が解決されました！"
- **FPS**: リアルタイムフレームレート（約55-60 FPS）
- **実行時間**: 起動からの経過時間
- **マウス位置**: リアルタイムでマウス座標を追跡
- **グラフィックス情報**: Metal GPU使用状況

## 操作方法

- **ESCキー**: アプリケーションを終了
- **マウス移動**: カーソル位置が画面に表示されます

## 技術詳細

### グラフィックスバックエンド
- **API**: Metal (Apple標準)
- **GPU**: AMD Radeon Pro 5500M
- **ウィンドウシステム**: GLFW 3.4.0
- **解像度**: Retina対応（DPI scale 2.0）

### パフォーマンス
- **フレームレート**: 約55-60 FPS
- **レンダリング**: Metalシェーダーをランタイムコンパイル
- **メモリ管理**: 安定したリソース管理

### ライブラリ構成
- **SimpleGraphic.dylib**: 49KB
- **場所**: PathOfBuilding.app/Contents/Resources/

## トラブルシューティング

### アプリが起動しない場合

1. **実行権限の確認**:
   ```bash
   chmod +x PathOfBuilding.app/Contents/MacOS/PathOfBuilding
   ```

2. **LuaJITのインストール確認**:
   ```bash
   which luajit
   # 出力: /usr/local/bin/luajit
   ```

3. **ライブラリの確認**:
   ```bash
   ls -lh PathOfBuilding.app/Contents/Resources/SimpleGraphic.dylib
   ```

### セキュリティ警告が出る場合

macOSのセキュリティ設定で、未署名のアプリケーションをブロックする場合があります：

1. 「システム設定」→「プライバシーとセキュリティ」を開く
2. 「このまま開く」をクリック

または：
```bash
xattr -cr PathOfBuilding.app
```

## 次のステップ

この動作確認が成功したら、本格的なPath of Buildingアプリケーションの統合を進めることができます：

1. **完全なLua統合**: LoadModule(), PLoadModule()の実装
2. **テキストレンダリング**: FreeTypeによる完全な文字描画
3. **画像読み込み**: stb_imageによるPNG/JPEG対応
4. **UI要素**: ボタン、テキストボックス等の実装

## 実装完了済み機能

✅ ウィンドウ表示（黒い画面問題解決）  
✅ Metalバックエンド  
✅ イベント処理  
✅ 入力ハンドリング（キーボード・マウス）  
✅ フレームレート管理  
✅ リソース管理  

## 開発者情報

- **プロジェクト**: Path of Building macOS移植
- **グラフィックスライブラリ**: SimpleGraphic.dylib
- **開発日**: 2026-01-30
- **ステータス**: MVP完成

---

**問題が解決されました！ウィンドウが正常に表示されます。**
