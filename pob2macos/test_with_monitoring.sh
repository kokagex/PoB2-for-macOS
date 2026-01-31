#!/bin/bash
# Test execution with process numbering and CPU monitoring

# Get next test number
TEST_NUMBER_FILE="/tmp/pob_test_counter"
if [ -f "$TEST_NUMBER_FILE" ]; then
    TEST_NUM=$(cat "$TEST_NUMBER_FILE")
    TEST_NUM=$((TEST_NUM + 1))
else
    TEST_NUM=1
fi
echo $TEST_NUM > "$TEST_NUMBER_FILE"

echo "=== Starting Test #$TEST_NUM ==="
LOG_FILE="/tmp/pob_test_${TEST_NUM}.log"
PID_FILE="/tmp/pob_test_${TEST_NUM}.pid"

# Function to check CPU and kill old processes
monitor_cpu() {
    while true; do
        CPU_IDLE=$(top -l 1 | grep "CPU usage" | awk '{print $7}' | sed 's/%//')
        CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)

        if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
            echo "⚠️  CPU usage ${CPU_USAGE}% exceeds 80% - killing old processes"

            # Kill oldest PathOfBuilding processes
            OLDEST_PIDS=$(ps aux | grep "PathOfBuilding" | grep -v grep | sort -k10 | head -3 | awk '{print $2}')
            for pid in $OLDEST_PIDS; do
                echo "Killing old process: $pid"
                kill -9 $pid 2>/dev/null
            done
        fi
        sleep 5
    done
}

# Start CPU monitoring in background
monitor_cpu &
MONITOR_PID=$!

# Run the test
echo "Running test with PID monitoring..."
./run_pob2.sh > "$LOG_FILE" 2>&1 &
APP_PID=$!
echo $APP_PID > "$PID_FILE"

echo "Test #$TEST_NUM started (PID: $APP_PID)"
echo "Log: $LOG_FILE"
echo "CPU monitor PID: $MONITOR_PID"

# Wait for specified duration (default 30s)
DURATION=${1:-30}
sleep $DURATION

# Clean up
echo "Stopping test #$TEST_NUM..."
kill $APP_PID 2>/dev/null
kill $MONITOR_PID 2>/dev/null

echo "=== Test #$TEST_NUM completed ==="
echo "Logs saved to: $LOG_FILE"
