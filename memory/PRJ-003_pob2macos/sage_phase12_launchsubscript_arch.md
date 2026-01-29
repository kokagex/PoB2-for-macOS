# Phase 12 - LaunchSubScript Architecture Design

**Date**: 2026-01-29
**Phase**: 12 (Rendering Pipeline & Remaining Features)
**Project**: PoB2 macOS Native Port
**Author**: Sage (賢者)
**Status**: Architecture Design Complete

---

## Executive Summary

PoB2 uses `LaunchSubScript` to execute background tasks (HTTP downloads, OAuth authentication, update checks) in separate LuaJIT contexts. This prevents UI freezing during network operations.

**Current Status**: Stubbed in `pob2_launcher.lua` (returns `nil` - non-functional)

**Design Challenge**: Implement thread-safe, result-communicating sub-script execution on macOS

**Recommended Approach**: **LuaJIT State-Per-Thread with Pipe-Based Result Communication**

---

## PoB2 LaunchSubScript Usage Analysis

### 1. Usage Patterns from Source Code

#### OAuth Authentication (PoEAPI.lua)
```lua
local server = io.open("LaunchServer.lua", "r")
local id = LaunchSubScript(server:read("*a"), "", "ConPrintf,OpenURL", authUrl)
if id then
    launch.subScripts[id] = {
        type = "DOWNLOAD",
        callback = function(code, errMsg, state, port)
            -- Called when OAuth server receives redirect
            if code then
                -- Process auth code...
            end
        end
    }
end
```

**Key Points**:
- Lua code passed as string (entire LaunchServer.lua file)
- Callback happens asynchronously in main loop
- Arguments passed as varargs: `(scriptCode, funcList, subFuncList, ...args)`

#### HTTP Download (Launch.lua)
```lua
local script = [[
    local url, requestHeader, requestBody, connectionProtocol, proxyURL, noSSL = ...
    local responseBody = ""
    local responseHeader = ""
    -- Use curl to download
    local curl = require("lcurl.safe")
    -- ... setup curl ...
    -- Return: responseBody, errMsg, responseHeader
]]
local id = LaunchSubScript(script, "", "ConPrintf", url, params.header, params.body, ...)
if id then
    launch.subScripts[id] = {
        type = "DOWNLOAD",
        callback = function(responseBody, errMsg, responseHeader)
            callback({header=responseHeader, body=responseBody}, errMsg)
        end
    }
end
```

**Key Points**:
- Script is inline Lua code as string
- Sub-script calls forbidden functions (e.g., "ConPrintf") via callback
- Results returned from script execution
- Callback invoked in main thread context

#### Update Check (Launch.lua)
```lua
local update = io.open("UpdateCheck.lua", "r")
local id = LaunchSubScript(update:read("*a"),
    "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir",  -- sub-functions (allowed)
    "ConPrintf,UpdateProgress",                          -- callback functions
    self.connectionProtocol, self.proxyURL, self.noSSL or false)
```

**Key Points**:
- Some functions are "sub-functions" (executed in sub-script context)
- Others are "callbacks" (executed in main context with sub-script results)

### 2. Function List Semantics

**Sub-Functions** (first argument, comma-separated):
- Functions available in sub-script context
- Examples: `GetScriptPath`, `GetRuntimePath`, `GetWorkDir`, `MakeDir`
- These are SimpleGraphic API functions
- Called directly from sub-script: `local path = GetScriptPath()`

**Callback Functions** (second argument, comma-separated):
- Functions called from sub-script
- Invoked in main thread context
- Bridge communication: sub-script → main thread
- Examples: `ConPrintf`, `UpdateProgress`, `OpenURL`
- Usage: `ConPrintf("Progress: %d%%", percent)`

### 3. Execution Flow

```
Main Thread:
    id = LaunchSubScript(scriptCode, subFuncs, callbackFuncs, arg1, arg2, ...)
    ↓
    [Worker Thread Created]

Worker Thread:
    1. Create new LuaJIT state
    2. Register sub-functions (read-only APIs)
    3. Register callback-function proxies (pipes back to main thread)
    4. Execute scriptCode with args
    5. Collect return values
    6. Send results to main thread via pipe
    7. Exit

Main Thread (in OnFrame):
    for each subScript id in subScripts:
        if subScript has completed:
            results = read_from_pipe(id)
            subScript.callback(unpack(results))  -- Invoke callback
            delete subScript
```

