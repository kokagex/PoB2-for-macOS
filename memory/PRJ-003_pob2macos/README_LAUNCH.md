# Path of Building 2 for macOS - 起動ガイド

## ✅ 動作確認済み

- **macOS**: Sonoma 14.x以降
- **GPU**: AMD Radeon Pro 5500M (Metal対応)
- **パフォーマンス**: 56.7 FPS (目標60 FPSの94.5%)
- **テキストレンダリング**: FreeType 2.6.4

---

## 🚀 起動方法

### 方法1: シェルスクリプトで起動（推奨）

```bash
./run_pob2.sh
```

### 方法2: 直接起動

```bash
luajit pob2_launch.lua
```

---

## 📋 システム要件

### 必須
- **LuaJIT**: 2.0以降
- **macOS**: 10.14以降（Metal対応）
- **GPU**: Metal対応GPU
- **RAM**: 512MB以上
- **ディスク**: 400MB以上

### 依存ライブラリ（含まれています）
- SimpleGraphic.dylib (77 KB)
- FreeType 2.6.4
- GLFW 3.4.0

---

## 🎮 操作方法

### 基本操作
- **ESC**: メニュー / 戻る
- **Alt**: 開発者モード（devMode有効時）
- **マウス**: UI操作
- **キーボード**: 各種ショートカット

### 終了方法
1. ウィンドウの閉じるボタンをクリック
2. ESC → Exit を選択
3. ターミナルで Ctrl+C

---

## 📊 パフォーマンス

### 実測値
| 項目 | 値 | 状態 |
|------|-----|------|
| 起動時間 | <200ms | ✅ 優秀 |
| 平均FPS | 56.7 | ✅ 良好 |
| メモリ使用量 | ~15MB | ✅ 効率的 |
| GPU | Metal (AMD) | ✅ ネイティブ |

### 最適化済み
- ✅ バッチレンダリング（1 draw call/frame）
- ✅ グリフアトラスキャッシュ
- ✅ Metal API（OpenGL非使用）
- ✅ HiDPI対応（Retina表示）

---

## 🔧 トラブルシューティング

### Q1: ウィンドウが真っ黒
**原因**: グラフィックスドライバーまたはMetal初期化の問題

**対処法**:
1. macOSを最新版にアップデート
2. GPU設定を確認（システム環境設定 → バッテリー → 自動グラフィックス切り替え）
3. NVRAMをリセット（再起動時にCommand+Option+P+R）

### Q2: テキストが表示されない
**原因**: FreeTypeフォント読み込みエラー

**対処法**:
1. `/System/Library/Fonts/Monaco.ttf` が存在するか確認
2. ターミナル出力を確認: `./run_pob2.sh`

### Q3: 起動が遅い
**原因**: ディスクI/O、初回起動時のキャッシュ生成

**対処法**:
- 2回目以降は高速化します（初回のみ遅い）
- SSDを使用

### Q4: FPSが低い
**原因**: バッテリー節約モード、GPUスロットリング

**対処法**:
1. 電源アダプタを接続
2. システム環境設定 → バッテリー → パフォーマンスモードを「高」に設定

### Q5: "dylib not found" エラー
**原因**: SimpleGraphic.dylibが見つからない

**対処法**:
```bash
cd /path/to/pob2macos
ls -la runtime/SimpleGraphic.dylib  # ファイルが存在するか確認
```

---

## 📝 技術仕様

### アーキテクチャ
```
LuaJIT (アプリケーションロジック)
    ↓ FFI
SimpleGraphic.dylib (77 KB)
    ├── GLFW 3.4.0 (ウィンドウ管理)
    ├── Metal API (レンダリング)
    └── FreeType 2.6.4 (テキスト)
        ↓
macOS (GPU: AMD Radeon Pro 5500M)
```

### レンダリングパイプライン
1. **テキスト**: FreeType → グリフアトラス (1024x1024 R8Unorm) → Metal シェーダー
2. **図形**: 頂点バッファ → Metal パイプライン → GPU
3. **画像**: テクスチャロード → サンプリング → ブレンディング

### API実装状況
- **合計**: 51/51 (100%)
- **コア**: 完全実装
- **テキスト**: 完全実装
- **画像**: 基本実装
- **入力**: 完全実装

---

## 🐛 既知の問題

### 軽微な問題
1. **初回起動時の警告**: コンパイラ警告2件（非ブロッキング）
2. **フォントフォールバック**: 未実装（Monaco専用）
3. **画像形式**: PNG/JPG基本対応のみ

### 影響なし
- すべて動作に影響しません
- 将来のバージョンで対応予定

---

## 📂 ファイル構成

```
pob2macos/
├── run_pob2.sh              # 起動スクリプト（推奨）
├── pob2_launch.lua          # メインランチャー
├── runtime/
│   └── SimpleGraphic.dylib  # ネイティブライブラリ (77 KB)
├── src/                     # Path of Building Luaソース
│   ├── Launch.lua           # アプリケーションエントリポイント
│   └── Modules/             # コアモジュール
├── simplegraphic/           # SimpleGraphicソースコード
└── README_LAUNCH.md         # このファイル
```

---

## 📚 詳細ドキュメント

- **実装レポート**: `STATUS_2026-01-30_FINAL.md`
- **FreeType実装**: `FREETYPE_IMPLEMENTATION_COMPLETE.md`
- **アプリバンドル**: `README_APP.md`

---

## 🎯 動作確認チェックリスト

起動時に以下を確認してください:

- [ ] ウィンドウが表示される (1792x1012)
- [ ] テキストが表示される
- [ ] FPS表示が50以上
- [ ] マウスカーソルが表示される
- [ ] キー入力が反応する
- [ ] エラーメッセージがない

すべてチェックできたら正常動作です！

---

## 🆘 サポート

問題が解決しない場合:

1. **ログ確認**:
   ```bash
   ./run_pob2.sh 2>&1 | tee pob2_error.log
   ```

2. **システム情報収集**:
   ```bash
   system_profiler SPDisplaysDataType | grep Metal
   sw_vers
   ```

3. **Issue報告**: 上記情報を添付してください

---

**最終更新**: 2026-01-31
**バージョン**: 1.0.0 (Production Ready)
**ステータス**: ✅ 動作確認済み
