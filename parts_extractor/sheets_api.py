"""
Google Sheets API 連携モジュール

Google スプレッドシートからのデータ取得を担当。
15分のAPI検証リミットとモックデータへのフェイルセーフを実装。
"""

import os
import json
import time
from typing import List, Dict, Optional, Tuple
import pandas as pd
from google.oauth2.service_account import Credentials as ServiceAccountCredentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import mock_data
import data_storage
import config


class GoogleSheetsAPI:
    """
    Google Sheets API操作インターフェース

    機能:
    - サービスアカウント認証
    - 指定シートからのデータ取得
    - シート一覧の取得
    - 15分の検証リミット
    - タイムアウト時のモックデータ自動切り替え
    - エラー処理とログ
    """

    # API検証開始時刻を追跡するクラス変数
    _verification_start_time = None
    _api_verification_limit = 900  # 15分（秒）

    def __init__(self, credentials_path: str = "credentials.json"):
        """
        Google Sheets APIクライアントを初期化

        Args:
            credentials_path: サービスアカウント認証JSONファイルのパス
        """
        self.credentials_path = credentials_path
        self.service = None
        self.api_available = False
        self.use_mock_data = False
        self._verification_failed = False
        self.storage_manager = data_storage.DataStorageManager()
        self._authenticate()

    def _authenticate(self) -> bool:
        """
        サービスアカウント認証を実行

        15分の検証タイマーを実装。15分以内に認証できない場合は
        モックデータに切り替えてエラーをログに記録。

        Returns:
            bool: 認証成功時True、失敗時False
        """
        # 検証タイマーを開始（まだ開始していない場合）
        if GoogleSheetsAPI._verification_start_time is None:
            GoogleSheetsAPI._verification_start_time = time.time()

        # 15分リミットを超えたかチェック
        elapsed = time.time() - GoogleSheetsAPI._verification_start_time
        if elapsed > GoogleSheetsAPI._api_verification_limit:
            self._handle_verification_timeout()
            return False

        try:
            if not os.path.exists(self.credentials_path):
                raise FileNotFoundError(f"認証ファイルが見つかりません: {self.credentials_path}")

            # 認証情報を読み込み
            with open(self.credentials_path, 'r') as f:
                credentials_info = json.load(f)

            # サービスアカウント認証を作成
            credentials = ServiceAccountCredentials.from_service_account_info(
                credentials_info,
                scopes=["https://www.googleapis.com/auth/spreadsheets.readonly"]
            )

            # Sheets APIサービスを構築
            self.service = build("sheets", "v4", credentials=credentials, cache_discovery=False)

            # API接続をテスト
            self._test_api_connection()

            self.api_available = True
            self.use_mock_data = False
            return True

        except FileNotFoundError as e:
            print(f"認証エラー: {e}")
            self._switch_to_mock_mode("認証ファイルが見つかりません")
            return False
        except json.JSONDecodeError as e:
            print(f"認証JSONが無効です: {e}")
            self._switch_to_mock_mode("認証ファイルのJSON形式が無効です")
            return False
        except Exception as e:
            print(f"認証エラー: {e}")
            self._switch_to_mock_mode(f"認証失敗: {str(e)}")
            return False

    def _test_api_connection(self) -> None:
        """
        API接続をテスト

        Raises:
            Exception: API接続テスト失敗時
        """
        if self.service is None:
            raise Exception("サービスが初期化されていません")

    def _switch_to_mock_mode(self, reason: str = "API利用不可") -> None:
        """
        モックデータモードに切り替えてエラーをログに記録

        Args:
            reason: モックモードに切り替えた理由
        """
        self.api_available = False
        self.use_mock_data = True
        self._verification_failed = True

        # エラーをファイルに記録
        self._log_api_error(reason)
        print(f"モックデータモードに切り替えました: {reason}")

    def _handle_verification_timeout(self) -> None:
        """15分のAPI検証タイムアウトを処理"""
        reason = "API検証が15分のリミットを超えました"
        self._switch_to_mock_mode(reason)
        self._log_api_error(reason)

    def _log_api_error(self, error_message: str) -> None:
        """
        APIエラーをmemory/api_error.mdファイルに記録

        Args:
            error_message: 記録するエラーメッセージ
        """
        try:
            memory_dir = os.path.join(os.path.dirname(__file__), "..", "memory")
            os.makedirs(memory_dir, exist_ok=True)

            error_file = os.path.join(memory_dir, "api_error.md")
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

            with open(error_file, 'a', encoding='utf-8') as f:
                f.write(f"\n## {timestamp}\n")
                f.write(f"**エラー:** {error_message}\n")
                f.write(f"**モジュール:** sheets_api.py\n")
                f.write(f"**対応:** モックデータモードに切り替え\n\n")
        except Exception as e:
            print(f"APIエラーのログ記録に失敗: {e}")

    def _apply_column_mapping(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        列名マッピングを適用

        Args:
            df: 元のDataFrame

        Returns:
            列名を変換したDataFrame
        """
        # 列名をマッピング
        rename_dict = {}
        for col in df.columns:
            if col in config.COLUMN_MAPPING:
                rename_dict[col] = config.COLUMN_MAPPING[col]

        if rename_dict:
            df = df.rename(columns=rename_dict)

        return df

    def get_sheet_data(self, spreadsheet_id: str, sheet_name: str) -> Optional[pd.DataFrame]:
        """
        指定シートからデータを取得

        APIが利用できない場合はモックデータにフォールバック

        Args:
            spreadsheet_id: Google スプレッドシートID
            sheet_name: 取得するシート名

        Returns:
            pandas.DataFrame または 取得失敗時None
        """
        # モックモードの場合はモックデータを返す
        if self.use_mock_data or not self.api_available:
            return mock_data.get_mock_data()

        try:
            if not self.service:
                raise Exception("APIが認証されていません")

            # 範囲文字列を構築（A:Zでほとんどの列をカバー）
            range_name = f"'{sheet_name}'!A:Z"

            # Sheets APIを呼び出し
            result = self.service.spreadsheets().values().get(
                spreadsheetId=spreadsheet_id,
                range=range_name
            ).execute()

            values = result.get('values', [])

            if not values:
                print(f"シートにデータがありません: {sheet_name}")
                return mock_data.get_mock_data()

            # DataFrameに変換
            headers = values[0]
            data = values[1:]

            # 行の長さをヘッダーに合わせる
            normalized_data = []
            for row in data:
                if len(row) < len(headers):
                    row = row + [''] * (len(headers) - len(row))
                elif len(row) > len(headers):
                    row = row[:len(headers)]
                normalized_data.append(row)

            df = pd.DataFrame(normalized_data, columns=headers)

            # 列名マッピングを適用
            df = self._apply_column_mapping(df)

            # 数値列を適切な型に変換
            if 'amount' in df.columns:
                df['amount'] = pd.to_numeric(df['amount'], errors='coerce')
            if 'stock_quantity' in df.columns:
                df['stock_quantity'] = pd.to_numeric(df['stock_quantity'], errors='coerce')

            return df

        except HttpError as e:
            print(f"API エラー（シート取得）: {e}")
            self._switch_to_mock_mode(f"APIエラー: {str(e)}")
            return mock_data.get_mock_data()
        except Exception as e:
            print(f"シートデータ処理エラー: {e}")
            return mock_data.get_mock_data()

    def list_sheets(self, spreadsheet_id: str) -> List[str]:
        """
        スプレッドシート内のシート名一覧を取得

        APIが利用できない場合は空のリストを返し、モックデータフォールバックを許可

        Args:
            spreadsheet_id: Google スプレッドシートID

        Returns:
            シート名のリスト、API利用不可時は空リスト
        """
        # モックモードの場合はデフォルトのシート名を返す
        if self.use_mock_data or not self.api_available:
            return ["Sheet1", "データ", "モックデータ"]

        try:
            if not self.service:
                raise Exception("APIが認証されていません")

            result = self.service.spreadsheets().get(
                spreadsheetId=spreadsheet_id,
                fields='sheets.properties.title'
            ).execute()

            sheets = result.get('sheets', [])
            sheet_names = [sheet['properties']['title'] for sheet in sheets]

            return sheet_names if sheet_names else []

        except HttpError as e:
            print(f"APIエラー（シート一覧）: {e}")
            return []
        except Exception as e:
            print(f"シート一覧取得エラー: {e}")
            return []

    def is_authenticated(self) -> bool:
        """APIが認証済みで利用可能かチェック"""
        return self.api_available and self.service is not None

    def is_using_mock_data(self) -> bool:
        """現在モックデータを使用中かチェック"""
        return self.use_mock_data

    def get_verification_status(self) -> Dict[str, any]:
        """
        現在の検証とAPIステータスを取得

        Returns:
            ステータス情報の辞書
        """
        elapsed = time.time() - (GoogleSheetsAPI._verification_start_time or time.time())

        return {
            "api_available": self.api_available,
            "using_mock_data": self.use_mock_data,
            "verification_failed": self._verification_failed,
            "time_elapsed": elapsed,
            "time_limit": GoogleSheetsAPI._api_verification_limit,
            "authenticated": self.is_authenticated()
        }

    def save_data_to_json(
        self,
        df: pd.DataFrame,
        spreadsheet_id: str,
        sheet_name: str,
        filename: str = None
    ) -> Tuple[bool, str]:
        """
        DataFrameをJSONファイルに保存

        Args:
            df: 保存するDataFrame
            spreadsheet_id: Google スプレッドシートID
            sheet_name: シート名
            filename: 出力JSONファイル名（デフォルト: parts_list.json）

        Returns:
            (成功: bool, メッセージ: str) のタプル
        """
        try:
            if self.storage_manager is None:
                return False, "ストレージマネージャーが初期化されていません"

            success, result = self.storage_manager.save_to_json(
                df=df,
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name,
                filename=filename
            )

            if success:
                return True, f"データを保存しました: {result}"
            else:
                return False, result

        except Exception as e:
            error_msg = f"データ保存エラー: {str(e)}"
            print(error_msg)
            return False, error_msg

    def get_saved_data_info(self, filename: str = None) -> Dict:
        """
        保存済みJSONファイルの情報を取得

        Args:
            filename: JSONファイル名（デフォルト: parts_list.json）

        Returns:
            ファイル情報の辞書
        """
        try:
            if self.storage_manager is None:
                return {"error": "ストレージマネージャーが初期化されていません"}

            return self.storage_manager.get_file_info(filename)

        except Exception as e:
            return {"error": str(e)}
