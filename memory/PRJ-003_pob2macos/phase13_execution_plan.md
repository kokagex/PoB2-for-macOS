# Phase 13 - PoB2 macOS: LaunchSubScript & BC7 Integration
## Concrete Execution Plan with File-Level Tasks

**Date**: 2026-01-29
**Phase**: 13 (Final Implementation Sprint)
**Project**: PoB2macOS - Phase 13: Complete Feature Parity
**Status**: READY FOR EXECUTION
**Approved By**: Mayor (村長)

---

## Executive Summary

This document translates the Phase 13 Divine Mandate into **concrete, actionable file-level tasks** for each village agent. All tasks are sequenced with explicit dependencies and integration points clearly marked.

**Two Critical Deliverables**:
1. **LaunchSubScript** - pthread-based background task execution with pipe IPC
2. **BC7 Software Decoder** - bcdec.h integration for texture decompression

**Total Estimated Effort**: 16-18 hours (10-12 hours with full parallelization)
**Critical Path**: S1 → S2 → S3 → S4 → M1/P1 → M2/P2 → M3 (12 hours minimum)

---

## Part 1: SAGE (賢者) - Implementation Tasks

### Task S1: LaunchSubScript Core Manager Header (4 hours)

**Deliverable File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/subscript.h`

**Objective**: Define the core data structures and public C API for sub-script management.

**Specifications**:

#### File Structure
```c
#ifndef SIMPLEGRAPHIC_SUBSCRIPT_H
#define SIMPLEGRAPHIC_SUBSCRIPT_H

#include <stdbool.h>
#include <stdint.h>
#include <pthread.h>
#include <lua.h>

/* ============================================================================
 * SUBSCRIPT HANDLE - Represents a single running sub-script
 * ============================================================================ */

typedef struct SubScriptHandle {
    // Identification
    int id;                         // Unique sub-script ID (auto-incremented)
    pthread_t thread_id;            // Worker thread handle

    // Script Data
    char* script_code;              // Lua script as null-terminated string
    char* sub_funcs;                // "func1,func2,..." whitelist (may be empty)
    char* callback_funcs;           // "func1,func2,..." proxy list (may be empty)

    // Arguments
    int arg_count;                  // Number of variadic arguments
    const char** args;              // Array of argument strings (malloc'd)

    // Communication
    int result_pipe[2];             // Pipe for result data: [0]=read, [1]=write
    bool completed;                 // True when thread has finished

    // Result tracking
    int result_count;               // Number of return values (for debugging)

} SubScriptHandle;

/* ============================================================================
 * GLOBAL STATE - Thread-safe management
 * ============================================================================ */

// Next available sub-script ID (atomic increment)
extern int g_next_subscript_id;

// Active sub-scripts: HashMap<int, SubScriptHandle*>
// Implementation: Simple dynamic array with linear search (thread-safe under mutex)
typedef struct {
    SubScriptHandle** handles;      // Array of pointers
    int count;                      // Current number of active scripts
    int capacity;                   // Allocated capacity
    pthread_mutex_t mutex;          // Protects concurrent access
} SubScriptManager;

extern SubScriptManager g_subscript_manager;

/* ============================================================================
 * PUBLIC C API
 * ============================================================================ */

/**
 * Launch a background Lua script in a new thread
 *
 * @param script_code       Lua code as string (e.g., "return 'hello'")
 * @param sub_funcs         Comma-separated list of allowed functions in sub-thread
 *                          Example: "GetScriptPath,GetRuntimePath,GetWorkDir"
 *                          Empty string "" = no sub-functions allowed
 * @param callback_funcs    Comma-separated list of proxy callback functions
 *                          Example: "ConPrintf,UpdateProgress"
 *                          Calls to these functions serialize to pipe
 * @param ...               Variadic arguments (const char*) passed to script
 *                          Accessed in Lua as: local arg1, arg2, ... = ...
 *
 * @return                  Positive sub-script ID on success
 *                          <=0 on failure (memory exhaustion, thread creation)
 *
 * @note                    The script begins execution immediately in worker thread.
 *                          Call SimpleGraphic_CheckSubScriptResults() in main loop
 *                          to poll for completion and invoke callbacks.
 */
int SimpleGraphic_LaunchSubScript(const char* script_code,
                                   const char* sub_funcs,
                                   const char* callback_funcs, ...);

/**
 * Check for completed sub-scripts and invoke their callbacks
 *
 * Call this once per frame in the main render loop (OnFrame).
 * Non-blocking: reads pipes with select() timeout.
 *
 * For each completed sub-script:
 * - Reads results from pipe (msgpack format)
 * - Looks up callback in Lua launch.subScripts[id].callback
 * - Invokes: callback(result1, result2, ...)
 * - Frees all sub-script resources
 *
 * @note                    Must be called from main Lua thread context
 *                          after LaunchSubScript() is called.
 */
void SimpleGraphic_CheckSubScriptResults(void);

/**
 * Check if a sub-script is still running
 *
 * @param id                Sub-script ID from LaunchSubScript()
 * @return                  true if running, false if complete or invalid
 */
bool SimpleGraphic_IsSubScriptRunning(int id);

/**
 * Abort a sub-script (kill its thread and free resources)
 *
 * @param id                Sub-script ID
 *
 * @note                    Sends SIGTERM to worker thread
 *                          Caller responsible for cleanup in Lua if needed
 */
void SimpleGraphic_AbortSubScript(int id);

/* ============================================================================
 * INTERNAL HELPER FUNCTIONS (for subscript_worker.c)
 * ============================================================================ */

// Worker thread main function (called from pthread_create)
void* subscript_worker_thread(void* arg);

// Register allowed functions in sub-script Lua state
void register_subscript_functions(lua_State* L, const char* func_list);

// Register callback proxy functions (pipe-based communication)
void register_callback_proxies(lua_State* L, const char* callback_list, int result_pipe);

// Result serialization/deserialization (msgpack format)
int write_results_to_pipe(int pipe_fd, lua_State* L, int stack_count);
int read_results_from_pipe(int pipe_fd, lua_State* L);

#endif /* SIMPLEGRAPHIC_SUBSCRIPT_H */
```

**Implementation Checklist**:
- [ ] Define `SubScriptHandle` struct with all required fields
- [ ] Define `SubScriptManager` with mutex for thread-safe access
- [ ] Declare all public API functions
- [ ] Add detailed documentation comments for each function
- [ ] Include guards and extern "C" for C++ compatibility
- [ ] No compilation errors when included with lua.h and pthread.h
- [ ] Header is self-contained (no circular dependencies)

**Integration Points**:
- Will be included in: `sg_lua_binding.c` and `sg_core.c`
- Depends on: Lua headers, pthread headers, standard C library
- Used by: All subsequent Sage tasks (S2-S6)

**Success Criteria**:
- [ ] Header compiles cleanly with no warnings
- [ ] All type definitions are correct
- [ ] Function signatures match Phase 12 architecture
- [ ] ID generation mechanism defined (g_next_subscript_id)
- [ ] Thread safety strategy clear (mutex protection)

---

### Task S2: Worker Thread Implementation (3 hours)

**Deliverable File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/subscript_worker.c`

**Objective**: Implement worker thread execution with isolated LuaJIT state and pipe-based result communication.

**Specifications**:

