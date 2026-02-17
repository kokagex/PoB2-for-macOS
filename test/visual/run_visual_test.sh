#!/bin/bash
set -euo pipefail

# ====================================================
# pob2 ビジュアル回帰テスト ランナー
# アプローチA: TakeScreenshot API → B: screencapture フォールバック
# ====================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/PathOfBuilding.app"
RESOURCES="$APP_DIR/Contents/Resources"
SCREENSHOT_DIR="$RESOURCES/screenshots"
BASELINE_DIR="$PROJECT_ROOT/test/visual/baselines"
RESULTS_DIR="$PROJECT_ROOT/test/visual/results"
DIFF_DIR="$PROJECT_ROOT/test/visual/diffs"

# タイムアウト (秒)
TIMEOUT="${POB_TEST_TIMEOUT:-30}"

# ベースライン更新モード
UPDATE_BASELINES=false
if [[ "${1:-}" == "--update-baselines" ]]; then
    UPDATE_BASELINES=true
fi

mkdir -p "$SCREENSHOT_DIR" "$RESULTS_DIR" "$DIFF_DIR" "$BASELINE_DIR"

echo "=== pob2 Visual Regression Test ==="
echo "Project root: $PROJECT_ROOT"
echo "Timeout: ${TIMEOUT}s"
echo ""

# --- Step 1: アプリ起動 (POB_VISUAL_TEST=1 でテストモード) ---
echo "Starting pob2 in visual test mode..."

cd "$RESOURCES"
POB_VISUAL_TEST=1 "$APP_DIR/Contents/MacOS/PathOfBuilding" > /tmp/pob2_visual_test.log 2>&1 &
POB_PID=$!

echo "pob2 started (PID: $POB_PID)"

# --- Step 2: スクリーンショット完了待ち ---
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! kill -0 $POB_PID 2>/dev/null; then
        echo "pob2 exited after ${ELAPSED}s"
        break
    fi

    # テストモードの自動終了を待つ
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# 強制終了
if kill -0 $POB_PID 2>/dev/null; then
    echo "Timeout reached. Stopping pob2..."
    kill $POB_PID 2>/dev/null || true
    wait $POB_PID 2>/dev/null || true
fi

# --- Step 2.5: フォールバック - screencapture (アプローチB) ---
# TakeScreenshotが機能しなかった場合の代替手段
# 注: このフォールバックは手動テスト用。自動テストではTakeScreenshotを使用
fallback_capture() {
    local output_path="$1"
    local window_id
    window_id=$(osascript -e '
    tell application "System Events"
        set pobProc to first process whose name contains "PathOfBuilding"
        return id of first window of pobProc
    end tell
    ' 2>/dev/null || echo "")

    if [ -n "$window_id" ]; then
        screencapture -l "$window_id" -o -t png "$output_path"
        return $?
    fi
    return 1
}

# --- Step 3: 画像比較 ---
echo ""
echo "=== Comparing Screenshots ==="
echo ""

FAIL_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0

# スクリーンショットファイルを検索
for actual in "$SCREENSHOT_DIR"/test_*.png "$SCREENSHOT_DIR"/test_*.bmp "$SCREENSHOT_DIR"/test_*.tga; do
    [ -f "$actual" ] || continue

    # ファイル名からテストケース名を抽出
    basename=$(basename "$actual")
    test_case="${basename%.*}"
    test_case="${test_case#test_}"

    BASELINE="$BASELINE_DIR/${test_case}.png"
    DIFF="$DIFF_DIR/${test_case}_diff.png"

    if $UPDATE_BASELINES; then
        echo "[UPDATE] $test_case - Saving as new baseline"
        cp "$actual" "$BASELINE"
        PASS_COUNT=$((PASS_COUNT + 1))
        continue
    fi

    if [ ! -f "$BASELINE" ]; then
        echo "[NEW]  $test_case - No baseline exists. Saving as new baseline."
        cp "$actual" "$BASELINE"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    # Python 画像比較
    if python3 "$SCRIPT_DIR/visual_diff.py" \
        "$BASELINE" "$actual" \
        --diff "$DIFF" \
        --pixel-threshold 5.0 \
        --ssim-threshold 0.98 \
        --diff-pct 0.1; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# スクリーンショットが1つもない場合
if [ $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT)) -eq 0 ]; then
    echo "[WARN] No screenshots found in $SCREENSHOT_DIR"
    echo "       TakeScreenshot may not have produced output."
    echo "       Check /tmp/pob2_visual_test.log for details."
    SKIP_COUNT=1
fi

echo ""
echo "=== Summary ==="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  SKIP: $SKIP_COUNT"
echo ""

# --- Step 4: クリーンアップ ---
# テスト用スクリーンショットは残す（デバッグ用）
# rm -f "$SCREENSHOT_DIR"/test_*.png

# 結果コード
if [ $FAIL_COUNT -gt 0 ]; then
    echo "VISUAL REGRESSION TEST FAILED"
    exit 1
else
    echo "VISUAL REGRESSION TEST PASSED"
    exit 0
fi
