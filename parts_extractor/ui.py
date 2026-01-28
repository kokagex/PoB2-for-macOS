"""
Tkinter UIモジュール

高額部品抽出ツールのグラフィカルユーザーインターフェースを提供
"""

import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from typing import Optional
import sheets_api
import data_analyzer
import mock_data
import config


class PartsExtractorUI:
    """
    高額部品抽出ツールのメインUIクラス

    機能:
    - スプレッドシートID入力
    - シート選択ドロップダウン
    - 金額閾値入力
    - Treeviewでの結果表示
    - CSVエクスポート機能
    - ステータスメッセージとエラー処理
    """

    def __init__(self, root: tk.Tk):
        """
        UIを初期化

        Args:
            root: Tkinterのルートウィンドウ
        """
        self.root = root
        self.sheets_api = sheets_api.GoogleSheetsAPI()
        self.data_analyzer = None
        self.current_data = None

        # UI変数
        self.spreadsheet_id_var = tk.StringVar()
        self.sheet_name_var = tk.StringVar()
        self.amount_var = tk.StringVar(value=str(config.DEFAULT_MIN_AMOUNT))

        self._create_widgets()
        self._setup_layout()

        mode = "モック" if self.sheets_api.is_using_mock_data() else "Google Sheets"
        self._update_status(f"準備完了。{mode}データを使用中。")

    def _create_widgets(self) -> None:
        """全てのUIウィジェットを作成"""

        # メインコンテナ
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # グリッドウェイトを設定
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(3, weight=1)

        # === 入力セクション ===
        input_frame = ttk.LabelFrame(main_frame, text="設定", padding="10")
        input_frame.grid(row=0, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=10)
        input_frame.columnconfigure(1, weight=1)

        # スプレッドシートID
        ttk.Label(input_frame, text="スプレッドシートID:").grid(row=0, column=0, sticky=tk.W, padx=5)
        self.spreadsheet_id_entry = ttk.Entry(input_frame, textvariable=self.spreadsheet_id_var, width=50)
        self.spreadsheet_id_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=5)
        ttk.Label(input_frame, text="(URLから取得)", font=('Arial', 8), foreground='gray').grid(row=0, column=2, padx=5)

        # シート名
        ttk.Label(input_frame, text="シート名:").grid(row=1, column=0, sticky=tk.W, padx=5, pady=5)
        self.sheet_name_combo = ttk.Combobox(input_frame, textvariable=self.sheet_name_var, width=47, state='readonly')
        self.sheet_name_combo.grid(row=1, column=1, sticky=(tk.W, tk.E), padx=5, pady=5)

        # 金額閾値
        ttk.Label(input_frame, text="最低金額（円）:").grid(row=2, column=0, sticky=tk.W, padx=5, pady=5)
        self.amount_entry = ttk.Entry(input_frame, textvariable=self.amount_var, width=20)
        self.amount_entry.grid(row=2, column=1, sticky=tk.W, padx=5, pady=5)
        ttk.Label(input_frame, text="※この金額以上の部品を抽出", font=('Arial', 8), foreground='gray').grid(row=2, column=2, padx=5)

        # === ボタンセクション ===
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=10)

        self.get_data_button = ttk.Button(button_frame, text="データ取得", command=self._on_get_data_clicked)
        self.get_data_button.pack(side=tk.LEFT, padx=5)

        self.export_button = ttk.Button(button_frame, text="CSVエクスポート", command=self._on_export_clicked, state=tk.DISABLED)
        self.export_button.pack(side=tk.LEFT, padx=5)

        self.save_json_button = ttk.Button(button_frame, text="JSON保存", command=self._on_save_json_clicked, state=tk.DISABLED)
        self.save_json_button.pack(side=tk.LEFT, padx=5)

        self.refresh_sheets_button = ttk.Button(button_frame, text="シート一覧更新", command=self._refresh_sheet_list)
        self.refresh_sheets_button.pack(side=tk.LEFT, padx=5)

        # === 結果セクション ===
        results_frame = ttk.LabelFrame(main_frame, text="抽出結果", padding="10")
        results_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=10)
        results_frame.columnconfigure(0, weight=1)
        results_frame.rowconfigure(0, weight=1)

        # Treeview - 日本語列名
        self.tree_columns = config.TABLE_COLUMNS
        self.tree = ttk.Treeview(results_frame, columns=self.tree_columns, show='headings', height=15)

        # 列の見出しと幅を定義
        column_widths = {
            'part_id': 120,
            'part_name': 180,
            'amount': 120,
            'vehicle_name': 100,
            'short_model': 120,
            'body_color_name': 120,
        }

        for col in self.tree_columns:
            display_name = config.DISPLAY_COLUMNS.get(col, col)
            width = column_widths.get(col, 100)
            self.tree.heading(col, text=display_name)
            self.tree.column(col, width=width, anchor=tk.W)

        # スクロールバー
        vsb = ttk.Scrollbar(results_frame, orient=tk.VERTICAL, command=self.tree.yview)
        hsb = ttk.Scrollbar(results_frame, orient=tk.HORIZONTAL, command=self.tree.xview)
        self.tree.configure(yscroll=vsb.set, xscroll=hsb.set)

        self.tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        vsb.grid(row=0, column=1, sticky=(tk.N, tk.S))
        hsb.grid(row=1, column=0, sticky=(tk.W, tk.E))

        # === ステータスセクション ===
        status_frame = ttk.Frame(main_frame)
        status_frame.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=5)
        status_frame.columnconfigure(0, weight=1)

        self.status_label = ttk.Label(status_frame, text="準備完了", relief=tk.SUNKEN, font=('Arial', 9))
        self.status_label.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)

        # 情報ラベル
        self.info_label = ttk.Label(status_frame, text="", font=('Arial', 8), foreground='blue')
        self.info_label.grid(row=1, column=0, sticky=tk.W, padx=5)

    def _setup_layout(self) -> None:
        """ウィジェットレイアウトを設定"""
        # _create_widgetsで完了済み
        pass

    def _refresh_sheet_list(self) -> None:
        """利用可能なシートの一覧を更新"""
        spreadsheet_id = self.spreadsheet_id_var.get().strip()
        if not spreadsheet_id:
            messagebox.showwarning("警告", "スプレッドシートIDを入力してください")
            return

        self._update_status("シート一覧を取得中...")
        try:
            sheets = self.sheets_api.list_sheets(spreadsheet_id)
            if sheets:
                self.sheet_name_combo['values'] = sheets
                self.sheet_name_var.set(sheets[0])
                self._update_status(f"{len(sheets)}個のシートを取得しました")
            else:
                messagebox.showerror("エラー", "シートを取得できませんでした。デフォルトを使用します。")
                self.sheet_name_combo['values'] = ["Sheet1", "データ"]
                self._update_status("デフォルトのシート名を使用")
        except Exception as e:
            messagebox.showerror("エラー", f"シート一覧の取得に失敗しました: {e}")
            self._update_status(f"エラー: {e}")

    def _on_get_data_clicked(self) -> None:
        """データ取得ボタンのクリックイベントを処理"""
        spreadsheet_id = self.spreadsheet_id_var.get().strip()
        sheet_name = self.sheet_name_var.get().strip()

        if not spreadsheet_id:
            messagebox.showwarning("警告", "スプレッドシートIDを入力してください")
            return

        if not sheet_name:
            messagebox.showwarning("警告", "シート名を選択してください")
            return

        self._update_status(f"'{sheet_name}'からデータを取得中...")

        try:
            # APIまたはモックからデータを取得
            df = self.sheets_api.get_sheet_data(spreadsheet_id, sheet_name)

            if df is None or len(df) == 0:
                messagebox.showwarning("警告", "指定されたシートにデータがありません")
                self._update_status("データが見つかりません")
                return

            # データアナライザーを初期化
            self.data_analyzer = data_analyzer.DataAnalyzer(df)

            # データを検証
            is_valid, msg = self.data_analyzer.validate_data()
            if not is_valid:
                messagebox.showerror("エラー", f"データ検証に失敗しました: {msg}")
                self._update_status(f"検証失敗: {msg}")
                return

            # フィルタを適用
            try:
                min_amount = float(self.amount_entry.get())
            except ValueError:
                messagebox.showerror("エラー", "金額には数値を入力してください")
                self._update_status("無効な金額値")
                return

            filtered_df = self.data_analyzer.filter_by_amount(min_amount)

            # 結果を表示
            self._display_results(filtered_df)

            # ステータスを更新
            summary = self.data_analyzer.get_filter_summary()
            self._update_status(f"{summary['total_rows']}件の部品を表示。合計金額: ¥{summary['total_value']:,.0f}")
            self._update_info(f"フィルタ条件 - 最低金額: ¥{min_amount:,.0f}")

            # エクスポートと保存ボタンを有効化
            self.export_button.config(state=tk.NORMAL)
            self.save_json_button.config(state=tk.NORMAL)

        except Exception as e:
            messagebox.showerror("エラー", f"データの取得に失敗しました: {e}")
            self._update_status(f"エラー: {e}")

    def _on_export_clicked(self) -> None:
        """CSVエクスポートボタンのクリックイベントを処理"""
        if self.data_analyzer is None or self.data_analyzer.get_filtered_data().empty:
            messagebox.showwarning("警告", "エクスポートするデータがありません")
            return

        try:
            success, filepath = self.data_analyzer.export_to_csv()
            if success:
                messagebox.showinfo("成功", f"データをエクスポートしました:\n{filepath}")
                self._update_status(f"エクスポート完了: {filepath}")
            else:
                messagebox.showerror("エラー", filepath)
                self._update_status(f"エクスポート失敗: {filepath}")
        except Exception as e:
            messagebox.showerror("エラー", f"エクスポートに失敗しました: {e}")
            self._update_status(f"エクスポートエラー: {e}")

    def _on_save_json_clicked(self) -> None:
        """JSON保存ボタンのクリックイベントを処理"""
        if self.data_analyzer is None or self.data_analyzer.get_filtered_data().empty:
            messagebox.showwarning("警告", "保存するデータがありません")
            return

        try:
            spreadsheet_id = self.spreadsheet_id_var.get().strip()
            sheet_name = self.sheet_name_var.get().strip()

            if not spreadsheet_id or not sheet_name:
                messagebox.showwarning("警告", "スプレッドシートIDとシート名が必要です")
                return

            # フィルタリング済みデータを取得
            filtered_data = self.data_analyzer.get_filtered_data()

            # JSONに保存
            success, message = self.sheets_api.save_data_to_json(
                df=filtered_data,
                spreadsheet_id=spreadsheet_id,
                sheet_name=sheet_name
            )

            if success:
                messagebox.showinfo("成功", f"JSONに保存しました:\n{message}")
                self._update_status(f"JSON保存完了: {message}")
            else:
                messagebox.showerror("エラー", f"JSON保存に失敗しました:\n{message}")
                self._update_status(f"JSON保存失敗: {message}")

        except Exception as e:
            messagebox.showerror("エラー", f"JSON保存に失敗しました: {e}")
            self._update_status(f"JSON保存エラー: {e}")

    def _display_results(self, data) -> None:
        """
        Treeviewに結果を表示

        Args:
            data: フィルタリング済み結果のDataFrame
        """
        # 既存のアイテムをクリア
        for item in self.tree.get_children():
            self.tree.delete(item)

        # 新しいデータを挿入
        for index, row in data.iterrows():
            values = []
            for col in self.tree_columns:
                val = row.get(col, '')
                if col == 'amount' and val != '':
                    try:
                        values.append(f"¥{float(val):,.0f}")
                    except:
                        values.append(str(val))
                else:
                    values.append(str(val) if val != '' else '')
            self.tree.insert('', 'end', values=values)

    def _update_status(self, message: str) -> None:
        """
        ステータスメッセージを更新

        Args:
            message: 表示するステータスメッセージ
        """
        self.status_label.config(text=message)
        self.root.update()

    def _update_info(self, message: str) -> None:
        """
        情報メッセージを更新

        Args:
            message: 表示する情報メッセージ
        """
        self.info_label.config(text=message)
        self.root.update()
