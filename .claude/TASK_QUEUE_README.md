# Claude Code 自律タスクキューシステム

レート制限を自動的に処理しながら、無人でタスクを実行するための自律タスクキューシステムです。

## 概要

このシステムは以下の機能を提供します：

- ✅ タスクのキューイングと自動実行
- ✅ レート制限の自動検出と指数バックオフ
- ✅ タスク間の依存関係管理
- ✅ 詳細な実行ログ
- ✅ 失敗したタスクの自動リトライ（最大5回）
- ✅ キューの永続化（YAMLファイル）

## ファイル構成

```
.claude/
├── task_queue.yaml          # タスクキュー（永続化データ）
├── queue_log.md             # 実行ログ
├── run_queue.sh             # キュー実行スクリプト
├── add_task.sh              # タスク追加ヘルパースクリプト
├── show_queue.sh            # キュー状態表示スクリプト
└── skills/queue/SKILL.md    # /queue スキル定義
```

## セットアップ

### 1. 依存関係のインストール

```bash
# yqが必要です（YAMLファイルの操作に使用）
brew install yq
```

### 2. 確認

```bash
# スクリプトが実行可能であることを確認
ls -la .claude/*.sh

# すべて -rwxr-xr-x になっていればOK
```

## 基本的な使い方

### 方法1: Claude Codeのスキルを使用（推奨）

```bash
# Claude Codeで以下のように入力
/queue add "pob2macosのビルドステータスを確認"
/queue add "Metalシェーダーのデバッグを実行"
/queue list              # キューの確認
/queue run               # キューの実行開始
```

### 方法2: コマンドラインスクリプトを使用

```bash
# タスクの追加
./.claude/add_task.sh "pob2macosのビルドステータスを確認"

# 依存関係のあるタスクの追加
./.claude/add_task.sh "ビルドを実行"
./.claude/add_task.sh "テストを実行" 1  # タスク1に依存

# キューの状態を確認
./.claude/show_queue.sh

# キューを実行
./.claude/run_queue.sh

# バックグラウンドで実行
nohup ./.claude/run_queue.sh > .claude/queue_run.log 2>&1 &
```

## タスクの構造

各タスクは以下のフィールドを持ちます：

```yaml
- id: 1                                    # タスクID（自動採番）
  description: "タスクの説明"              # 何をするか
  status: pending                          # pending, in_progress, done, blocked
  dependencies: []                         # 依存するタスクのIDリスト
  retry_count: 0                           # リトライ回数
  last_error: null                         # 最後のエラーメッセージ
  created_at: "2026-02-04T10:00:00"       # 作成日時
  updated_at: "2026-02-04T10:00:00"       # 更新日時
  blocked_at: null                         # ブロックされた日時
  completed_at: null                       # 完了日時
```

## タスクのステータス

- **pending**: 実行待ち（依存関係が解決されている）
- **in_progress**: 現在実行中
- **blocked**: レート制限やエラーでブロック中（自動的に再試行される）
- **done**: 完了

## レート制限の処理

レート制限に達した場合、システムは以下のように動作します：

1. タスクのステータスを `blocked` に変更
2. リトライカウントをインクリメント
3. 指数バックオフで待機
   - 1回目: 60秒
   - 2回目: 120秒
   - 3回目: 240秒
   - 4回目: 480秒
   - 5回目: 960秒
4. 待機後、自動的に再試行
5. 最大5回まで再試行（それでも失敗したら停止）

## 依存関係の管理

タスクは他のタスクに依存できます：

```bash
# タスク1を追加
./.claude/add_task.sh "ビルドを実行"

# タスク2を追加（タスク1に依存）
./.claude/add_task.sh "テストを実行" 1

# タスク3を追加（タスク1と2の両方に依存）
./.claude/add_task.sh "デプロイを実行" 1 2
```

実行順序：
1. タスク1が完了
2. タスク2が実行可能になる
3. タスク2が完了
4. タスク3が実行可能になる（タスク1と2の両方が完了しているため）

## ログとモニタリング

### 実行ログの確認

```bash
# ログファイルを確認
cat .claude/queue_log.md

# リアルタイムでログを監視（バックグラウンド実行時）
tail -f .claude/queue_log.md
```

### キューの状態確認

```bash
# キューの状態を表示
./.claude/show_queue.sh
```

出力例：
```
=== タスクキューの状態 ===

統計:
  合計: 5 タスク
  Pending: 2
  In Progress: 1
  Blocked: 0
  Done: 2

## In Progress (実行中)
  [#3] Metalシェーダーのデバッグを実行

## Pending (実行待ち)
  [#4] dylibのデプロイ確認
  [#5] ビジュアルテストの実行

## Done (完了)
  [#1] pob2macosのビルドステータスを確認
  [#2] ビルドを実行

次の実行可能なタスク: [#4] dylibのデプロイ確認

キューを実行するには:
  ./.claude/run_queue.sh
```

