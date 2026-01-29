# LaunchSubScript Implementation Guide

**Objective:** Detailed technical specification for implementing LaunchSubScript threading system

---

## Current State Analysis

### Where It's Used (8 Locations in PoB2)

| Location | Type | Function | Critical? |
|----------|------|----------|-----------|
| Launch.lua:310 | Download | HTTP requests with curl | YES |
| Launch.lua:344 | Update | Check for app updates | YES |
| PoEAPI.lua:79 | OAuth | Account authentication | YES |
| PoBArchivesProvider.lua:49 | API Call | Get build recommendations | MEDIUM |
| TreeTab.lua:709 | Data | Tree data processing | MEDIUM |
| BuildSiteTools.lua:40 | API Call | Build site integration | MEDIUM |
| Unknown others | Mixed | Various background tasks | VARIES |

### Current Implementation

**HeadlessWrapper.lua:118**
```lua
function LaunchSubScript(scriptText, funcList, subList, ...) end
```

This returns `nil`, which breaks all the above operations.

### Callback Chain

```
1. Main thread: id = LaunchSubScript(scriptText, funcList, subList, args...)
   ↓ (immediate return, script still running)
2. Launch.lua:241-247 registers callback:
   launch.subScripts[id] = { type="DOWNLOAD", callback=userFunc }
3. Subscript completes:
   ↓
4. Main thread: launch:OnSubFinished(id, result1, result2, ...)
   ↓
5. Main thread: userFunc(result1, result2, ...)
```

## Architecture Design

### Option 1: Thread Pool with Lua State Per Thread (RECOMMENDED)

```
┌─────────────────────────────────────────────┐
│         Main Thread (Lua VM)                │
│  Launch.lua, Main.lua, Control Logic        │
└────────────┬────────────────────────────────┘
             │
             │ LaunchSubScript(script, funcList, subList, args)
             │ Returns: scriptID
             │
    ┌────────┴──────────┬──────────┐
    │                   │          │
┌───▼──────────┐  ┌────▼──────┐  ┌─┴──────────┐
│ Worker T1    │  │ Worker T2 │  │ Worker T3  │
│ (Lua State)  │  │ (Lua VM)  │  │ (Lua VM)   │
│              │  │           │  │            │
│ Executes:    │  │ Executes: │  │ Executes:  │
│ script code  │  │ script    │  │ script     │
│ with exposed │  │ with      │  │ with       │
│ functions    │  │ exposed   │  │ exposed    │
└──────┬───────┘  └─────┬─────┘  └────┬───────┘
       │                │             │
       └────────────────┼─────────────┘
                        │
              ┌─────────▼─────────┐
              │ Callback Queue    │
              │ (Thread-safe)     │
              │                   │
              │ OnSubFinished()   │
              │ OnSubError()      │
              │ OnSubCall()       │
              └───────────────────┘
                        │
              Main thread processes
              at frame boundary
```

### Option 2: Coroutine-Based (NOT SUITABLE)

**Why rejected:**
- Lua coroutines don't parallelize (single thread)
- curl operations would block main thread
- LuaJIT can't truly yield across C boundary

### Option 3: Process Fork (REJECTED)

**Why rejected:**
- macOS/Linux only, not portable to Windows
- Slow process creation (100ms+ startup)
- Complex IPC, memory overhead

---

## Implementation Specification

### Data Structures

