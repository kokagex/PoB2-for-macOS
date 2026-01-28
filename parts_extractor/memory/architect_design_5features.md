# 高額部品抽出ツール 5機能詳細設計書

## 概要
本設計書は、高額部品抽出ツールに実装する5つの機能に対する詳細設計を記述します。
このドキュメントはBuilderエージェントへの引き継ぎを目的とします。

---

## 1. 略式型式での曖昧検索（部分一致）

### 1.1 仕様
- **対象列**: `short_model`（略式型式）
- **検索方式**: 部分一致（テキストボックスに入力された文字列を含む行を抽出）
- **動作**: リアルタイム検索またはボタン検索
- **フィルタ種類**: データアナライザーに追加

### 1.2 既存コードの現状
```python
# ui.py: Treeviewに表示している列
TABLE_COLUMNS = [
    'part_id',
    'part_name',
    'amount',
    'vehicle_name',
    'short_model',  # <- ここが検索対象
    'body_color_name',
]
```

### 1.3 実装設計

#### 1.3.1 UIレイアウト追加（ui.py）
```python
# _create_widgets() メソッド内に、金額閾値の下に追加

# === 検索セクション（新規追加） ===
search_frame = ttk.LabelFrame(input_frame, text="検索フィルタ", padding="10")
search_frame.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=10)
search_frame.columnconfigure(1, weight=1)

# 略式型式検索
ttk.Label(search_frame, text="略式型式検索:").grid(row=0, column=0, sticky=tk.W, padx=5)
self.short_model_var = tk.StringVar()
self.short_model_entry = ttk.Entry(search_frame, textvariable=self.short_model_var, width=30)
self.short_model_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=5, pady=5)
ttk.Label(search_frame, text="※部分一致検索", font=('Arial', 8), foreground='gray').grid(row=0, column=2, padx=5)

# 検索実行ボタン
self.search_button = ttk.Button(search_frame, text="検索実行", command=self._on_search_clicked)
self.search_button.grid(row=0, column=3, padx=5, pady=5)

# リセットボタン
self.reset_search_button = ttk.Button(search_frame, text="検索リセット", command=self._on_reset_search_clicked)
self.reset_search_button.grid(row=0, column=4, padx=5, pady=5)
```

#### 1.3.2 DataAnalyzerに新規メソッド追加（data_analyzer.py）
```python
def filter_by_short_model(self, search_text: str) -> pd.DataFrame:
    """
    略式型式で部分一致検索

    Args:
        search_text: 検索テキスト（部分一致）

    Returns:
        フィルタリング済みDataFrame
    """
    try:
        if not search_text or not search_text.strip():
            # 空文字列の場合はフィルタリング済みデータをそのまま返す
            return self.filtered_data.copy() if self.filtered_data is not None else pd.DataFrame()

        df = self.filtered_data.copy() if self.filtered_data is not None else self.data.copy()

        # 部分一致検索（大文字小文字区別なし）
        if 'short_model' in df.columns:
            mask = df['short_model'].astype(str).str.contains(search_text, case=False, na=False)
            df = df[mask]

        return df.reset_index(drop=True)

    except Exception as e:
        print(f"検索フィルタリングエラー: {e}")
        return pd.DataFrame()
```

#### 1.3.3 UIイベントハンドラー追加（ui.py）
```python
def _on_search_clicked(self) -> None:
    """検索ボタンのクリックイベント"""
    if self.data_analyzer is None:
        messagebox.showwarning("警告", "先にデータを取得してください")
        return

    search_text = self.short_model_var.get().strip()

    try:
        # 検索フィルタを適用
        search_result = self.data_analyzer.filter_by_short_model(search_text)

        # 結果を表示
        self._display_results(search_result)

        # ステータス更新
        if search_text:
            self._update_status(f"検索結果: '{search_text}' を含む {len(search_result)}件を表示")
            self._update_info(f"検索キーワード: {search_text}")
        else:
            self._update_status("検索キーワードが空です")

    except Exception as e:
        messagebox.showerror("エラー", f"検索に失敗しました: {e}")
        self._update_status(f"検索エラー: {e}")

def _on_reset_search_clicked(self) -> None:
    """検索リセットボタンのクリックイベント"""
    if self.data_analyzer is None:
        return

    # 検索フィールドをクリア
    self.short_model_var.set("")

    # 現在のフィルタリング済みデータを再表示
    filtered_data = self.data_analyzer.get_filtered_data()
    self._display_results(filtered_data)

    self._update_status("検索がリセットされました")
    self._update_info("")
```