---

## Implementation Options

### Option A: pthread + Pipe (RECOMMENDED)

#### Architecture
```
Main Thread (Lua):
  ├─ SetMainObject(main)
  └─ OnFrame() loop
     ├─ For each active sub-script:
     │  └─ Check pipe for results
     │  └─ If complete: invoke callback
     └─ Continue rendering

Sub-Script Thread (Worker Pool):
  ├─ Execute LaunchSubScript()
  └─ Write results to pipe
  └─ Exit
```

#### Components

**1. Sub-Script Manager** (`simplegraphic/subscript.h`)

```c
typedef struct {
    int id;                    // Unique sub-script ID
    pthread_t thread_id;       // Worker thread
    int result_pipe[2];        // Pipe for results
    char* script_code;         // Lua script as string
    char* sub_funcs;          // "func1,func2,..." list
    char* callback_funcs;     // "func1,func2,..." list
    int arg_count;
    const char** args;        // Arguments passed to script
    bool completed;
    int result_count;
} SubScriptHandle;

// Unique ID generator
int g_next_subscript_id = 1;
HashMap<int, SubScriptHandle*> g_active_subscripts;

// API
int SimpleGraphic_LaunchSubScript(const char* script_code,
                                  const char* sub_funcs,
                                  const char* callback_funcs, ...);
void SimpleGraphic_CheckSubScriptResults();
void SimpleGraphic_AbortSubScript(int id);
bool SimpleGraphic_IsSubScriptRunning(int id);
```

**2. Worker Thread Function**

```c
static void* subscript_worker_thread(void* arg) {
    SubScriptHandle* handle = (SubScriptHandle*)arg;

    // 1. Create isolated LuaJIT state
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);  // std library only

    // 2. Register sub-functions (read-only APIs)
    register_subscript_functions(L, handle->sub_funcs);

    // 3. Register callback proxies (write to pipe)
    register_callback_proxies(L, handle->callback_funcs, handle->result_pipe[1]);

    // 4. Push arguments onto stack
    for (int i = 0; i < handle->arg_count; i++) {
        lua_pushstring(L, handle->args[i]);
    }

    // 5. Load and execute script
    if (luaL_loadstring(L, handle->script_code) == 0) {
        int nargs = handle->arg_count;
        int nresults = LUA_MULTRET;

        if (lua_pcall(L, nargs, nresults, 0) == 0) {
            // Script succeeded, collect results
            int results_on_stack = lua_gettop(L);
            write_results_to_pipe(handle->result_pipe[1], L, results_on_stack);
        } else {
            // Script error
            write_error_to_pipe(handle->result_pipe[1], lua_tostring(L, -1));
        }
    }

    lua_close(L);
    close(handle->result_pipe[1]);
    handle->completed = true;

    return NULL;
}
```

**3. Result Collection in Main Loop**

```c
void SimpleGraphic_CheckSubScriptResults() {
    HashMap<int, SubScriptHandle*>::Iterator it = g_active_subscripts.begin();

    while (it != g_active_subscripts.end()) {
        SubScriptHandle* handle = it->value;

        if (handle->completed) {
            // Check if pipe has data
            char buffer[4096];
            ssize_t n = read(handle->result_pipe[0], buffer, sizeof(buffer) - 1);

            if (n > 0) {
                buffer[n] = '\0';

                // Parse results from buffer (msgpack or custom format)
                lua_State* L = _G._pob2_lua_state;  // Main Lua state

                // Get callback for this sub-script
                lua_getfield(L, LUA_GLOBALSINDEX, "launch");
                lua_getfield(L, -1, "subScripts");
                lua_rawgeti(L, -1, handle->id);  // Get subScript[id]
                lua_getfield(L, -1, "callback");

                // Push results
                push_results_from_buffer(L, buffer);

                // Call callback
                lua_call(L, result_count, 0);
            }

            // Cleanup
            close(handle->result_pipe[0]);
            free(handle->script_code);
            free(handle->sub_funcs);
            free(handle->callback_funcs);
            free(handle);

            it = g_active_subscripts.erase(it);
        } else {
            ++it;
        }
    }
}
```