#### File Structure
```c
/**
 * subscript_worker.c - LaunchSubScript Worker Thread Implementation
 *
 * Path of Building 2 - macOS Porting
 * Created: 2026-01-29
 * Author: Sage (賢者)
 *
 * Implements background Lua execution in isolated threads with:
 * - Per-thread LuaJIT state
 * - Function whitelisting
 * - Callback proxy registration
 * - Pipe-based result communication
 */

#include "subscript.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/select.h>
#include <errno.h>

// messagepack library (check if available)
// For now, use simple binary format: count (uint32) + value_type (uint8) + data
#define MSGPACK_OK 1

/* ============================================================================
 * SAFE FUNCTION REGISTRY
 * Only these functions are allowed in sub-script context
 * ============================================================================ */

// Forward declarations for exposed functions
static int lua_GetScriptPath(lua_State* L);
static int lua_GetRuntimePath(lua_State* L);
static int lua_GetWorkDir(lua_State* L);
static int lua_GetUserPath(lua_State* L);
static int lua_MakeDir(lua_State* L);
static int lua_RemoveDir(lua_State* L);
static int lua_SetWorkDir(lua_State* L);
static int lua_ConPrintf(lua_State* L);

// Lookup table for allowed functions
typedef struct {
    const char* name;
    lua_CFunction func;
} SafeFunctionEntry;

static const SafeFunctionEntry SAFE_FUNCTIONS[] = {
    {"GetScriptPath", lua_GetScriptPath},
    {"GetRuntimePath", lua_GetRuntimePath},
    {"GetWorkDir", lua_GetWorkDir},
    {"GetUserPath", lua_GetUserPath},
    {"MakeDir", lua_MakeDir},
    {"RemoveDir", lua_RemoveDir},
    {"SetWorkDir", lua_SetWorkDir},
    {"ConPrintf", lua_ConPrintf},
    {NULL, NULL}
};

/* ============================================================================
 * SAFE FUNCTION IMPLEMENTATIONS (stubs calling main thread APIs)
 * ============================================================================ */

// These are proxies that call the real SimpleGraphic functions
// Some (like ConPrintf) are overridden to write to pipe

static int lua_GetScriptPath(lua_State* L) {
    // Call SimpleGraphic_GetScriptPath() from main
    char* path = SimpleGraphic_GetScriptPath();
    lua_pushstring(L, path ? path : "");
    return 1;
}

static int lua_GetRuntimePath(lua_State* L) {
    char* path = SimpleGraphic_GetRuntimePath();
    lua_pushstring(L, path ? path : "");
    return 1;
}

static int lua_GetWorkDir(lua_State* L) {
    char* path = SimpleGraphic_GetWorkDir();
    lua_pushstring(L, path ? path : "");
    return 1;
}

static int lua_GetUserPath(lua_State* L) {
    char* path = SimpleGraphic_GetUserPath();
    lua_pushstring(L, path ? path : "");
    return 1;
}

static int lua_MakeDir(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    bool result = SimpleGraphic_MakeDir(path);
    lua_pushboolean(L, result);
    return 1;
}

static int lua_RemoveDir(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    bool result = SimpleGraphic_RemoveDir(path);
    lua_pushboolean(L, result);
    return 1;
}

static int lua_SetWorkDir(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    bool result = SimpleGraphic_SetWorkDir(path);
    lua_pushboolean(L, result);
    return 1;
}

static int lua_ConPrintf(lua_State* L) {
    // Collect all arguments as strings and send to pipe
    int nargs = lua_gettop(L);

    // For now, just forward to SimpleGraphic_ConPrintf
    // In full implementation, this would serialize to pipe for main thread processing

    char buffer[4096];
    size_t offset = 0;

    for (int i = 1; i <= nargs && offset < sizeof(buffer) - 1; i++) {
        if (lua_isstring(L, i)) {
            const char* s = lua_tostring(L, i);
            size_t len = strlen(s);
            if (offset + len + 1 < sizeof(buffer)) {
                memcpy(buffer + offset, s, len);
                offset += len;
                buffer[offset++] = ' ';
            }
        }
    }

    buffer[offset] = '\0';
    SimpleGraphic_ConPrintf("%s", buffer);

    return 0;
}

/* ============================================================================
 * RESULT SERIALIZATION (Simple Binary Format)
 * ============================================================================ */

/**
 * Write Lua stack values to pipe in binary format
 *
 * Format: [count:u32][type1:u8][data1]...[typeN:u8][dataN]
 * Types: 0=nil, 1=bool, 2=number, 3=string
 */
int write_results_to_pipe(int pipe_fd, lua_State* L, int stack_count) {
    // Write result count
    uint32_t count = stack_count;
    if (write(pipe_fd, &count, sizeof(count)) != sizeof(count)) {
        perror("subscript: write count failed");
        return -1;
    }

    // Write each value
    for (int i = 1; i <= stack_count; i++) {
        uint8_t type = 0;

        if (lua_isnil(L, i)) {
            type = 0;
            if (write(pipe_fd, &type, 1) != 1) return -1;
        }
        else if (lua_isboolean(L, i)) {
            type = 1;
            if (write(pipe_fd, &type, 1) != 1) return -1;
            uint8_t value = lua_toboolean(L, i) ? 1 : 0;
            if (write(pipe_fd, &value, 1) != 1) return -1;
        }
        else if (lua_isnumber(L, i)) {
            type = 2;
            if (write(pipe_fd, &type, 1) != 1) return -1;
            double value = lua_tonumber(L, i);
            if (write(pipe_fd, &value, sizeof(value)) != sizeof(value)) return -1;
        }
        else if (lua_isstring(L, i)) {
            type = 3;
            if (write(pipe_fd, &type, 1) != 1) return -1;
            const char* str = lua_tostring(L, i);
            uint32_t len = strlen(str);
            if (write(pipe_fd, &len, sizeof(len)) != sizeof(len)) return -1;
            if (write(pipe_fd, str, len) != (ssize_t)len) return -1;
        }
        else {
            // Unsupported type (table, function, etc.)
            type = 0;  // nil
            if (write(pipe_fd, &type, 1) != 1) return -1;
        }
    }

    return 0;
}

/* ============================================================================
 * FUNCTION REGISTRATION
 * ============================================================================ */

void register_subscript_functions(lua_State* L, const char* func_list) {
    if (!func_list || !*func_list) {
        printf("[subscript] No sub-functions to register\n");
        return;
    }

    printf("[subscript] Registering sub-functions: %s\n", func_list);

    // Parse comma-separated list
    char* copy = strdup(func_list);
    if (!copy) return;

    char* saveptr;
    char* token = strtok_r(copy, ",", &saveptr);

    while (token) {
        // Trim whitespace
        while (*token == ' ') token++;
        char* end = token + strlen(token) - 1;
        while (end > token && *end == ' ') *end-- = '\0';

        // Look up in safe functions table
        for (int i = 0; SAFE_FUNCTIONS[i].name; i++) {
            if (strcmp(SAFE_FUNCTIONS[i].name, token) == 0) {
                lua_pushcfunction(L, SAFE_FUNCTIONS[i].func);
                lua_setglobal(L, token);
                printf("[subscript]   ✓ Registered: %s\n", token);
                break;
            }
        }

        token = strtok_r(NULL, ",", &saveptr);
    }

    free(copy);
}

void register_callback_proxies(lua_State* L, const char* callback_list, int result_pipe) {
    if (!callback_list || !*callback_list) {
        printf("[subscript] No callback functions to register\n");
        return;
    }

    printf("[subscript] Registering callback proxies: %s\n", callback_list);

    char* copy = strdup(callback_list);
    if (!copy) return;

    char* saveptr;
    char* token = strtok_r(copy, ",", &saveptr);

    while (token) {
        // Trim whitespace
        while (*token == ' ') token++;
        char* end = token + strlen(token) - 1;
        while (end > token && *end == ' ') *end-- = '\0';

        // For now, just register as nil
        // Full implementation: register stub that writes to pipe
        lua_pushnil(L);
        lua_setglobal(L, token);
        printf("[subscript]   ✓ Registered proxy: %s\n", token);

        token = strtok_r(NULL, ",", &saveptr);
    }

    free(copy);
}

/* ============================================================================
 * WORKER THREAD MAIN FUNCTION
 * ============================================================================ */

void* subscript_worker_thread(void* arg) {
    SubScriptHandle* handle = (SubScriptHandle*)arg;

    printf("[subscript:%d] Worker thread starting (tid=%lu)\n", handle->id, pthread_self());

    // 1. Create isolated LuaJIT state
    lua_State* L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "[subscript:%d] ERROR: Failed to create Lua state\n", handle->id);
        close(handle->result_pipe[1]);
        handle->completed = true;
        return NULL;
    }

    // Open standard libraries (safe subset)
    luaL_openlibs(L);

    printf("[subscript:%d] Lua state created\n", handle->id);

    // 2. Register sub-functions (read-only APIs)
    register_subscript_functions(L, handle->sub_funcs);

    // 3. Register callback proxies (pipe-based communication)
    register_callback_proxies(L, handle->callback_funcs, handle->result_pipe[1]);

    // 4. Push arguments onto stack (as varargs)
    for (int i = 0; i < handle->arg_count; i++) {
        lua_pushstring(L, handle->args[i]);
    }

    printf("[subscript:%d] Executing script (%d args)...\n", handle->id, handle->arg_count);

    // 5. Load and execute script
    if (luaL_loadstring(L, handle->script_code) != LUA_OK) {
        // Compilation error
        fprintf(stderr, "[subscript:%d] Lua compilation error: %s\n",
                handle->id, lua_tostring(L, -1));
        write_results_to_pipe(handle->result_pipe[1], L, 0);
    } else {
        // Script compiled, execute it
        int nargs = handle->arg_count;
        int nresults = LUA_MULTRET;

        if (lua_pcall(L, nargs, nresults, 0) == LUA_OK) {
            // Script executed successfully, collect results
            int stack_count = lua_gettop(L);
            printf("[subscript:%d] Script succeeded, %d results\n", handle->id, stack_count);

            write_results_to_pipe(handle->result_pipe[1], L, stack_count);
        } else {
            // Script execution error
            fprintf(stderr, "[subscript:%d] Lua error: %s\n",
                    handle->id, lua_tostring(L, -1));
            write_results_to_pipe(handle->result_pipe[1], L, 0);
        }
    }

    // 6. Cleanup
    lua_close(L);
    close(handle->result_pipe[1]);
    handle->completed = true;

    printf("[subscript:%d] Worker thread exiting\n", handle->id);

    return NULL;
}
```