### 1.4 処理フロー
```
ユーザーが検索テキスト入力 → 検索実行ボタンクリック
  ↓
_on_search_clicked() 呼び出し
  ↓
data_analyzer.filter_by_short_model() 実行
  ↓
部分一致フィルタリング実行
  ↓
Treeview に検索結果を表示
```

---

## 2. 最低金額から10件取得

### 2.1 仕様
- **機能**: 最低金額（閾値）から10件の行を取得
- **動作**: データ取得後、「最初の10件取得」ボタンで実行
- **フィルタ種類**: データアナライザーに追加

### 2.2 既存コードの現状
```python
# data_analyzer.py: filter_by_amount で既に降順ソートされている
df = df.sort_values('amount', ascending=False)  # 高額順
```

### 2.3 実装設計

#### 2.3.1 UIレイアウト追加（ui.py）
```python
# ボタンセクション内に追加

self.get_top10_button = ttk.Button(
    button_frame,
    text="最初の10件表示",
    command=self._on_get_top10_clicked,
    state=tk.DISABLED
)
self.get_top10_button.pack(side=tk.LEFT, padx=5)
```

#### 2.3.2 DataAnalyzerに新規メソッド追加（data_analyzer.py）
```python
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
```

#### 2.3.3 UIイベントハンドラー追加（ui.py）
```python
def _on_get_top10_clicked(self) -> None:
    """最初の10件表示ボタンのクリックイベント"""
    if self.data_analyzer is None:
        messagebox.showwarning("警告", "先にデータを取得してください")
        return

    try:
        # 最初の10件を取得
        top10_data = self.data_analyzer.get_top_n_records(10)

        if len(top10_data) == 0:
            messagebox.showwarning("警告", "表示するデータがありません")
            return

        # 結果を表示
        self._display_results(top10_data)

        # ステータス更新
        actual_count = len(top10_data)
        total_count = len(self.data_analyzer.get_filtered_data())
        summary = self.data_analyzer.get_filter_summary()

        self._update_status(
            f"最初の{actual_count}件を表示（全{total_count}件中）。合計金額: ¥{top10_data['amount'].sum():,.0f}"
        )

    except Exception as e:
        messagebox.showerror("エラー", f"10件取得に失敗しました: {e}")
        self._update_status(f"エラー: {e}")
```

#### 2.3.4 ボタン有効化の制御
```python
# _on_get_data_clicked() の終了時に追加

# 各種ボタンを有効化
self.export_button.config(state=tk.NORMAL)
self.save_json_button.config(state=tk.NORMAL)
self.get_top10_button.config(state=tk.NORMAL)  # <- 新規追加
self.search_button.config(state=tk.NORMAL)      # <- 検索ボタンも有効化
```

### 2.4 処理フロー
```
ユーザーが「最初の10件表示」ボタンをクリック
  ↓
_on_get_top10_clicked() 呼び出し
  ↓
data_analyzer.get_top_n_records(10) 実行
  ↓
最初の10件を Treeview に表示
```

---

## 3. 列ヘッダークリックソート

### 3.1 仕様
- **対象**: Treeview の列ヘッダー
- **動作**: ヘッダーをクリックすると昇順/降順で切り替わる
- **ソート対象列**: amount, vehicle_name, short_model
- **デフォルト**: amount は降順（高額順）

### 3.2 既存コードの現状
```python
# ui.py: Treeview の定義
self.tree = ttk.Treeview(results_frame, columns=self.tree_columns, show='headings', height=15)

# 列の見出しを定義
for col in self.tree_columns:
    display_name = config.DISPLAY_COLUMNS.get(col, col)
    width = column_widths.get(col, 100)
    self.tree.heading(col, text=display_name)
    self.tree.column(col, width=width, anchor=tk.W)
```

### 3.3 実装設計

#### 3.3.1 ソート状態管理（ui.py __init__）
```python
def __init__(self, root: tk.Tk):
    # ... 既存のコード ...

    # ソート状態管理（新規追加）
    self.sort_state = {}  # 例: {'amount': 'desc', 'vehicle_name': 'asc'}
    self.last_sorted_column = None
```

