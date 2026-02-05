# Claude Skills 完全インストールガイド 🚀

**作成日**: 2026-02-01
**対象**: Awesome Claude Skills コレクション
**リポジトリ**: https://github.com/BehiSecc/awesome-claude-skills

---

## 📋 目次

1. [スキルとは](#スキルとは)
2. [インストール方法](#インストール方法)
3. [厳選スキル一覧](#厳選スキル一覧)
4. [カテゴリ別詳細](#カテゴリ別詳細)
5. [トラブルシューティング](#トラブルシューティング)

---

## 🎯 スキルとは

**Claude Skills（スキル）**は、Claude Codeの機能を拡張する専用プラグインです。

### 特徴
- ✅ 特定タスクに特化した専門機能
- ✅ コマンド実行で簡単に呼び出し
- ✅ コミュニティ開発による豊富な種類
- ✅ Git経由で簡単インストール

### スキルの種類
- **公式スキル**: Anthropic社が開発・保守
- **コミュニティスキル**: サードパーティ開発者による拡張

---

## 🔧 インストール方法

### 基本コマンド

```bash
# 公式スキルのインストール
/plugin install <skill-name>

# GitHubリポジトリからインストール
/plugin marketplace add <github-username>
/plugin install <skill-name>@<github-username>

# ローカルスキルのインストール
cd ~/.claude/skills
git clone <repository-url>
```

### ステップ・バイ・ステップ

#### 1. 公式スキルの場合

```bash
# 例: PDF スキル
/plugin install pdf
```

#### 2. コミュニティスキルの場合

```bash
# マーケットプレイスに開発者を追加
/plugin marketplace add anthropics

# スキルをインストール
/plugin install pdf@anthropics
```

#### 3. 手動インストール（上級者向け）

```bash
# スキルディレクトリに移動
cd ~/.claude/skills

# リポジトリをクローン
git clone https://github.com/username/skill-name.git

# Claude Codeを再起動
/reload
```

---

## ⭐ 厳選スキル一覧（推奨インストール順）

### 🥇 Tier 1: 必須スキル（最優先）

| スキル名 | 説明 | インストールコマンド |
|---------|------|---------------------|
| **pdf** | PDF解析・抽出 | `/plugin install pdf` |
| **docx** | Word文書編集 | `/plugin install docx` |
| **xlsx** | Excel操作 | `/plugin install xlsx` |
| **csv-data-summarizer** | CSV自動分析 | GitHub経由 |
| **test-driven-development** | TDD支援 | GitHub経由 |

### 🥈 Tier 2: 高頻度利用スキル

| スキル名 | 説明 | インストールコマンド |
|---------|------|---------------------|
| **pptx** | PowerPoint生成 | `/plugin install pptx` |
| **youtube-transcript** | YouTube文字起こし | GitHub経由 |
| **web-artifacts-builder** | React/Tailwind Web構築 | GitHub経由 |
| **postgres** | PostgreSQL操作 | GitHub経由 |
| **aws-skills** | AWS開発支援 | GitHub経由 |

### 🥉 Tier 3: 専門スキル

| スキル名 | 説明 | インストールコマンド |
|---------|------|---------------------|
| **claude-scientific-skills** | 科学研究125+スキル | GitHub経由 |
| **google-workspace-skills** | Google統合 | GitHub経由 |
| **linear-claude-skill** | プロジェクト管理 | GitHub経由 |
| **imagen** | AI画像生成 | GitHub経由 |
| **deep-research** | 自動リサーチ | GitHub経由 |

---

## 📚 カテゴリ別詳細

### 📄 ドキュメント処理スキル

#### 1. **pdf** - PDF処理の決定版

**機能**:
- ✅ テキスト抽出（OCR対応）
- ✅ テーブル構造解析
- ✅ メタデータ取得
- ✅ ページ分割・結合

**使用例**:
```bash
# PDFスキルを起動
/pdf analyze document.pdf

# テキスト抽出
/pdf extract-text report.pdf

# テーブル抽出
/pdf extract-tables data.pdf
```

**インストール**:
```bash
/plugin install pdf
```

---

#### 2. **docx** - Word文書の完全制御

**機能**:
- ✅ 文書作成・編集
- ✅ 変更履歴トラッキング
- ✅ コメント追加
- ✅ フォーマット調整

**使用例**:
```bash
# Word文書作成
/docx create report.docx "タイトル" "本文内容"

# 既存文書編集
/docx edit contract.docx --add-comment "要確認"

# フォーマット適用
/docx format proposal.docx --style professional
```

**インストール**:
```bash
/plugin install docx
```

---

#### 3. **xlsx** - Excel自動化の強力ツール

**機能**:
- ✅ スプレッドシート読み書き
- ✅ 数式・関数適用
- ✅ グラフ生成
- ✅ データ変換

**使用例**:
```bash
# Excelファイル作成
/xlsx create budget.xlsx

# データ分析
/xlsx analyze sales-data.xlsx --pivot-table

# グラフ生成
/xlsx chart revenue.xlsx --type bar
```

**インストール**:
```bash
/plugin install xlsx
```

---

#### 4. **pptx** - PowerPoint生成

**機能**:
- ✅ スライド自動生成
- ✅ レイアウト調整
- ✅ テンプレート適用
- ✅ 画像・グラフ挿入

**使用例**:
```bash
# プレゼン作成
/pptx create pitch.pptx --template business

# スライド追加
/pptx add-slide pitch.pptx --title "Q4 Results"
```

**インストール**:
```bash
/plugin install pptx
```

---

### 🛠 開発ツールスキル

#### 5. **test-driven-development** - TDD支援

**機能**:
- ✅ テストケース自動生成
- ✅ モック作成支援
- ✅ カバレッジ分析
- ✅ リファクタリング提案

**使用例**:
```bash
# TDDモードで開発開始
/tdd start --language python

# テストケース生成
/tdd generate-tests calculate_total()

# テスト実行
/tdd run
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/test-driven-development.git
```

---

#### 6. **web-artifacts-builder** - モダンWeb開発

**機能**:
- ✅ React コンポーネント生成
- ✅ Tailwind CSS スタイリング
- ✅ shadcn/ui 統合
- ✅ レスポンシブデザイン

**使用例**:
```bash
# Reactアプリ作成
/web-artifacts create-app my-app --framework react

# コンポーネント生成
/web-artifacts component Button --variant primary
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/web-artifacts-builder.git
```

---

#### 7. **aws-skills** - AWS開発支援

**機能**:
- ✅ AWS CDK テンプレート生成
- ✅ Lambda関数作成
- ✅ サーバーレス設計
- ✅ IAM ポリシー管理

**使用例**:
```bash
# Lambda関数作成
/aws lambda create process-orders --runtime nodejs18

# CDK スタック生成
/aws cdk init --stack web-app
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/aws-skills.git
```

---

### 📊 データ分析スキル

#### 8. **csv-data-summarizer** - CSV自動分析

**機能**:
- ✅ 列の自動検出
- ✅ データ分布分析
- ✅ 欠損値検出
- ✅ 統計サマリー生成

**使用例**:
```bash
# CSVファイル分析
/csv-summarize data.csv

# 詳細レポート生成
/csv-summarize sales.csv --detailed --output report.html
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/csv-data-summarizer-claude-skill.git
```

---

#### 9. **postgres** - PostgreSQL操作

**機能**:
- ✅ 安全な読み取り専用クエリ
- ✅ スキーマ分析
- ✅ クエリ最適化提案
- ✅ データエクスポート

**使用例**:
```bash
# データベース接続
/postgres connect --host localhost --db myapp

# クエリ実行
/postgres query "SELECT * FROM users WHERE created_at > '2024-01-01'"

# スキーマ分析
/postgres analyze-schema users
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/postgres.git
```

---

### 🎬 メディアスキル

#### 10. **youtube-transcript** - YouTube文字起こし

**機能**:
- ✅ 自動文字起こし
- ✅ タイムスタンプ付き
- ✅ 要約生成
- ✅ 多言語対応

**使用例**:
```bash
# 動画の文字起こし
/youtube-transcript https://www.youtube.com/watch?v=VIDEO_ID

# 要約生成
/youtube-transcript https://youtu.be/VIDEO_ID --summarize

# 特定セクション抽出
/youtube-transcript VIDEO_ID --start 2:30 --end 5:45
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/youtube-transcript.git
```

---

#### 11. **imagen** - AI画像生成

**機能**:
- ✅ Google Gemini API統合
- ✅ 高品質画像生成
- ✅ スタイル指定
- ✅ バッチ生成

**使用例**:
```bash
# 画像生成
/imagen generate "a futuristic city at sunset" --style photorealistic

# バッチ生成
/imagen batch prompts.txt --count 10
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/imagen.git
# Gemini API キーが必要
```

---

### 🔬 科学研究スキル

#### 12. **claude-scientific-skills** - 科学研究125+スキル

**機能**:
- ✅ バイオインフォマティクス解析
- ✅ 化学構造処理
- ✅ 論文データ抽出
- ✅ 統計分析

**対応分野**:
- 生物学・ゲノム解析
- 化学・分子モデリング
- 物理学・データ解析
- 医学・臨床研究

**使用例**:
```bash
# タンパク質配列分析
/bio analyze-sequence ATCG...

# 化学構造解析
/chem parse-smiles "CCO"

# 論文データ抽出
/paper extract-data paper.pdf
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/claude-scientific-skills.git
```

---

### 🤝 コラボレーションスキル

#### 13. **google-workspace-skills** - Google統合

**機能**:
- ✅ Gmail操作
- ✅ Googleカレンダー管理
- ✅ Googleドキュメント編集
- ✅ スプレッドシート操作
- ✅ Googleドライブ管理

**使用例**:
```bash
# メール送信
/gmail send --to user@example.com --subject "Report" --body "..."

# カレンダーイベント作成
/calendar create "Meeting" --date 2026-02-10 --time 14:00

# ドキュメント作成
/gdocs create "Project Plan"
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/google-workspace-skills.git
# Google OAuth認証が必要
```

---

#### 14. **linear-claude-skill** - プロジェクト管理

**機能**:
- ✅ 課題作成・更新
- ✅ プロジェクト管理
- ✅ スプリント計画
- ✅ レポート生成

**使用例**:
```bash
# 課題作成
/linear create-issue "Fix login bug" --priority high

# プロジェクト状況確認
/linear project-status "Q1 Release"

# スプリント計画
/linear plan-sprint --start 2026-02-03
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/linear-claude-skill.git
# Linear APIキーが必要
```

---

### 🎓 学習・研究スキル

#### 15. **deep-research** - 自動リサーチエージェント

**機能**:
- ✅ Gemini Deep Research統合
- ✅ 多段階リサーチ
- ✅ 引用付きレポート
- ✅ データ収集自動化

**使用例**:
```bash
# 深層リサーチ実行
/deep-research "Quantum computing applications in 2026"

# カスタムリサーチ
/deep-research "AI safety frameworks" --depth comprehensive --sources 20
```

**インストール**:
```bash
cd ~/.claude/skills
git clone https://github.com/anthropics/deep-research.git
# Gemini APIキーが必要
```

---

## 🚀 クイックスタートガイド

### 1. 最初にインストールすべきスキル（5分）

```bash
# ドキュメント処理の基本3点セット
/plugin install pdf
/plugin install docx
/plugin install xlsx

# これで80%の日常タスクをカバー
```

### 2. 開発者向けセットアップ（10分）

```bash
# ドキュメント処理
/plugin install pdf
/plugin install docx

# 開発ツール
cd ~/.claude/skills
git clone https://github.com/anthropics/test-driven-development.git
git clone https://github.com/anthropics/web-artifacts-builder.git
git clone https://github.com/anthropics/aws-skills.git

# データ分析
git clone https://github.com/anthropics/csv-data-summarizer-claude-skill.git
git clone https://github.com/anthropics/postgres.git

# 完了！Claude Codeを再起動
/reload
```

### 3. フルインストール（20分）

```bash
# Tier 1スキル
/plugin install pdf
/plugin install docx
/plugin install xlsx
/plugin install pptx

# Tier 2スキル（GitHub経由）
cd ~/.claude/skills
git clone https://github.com/anthropics/test-driven-development.git
git clone https://github.com/anthropics/web-artifacts-builder.git
git clone https://github.com/anthropics/csv-data-summarizer-claude-skill.git
git clone https://github.com/anthropics/postgres.git
git clone https://github.com/anthropics/youtube-transcript.git
git clone https://github.com/anthropics/aws-skills.git

# Tier 3専門スキル（必要に応じて）
git clone https://github.com/anthropics/claude-scientific-skills.git
git clone https://github.com/anthropics/google-workspace-skills.git
git clone https://github.com/anthropics/linear-claude-skill.git

# Claude Code再起動
/reload
```

---

## 🔍 スキルの使い方

### スキル一覧確認

```bash
# インストール済みスキル表示
/plugin

# スキルの詳細確認
/help <skill-name>
```

### スキル実行

```bash
# スラッシュコマンドで実行
/<skill-name> <arguments>

# 例：PDFスキル
/pdf analyze document.pdf

# 例：CSVスキル
/csv-summarize data.csv
```

### スキル削除

```bash
# プラグイン削除
/plugin remove <skill-name>

# または手動削除
rm -rf ~/.claude/skills/<skill-name>
```

---

## ⚠️ トラブルシューティング

### 問題1: スキルがインストールされない

**症状**: `/plugin install` が失敗する

**解決策**:
```bash
# 1. プラグインリストを更新
/plugin refresh

# 2. 手動インストールを試す
cd ~/.claude/skills
git clone <repository-url>
/reload
```

---

### 問題2: スキルが認識されない

**症状**: インストール後もスキルが使えない

**解決策**:
```bash
# 1. Claude Codeを再起動
/reload

# 2. スキルディレクトリを確認
ls -la ~/.claude/skills

# 3. 権限を確認
chmod -R 755 ~/.claude/skills/<skill-name>
```

---

### 問題3: APIキーエラー

**症状**: 外部APIを使うスキルでエラー

**解決策**:
```bash
# 環境変数を設定
export GEMINI_API_KEY="your-key-here"
export GOOGLE_CLIENT_ID="your-id"
export LINEAR_API_KEY="your-key"

# または ~/.zshrc に追加
echo 'export GEMINI_API_KEY="..."' >> ~/.zshrc
source ~/.zshrc
```

---

### 問題4: 依存関係エラー

**症状**: `npm install` や `pip install` が失敗

**解決策**:
```bash
# Node.js依存関係
cd ~/.claude/skills/<skill-name>
npm install

# Python依存関係
cd ~/.claude/skills/<skill-name>
pip install -r requirements.txt

# または
python3 -m pip install -r requirements.txt
```

---

## 📊 スキル選択ガイド

### 用途別おすすめスキル

#### 📝 ドキュメント作業メイン
- **必須**: pdf, docx, xlsx
- **推奨**: pptx
- **オプション**: csv-data-summarizer

#### 💻 ソフトウェア開発
- **必須**: test-driven-development
- **推奨**: web-artifacts-builder, aws-skills
- **オプション**: postgres, using-git-worktrees

#### 📊 データ分析・リサーチ
- **必須**: csv-data-summarizer, postgres
- **推奨**: deep-research
- **オプション**: claude-scientific-skills

#### 🎬 コンテンツ制作
- **必須**: youtube-transcript, imagen
- **推奨**: revealjs-skill
- **オプション**: video-prompting-skill

#### 🏢 ビジネス・プロジェクト管理
- **必須**: google-workspace-skills, linear-claude-skill
- **推奨**: internal-comms
- **オプション**: invoice-organizer

---

## 🎯 まとめ

### 推奨インストールプラン

**最小構成（3スキル）**:
```bash
/plugin install pdf
/plugin install docx
/plugin install xlsx
```

**標準構成（10スキル）**:
- 上記3スキル
- + pptx
- + test-driven-development
- + web-artifacts-builder
- + csv-data-summarizer
- + postgres
- + youtube-transcript
- + aws-skills

**フル構成（20+スキル）**:
- 標準構成
- + 専門スキル（scientific, google-workspace, linear等）
- + 追加ツール（imagen, deep-research等）

---

## 📞 サポート・リソース

### 公式リソース
- **Awesome Claude Skills**: https://github.com/BehiSecc/awesome-claude-skills
- **Claude Code ドキュメント**: https://docs.anthropic.com/claude-code
- **スキル開発ガイド**: https://github.com/anthropics/claude-agent-sdk

### コミュニティ
- **Discord**: Claude Code Community
- **GitHub Discussions**: 各スキルリポジトリ
- **Stack Overflow**: タグ `claude-code`

---

## 🔄 アップデート履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-02-01 | 初版作成・全スキル網羅 |

---

**次のステップ**:
1. 上記コマンドで必要なスキルをインストール
2. `/plugin` でインストール確認
3. `/<skill-name> --help` で使い方を確認
4. 実際のタスクで試す

**Happy Coding with Claude! 🚀**
