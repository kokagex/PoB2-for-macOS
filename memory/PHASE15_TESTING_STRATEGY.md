# Phase 15: ThreadSanitizer & Valgrind Testing Strategy

**Document**: PHASE15_TESTING_STRATEGY.md
**Authority**: Sage (賢者) - Testing & Validation Authority
**Status**: APPROVED FOR MERCHANT EXECUTION
**Date**: 2026-01-29
**Length**: 2,400+ words (complete test specification)

---

## Executive Summary

This document specifies comprehensive testing strategy for validating thread safety and memory safety of the cooperative shutdown implementation in Phase 15.

**Two primary testing tools**:
1. **ThreadSanitizer** - Detects data races and synchronization bugs
2. **Valgrind** - Detects memory leaks and invalid memory access

**Six test scenarios** exercise all critical code paths:
- Single timeout (baseline)
- Concurrent timeouts (real-world)
- Sequential stress test (endurance)
- Edge cases (allocation, blocking I/O)
- Rapid cycles (stress)

**Quality gates**:
- ThreadSanitizer: ZERO races in all scenarios
- Valgrind: ZERO memory leaks in all scenarios
- Clean build: No compiler warnings

---

## Part 1: ThreadSanitizer Configuration & Execution

### 1.1 ThreadSanitizer Build Configuration

**Compiler Flags**:
```bash
-fsanitize=thread              # Enable thread sanitizer
-g                             # Include debug symbols
-O1 or O2                       # Optimization (O0 too slow, O3 may hide bugs)
-fPIC                          # Position-independent code
```

**CMakeLists.txt Configuration**:
```cmake
# Enable ThreadSanitizer in CMake
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)

if(ENABLE_TSAN)
    add_compile_options(-fsanitize=thread -g)
    add_link_options(-fsanitize=thread)
endif()
```

**Build Command**:
```bash
cd /Users/kokage/national-operations/pob2macos
mkdir build_tsan
cd build_tsan
cmake -DENABLE_TSAN=ON ..
make clean
make -j4
```

**Verification**:
```bash
# Check binary has TSAN instrumentation
nm ./pob2macos | grep __tsan | head -5
# Should output symbols like: __tsan_init, __tsan_write, etc.
```

### 1.2 Runtime ThreadSanitizer Configuration

**Environment Variables**:

```bash
# Set before running tests
export TSAN_OPTIONS="halt_on_error=1:verbosity=1:history_size=7"
```

**TSAN_OPTIONS Explanation**:

| Option | Value | Rationale |
|--------|-------|-----------|
| `halt_on_error` | 1 | Stop on first race detected (don't continue) |
| `verbosity` | 1 | Moderate verbosity (0=quiet, 2=verbose) |
| `history_size` | 7 | Keep history of last 7 memory accesses |
| `log_path` | tsan.log | Write output to file (optional) |
| `suppress_equal_pcs` | 1 | Suppress duplicate races at same PC |

**Full TSAN Configuration Example**:
```bash
export TSAN_OPTIONS="halt_on_error=1:\
verbosity=1:\
history_size=7:\
log_path=/tmp/tsan-report:\
thread_lifetime=32768"
```

### 1.3 Expected ThreadSanitizer Output

**CLEAN Output (PASS)**:
```
==================
WARNING: ThreadSanitizer: Processed 0 events
SUMMARY: ThreadSanitizer: 0 races detected
==================
```

**With Race Detected (FAIL)**:
```
==================
WARNING: ThreadSanitizer: data race
Read of size 4 at 0x7fff... by thread T2:
    #0 check_shutdown at subscript_worker.c:147 (...)
    #1 subscript_worker_thread at subscript_worker.c:182 (...)

Previous write of size 4 at 0x7fff... by thread T1:
    #0 request_worker_shutdown at subscript_worker.c:95 (...)

Mutexes held: none
==================
SUMMARY: ThreadSanitizer: 1 data race detected
==================
```

**If races detected**: Analyze stack traces to identify synchronization issue.

### 1.4 Common ThreadSanitizer False Positives

**Intentional suppressions** (if any):

```bash
# Create suppressions file if needed
cat > /tmp/tsan_suppressions.txt <<EOF
# Suppress known false positives (rarely needed)
# race:function_name
# race:file_name.c:line_number
EOF

export TSAN_OPTIONS="suppressions=/tmp/tsan_suppressions.txt"
```

**Note**: Should require zero suppressions if design is correct.

---

## Part 2: Valgrind Configuration & Execution

### 2.1 Valgrind Build Configuration

**Compiler Flags** (different from ThreadSanitizer):
```bash
-g                   # Debug symbols (REQUIRED)
-O1 or -O0          # Lower optimization for better accuracy
-fno-omit-frame-pointer  # Keep frame pointers for stack traces
```

**CMakeLists.txt Configuration**:
```cmake
option(ENABLE_VALGRIND "Build for Valgrind" OFF)

if(ENABLE_VALGRIND)
    add_compile_options(-g -O0 -fno-omit-frame-pointer)
endif()
```

**Build Command**:
```bash
cd /Users/kokage/national-operations/pob2macos
mkdir build_valgrind
cd build_valgrind
cmake -DENABLE_VALGRIND=ON ..
make clean
make -j4
```

### 2.2 Valgrind Leak Detection Configuration

**Core Valgrind Flags**:

```bash
valgrind \
  --tool=memcheck \              # Memory checking (default)
  --leak-check=full \            # Complete leak detection
  --show-leak-kinds=all \        # Show all leak types
  --track-origins=yes \          # Track memory origins
  --track-fds=yes \              # Track file descriptors
  --error-exitcode=1 \           # Exit with error if leaks found
  --log-file=valgrind-%p.log \   # Log to file
  ./pob2macos
```

**Leak Check Modes**:

| Mode | Sensitivity |
|------|-------------|
| `no` | Don't check for leaks |
| `summary` | Show summary only |
| `yes` | Definite + indirect leaks |
| `full` | Everything (recommended) |

**Leak Kinds** (shown with `--show-leak-kinds=all`):

| Kind | Definition |
|------|-----------|
| `definitely lost` | **CRITICAL** - Must be zero |
| `indirectly lost` | Lost due to definitely lost parent |
| `possibly lost` | Could be leak, probably false positive |
| `still reachable` | Memory allocated but not freed at exit |
| `suppressed` | Leaks matching suppression rules |

### 2.3 Expected Valgrind Output (CLEAN)

**PASS Output**:
```
==12345== HEAP SUMMARY:
==12345==     in use at exit: 1,024 bytes in 8 blocks
==12345==   total heap alloc: 524,288 bytes in 8,192 blocks
==12345==   total heap free: 523,264 bytes in 8,184 blocks
==12345==   free'd blocks reused: 8,100 times
==12345==   still reachable: 1,024 bytes in 8 blocks
==12345==       definitely lost: 0 bytes in 0 blocks
==12345==       indirectly lost: 0 bytes in 0 blocks
==12345==         possibly lost: 0 bytes in 0 blocks
==12345== SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

**FAIL Output** (if lua_close not called):
```
==12345== HEAP SUMMARY:
==12345==     in use at exit: 16,384 bytes in 16 blocks
==12345==   total heap alloc: 32,768 bytes in 32 blocks
==12345==   total heap free: 16,384 bytes in 16 blocks
==12345==   free'd blocks reused: 0 times
==12345==       definitely lost: 16,384 bytes in 16 blocks  ← **FAIL**
==12345==       indirectly lost: 0 bytes in 0 blocks
==12345==         possibly lost: 0 bytes in 0 blocks
==12345== SUMMARY: 2 errors from 2 contexts (suppressed: 0 from 0)
```

### 2.4 Valgrind Suppressions (Minimal)

**Suppressions for Initialization** (normal, not leaks):

```
# File: valgrind_suppress.txt
{
   <init_libpthread>
   Memcheck:Leak
   match-leak-kinds: reachable
   fun:malloc
   fun:pthread_create
}
```

**Apply suppressions**:
```bash
valgrind --suppressions=valgrind_suppress.txt ./pob2macos
```

**Target**: Ideally zero suppressions needed.

---

## Part 3: Test Scenario Specifications

### Scenario A: Single Sub-Script Timeout (Baseline)

**Purpose**: Verify basic timeout handling doesn't leak memory.

**Setup**:
```c
// Create one subscription
// Set timeout: 2 seconds
// Run script that takes 5 seconds
// Expect: timeout triggers, cleanup runs, no leaks
```

**Execution**:
```bash
# ThreadSanitizer
export TSAN_OPTIONS="halt_on_error=1:verbosity=1"
./pob2macos --test-scenario A

# Valgrind
valgrind --leak-check=full --show-leak-kinds=all \
  ./pob2macos --test-scenario A
```

**Duration**: 5-10 minutes (2s timeout, 5s script wait)

**Success Criteria**:
- [ ] ThreadSanitizer: ZERO races detected
- [ ] Valgrind: definitely lost 0 bytes
- [ ] Valgrind: no invalid reads/writes
- [ ] Program exits normally
- [ ] No core dumps

**Expected Metrics**:
- Timeout latency: 100-200ms from trigger to thread exit
- Memory freed: All Lua allocations
- Resource counters: created == freed

---

### Scenario B: 3 Concurrent Scripts, 1 Timeout (Real-World)

**Purpose**: Validate concurrent behavior and synchronization.

**Setup**:
```c
// Create 3 subscriptions in parallel
// First script: normal execution (10s), no timeout
// Second script: timeout at 2s (script is 5s)
// Third script: normal execution (3s), no timeout
// Expected: Only second script times out, others complete normally
```

**Execution**:
```bash
# ThreadSanitizer (tighter checking)
export TSAN_OPTIONS="halt_on_error=1:verbosity=2:history_size=10"
timeout 30 ./pob2macos --test-scenario B

# Valgrind
timeout 30 valgrind --leak-check=full \
  ./pob2macos --test-scenario B
```

**Duration**: 10-15 minutes (longest script: 10s, plus overhead)

**Success Criteria**:
- [ ] ThreadSanitizer: ZERO races on shutdown_requested flag
- [ ] ThreadSanitizer: ZERO races on resource counters
- [ ] Valgrind: definitely lost 0 bytes
- [ ] Timed-out script cleaned up
- [ ] Other scripts complete normally
- [ ] No deadlocks (all threads exit)

**Expected Metrics**:
- Concurrent workers: 3 created, 3 exited
- Lua states: 3 created, 3 closed
- Memory: All freed when slowest script completes

**Race Detection Points**:
- shutdown_requested flag (should be protected by volatility)
- active_workers counter (should be atomic)
- Result pipes (should have synchronization)

---

### Scenario C: 10 Sequential Timeouts (Stress)

**Purpose**: Detect memory leaks and resource exhaustion over time.

**Setup**:
```c
// Loop 10 times:
//   Create subscription with 1 second timeout
//   Run script that takes 5 seconds
//   Timeout triggers after 1s
//   Cleanup and continue
// After 10 cycles, verify all resources freed
```

**Execution**:
```bash
# ThreadSanitizer
export TSAN_OPTIONS="halt_on_error=1:verbosity=1"
timeout 60 ./pob2macos --test-scenario C

# Valgrind
timeout 60 valgrind --leak-check=full \
  --log-file=valgrind-scenario-c.log \
  ./pob2macos --test-scenario C
```

**Duration**: 50-60 seconds (10x 5s = 50s, plus overhead)

**Success Criteria**:
- [ ] All 10 timeouts complete without error
- [ ] ThreadSanitizer: ZERO races across all 10 iterations
- [ ] Valgrind: definitely lost 0 bytes after 10 timeouts
- [ ] Memory footprint stable (not growing)
- [ ] Subscription slots recycled correctly

**Expected Metrics**:
- Lua states created: 10
- Lua states freed: 10
- Memory lost: 0 bytes
- Memory growth rate: <1KB between iterations

**Valgrind Output Analysis**:
```
Iteration 1: created=1, freed=1, active=0
Iteration 2: created=2, freed=2, active=0
...
Iteration 10: created=10, freed=10, active=0
Final: definitely lost=0 bytes ✓
```

---

### Scenario D: Timeout During Lua Allocation (Edge Case)

**Purpose**: Test cleanup when timeout occurs during lua_eval.

**Setup**:
```c
// Create subscription with 100ms timeout
// Run script that allocates large Lua table:
//   for i=1,10000000 do t[i]=i end
// Timeout interrupts allocation mid-way
// Verify: lua_close() still called, memory freed
```

**Execution**:
```bash
# ThreadSanitizer
export TSAN_OPTIONS="halt_on_error=1:verbosity=2"
./pob2macos --test-scenario D

# Valgrind
valgrind --leak-check=full --track-origins=yes \
  ./pob2macos --test-scenario D
```

**Duration**: 2-5 minutes

**Success Criteria**:
- [ ] Timeout interrupts mid-allocation
- [ ] lua_close() called anyway
- [ ] Partially-allocated Lua tables freed
- [ ] No memory lost
- [ ] No invalid reads/writes

**Expected Metrics**:
- Lua state created: 1
- Lua state freed: 1 (in cleanup handler)
- Partial allocations: All freed by lua_close()
- Memory leak: 0 bytes

**Tricky Part**: Ensure lua_close() properly deallocates partial Lua data structures.

---

### Scenario E: Timeout During Pipe I/O (Blocking Call)

**Purpose**: Test shutdown when worker blocked on pipe read.

**Setup**:
```c
// Create subscription with 1 second timeout
// Script tries to read from pipe (blocks indefinitely)
// Timeout triggers while thread blocked in read()
// Verification: Thread exits cleanly, cleanup handlers run
```

**Execution**:
```bash
# ThreadSanitizer
export TSAN_OPTIONS="halt_on_error=1:verbosity=1"
./pob2macos --test-scenario E

# Valgrind
valgrind --leak-check=full --track-fds=yes \
  ./pob2macos --test-scenario E
```

**Duration**: 5-10 minutes

**Success Criteria**:
- [ ] Timeout interrupts blocking read()
- [ ] Thread exits from blocked state
- [ ] Cleanup handlers execute
- [ ] Pipes closed properly
- [ ] No resource leaks
- [ ] No file descriptor leaks

**Expected Metrics**:
- Pipe fds opened: 2 (stdin, stdout)
- Pipe fds closed: 2
- File descriptor leaks: 0
- Memory leak: 0 bytes

**Critical Detail**: Ensure shutdown flag check OR signal handler wakes up blocked thread.

---

### Scenario F: 30 Rapid Abort/Restart Cycles (Endurance)

**Purpose**: Stress test rapid creation/timeout/cleanup cycles.

**Setup**:
```c
// Loop 30 times:
//   Create subscription
//   Set short timeout (100ms)
//   Run very short script (50ms)
//   Timeout (if timing makes it happen)
//   Cleanup
//   Immediate next iteration
// No delays between cycles
```

**Execution**:
```bash
# ThreadSanitizer (tightest checking)
export TSAN_OPTIONS="halt_on_error=1:verbosity=2:history_size=15"
timeout 120 ./pob2macos --test-scenario F

# Valgrind
timeout 120 valgrind --leak-check=full \
  ./pob2macos --test-scenario F
```

**Duration**: 30-60 seconds (30 cycles, rapid)

**Success Criteria**:
- [ ] All 30 cycles complete
- [ ] ThreadSanitizer: ZERO races (high contention stress test)
- [ ] Valgrind: definitely lost 0 bytes
- [ ] No deadlocks or hangs
- [ ] Resource counters match

**Expected Metrics**:
- Cycles completed: 30
- Threads created: 30
- Threads exited: 30
- Memory leaks: 0
- Race conditions: 0

**Performance Expectation**: Should complete in <60s even with TSAN instrumentation.

---

## Part 4: Test Harness Implementation

### 4.1 Test Driver Code Structure

```c
// test_harness.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

// Run scenario based on command-line argument
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <scenario>\n", argv[0]);
        fprintf(stderr, "  A: Single timeout (baseline)\n");
        fprintf(stderr, "  B: 3 concurrent, 1 timeout\n");
        fprintf(stderr, "  C: 10 sequential timeouts\n");
        fprintf(stderr, "  D: Timeout during Lua allocation\n");
        fprintf(stderr, "  E: Timeout during pipe I/O\n");
        fprintf(stderr, "  F: 30 rapid cycles\n");
        return 1;
    }

    char scenario = argv[1][0];
    int result = 0;

    switch (scenario) {
        case 'A': result = test_scenario_a(); break;
        case 'B': result = test_scenario_b(); break;
        case 'C': result = test_scenario_c(); break;
        case 'D': result = test_scenario_d(); break;
        case 'E': result = test_scenario_e(); break;
        case 'F': result = test_scenario_f(); break;
        default:
            fprintf(stderr, "Unknown scenario: %c\n", scenario);
            return 1;
    }

    return result;  // 0 = pass, 1 = fail
}
```

### 4.2 Test Execution Script

```bash
#!/bin/bash
# test_all_scenarios.sh