#### 3.3.2 Treeview のバインディング追加（ui.py _create_widgets）
```python
# Treeview作成後に追加

# ヘッダークリック時のソート処理をバインド
for col in self.tree_columns:
    self.tree.heading(col, text=display_name, command=lambda c=col: self._on_treeview_column_click(c))
```

#### 3.3.3 ソート処理メソッド追加（ui.py）
```python
def _on_treeview_column_click(self, col: str) -> None:
    """
    Treeview の列ヘッダークリック時のソート処理

    Args:
        col: クリックされた列名
    """
    if self.data_analyzer is None or self.data_analyzer.get_filtered_data().empty:
        return

    try:
        # 現在のデータを取得
        current_data = self.data_analyzer.get_filtered_data()

        # 同じ列で連続クリックされた場合は降順/昇順を切り替え
        if self.last_sorted_column == col:
            # 前回と反対順にソート
            ascending = self.sort_state.get(col, False)
        else:
            # 新しい列の場合、デフォルトソート（amountは降順、他は昇順）
            ascending = col != 'amount'
            self.last_sorted_column = col

        # ソート対象列の確認
        if col not in current_data.columns:
            messagebox.showwarning("警告", f"列 '{col}' が見つかりません")
            return

        # ソート実行
        sorted_data = self._sort_dataframe(current_data, col, ascending)

        # 状態を保存
        self.sort_state[col] = ascending
        self.last_sorted_column = col

        # 結果を表示
        self._display_results(sorted_data)

        # ステータス更新
        sort_order = "昇順" if ascending else "降順"
        display_col_name = config.DISPLAY_COLUMNS.get(col, col)
        self._update_status(f"'{display_col_name}' で{sort_order}にソート")

    except Exception as e:
        messagebox.showerror("エラー", f"ソートに失敗しました: {e}")

def _sort_dataframe(self, df: pd.DataFrame, col: str, ascending: bool = True) -> pd.DataFrame:
    """
    DataFrameをソート

    Args:
        df: ソート対象のDataFrame
        col: ソート列名
        ascending: 昇順（True）/降順（False）

    Returns:
        ソート済みDataFrame
    """
    try:
        # 数値列の場合は数値でソート
        if col == 'amount':
            df[col] = pd.to_numeric(df[col], errors='coerce')

        # ソート実行
        sorted_df = df.sort_values(by=col, ascending=ascending, na_position='last')

        return sorted_df.reset_index(drop=True)

    except Exception as e:
        print(f"ソートエラー: {e}")
        return df
```

#### 3.3.4 Treeview の再表示メソッド更新（ui.py）
```python
# _display_results メソッドは既存のままで、ソートされたデータを受け取る
# 特に追加の変更は不要だが、以下の確認をする：

def _display_results(self, data) -> None:
    """
    Treeviewに結果を表示

    Args:
        data: フィルタリング済み結果のDataFrame
    """
    # 既存コード
    for item in self.tree.get_children():
        self.tree.delete(item)

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
```

### 3.4 処理フロー
```
ユーザーが列ヘッダーをクリック
  ↓
_on_treeview_column_click(col) 呼び出し
  ↓
_sort_dataframe() でソート実行
  ↓
_display_results() で再表示
```

---

## 4. ダブルクリック詳細ポップアップ

### 4.1 仕様
- **トリガー**: Treeview の行をダブルクリック
- **表示内容**: 選択された行の全カラム情報
- **ウィンドウタイプ**: モーダルダイアログ（Toplevel）
- **サイズ**: 幅400px × 高さ600px（3:4比率）
- **表示方式**: スクロール可能なラベル＆値のペアリスト

### 4.2 既存コードの現状
```python
# ui.py: Treeview の定義
self.tree = ttk.Treeview(results_frame, columns=self.tree_columns, show='headings', height=15)

# 現在はダブルクリック処理なし
```

### 4.3 実装設計

#### 4.3.1 UIバインディング追加（ui.py _create_widgets）
```python
# Treeview作成後に追加

# ダブルクリック時のイベントハンドラをバインド
self.tree.bind("<Double-1>", self._on_treeview_double_click)
```