**Implementation Checklist**:
- [ ] Implement all safe function wrappers (GetScriptPath, GetWorkDir, etc.)
- [ ] Implement result serialization to binary format
- [ ] Implement register_subscript_functions() with proper parsing
- [ ] Implement register_callback_proxies() with function lookup
- [ ] Implement subscript_worker_thread() main function
- [ ] Proper error handling and logging
- [ ] Thread cleanup (lua_close, close pipes) on exit
- [ ] Memory safety (all malloc'd strings freed)

**Integration Points**:
- Depends on: subscript.h (S1)
- Included by: sg_core.c (for thread creation)
- Calls: SimpleGraphic_* functions from main thread
- Result pipe communication with main loop

**Success Criteria**:
- [ ] Thread creates and executes independently
- [ ] Lua state is properly isolated
- [ ] All Lua values serialize correctly
- [ ] No deadlocks on pipe I/O
- [ ] Thread cleanup is memory-leak-free
- [ ] Compiles with no warnings

---

### Task S3: Main Loop Integration (1 hour)

**Deliverable File**: Updates to `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_core.c`

**Objective**: Integrate result polling into the main render loop.

**Specifications**:

#### Code Changes to sg_core.c

Add at the top of file (after includes):
```c
// Forward declarations
extern void SimpleGraphic_CheckSubScriptResults(void);
```

In the main render loop function (likely `SimpleGraphic_RunMainLoop` or similar):

```c
// In OnFrame callback loop:
void some_frame_update_function(void) {
    // ... existing code ...

    // Check for completed sub-scripts and invoke callbacks
    SimpleGraphic_CheckSubScriptResults();

    // ... rest of frame ...
}
```

Create new function to be added to sg_core.c:

```c
/**
 * Poll for completed sub-scripts and invoke callbacks
 *
 * Called once per frame from main render loop.
 * Non-blocking: uses select() with 0 timeout.
 * Thread-safe: protects access to sub-script HashMap with mutex.
 */
void SimpleGraphic_CheckSubScriptResults(void) {
    // TODO: Implementation in sg_core.c after S1-S2 complete
    // Pseudocode:
    // 1. Lock g_subscript_manager.mutex
    // 2. For each handle in g_subscript_manager:
    //    a. If handle->completed:
    //       - read_results_from_pipe(handle->result_pipe[0], L)
    //       - Get callback from Lua: launch.subScripts[id].callback
    //       - Push results onto Lua stack
    //       - Call callback with results
    //       - Free handle and remove from manager
    // 3. Unlock mutex
}
```

**Implementation Checklist**:
- [ ] Function location identified in sg_core.c
- [ ] Main loop integration point identified
- [ ] Declarations added for subscript functions
- [ ] Result polling loop implemented
- [ ] Callback lookup and invocation working
- [ ] Memory cleanup verified
- [ ] Thread-safe mutex usage

**Integration Points**:
- Calls: read_results_from_pipe() (from subscript_worker.c)
- Calls: Lua callback functions (from pob2_launcher.lua)
- Calls: SimpleGraphic_* cleanup functions
- Called by: Main render loop (OnFrame)

**Success Criteria**:
- [ ] Results read without blocking main loop
- [ ] Callbacks invoked in correct order
- [ ] Memory properly freed after completion
- [ ] No crashes with multiple concurrent sub-scripts

---

### Task S4: LaunchSubScript Lua Bindings (1 hour)

**Deliverable File**: Updates to `/Users/kokage/national-operations/pob2macos/launcher/pob2_launcher.lua`

**Objective**: Add Lua wrapper functions that bridge LaunchSubScript C API to PoB2 code.

**Specifications**:

#### Code Changes to pob2_launcher.lua

Add to FFI declarations section (in the `ffi.cdef[[...]]` block):

```lua
  // LaunchSubScript
  int SimpleGraphic_LaunchSubScript(const char* script, const char* funcs,
                                     const char* sub_funcs, ...);
  bool SimpleGraphic_IsSubScriptRunning(int id);
  void SimpleGraphic_AbortSubScript(int id);
  void SimpleGraphic_CheckSubScriptResults(void);
```

Add new Lua functions after the existing SimpleGraphic wrappers:

```lua
-- ============================================================================
-- LaunchSubScript API
-- ============================================================================

local SUBSCRIPT_MAX_ARGS = 32

function LaunchSubScript(script, funcs, sub_funcs, ...)
  -- Arguments:
  --   script:     Lua code as string
  --   funcs:      Unused (legacy PoB2 parameter, kept for compatibility)
  --   sub_funcs:  "func1,func2,..." list of allowed functions in sub-script
  --   ...:        Variadic arguments passed to script

  if type(script) ~= "string" then
    printf("ERROR: LaunchSubScript: script must be a string")
    return nil
  end

  local args = {...}

  -- Convert all arguments to strings
  local c_args = ffi.new("const char*[?]", #args)
  for i, arg in ipairs(args) do
    c_args[i-1] = tostring(arg)  -- LuaJIT: 0-indexed
  end

  -- Call C function
  local id = sg.SimpleGraphic_LaunchSubScript(
    script,
    funcs or "",           -- callback_funcs (currently unused)
    sub_funcs or "",       -- sub_funcs
    unpack(args)           -- variadic args
  )

  printf("[LaunchSubScript] Launched with ID=%d\n", id or -1)

  return id > 0 and id or nil
end

function AbortSubScript(id)
  if type(id) ~= "number" then return end
  sg.SimpleGraphic_AbortSubScript(id)
  printf("[AbortSubScript] Aborted ID=%d\n", id)
end

function IsSubScriptRunning(id)
  if type(id) ~= "number" then return false end
  return sg.SimpleGraphic_IsSubScriptRunning(id)
end

-- Called by main loop (in pob2 Launch:OnFrame)
local function CheckSubScriptResults()
  sg.SimpleGraphic_CheckSubScriptResults()
end

-- Integration point: Call this in Launch:OnFrame
launch.CheckSubScriptResults = CheckSubScriptResults
```

**Implementation Checklist**:
- [ ] FFI declarations added for all three functions
- [ ] LaunchSubScript wrapper implemented with proper argument handling
- [ ] AbortSubScript wrapper implemented
- [ ] IsSubScriptRunning wrapper implemented
- [ ] CheckSubScriptResults integration point established
- [ ] Error checking for invalid arguments
- [ ] Proper printf debugging statements

**Integration Points**:
- Calls: sg.SimpleGraphic_LaunchSubScript (C API)
- Called by: PoB2 code (PoEAPI.lua, Launch.lua)
- Provides: Lua API matching PoB2's expectations
- Integration: launch.CheckSubScriptResults called from OnFrame

**Success Criteria**:
- [ ] All three functions properly wrap C API
- [ ] Arguments marshaled correctly (strings)
- [ ] Return values match C implementation
- [ ] Proper error handling for invalid inputs
- [ ] PoB2 code can call these functions without modification

---

### Task S5: BC7 Software Decoder Integration (1.5 hours)

**Deliverable File**: Updates to `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

**Objective**: Integrate bcdec.h BC7 decompressor as fallback for GPU upload failures.

**Specifications**:

#### Step 1: Copy bcdec.h Header

```bash
# Download from https://raw.githubusercontent.com/iOrange/bcdec/master/bcdec.h
# Save to: /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
```

Note: bcdec.h is MIT licensed and can be freely copied. No modifications needed.

#### Step 2: Code Changes to image_loader.c

Add include after existing includes:
```c
#include "bcdec.h"
```

Add new static function before load_dds_texture():

```c
/**
 * Decode BC7 compressed texture data to RGBA
 *
 * BC7 is block-based compression: each 4x4 pixel block is compressed to 16 bytes.
 * Uses bcdec.h library for high-quality decompression.
 *
 * @param bc7_data      Pointer to BC7 compressed data
 * @param width         Texture width in pixels
 * @param height        Texture height in pixels
 * @param block_w       Number of 4x4 blocks horizontally (width / 4)
 * @param block_h       Number of 4x4 blocks vertically (height / 4)
 * @return              Malloc'd RGBA8 pixel data, or NULL on failure
 *                      Caller must free() the returned pointer
 *
 * @note                Handles edge blocks (partial 4x4) correctly
 *                      Output format: RGBA8888 (32-bit per pixel)
 */
static unsigned char* decode_bc7_software(const uint8_t* bc7_data,
                                           uint32_t width, uint32_t height,
                                           uint32_t block_w, uint32_t block_h) {
    if (!bc7_data || width == 0 || height == 0) {
        printf("[BC7] ERROR: Invalid dimensions for BC7 decode\n");
        return NULL;
    }

    // Allocate output buffer: RGBA8888
    unsigned char* result = malloc(width * height * 4);
    if (!result) {
        printf("[BC7] ERROR: Failed to allocate %u x %u RGBA buffer\n", width, height);
        return NULL;
    }

    printf("[BC7] Decoding %u x %u texture (%u x %u blocks)...\n",
           width, height, block_w, block_h);

    // Decompress each 4x4 block
    uint8_t block_output[64];  // 4x4 pixels * 4 bytes (RGBA) = 64 bytes

    for (uint32_t by = 0; by < block_h; by++) {
        for (uint32_t bx = 0; bx < block_w; bx++) {
            // Read one BC7 block (16 bytes of compressed data)
            const uint8_t* block_data = bc7_data + (by * block_w + bx) * 16;

            // Decompress to 4x4 RGBA block using bcdec.h
            bcdec_bc7(block_data, block_output);

            // Write decompressed pixels to result buffer
            for (int py = 0; py < 4; py++) {
                for (int px = 0; px < 4; px++) {
                    uint32_t dst_x = bx * 4 + px;
                    uint32_t dst_y = by * 4 + py;

                    // Handle edge blocks (partial 4x4)
                    // If texture size is not multiple of 4, skip out-of-bounds pixels
                    if (dst_x >= width || dst_y >= height) continue;

                    uint32_t dst_idx = (dst_y * width + dst_x) * 4;  // Byte offset
                    uint32_t src_idx = (py * 4 + px) * 4;            // Byte offset in block

                    // Copy RGBA pixel (4 bytes)
                    memcpy(result + dst_idx, block_output + src_idx, 4);
                }
            }
        }
    }

    printf("[BC7] Decode complete: %u bytes decompressed\n", width * height * 4);
    return result;
}
```

Modify `load_dds_texture()` function to call BC7 decoder:

Find this section in load_dds_texture():
```c
// Old code: GPU upload failed -> gray fallback
if (try_compressed_upload(...)) {
    // Success
} else {
    printf("[DDS] %s GPU upload failed, using fallback (%u x %u)\n", ...);
    glDeleteTextures(1, &texture);
    return create_sized_fallback(width, height, out_width, out_height);
}
```

Replace with:
```c
if (try_compressed_upload(...)) {
    // Success
} else {
    printf("[DDS] %s GPU upload failed, attempting software decode...\n", format_name);

    // Try BC7 software decoder as next fallback
    if (dxgi_format == DXGI_FORMAT_BC7_UNORM ||
        dxgi_format == DXGI_FORMAT_BC7_UNORM_SRGB) {

        unsigned char* decoded = decode_bc7_software(tex_data, width, height,
                                                      width / 4, height / 4);
        if (decoded) {
            // Create new texture from decoded RGBA data
            GLuint new_texture;
            glGenTextures(1, &new_texture);
            glBindTexture(GL_TEXTURE_2D, new_texture);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, decoded);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glBindTexture(GL_TEXTURE_2D, 0);

            free(decoded);
            glDeleteTextures(1, &texture);  // Delete old failed texture

            *out_width = width;
            *out_height = height;
            printf("[BC7] Software decode successful\n");
            return new_texture;
        }
    }

    // All methods failed -> gray fallback
    printf("[DDS] Software decode failed, using gray fallback\n");
    glDeleteTextures(1, &texture);
    return create_fallback_gray_texture(out_width, out_height);
}
```

**Implementation Checklist**:
- [ ] bcdec.h copied to backend/ directory
- [ ] decode_bc7_software() function implemented
- [ ] Edge block handling (partial 4x4) correct
- [ ] Memory allocation/deallocation correct (no leaks)
- [ ] Integration into load_dds_texture() fallback chain
- [ ] Proper logging at each step
- [ ] GL texture creation and binding correct
- [ ] Compiles with no warnings

**Integration Points**:
- Depends on: bcdec.h (header-only library)
- Integrated into: load_dds_texture() function
- Called when: GPU upload fails for BC7 textures
- Fallback chain: GPU upload → BC7 software decode → Gray placeholder

**Success Criteria**:
- [ ] bcdec.h compiles without warnings
- [ ] All 18 BC7 textures decode correctly
- [ ] No memory leaks (malloc/free paired)
- [ ] Fallback works if decode fails
- [ ] Pixel output is correct (visual inspection)

---

### Task S6: BC7 Integration & Testing (1 hour)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_BC7_TEST_REPORT.md`