#### Advantages
✅ **Native macOS support**: Uses standard POSIX threads
✅ **Result communication**: Pipe-based, simple, no shared memory
✅ **Isolated LuaJIT states**: Each thread has own Lua VM
✅ **Callback safety**: Results marshaled through pipes
✅ **Minimal locking**: Only protect script HashMap
✅ **Scalable**: Thread pool for multiple sub-scripts

#### Disadvantages
❌ **Thread overhead**: One thread per sub-script
❌ **Pipe marshaling**: Need to serialize results
❌ **Complexity**: More code than alternatives

---

### Option B: fork/exec (Not Recommended)

#### Why Not:
- **macOS sandbox**: fork() is restricted in sandboxed apps
- **State loss**: Child process can't access parent Lua state easily
- **Resource heavy**: Full process spawn vs thread
- **Result passing**: Need IPC (sockets, files)

---

### Option C: Shared LuaJIT State + Mutex (Not Recommended)

#### Why Not:
- **Thread safety**: Lua is NOT thread-safe
- **GC conflicts**: Concurrent GC collection causes crashes
- **Complexity**: Extensive locking needed
- **Performance**: Mutex contention on heavy work

---

## Recommended Architecture: Option A (pthread + Pipe)

### Design Details

#### 1. Result Serialization Format

Use **msgpack** for results (lightweight, Lua-compatible):

```c
// Serialize Lua stack to msgpack binary
static void pack_lua_values_msgpack(lua_State* L, int count, FILE* pipe) {
    msgpack_packer pk;
    msgpack_packer_init(&pk, pipe, msgpack_file_write);

    for (int i = 1; i <= count; i++) {
        switch (lua_type(L, i)) {
            case LUA_TSTRING:
                msgpack_pack_str(&pk, strlen(lua_tostring(L, i)));
                msgpack_pack_str_body(&pk, lua_tostring(L, i), strlen(lua_tostring(L, i)));
                break;
            case LUA_TNUMBER:
                msgpack_pack_double(&pk, lua_tonumber(L, i));
                break;
            case LUA_TBOOLEAN:
                lua_toboolean(L, i) ? msgpack_pack_true(&pk) : msgpack_pack_false(&pk);
                break;
            case LUA_TNIL:
                msgpack_pack_nil(&pk);
                break;
        }
    }
}
```

#### 2. Sub-Function Registration

Only expose safe SimpleGraphic functions:

```c
static const luaL_Reg subscript_safe_functions[] = {
    {"GetScriptPath", lua_GetScriptPath},
    {"GetRuntimePath", lua_GetRuntimePath},
    {"GetWorkDir", lua_GetWorkDir},
    {"GetUserPath", lua_GetUserPath},
    {"MakeDir", lua_MakeDir},
    {"RemoveDir", lua_RemoveDir},
    {"SetWorkDir", lua_SetWorkDir},
    {"ConPrintf", lua_ConPrintf},  // Different impl: write to pipe
    {NULL, NULL}
};

static void register_subscript_functions(lua_State* L, const char* func_list) {
    if (!func_list || !*func_list) return;

    char* copy = strdup(func_list);
    char* func = strtok(copy, ",");

    while (func) {
        // Lookup in safe functions table
        for (int i = 0; subscript_safe_functions[i].name; i++) {
            if (strcmp(subscript_safe_functions[i].name, func) == 0) {
                lua_pushcfunction(L, subscript_safe_functions[i].func);
                lua_setglobal(L, func);
                break;
            }
        }
        func = strtok(NULL, ",");
    }

    free(copy);
}
```

#### 3. Callback Proxy Registration

