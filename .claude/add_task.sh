#!/bin/bash

# タスクキューにタスクを追加するヘルパースクリプト
# 使用方法: ./add_task.sh "タスクの説明" [依存タスクID...]

QUEUE_FILE=".claude/task_queue.yaml"

if [ ! -f "$QUEUE_FILE" ]; then
    echo "エラー: $QUEUE_FILE が見つかりません"
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "使用方法: $0 \"タスクの説明\" [依存タスクID...]"
    echo "例: $0 \"ビルドを実行\""
    echo "例: $0 \"テストを実行\" 1 2  # タスク1と2に依存"
    exit 1
fi

DESCRIPTION=$1
shift
DEPENDENCIES=($@)

# yqの確認
if ! command -v yq &> /dev/null; then
    echo "エラー: yqがインストールされていません"
    echo "Homebrewでインストールしてください: brew install yq"
    exit 1
fi

# 次のタスクIDを取得
NEXT_ID=$(yq eval '.metadata.next_task_id' "$QUEUE_FILE")
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

# 依存関係の配列を作成
DEPS_YAML="[]"
if [ ${#DEPENDENCIES[@]} -gt 0 ]; then
    DEPS_YAML="["
    for dep in "${DEPENDENCIES[@]}"; do
        DEPS_YAML="${DEPS_YAML}${dep},"
    done
    DEPS_YAML="${DEPS_YAML%,}]"
fi

# 新しいタスクを追加
yq eval -i ".tasks += [{
  \"id\": $NEXT_ID,
  \"description\": \"$DESCRIPTION\",
  \"status\": \"pending\",
  \"dependencies\": $DEPS_YAML,
  \"retry_count\": 0,
  \"last_error\": null,
  \"created_at\": \"$TIMESTAMP\",
  \"updated_at\": \"$TIMESTAMP\",
  \"blocked_at\": null,
  \"completed_at\": null
}]" "$QUEUE_FILE"

# next_task_idをインクリメント
yq eval -i ".metadata.next_task_id = $((NEXT_ID + 1))" "$QUEUE_FILE"

echo "✓ タスク #$NEXT_ID を追加しました: $DESCRIPTION"

if [ ${#DEPENDENCIES[@]} -gt 0 ]; then
    echo "  依存関係: ${DEPENDENCIES[*]}"
fi