set -e  # Exit on first failure

BINARY="./pob2macos"
BUILD_DIR="build_tsan"

echo "=========================================="
echo "Phase 15 Testing: All Scenarios"
echo "=========================================="

# Build with ThreadSanitizer
echo ""
echo "[1/3] Building with ThreadSanitizer..."
mkdir -p $BUILD_DIR
cd $BUILD_DIR
cmake -DENABLE_TSAN=ON ..
make -j4
cd ..

# Run ThreadSanitizer tests
echo ""
echo "[2/3] Running ThreadSanitizer tests..."
export TSAN_OPTIONS="halt_on_error=1:verbosity=1"

for scenario in A B C D E F; do
    echo ""
    echo "Scenario $scenario..."
    timeout 180 $BUILD_DIR/$BINARY --test-scenario $scenario || echo "TSAN Test $scenario FAILED"
done

# Build with Valgrind flags
echo ""
echo "[3/3] Building for Valgrind..."
BUILD_DIR_VG="build_valgrind"
mkdir -p $BUILD_DIR_VG
cd $BUILD_DIR_VG
cmake -DENABLE_VALGRIND=ON ..
make -j4
cd ..

# Run Valgrind tests
echo ""
echo "[4/4] Running Valgrind tests..."
for scenario in A B C D E F; do
    echo ""
    echo "Scenario $scenario with Valgrind..."
    timeout 300 valgrind \
        --leak-check=full \
        --show-leak-kinds=all \
        --error-exitcode=1 \
        $BUILD_DIR_VG/$BINARY --test-scenario $scenario \
        2>&1 | tee valgrind-scenario-$scenario.log || echo "Valgrind Test $scenario FAILED"