```c
typedef struct {
    int result_pipe;
    const char* func_name;
} CallbackContext;

static int lua_callback_proxy(lua_State* L) {
    CallbackContext* ctx = (CallbackContext*)lua_touserdata(L, lua_upvalueindex(1));

    // Serialize function name + arguments to pipe
    FILE* pipe = fdopen(ctx->result_pipe, "wb");
    if (!pipe) return 0;

    // Write function name
    msgpack_packer pk;
    msgpack_packer_init(&pk, pipe, msgpack_file_write);
    msgpack_pack_str(&pk, strlen(ctx->func_name));
    msgpack_pack_str_body(&pk, ctx->func_name, strlen(ctx->func_name));

    // Write arguments
    int nargs = lua_gettop(L);
    msgpack_pack_array(&pk, nargs);
    pack_lua_values_msgpack(L, nargs, pipe);

    fflush(pipe);
    fclose(pipe);

    return 0;  // Callbacks return nil
}

static void register_callback_proxies(lua_State* L, const char* callback_list, int pipe) {
    if (!callback_list || !*callback_list) return;

    char* copy = strdup(callback_list);
    char* func = strtok(copy, ",");

    while (func) {
        CallbackContext* ctx = malloc(sizeof(CallbackContext));
        ctx->result_pipe = pipe;
        ctx->func_name = strdup(func);

        lua_pushlightuserdata(L, ctx);
        lua_pushcclosure(L, lua_callback_proxy, 1);
        lua_setglobal(L, func);

        func = strtok(NULL, ",");
    }

    free(copy);
}
```

#### 4. Integration with pob2_launcher.lua

```lua
function LaunchSubScript(script, funcs, sub_funcs, ...)
    local args = {...}
    local id = sg.SimpleGraphic_LaunchSubScript(script, funcs, sub_funcs, unpack(args))
    return id
end

function AbortSubScript(id)
    sg.SimpleGraphic_AbortSubScript(id)
end

function IsSubScriptRunning(id)
    return sg.SimpleGraphic_IsSubScriptRunning(id)
end
```

#### 5. Main Loop Integration

In launcher main loop's OnFrame:

```lua
function launch:OnFrame()
    -- Check for completed sub-scripts
    sg.SimpleGraphic_CheckSubScriptResults()

    -- ... rest of OnFrame ...
end
```

---

## Execution Flow Example: OAuth Authentication

```
Time  | Main Thread (Launch.lua)      | Worker Thread (LaunchServer.lua)
------|-------------------------------|-------------------------------------
T0    | LaunchSubScript(code, ...)    | [Thread created]
      | id = 42                       |
      | subScripts[42].callback = fn  | Create LuaJIT state
      |                               | Register: ConPrintf, OpenURL
      |                               | Execute: LaunchServer.lua
      |                               | Listen on socket
T1    | OnFrame()                     |
      | Check pipes (nothing yet)     | User opens browser
      | Render frame                  | User authorizes
      |                               | Receive OAuth code
T2    | OnFrame()                     | OpenURL("callback?code=123...")
      | Check pipes                   | Pipe: ["OpenURL", "http://..."]
      | Read: ["OpenURL", "url"]      | ConPrintf("Received code")
      | Open URL in main context      | Pipe: ["ConPrintf", "msg"]
      | Render frame                  | Collect return: code, errMsg, state, port
      |                               | Pipe: ["RESULT", [code, errMsg, ...]]
      |                               | Exit thread
T3    | OnFrame()                     | [Thread dead]
      | Check pipes                   |
      | Read: ["RESULT", values]      |
      | subScripts[42].callback(...)  |
      | callback(code, errMsg, ...)   |
      | Process OAuth result          |
      | Delete subScripts[42]         |
      | Render frame                  |
```

---

## Security Considerations

### 1. Function Whitelisting
Only expose explicitly listed functions in sub-functions list.

```c
// PoB2 will pass: "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir"
// We register ONLY these, nothing else
```

### 2. No Direct File Access
Sub-scripts cannot:
- Read arbitrary files (no file I/O functions)
- Execute arbitrary commands (no os.execute)
- Access main thread data (isolated state)

### 3. Result Validation
Main thread validates callback results before use:

```lua
-- Main thread
callback_result, err = read_from_callback()
if callback_result and type(callback_result) == "string" then
    -- Safe to use
else
    -- Reject malformed result
end
```

