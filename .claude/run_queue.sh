#!/bin/bash

# Claude Code 自律タスクキュー実行スクリプト
# このスクリプトはタスクキューを処理し、レート制限を自動的に処理します

set -e

# 設定
QUEUE_FILE=".claude/task_queue.yaml"
LOG_FILE=".claude/queue_log.md"
MAX_RETRIES=5
INITIAL_BACKOFF=60  # 初期バックオフ時間（秒）

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# yqの確認
if ! command -v yq &> /dev/null; then
    echo -e "${RED}エラー: yqがインストールされていません${NC}"
    echo "Homebrewでインストールしてください: brew install yq"
    exit 1
fi

# ログ記録関数
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# ログファイルの初期化
init_log() {
    if [ ! -f "$LOG_FILE" ]; then
        cat > "$LOG_FILE" <<EOF
# Claude Code タスクキュー実行ログ

開始日時: $(date '+%Y-%m-%d %H:%M:%S')

---

EOF
    fi

    echo "" >> "$LOG_FILE"
    echo "## 実行セッション: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# 次の実行可能なタスクを取得
get_next_task() {
    # pending状態で、依存関係が解決されているタスクを探す
    local task_id=$(yq eval '.tasks[] | select(.status == "pending") | select(.dependencies == [] or .dependencies == null) | .id' "$QUEUE_FILE" | head -n 1)

    if [ -z "$task_id" ]; then
        # blocked状態のタスクも確認（リトライ可能かチェック）
        local blocked_task=$(yq eval '.tasks[] | select(.status == "blocked") | select(.retry_count < '"$MAX_RETRIES"') | .id' "$QUEUE_FILE" | head -n 1)

        if [ ! -z "$blocked_task" ]; then
            # blocked_at時刻を確認して、十分な時間が経過しているかチェック
            local blocked_at=$(yq eval '.tasks[] | select(.id == '"$blocked_task"') | .blocked_at' "$QUEUE_FILE")
            local retry_count=$(yq eval '.tasks[] | select(.id == '"$blocked_task"') | .retry_count' "$QUEUE_FILE")

            # 指数バックオフの計算
            local backoff_time=$((INITIAL_BACKOFF * (2 ** retry_count)))

            if [ ! -z "$blocked_at" ]; then
                local blocked_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$blocked_at" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local elapsed=$((current_timestamp - blocked_timestamp))

                if [ $elapsed -ge $backoff_time ]; then
                    echo "$blocked_task"
                    return
                else
                    local remaining=$((backoff_time - elapsed))
                    log_message "INFO" "ブロックされたタスク $blocked_task は ${remaining}秒後にリトライ可能"
                fi
            fi
        fi

        echo ""
    else
        echo "$task_id"
    fi
}

# タスク情報を取得
get_task_description() {
    local task_id=$1
    yq eval '.tasks[] | select(.id == '"$task_id"') | .description' "$QUEUE_FILE"
}

# タスクステータスを更新
update_task_status() {
    local task_id=$1
    local status=$2
    local error_message=${3:-null}
    local timestamp=$(date '+%Y-%m-%dT%H:%M:%S')

    yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .status) = "'"$status"'"' "$QUEUE_FILE"
    yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .updated_at) = "'"$timestamp"'"' "$QUEUE_FILE"

    if [ "$status" == "blocked" ]; then
        yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .blocked_at) = "'"$timestamp"'"' "$QUEUE_FILE"
        yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .retry_count) += 1' "$QUEUE_FILE"

        if [ "$error_message" != "null" ]; then
            yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .last_error) = "'"$error_message"'"' "$QUEUE_FILE"
        fi
    elif [ "$status" == "done" ]; then
        yq eval -i '(.tasks[] | select(.id == '"$task_id"') | .completed_at) = "'"$timestamp"'"' "$QUEUE_FILE"

        # 依存関係を解決：他のタスクがこのタスクに依存している場合、依存関係を削除
        yq eval -i '(.tasks[] | .dependencies) |= (. - ['"$task_id"'])' "$QUEUE_FILE"
    fi
}

