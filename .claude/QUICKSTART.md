# タスクキューシステム クイックスタート

## 🚀 今すぐ使い始める

### 1. タスクを追加

**Claude Codeで**:
```
/queue add "pob2macosのビルドステータスを確認"
```

**またはコマンドラインで**:
```bash
./.claude/add_task.sh "pob2macosのビルドステータスを確認"
```

### 2. キューを確認

```bash
./.claude/show_queue.sh
```

### 3. キューを実行

**フォアグラウンドで**:
```bash
./.claude/run_queue.sh
```

**バックグラウンドで（推奨）**:
```bash
nohup ./.claude/run_queue.sh > .claude/queue_run.log 2>&1 &
```

---

## 📝 よく使うコマンド

### タスクの追加
```bash
# 単純なタスク
./.claude/add_task.sh "タスクの説明"

# 依存関係付きタスク（タスク1が完了してから実行）
./.claude/add_task.sh "依存タスク" 1

# 複数の依存関係（タスク1と2が完了してから実行）
./.claude/add_task.sh "複数依存タスク" 1 2
```

### キューの管理
```bash
# 状態を確認
./.claude/show_queue.sh

# ログを確認
cat .claude/queue_log.md

# リアルタイムでログを監視
tail -f .claude/queue_log.md

# キューをクリア（完了したタスクのみ保持）
yq eval -i '.tasks = [.tasks[] | select(.status == "done")]' .claude/task_queue.yaml

# キューを完全にリセット
yq eval -i '.tasks = []' .claude/task_queue.yaml
yq eval -i '.metadata.next_task_id = 1' .claude/task_queue.yaml
```

---

## 🌙 夜間自動実行の例

```bash
# 夕方：タスクをキューに入れる
./.claude/add_task.sh "pob2macosビルド検証"
./.claude/add_task.sh "Metalシェーダーデバッグ"
./.claude/add_task.sh "dylibデプロイ確認"
./.claude/add_task.sh "ビジュアルテスト実行"

# キューを確認
./.claude/show_queue.sh

# バックグラウンドで実行開始
nohup ./.claude/run_queue.sh > .claude/queue_run.log 2>&1 &

# プロセスIDを保存（後で停止する場合に使用）
echo $! > .claude/queue_pid.txt

# 翌朝：結果を確認
./.claude/show_queue.sh
tail -50 .claude/queue_log.md
```

---

## 🔗 依存関係の例

```bash
# ビルドパイプライン
./.claude/add_task.sh "コード検証"                    # ID: 1
./.claude/add_task.sh "ビルド実行" 1                   # ID: 2（1に依存）
./.claude/add_task.sh "ユニットテスト" 2               # ID: 3（2に依存）
./.claude/add_task.sh "統合テスト" 2                   # ID: 4（2に依存）
./.claude/add_task.sh "デプロイ" 3 4                   # ID: 5（3と4に依存）
./.claude/add_task.sh "デプロイ検証" 5                 # ID: 6（5に依存）

# 実行順序：
# 1 → 2 → (3 と 4 が並列) → 5 → 6
```

---

## ⚠️ トラブルシューティング

### レート制限でタスクがブロックされた
→ **自動的に処理されます**。指数バックオフで待機後、自動的に再試行されます。

### タスクが失敗した
```bash
# ログを確認
cat .claude/queue_log.md

# タスクの詳細を確認
./.claude/show_queue.sh

# 必要に応じて手動でステータスを変更
# .claude/task_queue.yaml を編集
```

### キューの実行が停止した
```bash
# プロセスを確認
ps aux | grep run_queue.sh

# 再起動
./.claude/run_queue.sh
```

---

## 📚 詳細ドキュメント

完全なドキュメントは `.claude/TASK_QUEUE_README.md` を参照してください。

---

## 💡 ヒント

- タスクは10分以内に完了するサイズに分割してください
- タスクの説明は具体的で実行可能な内容にしてください
- 依存関係を明示的に設定して、正しい順序で実行されるようにしてください
- レート制限は自動的に処理されるので、心配不要です
- ログは必ず確認して、何が起こったか把握しましょう

---

**準備完了！** 今すぐタスクを追加して、無人での自動実行を始めましょう 🎉
