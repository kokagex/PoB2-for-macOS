# JSON データストレージ機能 実装報告

**作成日:** 2026-01-28
**実装者:** Claude Code (Builder Agent)
**ステータス:** 完了

## 実装概要

スプレッドシートから取得したデータを `data/parts_list.json` に保存する機能を実装しました。

## 実装内容

### 1. 新規ファイル作成

#### `data_storage.py` (新規)
- **目的:** JSON ファイルへのデータ保存・読み込みを管理
- **主要クラス:** `DataStorageManager`
- **主要機能:**
  - `save_to_json()`: DataFrame を JSON に保存
  - `load_from_json()`: JSON からデータを読み込み
  - `_create_metadata()`: メタデータの生成
  - `get_file_info()`: ファイル情報の取得
  - `file_exists()`: ファイル存在確認

**特徴:**
- UTF-8 エンコーディング対応
- インデント付き JSON 出力（可読性向上）
- 自動で `data/` フォルダ作成
- メタデータにタイムスタンプを記録（ISO 8601 形式）

#### `.gitignore` (新規)
- `data/parts_list.json` を機密データとして指定
- `credentials.json` も保護

### 2. 既存ファイルの修正

#### `config.py`
**追加内容:**
```python
# JSON Data Storage Settings
DATA_STORAGE_FOLDER = "data"
JSON_STORAGE_FILENAME = "parts_list.json"
JSON_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%S"

def ensure_data_storage_folder() -> None:
    """Ensure data storage folder exists."""
    os.makedirs(DATA_STORAGE_FOLDER, exist_ok=True)
```

#### `sheets_api.py`
**追加内容:**
- `import data_storage` で DataStorageManager を統合
- `__init__` に `self.storage_manager = data_storage.DataStorageManager()` を追加
- `save_data_to_json()` メソッドを実装
- `get_saved_data_info()` メソッドを実装

#### `data_analyzer.py`
**追加内容:**
- `import data_storage` で統合
- `__init__` に `self.storage_manager` を初期化
- `export_to_json()` メソッドを実装

#### `ui.py`
**追加内容:**
- "Save to JSON" ボタンを追加
- `_on_save_json_clicked()` メソッドを実装
- データ取得後に Save JSON ボタンを有効化

### 3. JSON データ構造

保存される JSON ファイルの構造：

```json
{
  "metadata": {
    "spreadsheet_id": "xxx",
    "sheet_name": "Sheet1",
    "fetched_at": "2026-01-28T12:00:00",
    "row_count": 100
  },
  "columns": ["part_id", "part_name", "process_count", "amount", "manufacturer", "notes"],
  "data": [
    {"part_id": "P001", "part_name": "部品A", "process_count": 2, "amount": 150000, "manufacturer": "メーカーA", "notes": ""},
    ...
  ]
}
```

## 主要機能

### DataStorageManager クラス

| メソッド | 説明 | 戻り値 |
|---------|------|-------|
| `save_to_json()` | DataFrame を JSON に保存 | (bool, str) |
| `load_from_json()` | JSON からデータを読み込み | (DataFrame or None, Dict) |
| `file_exists()` | ファイル存在確認 | bool |
| `get_json_path()` | JSON ファイルのパスを取得 | str |
| `get_file_info()` | ファイル情報を取得 | Dict |

### UI 統合

1. **Save to JSON ボタン**
   - "Get Data" 実行後に有効化
   - フィルター済みデータを JSON に保存
   - 成功時にメッセージボックス表示
   - ステータスバーに結果を表示

2. **自動フォルダ生成**
   - `data/` フォルダが自動で作成される
   - 存在しない場合でもエラーなく処理

## テスト内容

`test_parts_extractor.py` に `TestDataStorage` クラスを追加：

| テスト | 説明 |
|-------|------|
| `test_storage_manager_initialization` | 初期化テスト |
| `test_save_to_json_success` | JSON 保存テスト |
| `test_save_to_json_with_custom_filename` | カスタムファイル名テスト |
| `test_load_from_json` | JSON 読み込みテスト |
| `test_json_metadata_structure` | メタデータ構造テスト |
| `test_save_empty_dataframe` | 空データ処理テスト |
| `test_file_exists_check` | ファイル存在確認テスト |
| `test_get_file_info` | ファイル情報取得テスト |

## エラーハンドリング

- 空の DataFrame に対する保存は失敗を返す
- ファイル I/O エラーは例外処理で適切に処理
- ユーザーに対しては分かりやすいエラーメッセージを表示

## セキュリティ対応

1. **機密データ保護:**
   - `.gitignore` に `data/parts_list.json` を追加
   - `credentials.json` も保護

2. **ユーザー指定情報:**
   - Spreadsheet ID と Sheet Name は UI から指定
   - メタデータとして JSON に記録

## ディレクトリ構造

```
parts_extractor/
├── config.py
├── sheets_api.py
├── data_analyzer.py
├── data_storage.py (新規)
├── ui.py
├── main.py
├── mock_data.py
├── test_parts_extractor.py
├── .gitignore (新規)
├── data/ (自動作成)
│   └── parts_list.json (出力ファイル)
└── memory/
    └── builder_json_storage.md (このファイル)
```

## 使用例

### プログラムから

```python
# DataStorageManager を直接使用
storage = data_storage.DataStorageManager()
success, filepath = storage.save_to_json(
    df=filtered_data,
    spreadsheet_id="1234567890",
    sheet_name="データ"
)

# DataAnalyzer から
analyzer = data_analyzer.DataAnalyzer(df)
analyzer.filter_by_thresholds(max_process_count=3, min_amount=100000)
success, msg = analyzer.export_to_json(
    spreadsheet_id="1234567890",
    sheet_name="データ"
)
```

### UI から

1. Spreadsheet ID を入力
2. Sheet Name を選択
3. "Get Data" をクリック
4. フィルター条件を設定
5. "Save to JSON" をクリック
6. 成功メッセージが表示される

## 今後の拡張可能性

1. **複数ファイル同時保存:** カスタムファイル名で複数の JSON を保存
2. **JSONスキーマ検証:** 出力 JSON が正しい構造か検証
3. **圧縮機能:** 大容量ファイルの圧縮保存
4. **差分保存:** 前回との差分のみ保存
5. **バージョン管理:** タイムスタンプ付きで複数バージョンを保存

## 完了チェックリスト

- [x] `data_storage.py` を新規作成
- [x] `config.py` に設定を追加
- [x] `sheets_api.py` にデータ保存機能を統合
- [x] `data_analyzer.py` に export_to_json() を追加
- [x] `ui.py` に Save to JSON ボタンを追加
- [x] `.gitignore` を作成（機密データ保護）
- [x] テストケースを追加
- [x] 作業報告を記録

## 実装完了日

2026-01-28 (実装時刻は記録なし)

---

**注記:** このドキュメントは実装時点での状態を記録しています。
今後の機能拡張や改善については、新しいドキュメントで記録してください。