# Claude Codeを実行
run_claude_code() {
    local task_id=$1
    local description=$2
    local temp_output=$(mktemp)

    log_message "INFO" "タスク $task_id を実行中: $description"
    echo -e "${BLUE}▶ タスク $task_id を実行中...${NC}"

    # Claude Codeを実行（タイムアウト付き）
    if timeout 600 claude -p "$description" > "$temp_output" 2>&1; then
        log_message "SUCCESS" "タスク $task_id が正常に完了"
        echo -e "${GREEN}✓ タスク $task_id が完了しました${NC}"

        # 出力をログに記録
        echo "### タスク $task_id の出力:" >> "$LOG_FILE"
        echo '```' >> "$LOG_FILE"
        cat "$temp_output" >> "$LOG_FILE"
        echo '```' >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"

        rm "$temp_output"
        return 0
    else
        local exit_code=$?
        local error_output=$(cat "$temp_output")

        # レート制限エラーをチェック
        if echo "$error_output" | grep -qi "rate limit\|usage limit\|quota exceeded"; then
            log_message "WARNING" "タスク $task_id がレート制限に達しました"
            echo -e "${YELLOW}⚠ レート制限に達しました。タスクをブロック状態にします${NC}"

            echo "### タスク $task_id のエラー（レート制限）:" >> "$LOG_FILE"
            echo '```' >> "$LOG_FILE"
            echo "$error_output" >> "$LOG_FILE"
            echo '```' >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"

            rm "$temp_output"
            return 2  # レート制限コード
        else
            log_message "ERROR" "タスク $task_id が失敗しました（終了コード: $exit_code）"
            echo -e "${RED}✗ タスク $task_id が失敗しました${NC}"

            echo "### タスク $task_id のエラー:" >> "$LOG_FILE"
            echo '```' >> "$LOG_FILE"
            echo "$error_output" >> "$LOG_FILE"
            echo '```' >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"

            rm "$temp_output"
            return 1  # 一般的なエラー
        fi
    fi
}

# メイン処理ループ
main() {
    echo -e "${GREEN}=== Claude Code 自律タスクキュー ===${NC}"
    echo ""

    init_log

    local processed_count=0
    local error_count=0
    local blocked_count=0

    while true; do
        # 次のタスクを取得
        local task_id=$(get_next_task)

        if [ -z "$task_id" ]; then
            # 実行可能なタスクがない
            local pending_count=$(yq eval '.tasks[] | select(.status == "pending") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')
            local blocked_task_count=$(yq eval '.tasks[] | select(.status == "blocked") | .id' "$QUEUE_FILE" | wc -l | tr -d ' ')

            if [ "$pending_count" -eq 0 ] && [ "$blocked_task_count" -eq 0 ]; then
                echo -e "${GREEN}✓ すべてのタスクが完了しました${NC}"
                log_message "INFO" "すべてのタスクが完了しました"
                break
            elif [ "$pending_count" -gt 0 ]; then
                echo -e "${YELLOW}依存関係が解決されていないタスクがあります${NC}"
                log_message "WARNING" "依存関係が解決されていないタスクがあります"
                break
            else
                # ブロックされたタスクのみ残っている
                echo -e "${YELLOW}すべてのタスクがブロックされています。待機中...${NC}"
                log_message "INFO" "すべてのタスクがブロックされています。60秒待機します"
                sleep 60
                continue
            fi
        fi

        # タスク情報を取得
        local description=$(get_task_description "$task_id")

        # タスクを実行中に設定
        update_task_status "$task_id" "in_progress"

        # Claude Codeを実行
        if run_claude_code "$task_id" "$description"; then
            # 成功
            update_task_status "$task_id" "done"
            ((processed_count++))
        else
            local result=$?
            if [ $result -eq 2 ]; then
                # レート制限
                update_task_status "$task_id" "blocked" "Rate limit exceeded"
                ((blocked_count++))

                # バックオフ時間を計算
                local retry_count=$(yq eval '.tasks[] | select(.id == '"$task_id"') | .retry_count' "$QUEUE_FILE")
                local backoff_time=$((INITIAL_BACKOFF * (2 ** (retry_count - 1))))

                echo -e "${YELLOW}${backoff_time}秒待機してから続行します...${NC}"
                log_message "INFO" "${backoff_time}秒の指数バックオフを開始"
                sleep "$backoff_time"
            else
                # その他のエラー
                update_task_status "$task_id" "blocked" "Execution failed"
                ((error_count++))
            fi
        fi

        echo ""
        sleep 2  # タスク間の短い遅延
    done

    # サマリーを表示
    echo ""
    echo -e "${GREEN}=== 実行サマリー ===${NC}"
    echo "完了: $processed_count"
    echo "エラー: $error_count"
    echo "ブロック: $blocked_count"
    echo ""

    log_message "INFO" "実行完了 - 完了: $processed_count, エラー: $error_count, ブロック: $blocked_count"
}

# スクリプト実行
main "$@"
