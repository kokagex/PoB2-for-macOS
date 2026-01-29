# Phase 15 Task A1: Cooperative Shutdown Implementation
# ARTISAN (職人) - Implementation Lead
# Status: IN PROGRESS
# Date: 2026-01-29

## Executive Summary

This document outlines the complete implementation of Task A1: Cooperative Shutdown Implementation for PoB2macOS Phase 15.

**Blocking Gate**: LIFTED by Sage S1 approval (design document: PHASE15_SHUTDOWN_DESIGN.md)
**Reference Implementation**: Sage S2 (PHASE15_LUA_CLEANUP_REFERENCE.c)
**Testing Requirements**: Sage S3 (PHASE15_TESTING_STRATEGY.md)

## A1 Implementation Requirements

### Target File
- `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/subscript_worker.c`

### Code Changes (Per Sage Specification)

#### 1. Worker Context Structure Extension (10 lines)

Add to WorkerContext struct:
```c
volatile sig_atomic_t shutdown_requested;  // Atomic shutdown flag
```

Purpose: Enable flag-based cancellation from any thread (safe, atomic).
Property: `volatile` prevents compiler optimization; `sig_atomic_t` guarantees atomicity on all POSIX.

#### 2. CHECK_SHUTDOWN() Macro (5 lines)

```c
#define CHECK_SHUTDOWN(ctx) do { \
    if ((ctx)->shutdown_requested) { \
        return;  /* Exit gracefully, cleanup handlers execute */ \
    } \
} while(0)
```

Purpose: Strategic points to check for shutdown requests.
Usage: Insert before user code execution, blocking calls, long loops.

#### 3. Insertion Points (6+ locations)

Required cancellation check points:
1. Before lua_eval() - User code execution (longest-running)
2. Before blocking pipe reads - I/O operations
3. In lua_eval() loop - If executing multiple statements
4. Before long-running loops - Any iteration loop
5. After signal delivery - If SIGUSR1 used for optimization
6. In timeout watchdog - When requesting shutdown

#### 4. Timeout Watchdog Modification (40 lines)

**Current problematic code:**
```c
// REMOVE: pthread_cancel(sub->worker_thread_id);
```

**Replace with:**
```c
// Request graceful shutdown
request_worker_shutdown(ctx);

// Optional: send signal to interrupt blocking calls
pthread_kill(ctx->worker_thread_id, SIGUSR1);
```

**Change thread model:**
- FROM: `pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);`
- TO: `pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);`

**Add join in cleanup:**
```c
pthread_join(sub->worker_thread_id, NULL);
```

#### 5. Cleanup Handler Implementation (20+ lines)

**Handler 1: cleanup_lua_state()**
```c
static void cleanup_lua_state(void *arg) {
    lua_State *L = (lua_State *)arg;
    if (L) {
        lua_close(L);  // Deallocates ALL Lua heap memory
        g_resources.lua_states_freed++;
    }
}
```

**Handler 2: cleanup_worker_context()**
```c
static void cleanup_worker_context(void *arg) {
    WorkerContext *ctx = (WorkerContext *)arg;
    if (!ctx) return;

    // Flush pending output
    if (ctx->result_pipe_fd > 0) {
        const char *marker = "CLEANUP\n";
        write(ctx->result_pipe_fd, marker, strlen(marker));
        close(ctx->result_pipe_fd);
    }

    g_resources.active_workers--;
}
```

**Handler registration (CRITICAL ORDER - LIFO execution):**
```c
void subscript_worker_thread(void *arg) {
    WorkerContext *ctx = arg;
    lua_State *L = luaL_newstate();

    // Track creation
    g_resources.lua_states_created++;
    g_resources.active_workers++;

    // Register handlers BEFORE user code (LIFO order)
    pthread_cleanup_push(cleanup_lua_state, L);
    pthread_cleanup_push(cleanup_worker_context, ctx);

    // ... user code execution ...

    // Pop handlers in reverse order (inner first)
    pthread_cleanup_pop(1);  // cleanup_worker_context
    pthread_cleanup_pop(1);  // cleanup_lua_state
}
```

#### 6. Resource Tracking Structure (100 lines)

**Global resource tracker:**
```c
struct ResourceTracker {
    volatile sig_atomic_t lua_states_created;
    volatile sig_atomic_t lua_states_freed;
    volatile sig_atomic_t active_workers;
    volatile sig_atomic_t cleanup_handlers_called;
    pthread_mutex_t lock;
    volatile sig_atomic_t peak_active_states;
};

static struct ResourceTracker g_resources = {
    .lua_states_created = 0,
    .lua_states_freed = 0,
    .active_workers = 0,
    .cleanup_handlers_called = 0,
    .lock = PTHREAD_MUTEX_INITIALIZER,
    .peak_active_states = 0,
};
```

**Update points:**
- SimpleGraphic_LaunchSubScript() → increment created counter
- Worker cleanup handler → increment freed counter
- Timeout event → log with resource state
- New function: GetResourceMetrics() → query current state

#### 7. Supporting Functions