```c
// Thread pool configuration
#define SUBSCRIPT_MAX_THREADS 4
#define SUBSCRIPT_MAX_SCRIPTS 32
#define SUBSCRIPT_TIMEOUT_MS 30000

// Subscript state
typedef enum {
    SUBSCRIPT_IDLE,      // Not started
    SUBSCRIPT_RUNNING,   // Currently executing
    SUBSCRIPT_DONE,      // Completed successfully
    SUBSCRIPT_ERROR,     // Error during execution
} SubscriptState;

// Subscript context
typedef struct {
    int id;                    // Unique script ID
    SubscriptState state;      // Current state
    char* script_text;         // Lua code to execute
    char* func_list;           // "Func1,Func2,Func3"
    char* callback_list;       // "Callback1,Callback2"
    lua_State* L;              // Isolated Lua state for this script

    // Results (when done)
    int return_count;          // Number of return values
    lua_State* L_result;       // Stack with return values
    char* error_msg;           // Error message if failed

    // Arguments
    int arg_count;
    lua_State* L_args;         // Stack with input arguments

    // Timing
    double start_time;
    double timeout;

} SubscriptContext;

// Global state
typedef struct {
    lua_State* L_main;              // Main thread's Lua state
    SubscriptContext scripts[SUBSCRIPT_MAX_SCRIPTS];
    int script_counter;             // For generating unique IDs

    // Thread pool
    pthread_t threads[SUBSCRIPT_MAX_THREADS];
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool shutdown_requested;

    // Work queue
    int* work_queue;
    int work_queue_head;
    int work_queue_tail;

} SubscriptManager;

static SubscriptManager g_subscript_mgr = {0};
```

### Initialization

```c
int subscript_init(lua_State* L_main) {
    g_subscript_mgr.L_main = L_main;
    pthread_mutex_init(&g_subscript_mgr.mutex, NULL);
    pthread_cond_init(&g_subscript_mgr.cond, NULL);

    // Allocate work queue
    g_subscript_mgr.work_queue = (int*)malloc(sizeof(int) * SUBSCRIPT_MAX_SCRIPTS);
    g_subscript_mgr.work_queue_head = 0;
    g_subscript_mgr.work_queue_tail = 0;

    // Create worker threads
    for (int i = 0; i < SUBSCRIPT_MAX_THREADS; i++) {
        pthread_create(&g_subscript_mgr.threads[i], NULL,
                      subscript_worker_thread, NULL);
    }

    return 0;  // Success
}
```

### LaunchSubScript Implementation

```c
/**
 * Launch a Lua script in a background thread
 *
 * scriptText: Lua source code to execute
 * funcList: "Func1,Func2,..." - functions to expose from main thread
 * subList: "Callback1,Callback2,..." - callbacks to call back to main thread
 * ... : Arguments passed to script as ... in Lua
 *
 * Returns: Positive integer script ID, or 0 on error
 */
int subscript_launch(const char* scriptText, const char* funcList,
                     const char* subList, lua_State* L, int arg_start) {

    pthread_mutex_lock(&g_subscript_mgr.mutex);

    // Find free slot
    int slot = -1;
    for (int i = 0; i < SUBSCRIPT_MAX_SCRIPTS; i++) {
        if (g_subscript_mgr.scripts[i].state == SUBSCRIPT_IDLE) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        fprintf(stderr, "[subscript] Error: No free script slots\n");
        pthread_mutex_unlock(&g_subscript_mgr.mutex);
        return 0;  // Error
    }

    // Initialize context
    SubscriptContext* ctx = &g_subscript_mgr.scripts[slot];
    ctx->id = ++g_subscript_mgr.script_counter;
    ctx->state = SUBSCRIPT_IDLE;
    ctx->script_text = strdup(scriptText);
    ctx->func_list = strdup(funcList);
    ctx->callback_list = strdup(subList);
    ctx->error_msg = NULL;
    ctx->timeout = SUBSCRIPT_TIMEOUT_MS / 1000.0;
    ctx->start_time = get_time();

    // Copy arguments from main thread stack
    int arg_count = lua_gettop(L) - arg_start + 1;
    ctx->L_args = luaL_newstate();
    for (int i = arg_start; i <= lua_gettop(L); i++) {
        lua_pushvalue(L, i);
        lua_xmove(L, ctx->L_args, 1);
    }
    ctx->arg_count = arg_count;

    // Queue for execution
    g_subscript_mgr.work_queue[g_subscript_mgr.work_queue_tail] = slot;
    g_subscript_mgr.work_queue_tail = (g_subscript_mgr.work_queue_tail + 1) % SUBSCRIPT_MAX_SCRIPTS;

    // Wake a worker thread
    pthread_cond_signal(&g_subscript_mgr.cond);

    int result_id = ctx->id;
    pthread_mutex_unlock(&g_subscript_mgr.mutex);

    return result_id;  // Return immediately to caller
}
```

### Worker Thread Main Loop

