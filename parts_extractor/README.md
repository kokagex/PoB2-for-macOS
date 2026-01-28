# 高額部品抽出ツール (Parts Extractor)

Google スプレッドシートから高額・低工程の部品を抽出するWindowsアプリケーション

## 概要

本ツールは、Google スプレッドシートに接続し、製造工程が少なく高額な部品を自動的に抽出します。製造計画やコスト最適化に活用できます。

**主な機能:**
- サービスアカウント認証によるGoogle Sheets接続
- 工程数・金額の閾値でフィルタリング
- 結果を表形式で表示
- CSV形式でエクスポート
- API未接続時はモックデータで動作

## 動作環境

- Windows 7 以降
- Python 3.8 以上（ソースから実行する場合）
- インターネット接続（Google Sheets API使用時）
- Google Cloud プロジェクト（Sheets API有効化済み）

## インストール方法

### 方法1: EXEファイルを使用（推奨）

1. `parts_extractor.exe` をダウンロード
2. ダブルクリックで実行（インストール不要）
3. `credentials.json` を EXE と同じフォルダに配置

### 方法2: ソースから実行

1. リポジトリをダウンロード
2. 依存パッケージをインストール:
   ```bash
   pip install -r requirements.txt
   ```
3. Google Sheets API の認証情報を設定（下記「設定」参照）
4. アプリケーションを起動:
   ```bash
   python main.py
   ```

## 設定

### Google Sheets API のセットアップ

1. **Google Cloud プロジェクトを作成:**
   - [Google Cloud Console](https://console.cloud.google.com/) にアクセス
   - 新しいプロジェクトを作成
   - Google Sheets API を有効化

2. **サービスアカウントを作成:**
   - Cloud Console で「サービスアカウント」を開く
   - 新しいサービスアカウントを作成
   - JSON形式のキーを作成
   - JSONファイルを `credentials.json` としてダウンロード

3. **credentials.json を配置:**
   - `credentials.json` をアプリケーションと同じフォルダにコピー
   - このファイルは機密情報のため、共有・公開しないこと

4. **スプレッドシートへのアクセス権を付与:**
   - 対象のスプレッドシートを開く
   - 「共有」からサービスアカウントのメールアドレスを追加
   - 「閲覧者」権限を付与

### アプリケーション設定

`config.py` で以下をカスタマイズ可能:
- `DEFAULT_MAX_PROCESS_COUNT`: 工程数の初期値（デフォルト: 3）
- `DEFAULT_MIN_AMOUNT`: 金額の初期値（デフォルト: 100,000円）
- `MOCK_DATA_ENABLED`: モックデータ使用フラグ

## 使い方

### アプリケーションの起動

**EXEから:**
`parts_extractor.exe` をダブルクリック

**ソースから:**
```bash
python main.py
```

### 操作手順

1. **スプレッドシートIDを入力:**
   - Google スプレッドシートのURLからIDをコピー
   - URL例: `https://docs.google.com/spreadsheets/d/{ここがID}/edit`

2. **シートを選択:**
   - ドロップダウンからシート名を選択

3. **閾値を設定:**
   - **工程数**: この数以下の部品を抽出
   - **金額（円）**: この金額以上の部品を抽出

4. **データ取得:**
   - 「データ取得」ボタンをクリック
   - 条件に合う部品が表に表示される

5. **結果のエクスポート:**
   - 「CSVエクスポート」ボタンをクリック
   - `exports/` フォルダにCSVファイルが保存される

## データ形式

スプレッドシートは以下の列構成を想定しています:

| 列名 | 型 | 説明 |
|------|------|------|
| part_id | 文字列 | 部品ID |
| part_name | 文字列 | 部品名 |
| process_count | 整数 | 工程数 |
| amount | 数値 | 金額（円） |
| manufacturer | 文字列 | 製造元 |
| notes | 文字列 | 備考（任意） |

### データ例:

| part_id | part_name | process_count | amount | manufacturer | notes |
|---------|-----------|---------------|--------|--------------|-------|
| P001 | 高速ベアリング | 2 | 250000 | ABC社 | 重要部品 |
| P002 | 精密ギア | 3 | 180000 | XYZ社 | 標準品 |
| P003 | 汎用ボルト | 1 | 50000 | 123社 | 低コスト |

## 機能詳細

### データフィルタリング
- **工程数フィルタ**: 製造工程が少ない部品を特定
- **金額フィルタ**: 高額な部品を特定

### 結果表示
- ソート可能なテーブル表示
- リアルタイムフィルタリング

### CSVエクスポート
- タイムスタンプ付きファイル名
- Excel互換（UTF-8 BOM付き）

### エラー処理
- API接続エラー時の自動フォールバック
- 15分以内にAPI接続できない場合、モックデータに切り替え
- わかりやすいエラーメッセージ

## トラブルシューティング

### 「Google Sheets への認証に失敗しました」
- `credentials.json` が正しい場所にあるか確認
- サービスアカウントにスプレッドシートへのアクセス権があるか確認

### 「シートが見つかりません」
- シート名が正確か確認（大文字・小文字を区別）
- 「データ取得」を押してシート一覧を更新

### アプリが起動しない
- 依存パッケージがインストールされているか確認: `pip install -r requirements.txt`
- Python 3.8 以上がインストールされているか確認

### データが表示されない
- スプレッドシートIDが正しいか確認
- シートに想定される列があるか確認
- 画面下部のステータスメッセージを確認

### モックデータが表示される
- API認証情報が正しく設定されているか確認
- インターネット接続を確認
- ログでAPIエラーを確認

## プロジェクト構成

```
parts_extractor/
├── main.py              # エントリーポイント
├── ui.py                # Tkinter GUI
├── sheets_api.py        # Google Sheets API 接続
├── data_analyzer.py     # データ解析ロジック
├── mock_data.py         # モックデータ生成
├── config.py            # 設定ファイル
├── requirements.txt     # 依存パッケージ
├── credentials.json     # Google認証情報（ユーザー配置）
├── README.md            # このファイル
└── dist/
    └── parts_extractor.exe  # Windows実行ファイル
```

## API検証リミット

開発時の安全装置として、API接続確認に15分の制限があります:

1. 15分以内にAPI接続できない場合、自動的にモックデータモードに切り替え
2. エラーログが `memory/api_error.md` に記録される
3. API設定が不完全でも開発を継続可能

## EXEのビルド方法

### 単一EXEファイルを作成

```bash
pip install pyinstaller
pyinstaller --onefile main.py --name parts_extractor
```

`dist/` フォルダにEXEが生成されます。

### アイコン付きでビルド

```bash
pyinstaller --onefile --icon=icon.ico main.py --name parts_extractor
```

## セキュリティとプライバシー

- **認証情報**: `credentials.json` はバージョン管理に含めないこと
- **データ**: 指定されたスプレッドシートのみ読み取り（読み取り専用）
- **通信**: Google API経由で暗号化通信
- **保存**: CSVエクスポートはローカルのみに保存

## バージョン履歴

### v1.0.0 - 2026-01-28
- 初回リリース
- Google Sheets API 連携
- フィルタリング・解析機能
- Tkinter GUI
- CSVエクスポート機能
- モックデータサポート
- PyInstaller EXE生成

## サポート

問題が発生した場合:
1. 上記「トラブルシューティング」を確認
2. 設定を見直す
3. アプリケーションログを確認

## ライセンス

内部利用限定
