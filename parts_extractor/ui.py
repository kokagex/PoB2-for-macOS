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
        self.filtered_data = None

        # UI変数
        self.spreadsheet_id_var = tk.StringVar()
        self.sheet_name_var = tk.StringVar()
        self.amount_var = tk.StringVar(value=str(config.DEFAULT_MIN_AMOUNT))
        self.short_model_var = tk.StringVar()
        self.limit_var = tk.BooleanVar(value=False)
        self.limit_count_var = tk.StringVar(value="10")

        # ソート管理
        self.sort_column = None
        self.sort_ascending = True

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

        # 略式型式検索
        ttk.Label(input_frame, text="略式型式で検索:").grid(row=3, column=0, sticky=tk.W, padx=5, pady=5)
        self.short_model_entry = ttk.Entry(input_frame, textvariable=self.short_model_var, width=47)
        self.short_model_entry.grid(row=3, column=1, sticky=(tk.W, tk.E), padx=5, pady=5)
        ttk.Label(input_frame, text="※部分一致で検索", font=('Arial', 8), foreground='gray').grid(row=3, column=2, padx=5)

        # 件数制限
        limit_frame = ttk.Frame(input_frame)
        limit_frame.grid(row=4, column=0, columnspan=3, sticky=tk.W, padx=5, pady=5)
        self.limit_checkbox = ttk.Checkbutton(limit_frame, text="上位N件のみ表示", variable=self.limit_var, command=self._on_limit_checkbox_changed)
        self.limit_checkbox.pack(side=tk.LEFT, padx=5)
        self.limit_spinbox = ttk.Spinbox(limit_frame, from_=1, to=1000, textvariable=self.limit_count_var, width=5, state=tk.DISABLED)
        self.limit_spinbox.pack(side=tk.LEFT, padx=5)
        ttk.Label(limit_frame, text="件", font=('Arial', 8)).pack(side=tk.LEFT, padx=2)

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

        # フィルタ適用ボタン
        self.apply_filter_button = ttk.Button(button_frame, text="フィルタ適用", command=self._on_apply_filter_clicked, state=tk.DISABLED)
        self.apply_filter_button.pack(side=tk.LEFT, padx=5)

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
            self.tree.heading(col, text=display_name, command=lambda c=col: self._on_column_header_click(c))
            self.tree.column(col, width=width, anchor=tk.W)

        # スクロールバー
        vsb = ttk.Scrollbar(results_frame, orient=tk.VERTICAL, command=self.tree.yview)
        hsb = ttk.Scrollbar(results_frame, orient=tk.HORIZONTAL, command=self.tree.xview)
        self.tree.configure(yscroll=vsb.set, xscroll=hsb.set)

        # ダブルクリックイベント
        self.tree.bind("<Double-Button-1>", self._on_row_double_click)

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

            # ボタンを有効化
            self.export_button.config(state=tk.NORMAL)
            self.save_json_button.config(state=tk.NORMAL)
            self.apply_filter_button.config(state=tk.NORMAL)

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

        # フィルタ済みデータを保持
        self.filtered_data = data.reset_index(drop=True)

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
            # tree_idとしてインデックスを使用
            self.tree.insert('', 'end', iid=str(index), values=values)

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

    def _on_limit_checkbox_changed(self) -> None:
        """件数制限チェックボックスの状態変化イベント"""
        if self.limit_var.get():
            self.limit_spinbox.config(state=tk.NORMAL)
        else:
            self.limit_spinbox.config(state=tk.DISABLED)

    def _on_apply_filter_clicked(self) -> None:
        """フィルタ適用ボタンのクリックイベント"""
        if self.data_analyzer is None:
            messagebox.showwarning("警告", "先にデータを取得してください")
            return

        try:
            # 金額でフィルタ
            min_amount = float(self.amount_entry.get())
            filtered_df = self.data_analyzer.filter_by_amount(min_amount)

            # 略式型式で検索
            search_text = self.short_model_var.get().strip()
            if search_text:
                filtered_df = self.data_analyzer.filter_by_short_model(search_text)

            # 件数制限を適用
            if self.limit_var.get():
                try:
                    limit_count = int(self.limit_count_var.get())
                    filtered_df = filtered_df.head(limit_count)
                except ValueError:
                    messagebox.showerror("エラー", "件数は整数で入力してください")
                    return

            # 結果を表示
            self._display_results(filtered_df)

            # ステータスを更新
            summary = self.data_analyzer.get_filter_summary()
            if search_text:
                self._update_status(f"{len(filtered_df)}件の部品を表示（検索: {search_text}）")
            else:
                self._update_status(f"{len(filtered_df)}件の部品を表示")

            # ボタンを有効化
            self.export_button.config(state=tk.NORMAL)
            self.save_json_button.config(state=tk.NORMAL)

        except ValueError:
            messagebox.showerror("エラー", "金額には数値を入力してください")

    def _on_column_header_click(self, column: str) -> None:
        """列ヘッダークリックイベント - ソート機能"""
        if self.filtered_data is None or len(self.filtered_data) == 0:
            return

        # 同じ列をクリックした場合は昇順/降順を切り替え
        if self.sort_column == column:
            self.sort_ascending = not self.sort_ascending
        else:
            self.sort_column = column
            self.sort_ascending = True

        # データをソート
        try:
            sorted_data = self.filtered_data.copy()
            sorted_data = sorted_data.sort_values(column, ascending=self.sort_ascending, na_position='last')
            self._display_results(sorted_data)

            # ヘッダーに矢印を表示
            self._update_column_headers()

            # ステータスを更新
            direction = "昇順" if self.sort_ascending else "降順"
            col_display_name = config.DISPLAY_COLUMNS.get(column, column)
            self._update_status(f"{col_display_name}で{direction}ソート中")

        except Exception as e:
            messagebox.showerror("エラー", f"ソート処理に失敗しました: {e}")

    def _update_column_headers(self) -> None:
        """ソート状態を反映してヘッダーを更新"""
        for col in self.tree_columns:
            display_name = config.DISPLAY_COLUMNS.get(col, col)
            if col == self.sort_column:
                indicator = " ▲" if self.sort_ascending else " ▼"
                self.tree.heading(col, text=display_name + indicator)
            else:
                self.tree.heading(col, text=display_name)

    def _on_row_double_click(self, event) -> None:
        """行のダブルクリックイベント"""
        selection = self.tree.selection()
        if not selection:
            return

        # 選択された行のインデックスを取得
        item_id = selection[0]
        try:
            row_index = int(item_id)
            if self.filtered_data is not None and row_index < len(self.filtered_data):
                row_data = self.filtered_data.iloc[row_index]
                self._show_detail_dialog(row_data)
        except (ValueError, IndexError):
            messagebox.showerror("エラー", "選択された行の情報を取得できません")

    def _show_detail_dialog(self, row_data) -> None:
        """詳細情報をポップアップウィンドウで表示"""
        # Toplevelウィンドウを作成
        detail_window = tk.Toplevel(self.root)
        detail_window.title("部品詳細情報")
        detail_window.geometry("600x800")
        detail_window.resizable(True, True)

        # メインフレーム（スクロール対応）
        main_frame = ttk.Frame(detail_window)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # Canvas とスクロールバーの作成
        canvas = tk.Canvas(main_frame, bg='white')
        scrollbar = ttk.Scrollbar(main_frame, orient=tk.VERTICAL, command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)

        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscroll=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # カテゴリ別にグループ化
        categories = {
            "基本情報": ["part_id", "part_name", "amount"],
            "車両情報": ["vehicle_name", "short_model", "body_color_name", "model_year", "engine_model"],
            "在庫・品質情報": ["stock_status", "quality_category", "storage_location"],
            "その他情報": ["part_code", "maker_name", "registration_date"]
        }

        for category_name, columns in categories.items():
            # カテゴリごとのLabelFrame
            category_frame = ttk.LabelFrame(scrollable_frame, text=category_name, padding=10)
            category_frame.pack(fill=tk.X, padx=5, pady=5)

            for col in columns:
                if col in row_data.index:
                    label_text = config.DISPLAY_COLUMNS.get(col, col)
                    value = row_data[col]

                    # 金額フォーマット
                    if col == "amount" and value != "":
                        try:
                            display_value = f"¥{float(value):,.0f}"
                        except:
                            display_value = str(value)
                    else:
                        display_value = str(value) if value != "" else "未設定"

                    # 項目名と値
                    row_frame = ttk.Frame(category_frame)
                    row_frame.pack(fill=tk.X, pady=3)

                    ttk.Label(row_frame, text=label_text + ":", font=('Arial', 9, 'bold'), width=15).pack(side=tk.LEFT, anchor=tk.W)
                    ttk.Label(row_frame, text=display_value, font=('Arial', 9), wraplength=300, justify=tk.LEFT).pack(side=tk.LEFT, anchor=tk.W, fill=tk.X, expand=True, padx=(5, 0))

        # 閉じるボタン
        button_frame = ttk.Frame(detail_window)
        button_frame.pack(fill=tk.X, padx=10, pady=10)

        ttk.Button(button_frame, text="閉じる", command=detail_window.destroy).pack(side=tk.RIGHT)
