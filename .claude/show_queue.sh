#!/bin/bash

# タスクキューの状態を表示するスクリプト

QUEUE_FILE=".claude/task_queue.yaml"

if [ ! -f "$QUEUE_FILE" ]; then
    echo "エラー: $QUEUE_FILE が見つかりません"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "エラー: yqがインストールされていません"
    echo "Homebrewでインストールしてください: brew install yq"
    exit 1
fi

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== タスクキューの状態 ===${NC}\n"

# 統計情報
TOTAL=$(yq eval '.tasks | length' "$QUEUE_FILE")
PENDING=$(yq eval '.tasks[] | select(.status == "pending") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')
IN_PROGRESS=$(yq eval '.tasks[] | select(.status == "in_progress") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')
BLOCKED=$(yq eval '.tasks[] | select(.status == "blocked") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')
DONE=$(yq eval '.tasks[] | select(.status == "done") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')

echo -e "${BLUE}統計:${NC}"
echo "  合計: $TOTAL タスク"
echo -e "  ${YELLOW}Pending:${NC} $PENDING"
echo -e "  ${CYAN}In Progress:${NC} $IN_PROGRESS"
echo -e "  ${RED}Blocked:${NC} $BLOCKED"
echo -e "  ${GREEN}Done:${NC} $DONE"
echo ""

# Pendingタスク
if [ $PENDING -gt 0 ]; then
    echo -e "${YELLOW}## Pending (実行待ち)${NC}"
    yq eval '.tasks[] | select(.status == "pending") | "  [#" + (.id|tostring) + "] " + .description' "$QUEUE_FILE"
    echo ""
fi

# In Progressタスク
if [ $IN_PROGRESS -gt 0 ]; then
    echo -e "${CYAN}## In Progress (実行中)${NC}"
    yq eval '.tasks[] | select(.status == "in_progress") | "  [#" + (.id|tostring) + "] " + .description' "$QUEUE_FILE"
    echo ""
fi

# Blockedタスク
if [ $BLOCKED -gt 0 ]; then
    echo -e "${RED}## Blocked (ブロック中)${NC}"
    yq eval '.tasks[] | select(.status == "blocked") | "  [#" + (.id|tostring) + "] " + .description + " (リトライ: " + (.retry_count|tostring) + "/5)"' "$QUEUE_FILE"

    # ブロックされたタスクの詳細
    echo ""
    echo -e "${RED}ブロック詳細:${NC}"
    while IFS= read -r task_id; do
        if [ ! -z "$task_id" ]; then
            blocked_at=$(yq eval '.tasks[] | select(.id == '"$task_id"') | .blocked_at' "$QUEUE_FILE")
            last_error=$(yq eval '.tasks[] | select(.id == '"$task_id"') | .last_error' "$QUEUE_FILE")
            echo "  タスク #$task_id:"
            echo "    ブロック時刻: $blocked_at"
            echo "    エラー: $last_error"
        fi
    done < <(yq eval '.tasks[] | select(.status == "blocked") | .id' "$QUEUE_FILE")
    echo ""
fi

# Doneタスク
if [ $DONE -gt 0 ]; then
    echo -e "${GREEN}## Done (完了)${NC}"
    yq eval '.tasks[] | select(.status == "done") | "  [#" + (.id|tostring) + "] " + .description' "$QUEUE_FILE"
    echo ""
fi

# 依存関係のあるタスク
HAS_DEPS=$(yq eval '.tasks[] | select(.dependencies != [] and .dependencies != null) | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')
if [ $HAS_DEPS -gt 0 ]; then
    echo -e "${BLUE}## 依存関係${NC}"
    while IFS= read -r task_id; do
        if [ ! -z "$task_id" ]; then
            description=$(yq eval '.tasks[] | select(.id == '"$task_id"') | .description' "$QUEUE_FILE")
            deps=$(yq eval '.tasks[] | select(.id == '"$task_id"') | .dependencies | join(", ")' "$QUEUE_FILE")
            echo "  [#$task_id] $description"
            echo "    → タスク $deps の完了を待機中"
        fi
    done < <(yq eval '.tasks[] | select(.dependencies != [] and .dependencies != null) | .id' "$QUEUE_FILE")
    echo ""
fi

# 次の実行可能なタスク
NEXT_TASK=$(yq eval '.tasks[] | select(.status == "pending") | select(.dependencies == [] or .dependencies == null) | .id' "$QUEUE_FILE" | head -n 1)
if [ ! -z "$NEXT_TASK" ]; then
    NEXT_DESC=$(yq eval '.tasks[] | select(.id == '"$NEXT_TASK"') | .description' "$QUEUE_FILE")
    echo -e "${GREEN}次の実行可能なタスク:${NC} [#$NEXT_TASK] $NEXT_DESC"
    echo ""
fi

# 実行コマンドを表示
if [ $PENDING -gt 0 ] || [ $BLOCKED -gt 0 ]; then
    echo -e "${CYAN}キューを実行するには:${NC}"
    echo "  ./.claude/run_queue.sh"
    echo ""
    echo -e "${CYAN}バックグラウンドで実行するには:${NC}"
    echo "  nohup ./.claude/run_queue.sh > .claude/queue_run.log 2>&1 &"
fi