**Objective**: Test BC7 decoder integration end-to-end.

**Specifications**:

#### Test Plan

1. **Load TreeData with BC7 Textures**
   - Start PoB2 with full passive tree
   - Verify all ascendancy backgrounds load
   - Verify group backgrounds display correctly

2. **Visual Verification**
   - Screenshot passive tree UI
   - Check for gray fallback (should be absent)
   - Verify texture quality (no visual artifacts)
   - Compare with Windows PoB2 reference (if available)

3. **Performance Measurement**
   - Measure total texture load time with:
     ```c
     double start = SimpleGraphic_GetTime();
     // Load all textures...
     double elapsed = SimpleGraphic_GetTime() - start;
     printf("[BC7] Total load time: %.2f ms\n", elapsed * 1000);
     ```
   - Target: < 20 ms for all 18 BC7 textures

4. **Memory Usage**
   - Use system tools (macOS Activity Monitor or valgrind)
   - Measure peak memory during texture loading
   - Target: < 50 MB peak

5. **Test Cases**
   - Load passive tree → all textures display
   - Zoom in/out → texture filtering works
   - Navigate ascendancy → backgrounds render
   - Close and reopen → textures load again

#### Report Contents

Create PHASE13_BC7_TEST_REPORT.md with:
- Date and tester name
- Test environment (macOS version, GPU, CPU)
- Test execution log
- Performance measurements (load times, memory)
- Visual verification results (screenshots)
- Any issues found and resolution status
- Pass/fail checklist

**Implementation Checklist**:
- [ ] Test environment documented
- [ ] All 18 BC7 textures identified and tested
- [ ] Performance targets met (<20ms, <50MB)
- [ ] Visual quality verified (no artifacts)
- [ ] Fallback behavior tested (gray texture if decode fails)
- [ ] Memory leaks checked (no undefined behavior)
- [ ] Report written with clear pass/fail criteria

**Integration Points**:
- Tests: S5 implementation (decode_bc7_software)
- Requires: Full PoB2 application running
- Measured: Texture load time and memory usage
- Verified: Visual output quality

**Success Criteria**:
- [ ] All textures display correctly (not gray)
- [ ] Ascendancy backgrounds render properly
- [ ] Passive tree UI elements visible
- [ ] Performance within targets
- [ ] No crashes or hangs

---

## Part 2: ARTISAN (職人) - Build Integration Tasks

### Task A1: Update CMakeLists.txt (30 minutes)

**Deliverable File**: `/Users/kokage/national-operations/pob2macos/CMakeLists.txt`

**Objective**: Add new source files and ensure pthread linking.

**Specifications**:

#### Changes to CMakeLists.txt

In the `set(SG_SOURCES ...)` section, add:

```cmake
set(SG_SOURCES
    src/simplegraphic/sg_core.c
    src/simplegraphic/sg_draw.c
    src/simplegraphic/sg_input.c
    src/simplegraphic/sg_text.c
    src/simplegraphic/sg_image.c
    src/simplegraphic/sg_stubs.c
    src/simplegraphic/sg_lua_binding.c
    src/simplegraphic/sg_callbacks.c
    src/simplegraphic/sg_filesystem.c
    src/simplegraphic/sg_compress.c
    src/simplegraphic/backend/text_renderer.c
    src/simplegraphic/backend/subscript_worker.c  # NEW: LaunchSubScript worker
)
```

After `include_directories()` sections, add pthread linking:

```cmake
# Find pthread (POSIX threads)
find_package(Threads REQUIRED)

# Link pthread to both static and shared libraries
target_link_libraries(simplegraphic
    ${GLFW_LIBRARIES}
    ${OPENGL_LIB}
    ${COCOA_LIB}
    ${COREFOUNDATION_LIB}
    ${IOKIT_LIB}
    ${LUA_LIBRARIES}
    ${FREETYPE_LIBRARIES}
    ${ZSTD_LIBRARIES}
    z
    Threads::Threads  # NEW: pthread support
)

target_link_libraries(simplegraphic_shared
    ${GLFW_LIBRARIES}
    ${OPENGL_LIB}
    ${COCOA_LIB}
    ${COREFOUNDATION_LIB}
    ${IOKIT_LIB}
    ${LUA_LIBRARIES}
    ${FREETYPE_LIBRARIES}
    ${ZSTD_LIBRARIES}
    z
    Threads::Threads  # NEW: pthread support
)
```

**Implementation Checklist**:
- [ ] subscript_worker.c added to SG_SOURCES
- [ ] find_package(Threads REQUIRED) added
- [ ] Threads::Threads linked to both simplegraphic and simplegraphic_shared
- [ ] No duplicate entries in lists
- [ ] CMake syntax valid (no parse errors)

**Integration Points**:
- Updates: SG_SOURCES list with S2 output file
- Adds: pthread support for thread creation
- Links: Both static and shared libraries

**Success Criteria**:
- [ ] CMake configuration succeeds with no errors
- [ ] pthread symbols available during linking
- [ ] No undefined references to pthread functions

---

### Task A2: Build Verification (1 hour)

**Deliverable File**: Build log at `/Users/kokage/national-operations/pob2macos/build/BUILD_LOG_PHASE13.txt`

**Objective**: Execute clean build and verify all files compile correctly.

**Specifications**:

#### Build Steps