done

echo ""
echo "=========================================="
echo "All tests completed. Check logs above."
echo "=========================================="
```

---

## Part 5: Acceptance Criteria & Automation

### 5.1 Automated Test Success Criteria

```bash
# Check ThreadSanitizer output
grep "SUMMARY: ThreadSanitizer: 0 races detected" tsan_output.log
# Return: 0 = pass, 1 = fail

# Check Valgrind output
grep "definitely lost: 0 bytes" valgrind_output.log
# Return: 0 = pass, 1 = fail

# Check resource counters
grep "created == freed" resource_report.log
# Return: 0 = pass, 1 = fail
```

### 5.2 CI/CD Integration

```yaml
# .github/workflows/phase15-test.yml
name: Phase 15 Testing

on: [push, pull_request]

jobs:
  thread-safety:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build with ThreadSanitizer
        run: |
          mkdir build_tsan && cd build_tsan
          cmake -DENABLE_TSAN=ON ..
          make -j4
      - name: Run scenario tests
        run: |
          cd build_tsan
          for s in A B C D E F; do
            timeout 180 ./pob2macos --test-scenario $s || exit 1
          done

  memory-safety:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build for Valgrind
        run: |
          mkdir build_vg && cd build_vg
          cmake -DENABLE_VALGRIND=ON ..
          make -j4
      - name: Run Valgrind tests
        run: |
          cd build_vg
          for s in A B C D E F; do
            valgrind --leak-check=full ./pob2macos --test-scenario $s || exit 1
          done
