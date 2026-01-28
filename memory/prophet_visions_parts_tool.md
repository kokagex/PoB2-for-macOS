# 天啓：高額部品抽出ツール

**受信日時**: 2026-01-28
**神からの指示**: 高額部品抽出ツール（Windows .exe形式）の創造

---

## 目的

Google スプレッドシートからデータを取得し、低工程・高額な部品を解析・表示するWindowsアプリケーションを創造する。

---

## 使用技術

- **言語**: Python 3.x
- **API**: Google Sheets API
- **認証**: サービスアカウント（credentials.json）
- **UI**: Tkinter（軽量GUIフレームワーク）
- **EXE化**: PyInstaller
- **データ処理**: pandas

---

## 主要機能

### 1. Google Sheets 接続機能
- サービスアカウント認証でスプレッドシートに接続
- スプレッドシートIDを指定してデータ取得
- シート名を選択可能

### 2. 部品データ解析機能
- 取得したデータをDataFrameとして処理
- ユーザー指定の条件でフィルタリング:
  - 工程数の閾値（例: 3以下）
  - 金額の閾値（例: 10万円以上）

### 3. UI機能（Tkinter）
- スプレッドシートID入力欄
- シート名選択
- 閾値入力:
  - 工程数上限（スライダーまたは入力）
  - 金額下限（入力）
- データ取得ボタン
- 結果表示テーブル（Treeview）
- CSVエクスポート機能

### 4. EXE出力
- PyInstallerで単一.exeファイルに変換
- Windows環境で動作

---

## APIアクセスの掟（安全装置）

### 検証リミット
- API接続確認やデータ取得の試行錯誤は **累計15分以内**

### フェイルセーフ
- 15分以内に疎通確認できない場合:
  1. APIアクセスを即座に停止
  2. `memory/api_error.md` にログを残す
  3. ダミーデータ（Mock）を用いた開発に切り替え

### 非ポーリング
- 無意味な連続アクセスを避ける
- イベント駆動を徹底（ボタンクリック時のみ通信）

---

## ディレクトリ構成（理想）

```
parts_extractor/
├── main.py              # エントリーポイント
├── sheets_api.py        # Google Sheets API接続
├── data_analyzer.py     # データ解析ロジック
├── ui.py                # Tkinter UI
├── mock_data.py         # ダミーデータ（フェイルセーフ用）
├── config.py            # 設定ファイル
├── credentials.json     # 認証情報（ユーザー配置）
├── requirements.txt     # 依存パッケージ
└── README.md            # 使用説明書
```

---

## 村長への指示

### 並列実行グループ（同時開始可能）
| エージェント | 担当 |
|-------------|------|
| architect | 設計・ディレクトリ構造・スケルトン作成 |
| librarian | README.md・使用説明書作成 |

### 順序実行グループ
| エージェント | 担当 | 依存 |
|-------------|------|------|
| builder (API) | sheets_api.py, mock_data.py 実装 | architect |
| builder (Logic) | data_analyzer.py 実装 | architect |
| builder (UI) | ui.py, main.py 実装 | architect |
| tester | テスト実施 | builder全て |
| guardian | 最終レビュー | tester |

**注意**: API検証は15分リミット厳守。超過時はMockに切り替え。

---

## ステータス

- [x] 預言者: 仕様策定完了
- [ ] 村長: タスク割り振り中
- [ ] 各村人: 作業中