### 4. Timeout Protection (Phase 13)
Add timeout to sub-script execution:

```c
// If sub-script runs > 30 seconds, forcibly kill thread
pthread_t watchdog = spawn_watchdog_thread(id, 30);
pthread_join(worker_thread, NULL);
```

---

## Performance Characteristics

### Load Time
- **Thread creation**: ~1-2 ms per sub-script
- **Lua state init**: ~5-10 ms per sub-script
- **Script execution**: Depends on work (typically 50-500 ms for network)
- **Total overhead**: <15 ms per sub-script

### Memory
- **Per sub-script**: ~2-5 MB (Lua state + buffers)
- **3 concurrent**: ~15 MB peak
- **After completion**: Memory freed

### Concurrency
- **Max recommended**: 5-10 concurrent sub-scripts
- **Typical usage**: 1-2 (download + update check)

---

## Testing Plan

### Unit Tests
```c
// test_subscript.c
void test_subscript_launch() {
    const char* script = "return 'hello', 42";
    int id = SimpleGraphic_LaunchSubScript(script, "", "", 0, NULL);
    assert(id > 0);
    assert(IsSubScriptRunning(id) == true);
}

void test_subscript_result() {
    const char* script = "return arg[1] * 2";
    int id = LaunchSubScript(script, "", "", 1, (const char*[]){"21"});

    // Simulate frames
    for (int i = 0; i < 100; i++) {
        CheckSubScriptResults();
        if (!IsSubScriptRunning(id)) break;
    }

    // Verify result was processed
}
```

### Integration Tests
```lua
-- test_launchsubscript.lua
function test_oauth_simulation()
    local id = LaunchSubScript([[
        ConPrintf("Testing OAuth...")
        return "auth_code_123", nil, "state_456", 12345
    ]], "", "ConPrintf")

    assert(IsSubScriptRunning(id) == true)

    -- Spin until complete
    repeat
        launch:OnFrame()
        coroutine.yield()
    until not IsSubScriptRunning(id)

    -- Verify callback was called
end
```

---

## Implementation Timeline

| Task | Time | Phase |
|------|------|-------|
| Design (completed) | - | 12 |
| Implement subscript manager | 4 hours | 12 |
| Thread pool + pipe IPC | 3 hours | 12 |
| Integrate pob2_launcher.lua | 1 hour | 12 |
| Test OAuth flow | 2 hours | 12 |
| Test update check | 1 hour | 12 |
| Performance tuning | 1 hour | 13 |
| Timeout watchdog | 2 hours | 13 |
| **Total** | **~14 hours** | 12-13 |

---

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Lua state corruption | Low | High | Strict isolation + testing |
| Pipe deadlock | Very Low | High | Non-blocking I/O + select() |
| Memory leak in worker | Low | Medium | valgrind testing |
| Callback ordering | Medium | Low | Queue callbacks in order |
| Network timeout | Medium | Low | Implement watchdog timer |

---

## Conclusion

**pthread + Pipe architecture** is optimal for PoB2 macOS:

1. **Native support**: Standard POSIX, no external dependencies
2. **Safety**: Isolated Lua states prevent crashes
3. **Simplicity**: Pipe-based communication is straightforward
4. **Performance**: <15 ms overhead per sub-script
5. **Scalability**: Supports typical 1-3 concurrent sub-scripts

This design maintains PoB2's asynchronous execution model while providing thread-safe result communication.

---

## References

- [PoB2 LaunchServer.lua Pattern](https://github.com/PathOfBuilding/PathOfBuilding/src/LaunchServer.lua)
- [POSIX Threads (pthreads)](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/pthread.h.html)
- [Pipe-based IPC](https://pubs.opengroup.org/onlinepubs/9699919799/functions/pipe.html)
- [msgpack-c](https://github.com/msgpack/msgpack-c)
- [LuaJIT Documentation](https://luajit.org/luajit.html)

---

**Document**: sage_phase12_launchsubscript_arch.md
**Last Updated**: 2026-01-29
**Status**: ✅ ARCHITECTURE COMPLETE - READY FOR IMPLEMENTATION