```

### 5.3 Failure Mode Documentation

**If ThreadSanitizer reports race**:
- [ ] Note line numbers from stack trace
- [ ] Identify which variable has race
- [ ] Check: Is shutdown_requested volatile sig_atomic_t?
- [ ] Check: Is access protected by mutex?
- [ ] Update synchronization if needed

**If Valgrind reports leak**:
- [ ] Note "definitely lost" bytes
- [ ] Note allocation stack trace
- [ ] Check: Is lua_close() called?
- [ ] Check: Is cleanup handler registered?
- [ ] Verify cleanup handler executes

---

## Part 6: Results Documentation

### 6.1 Test Report Template

```markdown
# Phase 15 Test Results

Date: 2026-01-29
Build: pob2macos Phase 15 Cooperative Shutdown
Tester: [Agent Name]

## ThreadSanitizer Results

| Scenario | Duration | Races | Status |
|----------|----------|-------|--------|
| A        | 8min     | 0     | PASS   |
| B        | 15min    | 0     | PASS   |
| C        | 55sec    | 0     | PASS   |
| D        | 4min     | 0     | PASS   |
| E        | 8min     | 0     | PASS   |
| F        | 45sec    | 0     | PASS   |
| **TOTAL**| **90min**| **0** | **PASS**|

## Valgrind Results

