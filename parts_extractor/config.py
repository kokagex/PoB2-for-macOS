"""
設定モジュール

高額部品抽出ツールの設定を管理
"""

import os

# アプリケーション設定
APP_NAME = "高額部品抽出ツール"
APP_VERSION = "1.2.0"

# ファイルパス
CREDENTIALS_FILE = "credentials.json"
MOCK_DATA_ENABLED = True  # APIが利用できない場合はTrue

# Google Sheets API設定
GOOGLE_SHEETS_SCOPE = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
API_TIMEOUT = 30  # 秒

# UIデフォルト設定
DEFAULT_WINDOW_WIDTH = 1100
DEFAULT_WINDOW_HEIGHT = 650

# フィルタデフォルト値
DEFAULT_MIN_AMOUNT = 100000  # 円

# CSVエクスポート設定
CSV_EXPORT_FOLDER = "exports"
CSV_TIMESTAMP_FORMAT = "%Y%m%d_%H%M%S"

# JSONデータ保存設定
DATA_STORAGE_FOLDER = "data"
JSON_STORAGE_FILENAME = "parts_list.json"
JSON_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%S"

# ログ設定
LOG_ENABLED = True
LOG_FILE = "parts_extractor.log"
LOG_LEVEL = "INFO"

# 実際のスプレッドシート列名マッピング
# スプレッドシートの列名 → アプリ内部の列名
COLUMN_MAPPING = {
    '部品管理番号': 'part_id',
    '登録日': 'registration_date',
    '部品コード': 'part_code',
    '部品名': 'part_name',
    '在庫ステータス区分': 'stock_status',
    '品質区分': 'quality_grade',
    '部品送料区分': 'shipping_category',
    '保管場所': 'storage_location',
    'ﾈｯﾄ価格': 'amount',
    'ネット価格': 'amount',
    '新品価格': 'new_price',
    '小売価格': 'retail_price',
    '原価': 'cost',
    '在庫数': 'stock_quantity',
    '生産数': 'production_quantity',
    '固定区分': 'fixed_category',
    '部品ﾒｰｶｰ': 'parts_maker',
    '部品メーカー': 'parts_maker',
    '部品ﾒｰｶｰ品番': 'maker_part_number',
    '部品メーカー品番': 'maker_part_number',
    'メーカー純正品番': 'oem_part_number',
    'メーカー代替品番': 'alt_part_number',
    '自社品番': 'internal_part_number',
    '部品カラー': 'part_color',
    '部品マイナー': 'part_minor',
    'カルテ番号': 'chart_number',
    'メーカーコード': 'maker_code',
    'メーカー': 'manufacturer',
    '車名コード': 'vehicle_code',
    # 新規追加
    '車名': 'vehicle_name',
    '略式型式': 'short_model',
    '車体カラー名称': 'body_color_name',
    '型式': 'model_type',
    '通称型式': 'common_model',
    '認定型式': 'certified_model',
    '年式': 'year',
    '駆動方式': 'drive_type',
    'グレード': 'grade',
    '車体カラー': 'body_color',
    '排気量': 'displacement',
    'エンジン型式': 'engine_type',
}

# UI表示用の列名（日本語）
DISPLAY_COLUMNS = {
    'part_id': '部品管理番号',
    'part_name': '部品名',
    'amount': 'ﾈｯﾄ価格',
    'vehicle_name': '車名',
    'short_model': '略式型式',
    'body_color_name': '車体カラー名称',
    'part_code': '部品コード',
    'quality_grade': '品質区分',
    'manufacturer': 'メーカー',
}

# テーブル表示する列（順序）
TABLE_COLUMNS = [
    'part_id',
    'part_name',
    'amount',
    'vehicle_name',
    'short_model',
    'body_color_name',
]


def get_credentials_path() -> str:
    """認証ファイルのフルパスを取得"""
    return os.path.join(os.path.dirname(__file__), CREDENTIALS_FILE)


def ensure_export_folder() -> None:
    """エクスポートフォルダが存在することを確認"""
    os.makedirs(CSV_EXPORT_FOLDER, exist_ok=True)


def ensure_data_storage_folder() -> None:
    """データ保存フォルダが存在することを確認"""
    os.makedirs(DATA_STORAGE_FOLDER, exist_ok=True)
