# Claude Skills インストールパッケージ 📦

**バージョン**: 1.0.0
**作成日**: 2026-02-01
**対象**: Awesome Claude Skills コレクション

---

## 📁 このフォルダについて

このフォルダには、**Awesome Claude Skills**コレクションの日本語ドキュメントが含まれています。

### 📄 含まれるファイル

1. **Claude_Skills_完全ガイド.md** (約20,000字)
   - 全スキルの詳細解説
   - インストール方法
   - 使用例
   - トラブルシューティング

2. **クイックリファレンス.md** (約2,000字)
   - 素早く参照できる早見表
   - よく使うコマンド集
   - 用途別インストールガイド

3. **README.md** (このファイル)
   - パッケージの概要
   - クイックスタート

---

## ⚡ クイックスタート

### 1. まず読むべきファイル

初めての方は**クイックリファレンス.md**から読んでください（5分）。

```bash
# macOSの場合
open クイックリファレンス.md

# Linuxの場合
xdg-open クイックリファレンス.md
```

### 2. 最初のスキルをインストール

```bash
/plugin install pdf
/plugin install docx
/plugin install xlsx
```

### 3. 使ってみる

```bash
/pdf analyze your-document.pdf
```

---

## 📚 ドキュメント構成

### レベル1: 初心者（5分）
👉 **クイックリファレンス.md**
- 必須スキル3つ
- 基本的な使い方
- トラブル解決

### レベル2: 詳細を知りたい（30分）
👉 **Claude_Skills_完全ガイド.md**
- 全15スキルの詳細
- カテゴリ別解説
- 高度な使用例

---

## 🎯 推奨インストール

### パターンA: 文書作業メイン（3スキル）
```bash
/plugin install pdf
/plugin install docx
/plugin install xlsx
```
**所要時間**: 2分

---

### パターンB: ソフトウェア開発（7スキル）
```bash
# 文書処理
/plugin install pdf
/plugin install docx

# 開発ツール
cd ~/.claude/skills
git clone https://github.com/anthropics/test-driven-development.git
git clone https://github.com/anthropics/web-artifacts-builder.git
git clone https://github.com/anthropics/aws-skills.git

# データ
git clone https://github.com/anthropics/csv-data-summarizer-claude-skill.git
git clone https://github.com/anthropics/postgres.git

# 再起動
/reload
```
**所要時間**: 10分

---

### パターンC: フルセット（15+スキル）
👉 **Claude_Skills_完全ガイド.md** の「フルインストール」セクション参照
**所要時間**: 20分

---

## 🔍 スキル検索

### 用途からスキルを探す

**「PDFを分析したい」** → `pdf` スキル
**「Excelを自動化したい」** → `xlsx` スキル
**「YouTubeの文字起こし」** → `youtube-transcript` スキル
**「AI画像生成」** → `imagen` スキル
**「テスト駆動開発」** → `test-driven-development` スキル

詳細は**完全ガイド**の目次から検索してください。

---

## 📞 サポート

### トラブル時
1. **クイックリファレンス.md** のトラブルシューティングセクション参照
2. **完全ガイド.md** の該当スキルのセクション参照
3. 公式リポジトリのIssuesを確認

### 質問・フィードバック
- Claude Code Discord
- GitHub Discussions
- 各スキルのリポジトリ

---

## 🔄 アップデート

### ドキュメントの更新
このフォルダは定期的に更新されます。

```bash
# 最新版をチェック
cd /Users/kokage/national-operations/installed-skills
git pull  # (もしgit管理している場合)
```

### スキルの更新
```bash
# 個別スキル更新
cd ~/.claude/skills/SKILL-NAME
git pull
/reload

# 全スキル更新
cd ~/.claude/skills
for dir in */; do
  cd "$dir"
  git pull
  cd ..
done
/reload
```

---

## 🎓 学習パス

### Day 1: 基礎（30分）
1. クイックリファレンスを読む
2. pdf, docx, xlsx をインストール
3. 実際のファイルで試す

### Day 2: 拡張（1時間）
1. 完全ガイドを流し読み
2. 興味あるスキルを2-3個追加
3. 各スキルの `--help` を確認

### Day 3: 実践（継続）
1. 実際の仕事でスキルを活用
2. 効率化できた箇所をメモ
3. 新しいスキルを追加

---

## 📊 統計

### 収録スキル数
- **Tier 1 (必須)**: 5スキル
- **Tier 2 (推奨)**: 5スキル
- **Tier 3 (専門)**: 5スキル
- **合計**: 15スキル＋α

### ドキュメント
- **完全ガイド**: 約20,000字
- **クイックリファレンス**: 約2,000字
- **合計**: 約22,000字

---

## ✅ チェックリスト

インストール前:
- [ ] Claude Codeがインストール済み
- [ ] 基本的な使い方を理解している
- [ ] 必要なAPIキーを準備（該当スキルのみ）

インストール後:
- [ ] `/plugin` で確認
- [ ] `/<skill> --help` で使い方確認
- [ ] 実際のファイルでテスト

---

## 🚀 次のステップ

1. ✅ **クイックリファレンス.md** を読む（5分）
2. ✅ 必須スキル3つをインストール（2分）
3. ✅ 実際に使ってみる（10分）
4. ✅ **完全ガイド.md** で詳細を確認（必要時）

---

**Happy Coding with Claude Skills! 🎉**

---

## 📄 ライセンス

このドキュメントは、各スキルの公式ドキュメントを基に作成されています。
各スキルのライセンスについては、それぞれのGitHubリポジトリを参照してください。

**ドキュメント作成**: Claude Sonnet 4.5
**日付**: 2026-02-01
