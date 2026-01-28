"""
データ解析モジュール

部品データのフィルタリング、処理、解析を担当
"""

import pandas as pd
from typing import Optional, Tuple, Dict
import os
from datetime import datetime
import data_storage
import config


class DataAnalyzer:
    """
    部品データを金額閾値に基づいて解析・フィルタリング

    機能:
    - 最低金額閾値でフィルタリング
    - データ検証とクリーニング
    - CSVエクスポート機能
    - 結果のソートと整理
    """

    def __init__(self, data: pd.DataFrame):
        """
        データでアナライザーを初期化

        Args:
            data: 部品データを含むDataFrame
        """
        self.original_data = data.copy()
        self.data = data
        self.filtered_data = None
        self.last_filter_params = None
        self.storage_manager = data_storage.DataStorageManager()

    def filter_by_amount(self, min_amount: float, limit: Optional[int] = None) -> pd.DataFrame:
        """
        金額閾値で部品をフィルタリング

        指定金額以上の高額部品を抽出:
        - amount >= min_amount
        - オプションで上位N件に制限

        Args:
            min_amount: 最低金額閾値（例: 100000）
            limit: 取得件数制限（Noneの場合は全件）

        Returns:
            フィルタリング済みDataFrame
        """
        try:
            # 入力パラメータを検証
            if min_amount < 0:
                raise ValueError("min_amountは0以上である必要があります")

            # オリジナルを変更しないようにコピー
            df = self.data.copy()

            # 数値列を確認
            if 'amount' in df.columns:
                df['amount'] = pd.to_numeric(df['amount'], errors='coerce')

            # フィルタを適用
            if 'amount' in df.columns:
                df = df[df['amount'] >= min_amount]

            # 金額で降順ソート（高額順）
            if 'amount' in df.columns:
                df = df.sort_values('amount', ascending=False)

            # 件数制限を適用
            if limit is not None and limit > 0:
                df = df.head(limit)

            # 結果を保存
            self.filtered_data = df.reset_index(drop=True)
            self.last_filter_params = {
                'min_amount': min_amount,
                'limit': limit
            }

            return self.filtered_data

        except Exception as e:
            print(f"データフィルタリングエラー: {e}")
            return pd.DataFrame()

    def get_filtered_data(self) -> pd.DataFrame:
        """現在のフィルタリング済みデータを取得"""
        if self.filtered_data is None:
            return pd.DataFrame()
        return self.filtered_data.copy()

    def get_filter_summary(self) -> Dict[str, any]:
        """
        現在のフィルタリング結果のサマリーを取得

        Returns:
            サマリー統計の辞書
        """
        if self.filtered_data is None or len(self.filtered_data) == 0:
            return {
                "total_rows": 0,
                "total_value": 0,
                "avg_value": 0,
                "filter_params": self.last_filter_params
            }

        total_amount = self.filtered_data['amount'].sum() if 'amount' in self.filtered_data.columns else 0
        avg_amount = self.filtered_data['amount'].mean() if 'amount' in self.filtered_data.columns else 0

        return {
            "total_rows": len(self.filtered_data),
            "total_value": total_amount,
            "avg_value": avg_amount,
            "min_value": self.filtered_data['amount'].min() if 'amount' in self.filtered_data.columns else 0,
            "max_value": self.filtered_data['amount'].max() if 'amount' in self.filtered_data.columns else 0,
            "filter_params": self.last_filter_params
        }

    def export_to_csv(self, filename: str = None) -> Tuple[bool, str]:
        """
        フィルタリング済みデータをCSVファイルにエクスポート

        Args:
            filename: 出力CSVファイル名。Noneの場合はタイムスタンプ付きで生成。

        Returns:
            (成功: bool, ファイルパス: str) のタプル
        """
        try:
            if self.filtered_data is None or len(self.filtered_data) == 0:
                return False, "エクスポートするデータがありません"

            # エクスポートフォルダがなければ作成
            export_folder = "exports"
            os.makedirs(export_folder, exist_ok=True)

            # ファイル名が指定されていない場合は生成
            if filename is None:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"部品エクスポート_{timestamp}.csv"

            filepath = os.path.join(export_folder, filename)

            # 表示用の列名に変換してエクスポート
            export_df = self.filtered_data.copy()

            # 列名を日本語に変換
            reverse_mapping = {v: k for k, v in config.COLUMN_MAPPING.items()}
            rename_dict = {}
            for col in export_df.columns:
                if col in reverse_mapping:
                    rename_dict[col] = reverse_mapping[col]
                elif col in config.DISPLAY_COLUMNS:
                    rename_dict[col] = config.DISPLAY_COLUMNS[col]

            if rename_dict:
                export_df = export_df.rename(columns=rename_dict)

            # CSVにエクスポート
            export_df.to_csv(filepath, index=False, encoding='utf-8-sig')

            return True, filepath

        except Exception as e:
            return False, f"エクスポート失敗: {str(e)}"

    def validate_data(self) -> Tuple[bool, str]:
        """
        データ構造と内容を検証

        チェック項目:
        - 必須列（amount）の存在
        - データ型の互換性
        - 重要な列が空でないこと

        Returns:
            (有効: bool, メッセージ: str) のタプル
        """
        try:
            # 空データをチェック
            if len(self.data) == 0:
                return False, "データが空です"

            # amount列をチェック（必須）
            if 'amount' not in self.data.columns:
                # 列名マッピング前のチェック
                if 'ﾈｯﾄ価格' not in self.data.columns:
                    return False, "金額列（amount または ﾈｯﾄ価格）が見つかりません"

            # データ型をチェック
            if 'amount' in self.data.columns:
                try:
                    pd.to_numeric(self.data['amount'], errors='coerce')
                except:
                    return False, "金額列は数値である必要があります"

            return True, "データ構造は有効です"

        except Exception as e:
            return False, f"検証エラー: {str(e)}"

    def reset_filters(self) -> None:
        """オリジナルデータにリセットしてフィルタをクリア"""
        self.data = self.original_data.copy()
        self.filtered_data = None
        self.last_filter_params = None

    def get_statistics(self) -> Dict[str, any]:
        """
        現在のデータの統計情報を取得

        Returns:
            データ統計の辞書
        """
        stats = {
            "total_parts": len(self.data),
            "columns": list(self.data.columns)
        }

        if 'amount' in self.data.columns:
            valid_amounts = self.data['amount'].dropna()
            if len(valid_amounts) > 0:
                stats['amount_stats'] = {
                    "min": valid_amounts.min(),
                    "max": valid_amounts.max(),
                    "mean": valid_amounts.mean(),
                    "median": valid_amounts.median(),
                    "total": valid_amounts.sum()
                }

        return stats

    def export_to_json(self, spreadsheet_id: str, sheet_name: str, filename: str = None) -> Tuple[bool, str]:
        """
        フィルタリング済みデータをJSONファイルにエクスポート

        Args:
            spreadsheet_id: Google スプレッドシートID
            sheet_name: シート名
            filename: 出力JSONファイル名。Noneの場合はデフォルトを使用。

        Returns:
            (成功: bool, メッセージ: str) のタプル
        """
        try:
            if self.filtered_data is None or len(self.filtered_data) == 0:
                return False, "エクスポートするデータがありません"

            success, result = self.storage_manager.save_to_json(
                df=self.filtered_data,
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name,
                filename=filename
            )

            if success:
                return True, f"JSONにエクスポートしました: {result}"
            else:
                return False, result

        except Exception as e:
            return False, f"JSONエクスポート失敗: {str(e)}"

    def filter_by_short_model(self, search_text: str, apply_to_filtered: bool = True) -> pd.DataFrame:
        """
        略式型式で部分一致検索

        Args:
            search_text: 検索テキスト（部分一致）
            apply_to_filtered: Trueの場合は現在のfiltered_dataに対して検索、Falseの場合はすべてのデータに対して検索

        Returns:
            フィルタリング済みDataFrame
        """
        try:
            if not search_text or not search_text.strip():
                # 空文字列の場合はフィルタリング済みデータをそのまま返す
                return self.filtered_data.copy() if apply_to_filtered and self.filtered_data is not None else pd.DataFrame()

            if apply_to_filtered:
                df = self.filtered_data.copy() if self.filtered_data is not None else self.data.copy()
            else:
                df = self.data.copy()

            # 部分一致検索（大文字小文字区別なし）
            if 'short_model' in df.columns:
                mask = df['short_model'].astype(str).str.contains(search_text, case=False, na=False)
                df = df[mask]

            return df.reset_index(drop=True)

        except Exception as e:
            print(f"検索フィルタリングエラー: {e}")
            return pd.DataFrame()

    def get_top_n_records(self, n: int = 10) -> pd.DataFrame:
        """
        フィルタリング済みデータから最初のN件を取得

        Args:
            n: 取得件数（デフォルト: 10）

        Returns:
            最初のN件のDataFrame
        """
        try:
            if self.filtered_data is None or len(self.filtered_data) == 0:
                return pd.DataFrame()

            # 既に金額で降順ソートされているので、先頭N件を取得
            return self.filtered_data.head(n).reset_index(drop=True)

        except Exception as e:
            print(f"トップN件取得エラー: {e}")
            return pd.DataFrame()