| Scenario | Leaked | Lost | Status |
|----------|--------|------|--------|
| A        | 0      | 0    | PASS   |
| B        | 0      | 0    | PASS   |
| C        | 0      | 0    | PASS   |
| D        | 0      | 0    | PASS   |
| E        | 0      | 0    | PASS   |
| F        | 0      | 0    | PASS   |
| **TOTAL**| **0**  | **0**| **PASS**|

## Summary

- [x] ThreadSanitizer: 0 races in all scenarios
- [x] Valgrind: 0 leaks in all scenarios
- [x] Resource counters: All match (created == freed)
- [x] Build clean: 0 warnings
- [x] All 6 scenarios completed successfully

**APPROVAL**: This implementation is memory-safe and thread-safe.
```

---

## Sign-Off

**Sage Authority Declaration**:

> "Testing strategy is comprehensive, covering all critical code paths with ThreadSanitizer and Valgrind. Six scenarios exercise baseline, concurrency, stress, and edge cases. Quality gates are measurable and non-negotiable: zero races, zero leaks.
>
> **STRATEGY APPROVED FOR EXECUTION**
>
> Merchant and Paladin may execute these tests immediately upon Artisan A1 completion."

**Status**: ✅ TEST STRATEGY APPROVED
**Authority**: Sage (賢者)
**Date**: 2026-01-29T23:45:00Z

---

## Appendix: Tool Installation

### Install Valgrind on macOS
```bash
brew install valgrind
```

### Verify ThreadSanitizer
```bash
# Included with Xcode clang
clang -fsanitize=thread -c test.c -o test.o
# Should compile without errors
```

### Troubleshooting

**ThreadSanitizer: "halt_on_error" not working**
- Solution: Update clang/LLVM version
- `xcode-select --install` or `brew upgrade llvm`

**Valgrind: "Cannot find suppressions"**
- Solution: Create empty suppressions file
- `touch valgrind_suppress.txt`

**Tests timeout**
- Solution: Increase timeout values for slower machines
- Increase `timeout` parameter in test script

---

**Document Status**: APPROVED FOR TESTING
**Authority**: Sage (賢者)
**Timestamp**: 2026-01-29T23:45:00Z