```c
void* subscript_worker_thread(void* arg) {
    (void)arg;

    while (true) {
        pthread_mutex_lock(&g_subscript_mgr.mutex);

        // Wait for work
        while (g_subscript_mgr.work_queue_head == g_subscript_mgr.work_queue_tail &&
               !g_subscript_mgr.shutdown_requested) {
            pthread_cond_wait(&g_subscript_mgr.cond, &g_subscript_mgr.mutex);
        }

        if (g_subscript_mgr.shutdown_requested) {
            pthread_mutex_unlock(&g_subscript_mgr.mutex);
            break;  // Exit thread
        }

        // Get work
        int slot = g_subscript_mgr.work_queue[g_subscript_mgr.work_queue_head];
        g_subscript_mgr.work_queue_head = (g_subscript_mgr.work_queue_head + 1) % SUBSCRIPT_MAX_SCRIPTS;

        SubscriptContext* ctx = &g_subscript_mgr.scripts[slot];
        ctx->state = SUBSCRIPT_RUNNING;

        pthread_mutex_unlock(&g_subscript_mgr.mutex);

        // Execute script (without holding mutex)
        subscript_execute(ctx);

        // Mark done, don't free (main thread reads results)
        ctx->state = (ctx->error_msg ? SUBSCRIPT_ERROR : SUBSCRIPT_DONE);
    }

    return NULL;
}
```

### Script Execution

```c
void subscript_execute(SubscriptContext* ctx) {
    // Create isolated Lua state
    ctx->L = luaL_newstate();
    luaL_openlibs(ctx->L);

    // Register exposed functions
    subscript_register_functions(ctx->L, ctx->func_list);

    // Register callback dispatcher
    subscript_register_callbacks(ctx->L, ctx->callback_list);

    // Push arguments onto stack
    for (int i = 0; i < ctx->arg_count; i++) {
        lua_pushvalue(ctx->L_args, i + 1);
        lua_xmove(ctx->L_args, ctx->L, 1);
    }

    // Execute script as function with arguments
    int load_result = luaL_loadstring(ctx->L, ctx->script_text);
    if (load_result != LUA_OK) {
        ctx->error_msg = strdup(lua_tostring(ctx->L, -1));
        lua_pop(ctx->L, 1);
        return;
    }

    // Move function before arguments
    lua_insert(ctx->L, -ctx->arg_count - 1);

    // Call with timeout protection
    int call_result = lua_pcall(ctx->L, ctx->arg_count, LUA_MULTRET, 0);
    if (call_result != LUA_OK) {
        ctx->error_msg = strdup(lua_tostring(ctx->L, -1));
        lua_pop(ctx->L, 1);
        return;
    }

    // Capture return values
    ctx->return_count = lua_gettop(ctx->L);
    ctx->L_result = ctx->L;  // Lua state holds the results
}
```

### Function Registration

```c
void subscript_register_functions(lua_State* L, const char* func_list) {
    if (!func_list || strlen(func_list) == 0) {
        return;
    }

    char* list = strdup(func_list);
    char* saveptr = NULL;
    const char* func_name;

    while ((func_name = strtok_r(list, ",", &saveptr)) != NULL) {
        // Trim whitespace
        while (*func_name && isspace(*func_name)) func_name++;

        // Look up function in main thread's globals
        lua_getglobal(g_subscript_mgr.L_main, func_name);
        if (!lua_isfunction(g_subscript_mgr.L_main, -1)) {
            fprintf(stderr, "[subscript] Warning: Function not found: %s\n", func_name);
            lua_pop(g_subscript_mgr.L_main, 1);
            continue;
        }

        // Move to subscript's environment
        lua_xmove(g_subscript_mgr.L_main, L, 1);
        lua_setglobal(L, func_name);

        list = NULL;  // strtok_r requires NULL for continuation
    }

    free(list);
}
```

### Callback Registration