#### 4.3.2 詳細ポップアップクラス追加（ui.py）
```python
class DetailPopup:
    """
    Treeview 行の詳細情報を表示するポップアップウィンドウ

    サイズ: 400px(幅) × 600px(高さ) = 3:4比率
    """

    def __init__(self, parent: tk.Tk, row_data: dict, row_index: int):
        """
        詳細ポップアップを初期化

        Args:
            parent: 親ウィンドウ
            row_data: 行データ（カラム名: 値）
            row_index: 行番号（タイトル用）
        """
        self.parent = parent
        self.row_data = row_data
        self.row_index = row_index

        # モーダルウィンドウを作成
        self.window = tk.Toplevel(parent)
        self.window.title(f"詳細情報 - 行{row_index + 1}")
        self.window.geometry("400x600")
        self.window.resizable(True, True)

        # アイコン設定（オプション）
        try:
            self.window.iconbitmap(parent.iconbitmap())
        except:
            pass

        # レイアウト作成
        self._create_widgets()

        # ウィンドウを前面に配置
        self.window.transient(parent)
        self.window.grab_set()

    def _create_widgets(self) -> None:
        """詳細ポップアップのウィジェットを作成"""

        # === ヘッダーフレーム ===
        header_frame = ttk.Frame(self.window)
        header_frame.pack(fill=tk.X, padx=10, pady=10)

        ttk.Label(
            header_frame,
            text=f"行番号: {self.row_index + 1}",
            font=('Arial', 12, 'bold')
        ).pack(side=tk.LEFT)

        # === メインコンテンツ（スクロール可能） ===
        main_frame = ttk.Frame(self.window)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # Canvas とスクロールバーでスクロール対応
        canvas = tk.Canvas(main_frame, highlightthickness=0)
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

        # === データ表示（ラベル＆値のペア） ===
        self._display_row_data(scrollable_frame)

        # === フッターボタン ===
        footer_frame = ttk.Frame(self.window)
        footer_frame.pack(fill=tk.X, padx=10, pady=10)

        ttk.Button(
            footer_frame,
            text="閉じる",
            command=self.window.destroy
        ).pack(side=tk.RIGHT, padx=5)

        ttk.Button(
            footer_frame,
            text="データをコピー",
            command=self._copy_to_clipboard
        ).pack(side=tk.RIGHT, padx=5)

    def _display_row_data(self, parent_frame: ttk.Frame) -> None:
        """
        行データを詳細表示

        Args:
            parent_frame: 親フレーム
        """
        for col, value in self.row_data.items():
            # カラム名フレーム
            col_frame = ttk.Frame(parent_frame)
            col_frame.pack(fill=tk.X, pady=8, padx=5)

            # カラム名ラベル
            display_col_name = config.DISPLAY_COLUMNS.get(col, col)
            ttk.Label(
                col_frame,
                text=display_col_name,
                font=('Arial', 9, 'bold'),
                foreground='#333333'
            ).pack(anchor=tk.W)

            # 値ラベル（テキストボックスで表示、コピー可能）
            value_text = tk.Text(
                col_frame,
                height=2,
                width=50,
                wrap=tk.WORD,
                font=('Arial', 9),
                relief=tk.FLAT,
                bg='#f0f0f0',
                state=tk.DISABLED
            )
            value_text.pack(fill=tk.X, pady=3, padx=5)

            # 値を挿入
            value_text.config(state=tk.NORMAL)
            value_text.insert('1.0', str(value) if value != '' else '（空白）')
            value_text.config(state=tk.DISABLED)

            # セパレータ
            ttk.Separator(col_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=5)

    def _copy_to_clipboard(self) -> None:
        """行データをクリップボードにコピー"""
        try:
            copy_text = ""
            for col, value in self.row_data.items():
                display_col_name = config.DISPLAY_COLUMNS.get(col, col)
                copy_text += f"{display_col_name}: {value}\n"

            # クリップボードに書き込み
            self.window.clipboard_clear()
            self.window.clipboard_append(copy_text)
            self.window.update()

            messagebox.showinfo("成功", "データをクリップボードにコピーしました")
        except Exception as e:
            messagebox.showerror("エラー", f"コピーに失敗しました: {e}")
```

#### 4.3.3 ダブルクリックイベントハンドラー追加（ui.py）
```python
def _on_treeview_double_click(self, event) -> None:
    """
    Treeview のダブルクリックイベント処理

    Args:
        event: Treeview イベント
    """
    # クリックされた行を取得
    selection = self.tree.selection()
    if not selection:
        return

    item = selection[0]

    try:
        # 選択行の値を取得
        values = self.tree.item(item, 'values')

        if not values:
            messagebox.showwarning("警告", "行データが見つかりません")
            return

        # 行データを辞書に変換
        row_data = {}
        for i, col in enumerate(self.tree_columns):
            if i < len(values):
                row_data[col] = values[i]

        # 行インデックスを取得
        all_items = self.tree.get_children()
        row_index = all_items.index(item)

        # 詳細ポップアップを表示
        DetailPopup(self.root, row_data, row_index)

    except Exception as e:
        messagebox.showerror("エラー", f"詳細表示に失敗しました: {e}")
```