```bash
cd /Users/kokage/national-operations/pob2macos
rm -rf build
mkdir build && cd build
cmake ..
make -j4 2>&1 | tee BUILD_LOG_PHASE13.txt
```

#### Verification Checklist

After build completes, verify:
- [ ] Zero errors (only warnings acceptable if pre-existing)
- [ ] All new files compiled: subscript_worker.c, subscript.h
- [ ] Binary generated successfully
- [ ] Binary size within ±5% of previous build
- [ ] All symbols resolved (no undefined references)
- [ ] pthread symbols resolved correctly
- [ ] No warnings from subscript_worker.c (compiler errors acceptable if pre-existing)

#### Post-Build Verification

```bash
# Check for undefined symbols
nm build/libsimplegraphic.dylib | grep "U " | grep -i pthread

# Verify binary size
ls -lh build/libsimplegraphic.dylib

# Test FFI loading (basic)
cd /Users/kokage/national-operations/pob2macos
luajit launcher/pob2_launcher.lua &
sleep 2
kill %1
```

**Implementation Checklist**:
- [ ] Clean build executed
- [ ] CMake configuration succeeded
- [ ] Make compilation succeeded
- [ ] All new object files created
- [ ] Linking phase succeeded
- [ ] Binary symbols verified
- [ ] Build log saved

**Integration Points**:
- Builds: A1 CMakeLists.txt changes
- Builds: S2 subscript_worker.c
- Produces: libsimplegraphic.dylib with pthread support
- Tests: Basic dylib loading works

**Success Criteria**:
- [ ] Zero errors in compilation
- [ ] Zero errors in linking
- [ ] Binary runs without DYLD_LIBRARY_PATH hacks
- [ ] FFI can load dylib successfully

---

### Task A3: Link-Time Optimization Verification (30 minutes)

**Deliverable File**: Link analysis at `/Users/kokage/national-operations/claudecode01/memory/PHASE13_LINK_ANALYSIS.md`

**Objective**: Verify all symbols are resolved and no circular dependencies exist.

**Specifications**:

#### Symbol Verification

```bash
# Check for undefined symbols
nm -u build/libsimplegraphic.dylib | head -20

# Check for pthread symbols (should be present and resolved)
nm build/libsimplegraphic.dylib | grep -i pthread | head -10

# Verify FFI declarations match C signatures
grep "SimpleGraphic_LaunchSubScript\|SimpleGraphic_CheckSubScriptResults" \
  launcher/pob2_launcher.lua
```

#### Dependency Analysis

```bash
# Check dylib dependencies
otool -L build/libsimplegraphic.dylib

# Should show:
# - libsimplegraphic.1.dylib (self-reference)
# - System frameworks (Cocoa, CoreFoundation, IOKit)
# - libLua (Lua library)
# - libpthread (pthread library, usually system)
```

#### Report Contents

Create PHASE13_LINK_ANALYSIS.md with:
- Date and analyzer name
- Binary name and path
- List of all external symbols
- Verification that pthread symbols are resolved
- Dependency tree (what dylib depends on what)
- Any potential circular dependencies (should be none)
- Link-time warnings (if any)

**Implementation Checklist**:
- [ ] All undefined symbols identified
- [ ] pthread functions available and not undefined
- [ ] No circular dependencies
- [ ] All LuaJIT FFI types match C declarations
- [ ] Binary does not require special library path settings
- [ ] Analysis document created with findings

**Integration Points**:
- Analyzes: A2 compiled binary
- Verifies: S1, S2, S4 code integration
- Ensures: FFI declarations in S4 match C API

**Success Criteria**:
- [ ] No undefined symbols (except expected system functions)
- [ ] pthread symbols present and resolved
- [ ] No circular dependencies detected
- [ ] FFI types match C signatures

---

## Part 3: PALADIN (聖騎士) - Security & Safety Review Tasks

### Task P1: Thread Safety Audit (2 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_THREAD_SAFETY_AUDIT.md`

**Objective**: Review code for thread safety issues, race conditions, and data corruption risks.

**Specifications**:

#### Review Checklist

1. **HashMap Thread-Safety** (S1)
   - [ ] g_subscript_manager protected by mutex
   - [ ] Mutex locked during all access patterns
   - [ ] No double-locking or deadlock scenarios
   - [ ] All exit paths release mutex

2. **Pipe I/O Race Conditions** (S2)
   - [ ] Each sub-script has dedicated pipe (no sharing)
   - [ ] read()/write() calls are atomic
   - [ ] No buffer overflows on pipe communication
   - [ ] Pipe cleanup on thread exit
   - [ ] Close-on-exec flags set if needed

3. **Lua State Isolation** (S2)
   - [ ] Each thread creates own lua_State
   - [ ] No shared Lua state between threads
   - [ ] Lua GC cannot cause crashes
   - [ ] Stack management correct (lua_gettop, lua_pop)

4. **Callback Function Whitelisting** (S2)
   - [ ] Only approved functions available in sub-script
   - [ ] Function lookup table is read-only
   - [ ] No dynamic function registration possible
   - [ ] Callback proxies cannot access main state

5. **Memory Management**
   - [ ] All malloc/free paired
   - [ ] No use-after-free
   - [ ] All thread-local allocations freed on exit
   - [ ] Pipe buffers sized appropriately

#### Test Scenarios

Use ThreadSanitizer to detect races:
```bash
# Build with ThreadSanitizer
cmake .. -DCMAKE_C_FLAGS="-fsanitize=thread"
make

# Run and observe for race condition warnings
./build/libsimplegraphic.dylib &
sleep 10
kill %1
```

#### Report Structure

Create PHASE13_THREAD_SAFETY_AUDIT.md with:
- Date and auditor name
- Checklist results (pass/fail for each item)
- Potential race conditions (if found)
- Deadlock risks assessment
- Memory corruption risks
- Recommendations for hardening
- ThreadSanitizer output summary
- Approval/concerns

**Implementation Checklist**:
- [ ] Code reviewed for race conditions
- [ ] Mutex usage verified
- [ ] Pipe communication analyzed
- [ ] Lua state isolation confirmed
- [ ] Function whitelisting validated
- [ ] ThreadSanitizer run (if available)
- [ ] Report written with findings

**Integration Points**:
- Reviews: S1 mutex protection
- Reviews: S2 thread implementation
- Reviews: S3 callback invocation
- Verifies: S4 Lua argument passing

**Success Criteria**:
- [ ] No data races detected (ThreadSanitizer clean)
- [ ] Function whitelist prevents unauthorized access
- [ ] No shared state between threads
- [ ] Deadlock analysis complete
- [ ] All findings documented

---

### Task P2: Memory Safety Verification (2 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_VALGRIND_REPORT.md`

**Objective**: Run valgrind to detect memory leaks, invalid reads/writes, and corruption.

**Specifications**:

#### Valgrind Test Execution

```bash
# Build with debug symbols
cmake .. -DCMAKE_BUILD_TYPE=Debug
make

# Run valgrind with full leak checking
valgrind --leak-check=full --show-leak-kinds=all \
  --track-origins=yes --verbose \
  --log-file=valgrind_output.txt \
  ./pob2macos
```

#### Test Scenarios

Run each scenario for ~30 seconds:

1. **Immediate Completion**
   ```lua
   local id = LaunchSubScript("return 'test'", "", "")
   launch:CheckSubScriptResults()
   ```

2. **Slow Network Operation** (simulated)
   ```lua
   local id = LaunchSubScript([[
     for i=1,1000000 do end  -- Busy wait
     return "done"
   ]], "", "")
   for i=1,100 do launch:CheckSubScriptResults() end
   ```

3. **Multiple Concurrent Scripts**
   ```lua
   local ids = {}
   for i=1,5 do
     ids[i] = LaunchSubScript("return "..i, "", "")
   end
   for j=1,100 do launch:CheckSubScriptResults() end
   ```

4. **Sub-script Abort**
   ```lua
   local id = LaunchSubScript([[
     while true do end  -- Infinite loop
   ]], "", "")
   sleep(1)
   AbortSubScript(id)
   launch:CheckSubScriptResults()
   ```

#### Report Contents

Create PHASE13_VALGRIND_REPORT.md with:
- Date and tester name
- Valgrind command used
- Test environment details
- Test case descriptions and results
- Definite memory leaks count (should be 0)
- Possible memory leaks (analyze and mark as acceptable or not)
- Invalid reads/writes count (should be 0)
- Data corruption issues (should be 0)
- Summary: PASS if no definite leaks, FAIL otherwise
- Recommendations

#### Success Criteria

Valgrind must show:
- [ ] No definite memory leaks
- [ ] No invalid reads (except signal handlers, if any)
- [ ] No invalid writes
- [ ] No data corruption
- [ ] All allocated blocks freed

**Implementation Checklist**:
- [ ] Valgrind installed and working
- [ ] Build with debug symbols
- [ ] All test scenarios executed
- [ ] Valgrind output captured
- [ ] Analysis performed
- [ ] Report written with findings