**request_worker_shutdown():**
```c
void request_worker_shutdown(WorkerContext *ctx, int timeout_expired) {
    if (!ctx) return;
    ctx->shutdown_requested = 1;  // Atomic, safe from any context

    if (timeout_expired) {
        write_debug("[watchdog] Timeout expired, requesting shutdown\n");
    }
}
```

**Signal handler (optional SIGUSR1):**
```c
static void sigusr1_handler(int sig) {
    // No-op: signal just wakes up blocking calls
    // Main loop checks shutdown_requested flag
    (void)sig;
}
```

## Execution Strategy

### Phase A: Code Modification
1. Backup current subscript_worker.c
2. Add volatile sig_atomic_t shutdown_requested to WorkerContext
3. Define CHECK_SHUTDOWN() macro
4. Add resource tracker struct
5. Create cleanup handlers
6. Modify timeout watchdog
7. Insert 6+ cancellation checks at strategic points
8. Change thread model to joinable
9. Add pthread_join() for proper cleanup synchronization

### Phase B: Testing & Verification
1. Compile with `-Werror` (warnings as errors)
2. Run mvp_test to verify backward compatibility
3. Test with ThreadSanitizer enabled
4. Test with AddressSanitizer enabled
5. Run Valgrind for 16 timeout cycles
6. Verify: created == freed Lua states

### Phase C: Quality Assurance
1. Code review: All pthread_cancel() removed
2. Thread safety: All concurrent access is atomic or mutex-protected
3. Resource cleanup: Handlers register in correct order
4. Documentation: Every non-obvious line has comment
5. Build: Zero warnings, all symbols resolved

## Success Metrics

| Metric | Target | Verification |
|--------|--------|--------------|
| pthread_cancel() calls | 0 remaining | grep "pthread_cancel" |
| Compilation warnings | 0 | Make with -Werror |
| Memory leaks (16 timeouts) | 0 bytes | Valgrind output |
| Data races | 0 detected | ThreadSanitizer output |
| Cleanup handler execution | 100% | Resource counter: freed == created |
| POSIX compliance | No UB | No pthread_cancel on detached threads |
| Backward compatibility | 100% | mvp_test passes unchanged |
| Code size | 500+ lines | Line count with comments |

## Critical Implementation Details (From Sage)

### Atomic Operations
- `shutdown_requested` is `volatile sig_atomic_t`
- All POSIX systems guarantee atomic read/write
- No locks needed for single-bit flag

### Handler Order (LIFO)
```
Push: cleanup_lua_state (inner)
      ↓
Push: cleanup_worker_context (outer)
      ↓
On exit: cleanup_worker_context executes first
         cleanup_lua_state executes second
         (Last pushed, first executed)
```

### Thread Model Change
- **OLD**: Detached threads + pthread_cancel() = UNDEFINED BEHAVIOR
- **NEW**: Joinable threads + cooperative shutdown = POSIX COMPLIANT

### Cleanup Path Safety
- All operations in cleanup handlers are async-signal-safe
- No malloc/free in cleanup path
- No pthread calls (thread is exiting anyway)
- lua_close() is safe because thread is same that created state

## Resource Accounting Validation

After 16 timeout events:

**Expected output:**
```
RESOURCE: lua_states_created = 16
RESOURCE: lua_states_freed = 16
RESOURCE: active_workers = 0
RESOURCE: cleanup_handlers_called = 16
```

**Valgrind verification:**
```
definitely lost: 0 bytes in 0 blocks
indirectly lost: 0 bytes in 0 blocks
possibly lost: 0 bytes in 0 blocks
SUMMARY: 0 errors
```

## Authority & Sign-Off Preparation

**Artisan Authority Declaration** (to be completed after A4):

"BUILD APPROVED:
- Zero pthread_cancel() calls remain in worker code
- Shutdown flags properly synchronized (volatile sig_atomic_t)
- All 6+ cancellation points covered with CHECK_SHUTDOWN()
- Cleanup handlers registered with pthread_cleanup_push/pop
- Code compiles without warnings
- 500+ lines of well-commented code
- Resource cleanup order documented
- ThreadSanitizer: ZERO races
- AddressSanitizer: ZERO errors
- Valgrind: ZERO memory leaks
- Backward compatibility: 100% (mvp_test unchanged)
- Binary size within acceptable range (<300KB static, <250KB dylib)"

## Next Steps

1. Implement changes to subscript_worker.c
2. Complete A1 (cooperative shutdown)
3. Proceed to A2 (resource tracking integration)
4. Proceed to A3 (backward compatibility layer)
5. Proceed to A4 (CMakeLists.txt & build verification)
6. Unblock Paladin P2-P4 and Merchant M2,M4,M5

## References

- **Design**: PHASE15_SHUTDOWN_DESIGN.md (Sage S1)
- **Reference**: PHASE15_LUA_CLEANUP_REFERENCE.c (Sage S2)
- **Testing**: PHASE15_TESTING_STRATEGY.md (Sage S3)
- **Standard**: POSIX.1-2017 (IEEE Std 1003.1-2017)

---

**Document Status**: IMPLEMENTATION SPECIFICATION COMPLETE
**Authority**: Artisan (職人)
**Timestamp**: 2026-01-29T23:50:00Z