## 典型的なワークフロー

### 夜間に自動実行

```bash
# 夕方にタスクをキューに入れる
./.claude/add_task.sh "pob2macosのビルドステータスを確認"
./.claude/add_task.sh "Metalシェーダーのデバッグを実行"
./.claude/add_task.sh "dylibのデプロイ確認"
./.claude/add_task.sh "ビジュアルテストの実行"
./.claude/add_task.sh "レポート生成"

# バックグラウンドで実行開始
nohup ./.claude/run_queue.sh > .claude/queue_run.log 2>&1 &

# プロセスIDを保存
echo $! > .claude/queue_pid.txt

# 翌朝、結果を確認
./.claude/show_queue.sh
cat .claude/queue_log.md
```

### レート制限を考慮した連続タスク

```bash
# 大量のタスクを追加
for i in {1..10}; do
    ./.claude/add_task.sh "タスク $i を実行"
done

# キューを実行（レート制限に達したら自動的に待機して再開）
./.claude/run_queue.sh
```

### 依存関係のある複雑なワークフロー

```bash
# ビルドパイプライン
./.claude/add_task.sh "ソースコードの検証"                    # タスク1
./.claude/add_task.sh "ビルドを実行" 1                          # タスク2（1に依存）
./.claude/add_task.sh "ユニットテストを実行" 2                  # タスク3（2に依存）
./.claude/add_task.sh "統合テストを実行" 2                      # タスク4（2に依存）
./.claude/add_task.sh "デプロイを実行" 3 4                      # タスク5（3と4に依存）
./.claude/add_task.sh "デプロイ検証を実行" 5                    # タスク6（5に依存）

# 実行
./.claude/run_queue.sh
```

## トラブルシューティング

### yqがインストールされていない

```bash
brew install yq
```

### タスクがブロックされ続ける

```bash
# ログを確認
cat .claude/queue_log.md

# タスクキューを確認
./.claude/show_queue.sh

# 必要に応じて、手動でタスクのステータスをリセット
# .claude/task_queue.yaml を編集し、ブロックされたタスクを pending に戻す
```

### キューの実行が停止している

```bash
# バックグラウンドプロセスを確認
ps aux | grep run_queue.sh

# 必要に応じて再起動
./.claude/run_queue.sh
```

### キューをリセットしたい

```bash
# バックアップを作成
cp .claude/task_queue.yaml .claude/task_queue.yaml.backup

# キューをクリア（完了したタスクを除く）
yq eval -i '.tasks = [.tasks[] | select(.status == "done")]' .claude/task_queue.yaml

# または完全にリセット
yq eval -i '.tasks = []' .claude/task_queue.yaml
yq eval -i '.metadata.next_task_id = 1' .claude/task_queue.yaml
```

## ベストプラクティス

### 1. タスクの粒度

- ✅ **良い**: 「pob2macosのMetalシェーダーをビルドしてテスト」
- ❌ **悪い**: 「プロジェクト全体を完了する」

タスクは10分以内に完了するサイズにしてください（タイムアウトは10分です）。

### 2. タスクの説明

- ✅ **良い**: 「src/metal_backend.mmの黄色テキスト問題をデバッグし、修正を提案」
- ❌ **悪い**: 「バグ修正」

具体的で実行可能な説明にしてください。

### 3. 依存関係

- ✅ **良い**: ビルド → テスト → デプロイの順序を依存関係で表現
- ❌ **悪い**: すべてのタスクを独立して実行し、手動で順序を管理

依存関係を明示的に設定することで、正しい順序で実行されます。

### 4. ログの監視

```bash
# 定期的にログを確認
tail -20 .claude/queue_log.md

# または継続的に監視
watch -n 10 "./.claude/show_queue.sh"
```

## 高度な使用例

### cronジョブとして設定

```bash
# crontabを編集
crontab -e

# 毎日午前2時にキューを実行
0 2 * * * cd /Users/kokage/national-operations && ./.claude/run_queue.sh >> .claude/cron.log 2>&1
```

### Slackへの通知（オプション）

```bash
# run_queue.shの最後に追加
# curl -X POST -H 'Content-type: application/json' \
#   --data '{"text":"タスクキュー実行完了"}' \
#   YOUR_SLACK_WEBHOOK_URL
```

## まとめ

このタスクキューシステムを使用することで：

- 🌙 **夜間に無人で作業を実行**できます
- 🔄 **レート制限を自動的に処理**し、待機して再試行します
- 📊 **すべての実行を記録**し、後で確認できます
- 🔗 **複雑な依存関係**を持つワークフローを管理できます
- ⚡ **手動介入なし**で連続してタスクを実行できます

質問や問題がある場合は、`.claude/queue_log.md` を確認するか、`/queue` スキルを使ってClaude Codeに相談してください。