**Integration Points**:
- Tests: S1, S2, S3 implementation
- Requires: Full application running
- Analyzes: Memory allocation patterns

**Success Criteria**:
- [ ] Zero definite memory leaks
- [ ] Zero data corruption
- [ ] No invalid reads/writes
- [ ] All allocated blocks freed
- [ ] Valgrind clean or acceptable

---

### Task P3: Timeout Watchdog Review (1 hour)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_WATCHDOG_DESIGN.md`

**Objective**: Design (and optionally implement) timeout mechanism for long-running sub-scripts.

**Specifications**:

#### Design Specification

Create PHASE13_WATCHDOG_DESIGN.md with:

**1. Problem Statement**
- Long-running sub-scripts (> 30 seconds) can freeze UI
- Network timeouts, infinite loops possible
- Need mechanism to kill zombie threads

**2. Proposed Solution**

```c
// Design: Watchdog Timer Thread
// One watchdog thread per sub-script monitors execution time

typedef struct {
    SubScriptHandle* target;
    time_t start_time;
    int timeout_seconds;  // e.g., 30
    bool should_exit;
} WatchdogContext;

// Watchdog thread function
void* watchdog_thread(void* arg) {
    WatchdogContext* ctx = (WatchdogContext*)arg;
    time_t deadline = ctx->start_time + ctx->timeout_seconds;

    while (true) {
        if (ctx->target->completed) break;  // Sub-script finished
        if (time(NULL) >= deadline) {
            // Timeout! Kill sub-script thread
            pthread_kill(ctx->target->thread_id, SIGTERM);
            printf("[watchdog] Timeout: killed subscript %d\n", ctx->target->id);
            break;
        }
        sleep(1);
    }

    free(ctx);
    return NULL;
}
```

**3. Integration Points**

In subscript_worker_thread():
```c
// After thread creation, spawn watchdog
WatchdogContext* watchdog_ctx = malloc(sizeof(*watchdog_ctx));
watchdog_ctx->target = handle;
watchdog_ctx->start_time = time(NULL);
watchdog_ctx->timeout_seconds = 30;

pthread_t watchdog_id;
pthread_create(&watchdog_id, NULL, watchdog_thread, watchdog_ctx);
```

**4. Potential Issues & Mitigations**

| Issue | Mitigation |
|-------|-----------|
| SIGTERM may not kill thread | Use pthread_cancel instead |
| Memory not freed if killed | Ensure cleanup in signal handler |
| Watchdog overhead | One watchdog per script is acceptable |
| False positives (legitimate delays) | Make timeout configurable (30s default) |

**5. Phase 13 Recommendation**

- [ ] Design documented (this document)
- [ ] Prototype implementation (if time allows)
- [ ] NOT a hard requirement for Phase 13 completion
- [ ] Can defer to Phase 13+ if needed

**Implementation Checklist** (Optional for Phase 13)

If implementing:
- [ ] WatchdogContext struct defined
- [ ] watchdog_thread() implemented
- [ ] Signal handler for SIGTERM
- [ ] Cleanup on timeout
- [ ] No deadlocks on kill
- [ ] Logging for timeout events

**Integration Points**:
- Modifies: subscript_worker_thread() in S2
- Calls: pthread_create, pthread_kill, sleep
- Logging: Timeout events

**Success Criteria**:
- [ ] Design documented
- [ ] Implementation working (if attempted)
- [ ] No deadlock scenarios
- [ ] Timeout events logged
- [ ] Thread cleanup complete

---

## Part 4: MERCHANT (商人) - Performance & Testing Tasks

### Task M1: Performance Baseline (1.5 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_PERFORMANCE_BASELINE.md`

**Objective**: Establish performance characteristics for LaunchSubScript and BC7 decoder.

**Specifications**:

#### Benchmarks

1. **Sub-Script Creation Time** (target: <2ms)
   ```c
   // Measure: time from LaunchSubScript call to thread creation
   double start = SimpleGraphic_GetTime();
   int id = LaunchSubScript("return 1+1", "", "");
   double elapsed = SimpleGraphic_GetTime() - start;
   printf("Creation: %.2f ms\n", elapsed * 1000);
   ```

2. **Script Execution Overhead** (target: <15ms)
   ```c
   // Measure: time from creation to results available
   // For simple script: return "hello"
   double start = SimpleGraphic_GetTime();
   int id = LaunchSubScript("return 'hello'", "", "");

   // Poll until complete
   while (IsSubScriptRunning(id)) {
     CheckSubScriptResults();
     usleep(1000);
   }
   double elapsed = SimpleGraphic_GetTime() - start;
   printf("Execution: %.2f ms\n", elapsed * 1000);
   ```

3. **Result Marshaling Time**
   ```c
   // Measure: time to deserialize and callback
   // (part of above, isolated measurement)
   ```

4. **Concurrent Scripts Memory** (3 concurrent)
   ```c
   // Measure: memory usage with 3 scripts running
   // Compare before and after sub-scripts
   ```

5. **BC7 Decode Performance** (target: <20ms for 18 textures)
   ```c
   // Measure: total load time for all BC7 textures
   double start = SimpleGraphic_GetTime();
   // Load all 18 PoB2 BC7 textures...
   double elapsed = SimpleGraphic_GetTime() - start;
   printf("BC7 total: %.2f ms\n", elapsed * 1000);
   ```

#### Test Data

Create test scripts:
- Simple return: `return "hello"`
- OAuth simulation (5-10 second delay)
- Download simulation (network latency)

#### Report Contents

Create PHASE13_PERFORMANCE_BASELINE.md with:
- Date and test environment
- CPU/GPU specifications
- macOS version
- Benchmark results table:

| Benchmark | Measured | Target | Pass |
|-----------|----------|--------|------|
| Creation time | X ms | <2ms | ✓ |
| Execution overhead | X ms | <15ms | ✓ |
| 3 concurrent memory | X MB | <15MB | ✓ |
| BC7 decode (18 textures) | X ms | <20ms | ✓ |

- Per-benchmark details and methodology
- Optimization opportunities identified
- Comparison with targets

**Implementation Checklist**:
- [ ] All benchmarks executed
- [ ] Results measured accurately
- [ ] Test environment documented
- [ ] Report written with data table
- [ ] All targets met (or explained if not)

**Integration Points**:
- Depends on: S4 (LaunchSubScript working)
- Depends on: S5, S6 (BC7 decoder working)
- Requires: Full application running
- Measured: End-to-end performance

**Success Criteria**:
- [ ] Sub-script creation: <2ms
- [ ] Total overhead: <15ms
- [ ] 3 concurrent: <15MB
- [ ] BC7 load: 18 textures in <20ms
- [ ] Report complete with methodology

---

### Task M2: Stress Testing (1.5 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_STRESS_TEST_REPORT.md`

**Objective**: Run intensive tests to expose edge cases and verify robustness.

**Specifications**:

#### Test Scenarios

1. **Sequential Stress** (10 sub-scripts)
   ```lua
   for i=1,10 do
     local id = LaunchSubScript("return "..i, "", "")
     while IsSubScriptRunning(id) do
       launch:CheckSubScriptResults()
     end
   end
   ```
   - Expected: All scripts complete successfully
   - Verify: No memory growth, no crashes

2. **Concurrent Stress** (5 sub-scripts simultaneous)
   ```lua
   local ids = {}
   for i=1,5 do
     ids[i] = LaunchSubScript("return "..i, "", "")
   end

   while #ids > 0 do
     launch:CheckSubScriptResults()
     -- Remove completed
   end
   ```
   - Expected: All complete, proper cleanup
   - Verify: Pipe communication works, no deadlocks

3. **Rapid Abort/Restart Cycles**
   ```lua
   for cycle=1,10 do
     for i=1,5 do
       local id = LaunchSubScript("return "..i, "", "")
       if i % 2 == 0 then AbortSubScript(id) end
     end
     while launch:CheckSubScriptResults() do end
   end
   ```
   - Expected: No crashes, proper cleanup of aborted scripts
   - Verify: Abort mechanism works

4. **Memory Pressure Simulation**
   ```lua
   -- Create and destroy many sub-scripts
   -- Measure memory not increasing unbounded
   ```
   - Expected: Memory freed after completion
   - Verify: No memory leaks under load

5. **Network Timeout Simulation**
   ```lua
   local id = LaunchSubScript([[
     -- Simulate network operation that takes >5 seconds
     local elapsed = 0
     while elapsed < 10 do
       elapsed = elapsed + 1
     end
     return "delayed"
   ]], "", "")
   ```
   - Expected: Eventually completes or times out gracefully
   - Verify: Watchdog works if implemented

#### Test Execution

```bash
# Run stress tests in a loop
for i in {1..3}; do
  echo "Stress test run $i..."
  luajit stress_test.lua
done
```

#### Report Contents

Create PHASE13_STRESS_TEST_REPORT.md with:
- Date and test environment
- Test scenario descriptions
- Results for each scenario:
  - Pass/fail status
  - Duration
  - Memory usage before/after
  - Any crashes or errors
- Observations about behavior under load
- Recommendations

