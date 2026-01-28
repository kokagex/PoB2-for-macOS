"""
モックデータモジュール

テストおよびフェイルセーフ動作用のサンプル/ダミーデータを提供
"""

import pandas as pd
from typing import Dict, List


def get_mock_data() -> pd.DataFrame:
    """
    テスト用のモック部品データを生成

    Returns:
        モック部品データのDataFrame

    列:
        - part_id: 部品管理番号
        - part_name: 部品名
        - amount: ﾈｯﾄ価格（円）
        - vehicle_name: 車名
        - short_model: 略式型式
        - body_color_name: 車体カラー名称
    """
    mock_data = {
        "part_id": [
            "6577860700", "8817720100", "8963720100", "6972420100", "7234560100",
            "8123450200", "9012340300", "6789010400", "7890120500", "8901230600",
            "9012340700", "1234560800", "2345670900", "3456781000", "4567891100"
        ],
        "part_name": [
            "A/Cｺﾝﾌﾟﾚｯｻｰ",
            "ｴﾝｼﾞﾝASSY",
            "ｴﾝｼﾞﾝASSY",
            "ｴﾝｼﾞﾝASSY",
            "ﾄﾗﾝｽﾐｯｼｮﾝASSY",
            "ﾗｼﾞｴｰﾀ",
            "ｵﾙﾀﾈｰﾀ",
            "ｽﾀｰﾀﾓｰﾀ",
            "ﾄﾞｱﾐﾗｰ左",
            "ﾍｯﾄﾞﾗﾝﾌﾟ右",
            "ﾃｰﾙﾗﾝﾌﾟ左",
            "ﾊﾞﾝﾊﾟｰFr",
            "ﾌｪﾝﾀﾞｰ右",
            "ﾎﾞﾝﾈｯﾄ",
            "ﾄﾗﾝｸﾘｯﾄﾞ"
        ],
        "amount": [
            120000, 100000, 100000, 100000, 150000,
            85000, 45000, 38000, 25000, 32000,
            18000, 55000, 42000, 78000, 35000
        ],
        "vehicle_name": [
            "フィット", "スイフト", "ワゴンR", "ムーヴ", "プリウス",
            "ノート", "デミオ", "ekワゴン", "インプレッサ", "N-BOX",
            "ヴィッツ", "マーチ", "アクセラ", "アルト", "タント"
        ],
        "short_model": [
            "GK3", "ZC33S", "MH34S", "LA100S", "ZVW30",
            "E12", "DJ3FS", "B11W", "GP7", "JF1",
            "NSP130", "K13", "BM5FP", "HA36S", "LA600S"
        ],
        "body_color_name": [
            "クリスタルブラックパール", "ピュアホワイトパール", "シルキーシルバーメタリック",
            "ブラックマイカメタリック", "ホワイトパールクリスタルシャイン",
            "ブリリアントシルバーメタリック", "ソウルレッドプレミアムメタリック",
            "ホワイトソリッド", "クリスタルホワイトパール", "プレミアムホワイトパール",
            "スーパーホワイトII", "ダークメタルグレーメタリック", "ソウルレッドクリスタルメタリック",
            "ピュアホワイトパール", "パールホワイトIII"
        ],
        "part_code": [
            "6070", "2010", "2010", "2010", "3010",
            "4020", "5010", "5020", "7010", "7020",
            "7030", "8010", "8020", "8030", "8040"
        ],
        "manufacturer": [
            "ホンダ", "スズキ", "スズキ", "ダイハツ", "トヨタ",
            "日産", "マツダ", "三菱", "スバル", "ホンダ",
            "トヨタ", "日産", "マツダ", "スズキ", "ダイハツ"
        ]
    }

    df = pd.DataFrame(mock_data)
    return df


def get_sample_data_structure() -> Dict[str, str]:
    """
    期待されるデータの構造/スキーマを取得

    Returns:
        データ構造を説明する辞書
    """
    return {
        "part_id": "string - 部品管理番号",
        "part_name": "string - 部品名",
        "amount": "float - ﾈｯﾄ価格（円）",
        "vehicle_name": "string - 車名",
        "short_model": "string - 略式型式",
        "body_color_name": "string - 車体カラー名称"
    }


def create_empty_dataframe() -> pd.DataFrame:
    """
    正しいスキーマで空のDataFrameを作成

    Returns:
        適切な列を持つ空のDataFrame
    """
    columns = ["part_id", "part_name", "amount", "vehicle_name", "short_model", "body_color_name"]
    return pd.DataFrame(columns=columns)


def validate_mock_data(df: pd.DataFrame) -> tuple[bool, str]:
    """
    モックデータが正しい構造を持っているか検証

    Args:
        df: 検証するDataFrame

    Returns:
        (有効かどうか, メッセージ) のタプル
    """
    required_columns = ["part_id", "part_name", "amount"]

    missing_columns = [col for col in required_columns if col not in df.columns]
    if missing_columns:
        return False, f"不足している列: {', '.join(missing_columns)}"

    if len(df) == 0:
        return False, "DataFrameが空です"

    # データ型を検証
    if 'amount' in df.columns:
        if not pd.api.types.is_numeric_dtype(df["amount"]):
            return False, "金額は数値である必要があります"

    return True, "モックデータは有効です"