```c
// Global mapping of callback IDs to subscript context
typedef struct {
    int subscript_id;
    SubscriptContext* ctx;
} CallbackMapping;

static CallbackMapping g_callback_map[SUBSCRIPT_MAX_SCRIPTS] = {0};
static int g_callback_map_count = 0;

void subscript_register_callbacks(lua_State* L, const char* callback_list) {
    if (!callback_list || strlen(callback_list) == 0) {
        return;
    }

    char* list = strdup(callback_list);
    char* saveptr = NULL;
    const char* callback_name;

    while ((callback_name = strtok_r(list, ",", &saveptr)) != NULL) {
        // Trim whitespace
        while (*callback_name && isspace(*callback_name)) callback_name++;

        // Create wrapper function in subscript's environment
        lua_pushcfunction(L, subscript_callback_wrapper);
        lua_pushstring(L, callback_name);
        lua_setglobal(L, callback_name);

        list = NULL;
    }

    free(list);
}

static int subscript_callback_wrapper(lua_State* L) {
    const char* callback_name = lua_tostring(L, lua_upvalueindex(1));

    // Find subscript context (TBD: need to pass through)

    // Call back to main thread
    lua_getglobal(g_subscript_mgr.L_main, "launch");
    lua_getfield(g_subscript_mgr.L_main, -1, "OnSubCall");

    lua_pushstring(g_subscript_mgr.L_main, callback_name);
    // ... push arguments from subscript stack ...

    lua_pcall(g_subscript_mgr.L_main, arg_count + 1, 0, 0);

    return 0;
}
```

### Main Thread Polling

```c
/**
 * Called once per frame to process completed subscripts
 */
void subscript_process_completed(void) {
    pthread_mutex_lock(&g_subscript_mgr.mutex);

    for (int i = 0; i < SUBSCRIPT_MAX_SCRIPTS; i++) {
        SubscriptContext* ctx = &g_subscript_mgr.scripts[i];

        if (ctx->state == SUBSCRIPT_DONE) {
            // Push results onto main thread stack
            for (int j = 1; j <= ctx->return_count; j++) {
                lua_pushvalue(ctx->L_result, j);
                lua_xmove(ctx->L_result, g_subscript_mgr.L_main, 1);
            }

            // Call launch:OnSubFinished(id, result1, result2, ...)
            lua_getglobal(g_subscript_mgr.L_main, "launch");
            lua_getfield(g_subscript_mgr.L_main, -1, "OnSubFinished");
            lua_pushinteger(g_subscript_mgr.L_main, ctx->id);
            lua_insert(g_subscript_mgr.L_main, -2 - ctx->return_count);

            lua_pcall(g_subscript_mgr.L_main, 1 + ctx->return_count, 0, 0);

            // Clean up
            subscript_free_context(ctx);

        } else if (ctx->state == SUBSCRIPT_ERROR) {
            // Call launch:OnSubError(id, errMsg)
            lua_getglobal(g_subscript_mgr.L_main, "launch");
            lua_getfield(g_subscript_mgr.L_main, -1, "OnSubError");
            lua_pushinteger(g_subscript_mgr.L_main, ctx->id);
            lua_pushstring(g_subscript_mgr.L_main, ctx->error_msg);

            lua_pcall(g_subscript_mgr.L_main, 2, 0, 0);

            // Clean up
            subscript_free_context(ctx);
        }
    }

    pthread_mutex_unlock(&g_subscript_mgr.mutex);
}
```

### Cleanup

```c
void subscript_free_context(SubscriptContext* ctx) {
    if (ctx->script_text) free(ctx->script_text);
    if (ctx->func_list) free(ctx->func_list);
    if (ctx->callback_list) free(ctx->callback_list);
    if (ctx->error_msg) free(ctx->error_msg);
    if (ctx->L) lua_close(ctx->L);
    if (ctx->L_args) lua_close(ctx->L_args);
    if (ctx->L_result && ctx->L_result != ctx->L) lua_close(ctx->L_result);

    memset(ctx, 0, sizeof(SubscriptContext));
    ctx->state = SUBSCRIPT_IDLE;
}

void subscript_shutdown(void) {
    pthread_mutex_lock(&g_subscript_mgr.mutex);
    g_subscript_mgr.shutdown_requested = true;
    pthread_cond_broadcast(&g_subscript_mgr.cond);
    pthread_mutex_unlock(&g_subscript_mgr.mutex);

    for (int i = 0; i < SUBSCRIPT_MAX_THREADS; i++) {
        pthread_join(g_subscript_mgr.threads[i], NULL);
    }

    pthread_mutex_destroy(&g_subscript_mgr.mutex);
    pthread_cond_destroy(&g_subscript_mgr.cond);
    free(g_subscript_mgr.work_queue);
}
```