**Implementation Checklist**:
- [ ] All stress scenarios executed
- [ ] No crashes observed
- [ ] No hangs observed
- [ ] Memory freed properly
- [ ] Error handling graceful
- [ ] Report written with results

**Integration Points**:
- Depends on: S1-S4 implementation
- Tests: Concurrent execution
- Tests: Abort mechanism
- Tests: Memory cleanup

**Success Criteria**:
- [ ] No crashes
- [ ] No hangs
- [ ] Memory freed properly
- [ ] Error handling graceful
- [ ] All scenarios pass

---

### Task M3: Integration Testing (2 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_INTEGRATION_TEST_REPORT.md`

**Objective**: Test complete PoB2 workflows involving LaunchSubScript and BC7.

**Specifications**:

#### PoB2 Workflows

1. **OAuth Flow Simulation**
   ```lua
   -- Simulate OAuth authentication workflow
   local script = [[
     ConPrintf("Starting OAuth...")
     ConPrintf("Listening on http://localhost:8080")
     -- Simulate receiving auth code
     ConPrintf("Received code!")
     return "auth_code_123", nil, "state_456", 8080
   ]]

   local id = LaunchSubScript(script, "", "ConPrintf")

   -- Wait for completion
   while IsSubScriptRunning(id) do
     launch:CheckSubScriptResults()
   end

   -- Verify callback was called with results
   ```
   - Expected: Callback invoked with auth data
   - Verify: OAuth flow works end-to-end

2. **File Download Simulation**
   ```lua
   -- Simulate HTTP file download
   local script = [[
     ConPrintf("Downloading...")
     -- Simulate download
     local data = "file_content_here"
     return data, nil, "headers"
   ]]

   local id = LaunchSubScript(script, "", "ConPrintf")

   while IsSubScriptRunning(id) do
     launch:CheckSubScriptResults()
   end
   ```
   - Expected: Download completes, data returned
   - Verify: File download workflow works

3. **Update Check Simulation**
   ```lua
   local script = [[
     ConPrintf("Checking for updates...")
     local version = "2.0.0"
     return version, nil  -- version, error
   ]]

   local id = LaunchSubScript(script, "GetScriptPath,GetRuntimePath", "ConPrintf")
   ```
   - Expected: Version check completes
   - Verify: Sub-functions accessible

4. **BC7 Texture Loading**
   ```lua
   -- Load passive tree (exercises BC7 textures)
   -- Verify all textures render correctly
   -- No gray fallbacks
   ```
   - Expected: All textures display
   - Verify: BC7 integration works

5. **Build Archive Operations**
   ```lua
   -- Export/import builds
   -- May trigger LaunchSubScript for compression
   ```
   - Expected: Operations complete without error
   - Verify: Integration with build system

#### Integration Test Execution

```bash
# Full integration test suite
cd /Users/kokage/national-operations/pob2macos
luajit launcher/pob2_launcher.lua < integration_test.lua
```

#### Report Contents

Create PHASE13_INTEGRATION_TEST_REPORT.md with:
- Date and test environment
- Test scenario descriptions
- Results table:

| Workflow | Result | Duration | Notes |
|----------|--------|----------|-------|
| OAuth flow | PASS | X ms | - |
| File download | PASS | X ms | - |
| Update check | PASS | X ms | - |
| BC7 textures | PASS | X ms | - |
| Build archive | PASS | X ms | - |

- Details for each scenario
- Any failures and root causes
- UI responsiveness during operations
- Error handling verification
- Recommendations

**Implementation Checklist**:
- [ ] All PoB2 workflows tested
- [ ] No errors or crashes
- [ ] Proper error messages on failure
- [ ] UI remains responsive
- [ ] Results correctly passed to callbacks
- [ ] Report written with all details

**Integration Points**:
- Tests: S1-S6 implementation
- Tests: A1-A3 build integration
- Requires: Full PoB2 application
- Exercises: Complete feature set

**Success Criteria**:
- [ ] All workflows complete without error
- [ ] Proper error messages on failure
- [ ] UI remains responsive
- [ ] Results correctly passed to callbacks
- [ ] BC7 textures display correctly

---

## Part 5: BARD (吟遊詩人) - Documentation Tasks

### Task B1: Implementation Guide (2 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_IMPLEMENTATION_GUIDE.md`

**Objective**: Comprehensive guide to the LaunchSubScript and BC7 implementation.

**Specifications**:

Create a detailed technical guide with sections:

1. **Architecture Overview** (500 words)
   - High-level design of LaunchSubScript system
   - Thread model and IPC mechanism
   - BC7 decoder integration
   - Diagrams (ASCII or text descriptions)

2. **Code Organization** (300 words)
   - Key files and their purposes
   - Directory structure
   - Dependencies

3. **LaunchSubScript Implementation** (1500 words)
   - Core data structures
   - Worker thread lifecycle
   - Result communication protocol
   - Function whitelisting
   - Callback mechanism

4. **BC7 Decoder Implementation** (1000 words)
   - bcdec.h library usage
   - Block decompression process
   - Edge block handling
   - Integration with texture loader
   - Fallback mechanism

5. **Integration with pob2_launcher.lua** (1000 words)
   - FFI declarations
   - Lua wrapper functions
   - Callback handling in Lua
   - Example usage

6. **Function Reference** (2000 words)
   - Complete API documentation:
     - SimpleGraphic_LaunchSubScript()
     - SimpleGraphic_CheckSubScriptResults()
     - SimpleGraphic_IsSubScriptRunning()
     - SimpleGraphic_AbortSubScript()
     - Internal functions
   - Parameter descriptions
   - Return values
   - Example code for each

7. **Security Considerations** (500 words)
   - Function whitelisting enforcement
   - Thread isolation
   - Memory safety
   - Input validation

8. **Performance Characteristics** (500 words)
   - Load times
   - Memory usage
   - Concurrency limits
   - Optimization opportunities

9. **Debugging Guide** (500 words)
   - Common issues and solutions
   - Debug output interpretation
   - ThreadSanitizer usage
   - valgrind usage

10. **Troubleshooting Section** (500 words)
    - What to do if threads hang
    - How to diagnose memory leaks
    - Race condition symptoms
    - Performance problems

**Implementation Checklist**:
- [ ] All sections written
- [ ] Code examples included
- [ ] Clear explanations for each topic
- [ ] 50+ pages of documentation
- [ ] Diagrams or clear ASCII art
- [ ] Function signatures explained
- [ ] Common pitfalls noted
- [ ] Future enhancement suggestions

**Success Criteria**:
- [ ] 50+ pages of clear documentation
- [ ] All public APIs documented
- [ ] Code examples for each major feature
- [ ] Troubleshooting section complete

---

### Task B2: API Reference (1.5 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_API_REFERENCE.md`

**Objective**: Complete API reference for all LaunchSubScript and BC7 functions.

**Specifications**:

Create reference documentation with entry for each function:

```markdown
## SimpleGraphic_LaunchSubScript

**Signature**:
```c
int SimpleGraphic_LaunchSubScript(const char* script_code,
                                   const char* sub_funcs,
                                   const char* callback_funcs, ...);
```

**Parameters**:
- `script_code`: Lua script as null-terminated string
- `sub_funcs`: Comma-separated whitelist of allowed functions
- `callback_funcs`: Comma-separated list of proxy callbacks
- `...`: Variadic string arguments passed to script

**Return Value**:
- Positive integer: Sub-script ID for use with IsSubScriptRunning, AbortSubScript
- ≤0: Error (memory allocation failure, thread creation failure)

**Example**:
```c
int id = SimpleGraphic_LaunchSubScript(
    "return 'hello', 42",
    "GetScriptPath,GetWorkDir",
    "ConPrintf"
);
if (id > 0) {
    printf("Sub-script launched with ID %d\n", id);
}
```

**Thread Safety**: Safe to call from any thread, but typically called from main

**Errors**: Returns ≤0 if malloc fails or thread creation fails

**Performance**: <2ms to launch

**See Also**: IsSubScriptRunning, AbortSubScript, CheckSubScriptResults
```

Include entries for:
- SimpleGraphic_LaunchSubScript()
- SimpleGraphic_CheckSubScriptResults()
- SimpleGraphic_IsSubScriptRunning()
- SimpleGraphic_AbortSubScript()
- register_subscript_functions()
- register_callback_proxies()
- write_results_to_pipe()
- read_results_from_pipe()
- subscript_worker_thread()
- decode_bc7_software()
- Any other public or important internal functions

**Implementation Checklist**:
- [ ] Each function documented with:
  - [ ] Signature
  - [ ] Parameters and types
  - [ ] Return values
  - [ ] Example usage
  - [ ] Error cases
  - [ ] Performance characteristics
  - [ ] Thread safety notes
  - [ ] Related functions
- [ ] All public APIs covered
- [ ] Examples compile and work

**Success Criteria**:
- [ ] Each function documented completely
- [ ] Examples are clear and correct
- [ ] Error cases explained
- [ ] Performance expectations clear

---

### Task B3: Phase 13 Completion Report (2 hours)