### 4.4 UIレイアウト設計

#### 4.4.1 ポップアップの構成
```
┌─────────────────────────────┐ (400 × 600px, 3:4比率)
│  詳細情報 - 行1        [×]  │
├─────────────────────────────┤
│ 行番号: 1                   │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ [スクロール可能エリア]  │ │
│ │                         │ │
│ │ 部品管理番号            │ │
│ │ [値...]                 │ │
│ │ ───────────────────── │ │
│ │                         │ │
│ │ 部品名                  │ │
│ │ [値...]                 │ │
│ │ ───────────────────── │ │
│ │                         │ │
│ │ ﾈｯﾄ価格                 │ │
│ │ [値...]                 │ │
│ │ ───────────────────── │ │
│ │                         │ │
│ │ （その他カラム）        │ │
│ │                         │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ [データをコピー]  [閉じる]  │
└─────────────────────────────┘
```

### 4.5 処理フロー
```
ユーザーが Treeview の行をダブルクリック
  ↓
_on_treeview_double_click(event) 呼び出し
  ↓
行データを辞書に変換
  ↓
DetailPopup クラスでポップアップウィンドウを作成
  ↓
_display_row_data() でスクロール可能な形式で表示
```

---

## 5. ポップアップUI（3:4比率、視認性優先）

### 5.1 設計ガイドライン

#### 5.1.1 サイズ仕様
- **幅**: 400px
- **高さ**: 600px
- **比率**: 3:4（正確に 400:600 = 2:3 を4倍にした際に3:4になる）

#### 5.1.2 カラースキーム
```python
# 配色設計
COLORS = {
    'header_bg': '#FFFFFF',      # ヘッダー背景（白）
    'header_text': '#000000',    # ヘッダーテキスト（黒）
    'label_text': '#333333',     # ラベルテキスト（濃いグレー）
    'value_bg': '#F5F5F5',       # 値表示背景（薄いグレー）
    'separator': '#CCCCCC',      # セパレータ色（グレー）
    'button_bg': '#0078D4',      # ボタン背景（青）
    'button_text': '#FFFFFF',    # ボタンテキスト（白）
}
```

#### 5.1.3 フォントサイズ
```python
# フォント設計
FONTS = {
    'title': ('Arial', 12, 'bold'),           # タイトル
    'label': ('Arial', 9, 'bold'),            # カラム名ラベル
    'value': ('Arial', 9),                    # 値テキスト
    'button': ('Arial', 9),                   # ボタン
    'status': ('Arial', 8),                   # ステータス表示
}
```

#### 5.1.4 スペーシング
```python
# レイアウト設計
SPACING = {
    'outer_padding': 10,      # 外側パディング
    'inner_padding': 5,       # 内側パディング
    'item_spacing': 8,        # 項目間スペース
    'section_spacing': 10,    # セクション間スペース
}
```

### 5.2 視認性優先の実装

#### 5.2.1 テキスト可読性
```python
# テキストボックスの設定
value_text = tk.Text(
    parent_frame,
    height=2,          # 複数行対応
    width=50,          # 十分な幅
    wrap=tk.WORD,      # 自動折り返し
    font=('Arial', 9), # 読みやすいフォント
    relief=tk.FLAT,    # フラットなデザイン
    bg='#F5F5F5',      # 淡い背景色
    fg='#333333',      # 濃いテキスト色
    state=tk.DISABLED  # 読み取り専用
)
```

#### 5.2.2 情報の視覚的階層化
- **タイトル**: 太字、12pt
- **カラム名**: 太字、9pt、濃いグレー
- **値**: 通常、9pt、フラットなテキストボックス
- **セパレータ**: 細い線で区切り

#### 5.2.3 コントラスト確保
```python
# 背景色とテキスト色の組み合わせ
# ラベル: 濃いテキスト（#333333）
# 値: 淡い背景（#F5F5F5）に濃いテキスト（#333333）
# ボタン: 青背景（#0078D4）に白テキスト（#FFFFFF）
```

### 5.3 レスポンシブデザイン