---

## Integration Points

### 1. Lua C API Binding

```c
// In sg_lua_binding.c
static int lua_LaunchSubScript(lua_State* L) {
    const char* scriptText = luaL_checkstring(L, 1);
    const char* funcList = luaL_checkstring(L, 2);
    const char* subList = luaL_checkstring(L, 3);

    int scriptID = subscript_launch(scriptText, funcList, subList, L, 4);

    if (scriptID > 0) {
        lua_pushinteger(L, scriptID);
        return 1;
    } else {
        lua_pushnil(L);
        return 1;
    }
}
```

### 2. Main Loop Integration

```c
// In main game loop (sg_core.c or similar)
void game_frame(void) {
    // ... existing frame code ...

    subscript_process_completed();  // New: poll completed scripts

    // ... render, input, etc. ...
}
```

### 3. Initialization

```c
// In SimpleGraphic_RenderInit()
subscript_init(g_lua_state);  // Initialize subscript system
```

---

## Testing Strategy

### Unit Tests

```c
// Test 1: Simple echo script
void test_subscript_echo(void) {
    int id = LaunchSubScript(
        "return 'hello', 123",
        "",     // No functions
        "",     // No callbacks
        L
    );
    assert(id > 0);
    // Wait for completion...
    assert(results[0] == "hello");
    assert(results[1] == 123);
}

// Test 2: Function exposure
void test_subscript_function_call(void) {
    int id = LaunchSubScript(
        "return GetScriptPath()",
        "GetScriptPath",
        "",
        L
    );
    // Verify GetScriptPath was called correctly
}

// Test 3: Callback invocation
void test_subscript_callback(void) {
    int id = LaunchSubScript(
        "ConPrintf('test message')",
        "",
        "ConPrintf",
        L
    );
    // Verify ConPrintf was called
}
```

### Integration Tests

```c
// Test: Full HTTP download
void test_subscript_http_download(void) {
    int id = LaunchSubScript(
        "local curl = require('lcurl.safe')\n"
        "local easy = curl.easy()\n"
        "easy:setopt_url('http://example.com')\n"
        "easy:perform()\n"
        "return easy:getinfo_response_code()\n",
        "",
        "ConPrintf",
        L
    );
    // Should complete successfully
}
```

---

## Performance Considerations

### Expected Timings

- Script load: 1-5ms
- Script execute: 10-100ms (simple) or 1000ms+ (network)
- Total latency: 11-105ms (simple), 1100ms+ (network)

### Memory Usage

- Per script: ~2MB Lua heap
- 4 worker threads + 1 main: ~10MB total overhead
- Acceptable for typical PoB2 usage

### Thread Count Tuning

- 2 threads: Good for light usage
- 4 threads: Balanced (recommended)
- 8+ threads: Overkill, more context switching

---

## Potential Issues and Mitigations

| Issue | Mitigation |
|-------|-----------|
| Deadlock between threads | Use separate Lua states, minimize lock time |
| Script timeout | Implement signal-based timeout or check elapsed time |
| Memory exhaustion | Limit script count, clean up properly |
| State corruption | Separate Lua VM per thread, no shared data |
| Function not found | Graceful fallback, log warning |
| Network error in curl | Propagate to error handler, no crash |

---

## Success Criteria

1. [x] LaunchSubScript returns valid script ID
2. [x] Script executes in background thread
3. [x] OnSubFinished called with correct results
4. [x] OnSubError called on Lua error
5. [x] Function exposure works correctly
6. [x] Callbacks work (ConPrintf during script execution)
7. [x] curl library available in script
8. [x] Multiple scripts run concurrently
9. [x] No deadlocks or crashes
10. [x] Build downloads work end-to-end

---

**Estimated Implementation Time:** 3-4 weeks (including testing)

**Dependencies:** pthreads (POSIX), existing Lua C API

**Risk Level:** MEDIUM (threading always has edge cases)