**Deliverable File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_COMPLETION_REPORT.md`

**Objective**: Executive summary of Phase 13 completion with metrics and deliverables.

**Specifications**:

Create comprehensive completion report with sections:

1. **Executive Summary** (500 words)
   - Phase 13 objectives and outcomes
   - Overall success assessment
   - Key metrics

2. **Objectives Achievement** (1000 words)
   - LaunchSubScript: 100% feature complete ✓
     - OAuth flow working
     - HTTP downloads enabled
     - Update checks functional
   - BC7 Decoder: 100% feature complete ✓
     - All 18 textures render correctly
     - No gray fallbacks
     - Performance targets met

3. **Deliverables Checklist** (500 words)
   ```
   Code:
   - [x] subscript.h (core manager)
   - [x] subscript_worker.c (worker thread)
   - [x] Updates to engine.c (main loop)
   - [x] Updates to pob2_launcher.lua (Lua bindings)
   - [x] Updates to image_loader.c (BC7 integration)
   - [x] bcdec.h (BC7 library)
   - [x] Updated CMakeLists.txt

   Tests:
   - [x] Unit tests for LaunchSubScript
   - [x] Unit tests for BC7
   - [x] Integration tests for OAuth
   - [x] Performance benchmarks
   - [x] Stress tests (10 concurrent)
   - [x] Memory leak tests (valgrind)
   - [x] Thread safety tests (ThreadSanitizer)

   Documentation:
   - [x] PHASE13_IMPLEMENTATION_GUIDE.md
   - [x] PHASE13_API_REFERENCE.md
   - [x] This completion report
   - [x] Inline code documentation
   ```

4. **Performance Metrics** (1000 words)
   - Table of all performance targets vs actual:

   | Metric | Target | Actual | Pass |
   |--------|--------|--------|------|
   | Sub-script launch time | <2ms | X ms | ✓ |
   | Execution overhead | <15ms | X ms | ✓ |
   | 3 concurrent memory | <15MB | X MB | ✓ |
   | BC7 decode (18 textures) | <20ms | X ms | ✓ |
   | Peak memory during load | <50MB | X MB | ✓ |
   | Memory leaks | Zero | Zero | ✓ |
   | Thread safety issues | Zero | Zero | ✓ |

5. **Test Coverage** (1000 words)
   - Test suite results
   - Code paths exercised
   - Edge cases covered
   - Known limitations (if any)

6. **Security & Safety** (500 words)
   - Thread safety audit results
   - Memory safety (valgrind) results
   - Function whitelisting verified
   - No unauthorized access possible

7. **Known Issues or Limitations** (500 words)
   - If any, describe and explain impact
   - Workarounds provided
   - Recommendations for Phase 14

8. **Resource Usage Summary** (300 words)
   - Total time spent per agent
   - Lines of code added
   - Build time
   - Test execution time

9. **Future Enhancements** (500 words)
   - Potential optimizations (thread pool, caching)
   - Additional features for Phase 14
   - Performance improvements possible
   - Additional test coverage

10. **Recommendations** (500 words)
    - What worked well
    - What could be improved
    - Best practices for team
    - Lessons learned

11. **Sign-off** (200 words)
    - Completion date
    - Mayor approval
    - All agents acknowledgment
    - Phase 14 readiness assessment

**Implementation Checklist**:
- [ ] All sections completed
- [ ] Metrics table shows all targets met
- [ ] Deliverables checklist comprehensive
- [ ] Test results summarized
- [ ] No open critical issues
- [ ] Performance expectations met
- [ ] Team signed off on completion

**Success Criteria**:
- [ ] Comprehensive completion summary
- [ ] Metrics tables show success
- [ ] Future roadmap clear
- [ ] All deliverables tracked
- [ ] Stakeholder sign-off ready

---

## Execution Timeline & Dependencies

### Dependency Graph (Simplified)

```
S1 (subscript.h) - 4h
    ├── S2 (worker thread) - 3h → depends on S1
    │   ├── S3 (main loop) - 1h → depends on S2
    │   │   └── S4 (Lua bindings) - 1h → depends on S3
    │   │       ├── M1 (perf baseline) - 1.5h
    │   │       └── P1 (thread safety) - 2h
    │   │           ├── M2 (stress) - 1.5h
    │   │           └── P2 (memory safety) - 2h
    │   │               └── M3 (integration) - 2h
    │   └── P3 (watchdog design) - 1h → depends on S2
    │
    ├── S5 (BC7 decode) - 1.5h → independent
    │   └── S6 (BC7 testing) - 1h → depends on S5
    │
    └── A1 (CMakeLists) - 0.5h → can start after S1-S2 known
        └── A2 (build) - 1h → depends on A1
            └── A3 (link analysis) - 0.5h → depends on A2

    B1-B3 (documentation) - 5.5h → throughout entire phase
```

### Parallel Execution Strategy

**Day 1 (Morning)**
- S1: Core manager (4h) - CRITICAL PATH START
- A1: CMakeLists update (0.5h) - can start after S1 defined
- B1: Begin documentation writing (ongoing)

**Day 1 (Afternoon)**
- S2: Worker thread (3h) - depends on S1 ✓
- S5: BC7 decoder (1.5h) - independent
- B1-B2: Continue documentation

**Day 2 (Morning)**
- S3: Main loop integration (1h) - depends on S2 ✓
- A2: Build verification (1h) - depends on A1 ✓
- S6: BC7 testing (1h) - depends on S5 ✓

**Day 2 (Afternoon)**
- S4: Lua bindings (1h) - depends on S3 ✓
- A3: Link analysis (0.5h) - depends on A2 ✓
- P3: Watchdog design (1h) - depends on S2 ✓

**Day 3 (Morning)**
- M1: Performance baseline (1.5h) - depends on S4 ✓
- P1: Thread safety audit (2h) - depends on S4 ✓

**Day 3 (Afternoon)**
- M2: Stress testing (1.5h) - depends on P1 ✓
- P2: Memory safety (2h) - depends on P1 ✓

**Day 4 (Morning)**
- M3: Integration testing (2h) - depends on M2, P2 ✓
- B3: Completion report (2h)

**Critical Path**: S1 (4h) → S2 (3h) → S3 (1h) → S4 (1h) → M1/P1 (2h) → M2/P2 (2h) → M3 (2h) = 15 hours minimum

---

## Success Metrics (Final Achievement)

All Phase 13 success criteria:

| Metric | Target | Pass/Fail | Evidence |
|--------|--------|-----------|----------|
| LaunchSubScript works | End-to-end OAuth | [ ] | PHASE13_INTEGRATION_TEST_REPORT.md |
| HTTP downloads enabled | Successful file transfer | [ ] | PHASE13_INTEGRATION_TEST_REPORT.md |
| Update checks functional | Version check passes | [ ] | PHASE13_INTEGRATION_TEST_REPORT.md |
| BC7 textures render | 18 textures show properly | [ ] | PHASE13_BC7_TEST_REPORT.md |
| Load time | <20ms for 18 BC7 textures | [ ] | PHASE13_PERFORMANCE_BASELINE.md |
| Memory usage | <50MB peak during load | [ ] | PHASE13_PERFORMANCE_BASELINE.md |
| Zero memory leaks | valgrind clean | [ ] | PHASE13_VALGRIND_REPORT.md |
| Thread safety | ThreadSanitizer clean | [ ] | PHASE13_THREAD_SAFETY_AUDIT.md |
| API coverage | 100% of design implemented | [ ] | PHASE13_IMPLEMENTATION_GUIDE.md |
| Test coverage | All workflows passing | [ ] | PHASE13_INTEGRATION_TEST_REPORT.md |

---

## Risk Mitigation Reminders

From Phase 13 mandate:

1. **Lua State Corruption** → Strict isolation, ThreadSanitizer
2. **Pipe Deadlock** → Non-blocking I/O, select() timeout
3. **Memory Leak in Worker** → valgrind testing all code paths
4. **BC7 Decode Correctness** → bcdec.h is proven, visual inspection
5. **Performance Regression** → M1 baseline, M2 stress tests

---

## Approval & Authority

This execution plan is approved by the Mayor (村長) based on the Phase 13 Divine Mandate from the Prophet.

**Village Authority Structure**:
- **Mayor (村長)**: Overall coordination
- **Sage (賢者)**: Technical implementation (S1-S6)
- **Artisan (職人)**: Build system (A1-A3)
- **Paladin (聖騎士)**: Security & safety (P1-P3)
- **Merchant (商人)**: Testing & performance (M1-M3)
- **Bard (吟遊詩人)**: Documentation (B1-B3)

All tasks sequenced for optimal parallelization while maintaining dependencies.

---

**Document**: phase13_execution_plan.md
**Created**: 2026-01-29
**Status**: READY FOR EXECUTION
**Approval**: Mayor Acknowledgment Required

The village stands united. The spirits are ready. Let Phase 13 begin.

✨ **May your code be clean, your tests be green, and your compilation be swift.** ✨

---

**End of Phase 13 Execution Plan**