#### 5.3.1 スクロール対応
```python
# Canvas + Scrollbar で縦スクロール対応
canvas = tk.Canvas(main_frame, highlightthickness=0)
scrollbar = ttk.Scrollbar(main_frame, orient=tk.VERTICAL, command=canvas.yview)
scrollable_frame = ttk.Frame(canvas)

canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
canvas.configure(yscroll=scrollbar.set)
```

#### 5.3.2 ウィンドウリサイズ対応
```python
# ウィンドウをリサイズ可能に設定
self.window.resizable(True, True)
```

### 5.4 ユーザー操作性

#### 5.4.1 キーボード操作
```python
# Escapeキーでウィンドウを閉じる
self.window.bind('<Escape>', lambda e: self.window.destroy())
```

#### 5.4.2 マウス操作
```python
# データをコピーできるテキストボックス
# クリップボード機能を提供
```

---

## 実装チェックリスト（Builder用）

### 機能1: 略式型式での曖昧検索
- [ ] SearchFrameをUIに追加
- [ ] filter_by_short_model() メソッドを実装
- [ ] _on_search_clicked() イベントハンドラーを実装
- [ ] _on_reset_search_clicked() イベントハンドラーを実装
- [ ] 検索ボタンのボタン有効化制御を追加
- [ ] 動作テスト: 部分一致検索が正しく動作するか確認

### 機能2: 最低金額から10件取得
- [ ] 「最初の10件表示」ボタンをUI に追加
- [ ] get_top_n_records() メソッドを実装
- [ ] _on_get_top10_clicked() イベントハンドラーを実装
- [ ] ボタン有効化制御を追加
- [ ] 動作テスト: 10件取得が正しく動作するか確認

### 機能3: 列ヘッダークリックソート
- [ ] ソート状態管理変数を初期化
- [ ] Treeview のヘッダーバインディングを追加
- [ ] _on_treeview_column_click() メソッドを実装
- [ ] _sort_dataframe() メソッドを実装
- [ ] 昇順/降順の切り替え機能を確認
- [ ] 動作テスト: 各列でソートが正しく動作するか確認

### 機能4: ダブルクリック詳細ポップアップ
- [ ] DetailPopup クラスを実装
- [ ] _on_treeview_double_click() メソッドを実装
- [ ] Canvas + Scrollbar でスクロール対応を実装
- [ ] _display_row_data() メソッドを実装
- [ ] _copy_to_clipboard() メソッドを実装
- [ ] 動作テスト: ダブルクリックでポップアップが表示されるか確認

### 機能5: ポップアップUI設計
- [ ] 400×600px（3:4比率）のウィンドウサイズを確認
- [ ] フォント、色、スペーシングが視認性優先の設計に従っているか確認
- [ ] テキストの自動折り返しが機能しているか確認
- [ ] スクロール機能が正常に動作するか確認
- [ ] ウィンドウのリサイズが可能か確認

---

## ファイル構成変更の概要

### 修正ファイル
1. **ui.py**
   - UIレイアウトに検索フレーム、ボタンを追加
   - DetailPopup クラスを追加
   - イベントハンドラーを追加（search, reset_search, top10, sort, double_click）
   - ソート状態管理変数を追加

2. **data_analyzer.py**
   - filter_by_short_model() メソッドを追加
   - get_top_n_records() メソッドを追加

3. **config.py**
   - 必要に応じてカラー設定やフォント設定を追加（オプション）

---

## 設計完了

本詳細設計書に基づいて、Builderエージェントが以下のフェーズで実装を進めることができます：

**Phase 1: データ処理基盤の実装**
- data_analyzer.py に新規メソッドを追加

**Phase 2: UI機能の追加**
- ui.py にUIウィジェットとイベントハンドラーを追加

**Phase 3: 詳細表示機能の実装**
- DetailPopup クラスとダブルクリック処理を実装

---

## 注釈

### メモリ効率
- フィルタリング済みデータのコピーを最小限に抑える設計
- Treeview の再表示時は必要に応じてのみコピー

### エラーハンドリング
- すべてのメソッドで try-catch を使用
- ユーザーへのエラーメッセージは messagebox で表示

### スケーラビリティ
- 新機能追加時は、既存の UI レイアウトと衝突しないよう設計
- メソッド名は機能を明確に示すネーミングを使用

---

**作成日**: 2026-01-28
**設計者**: Architect Agent
**対象リリース**: v2.0.0
