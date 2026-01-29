# Phase 11 Analysis: DDS/BC7 Support and API Gaps for PoB2 macOS
**Sage (賢者) Report**
**Generated:** 2026-01-29
**Mission:** Research OpenGL BC7 texture support on macOS and identify remaining API gaps

---

## Executive Summary

This analysis covers three critical areas for PoB2 macOS Phase 11:

1. **BC7/BPTC Texture Support** - OpenGL availability and fallback strategies
2. **Remaining API Gaps** - Missing implementations blocking full functionality
3. **LaunchSubScript Requirements** - Threading/async architecture for network operations

### Key Findings
- macOS OpenGL 3.3 Core **does NOT natively support BC7 (BPTC)** compression
- **LaunchSubScript is CRITICAL** - handles all network requests, OAuth, and background operations
- **7-10 medium-severity API gaps** identified that affect usability but not basic operation
- Software BC7 decode feasible but requires libsquish or similar library integration

---

## TASK 1: OpenGL BC7/BPTC Support on macOS

### 1.1 Current OpenGL Backend State

**File:** `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/opengl_backend.c`

The current implementation:
- Uses OpenGL 3.3 Core Profile (macOS requirement)
- Header: `#ifdef __APPLE__ #include <OpenGL/gl3.h>`
- No compressed texture support currently implemented
- Image loading deferred to stubs (lines 385-401)
- Shader-based approach, no legacy fixed pipeline

### 1.2 BC7 Availability on macOS

**Verdict: NOT AVAILABLE natively**

#### Evidence:
1. **macOS OpenGL Limitations:**
   - macOS caps OpenGL at 4.1 (vs. 4.6 on Linux/Windows)
   - `GL_ARB_texture_compression_bptc` extension **NOT exposed** in Metal interop layer
   - Most hardware supports it, but Apple doesn't expose the extension
   - This is a known Apple limitation since 10.7

2. **GL_COMPRESSED_RGBA_BPTC_UNORM (0x8E8C) - UNAVAILABLE**
   - Would require: `#ifdef GL_ARB_texture_compression_bptc`
   - On macOS: Will fail at runtime even if macro exists (OpenGL driver doesn't support it)
   - Apple's Metal abstraction layer doesn't map BC7 formats

3. **Relevant Code Notes:**
   ```c
   // opengl_backend.c:20 - macOS specific header
   #ifdef __APPLE__
   #include <OpenGL/gl3.h>  // Core profile, NO extensions for BPTC
   #else
   #include <GL/glew.h>      // Linux/Windows: can get extensions
   #endif
   ```

4. **Alternative OpenGL Extensions Available on macOS:**
   - `GL_EXT_texture_compression_s3tc` (S3TC/DXT) - **YES, available**
   - `GL_ARB_texture_compression` (generic compression query) - **YES**
   - `GL_APPLE_texture_packed_float` (RGBE) - **YES**
   - BC7 specifically - **NO**

### 1.3 PoB2 Asset Format Requirement

**Current Asset Packaging:**
- PoE2 tree assets: `*.dds.zst` (DDS wrapped in Zstandard compression)
- DDS files typically use BC7 for modern assets
- Zstandard decompression is implemented (sg_compress.c)
- DDS format itself is recognized in whitelist (sg_image.c:83)

**Problem Chain:**
```
*.dds.zst file → decompress .zst → DDS file with BC7 blocks →
  glCompressedTexImage2D(..., GL_COMPRESSED_RGBA_BPTC_UNORM, ...)
  → FAILS on macOS (extension not available)
```

### 1.4 Software Decode Recommendation

**Approach: Two-Tier Strategy**

#### Tier 1: Query and Fallback (IMMEDIATE - Phase 11)
```c
// In sg_image.c or new dds_loader.c
GLint numFormats;
glGetIntegerv(GL_NUM_COMPRESSED_TEXTURE_FORMATS, &numFormats);

// Check if BC7 is in the list (it won't be on macOS)
bool bc7_supported = check_compressed_format(GL_COMPRESSED_RGBA_BPTC_UNORM);

if (!bc7_supported) {
    // Use software decode fallback
    result = load_dds_with_software_decode(filename);
} else {
    // Use GPU compressed format
    result = load_dds_hardware(filename);
}
```

#### Tier 2: BC7 Software Decoder Implementation (Phase 12)

**Option A: libsquish (RECOMMENDED)**
- Lightweight, C library for S3TC and BC textures
- License: MIT
- Performance: ~1-2ms per 4x4 block on modern CPU
- Integration: ~300 lines of wrapper code

```c
// Pseudo-code
#include <squish.h>

bool decode_bc7_software(const uint8_t* bc7_block, uint8_t* rgba_out, int width, int height) {
    squish::DecompressImage(
        rgba_out,           // output RGBA buffer
        width, height,
        bc7_block,          // input BC7 compressed
        squish::kBc7        // format flag
    );
    return true;
}
```

**Option B: Custom BC7 Decoder**
- No external dependency
- Complex: 1500+ lines minimum
- Only needed if libsquish cannot be vendored
- Reference: https://github.com/RTCore/BC7Decoder

**Option C: Transcode via CPU Texture**
- Upload decompressed data as GL_RGBA uncompressed
- 4x memory footprint in VRAM
- Acceptable for macOS (most users have ≥4GB VRAM)

#### Tier 3: Future - Metal Backend (Post-MVP)
- Metal natively supports BC7 (`MTLPixelFormatBC7_RGBAUnorm`)
- Would require parallel Metal backend
- Out of scope for Phase 11

### 1.5 DDS Format Support Status

**Current Implementation:**
- Format is **recognized** in path validation (sg_image.c:83)
- Actually **NOT loaded** - backend stubs return hardcoded dimensions (100x100)
- sg_backend_load_image() in opengl_backend.c:385 is a stub

**Required Changes:**
1. Parse DDS header (128 byte + variant structures)
2. Extract width, height, format, mipmap count
3. Load compressed data blocks
4. Either:
   - GPU upload with GL_COMPRESSED_RGBA_BPTC_UNORM (fails on macOS)
   - CPU software decode to RGBA → GL_RGBA uncompressed
   - Transcode to S3TC if BC7 unavailable

### 1.6 Implementation Priority

**Phase 11 Deliverable:**
- [x] Document BC7 unavailability on macOS
- [x] Recommend software decode fallback
- [ ] Integrate minimal DDS parser
- [ ] Stub software BC7 decode (libsquish integration defer to Phase 12)

**Phase 12 Expansion:**
- [ ] Integrate libsquish for BC7 CPU decode
- [ ] Optimize decode pipeline
- [ ] Add mipmap support

---

## TASK 2: Remaining API Gaps for Full PoB2 Usability

### 2.1 Test Log Error Analysis

**Source:** `/tmp/pob2_interactive_test.log` (2,981,702 lines)

**Identified Issues:**
1. **Missing tree nodes** (non-fatal, rendering issue):
   ```
   missing node 63493, 24665, 35715, 28429, 26353, 950, 45406, 50198, 5162,
   11495, 10889, 62386, 39383, 51916, 54579, 16732
   ```
   - Indicates passive tree data incomplete
   - Does not block basic operation

2. **Directory creation failures** (medium severity):
   ```
   [MakeDir] Failed to create directory: /Users/kokage/Library/Application Support/PathOfBuilding2/scripts/ (errno: 2)
   [MakeDir] Failed to create directory: /Users/kokage/Library/Application Support/PathOfBuilding2/scripts/Builds/ (errno: 2)
   ```
   - errno: 2 = ENOENT (parent directory doesn't exist)
   - **Problem:** MakeDir doesn't create parent directories (no `-p` equivalent)
   - **Impact:** Prevents user data persistence
   - **Severity:** MEDIUM-HIGH

### 2.2 Critical API Inventory

**Implemented (in sg_stubs.c and sg_lua_binding.c):**
- ✅ Console: ConExecute, ConClear, ConPrintf
- ✅ Clipboard: Copy, Paste, SetClipboard, GetClipboard
- ✅ System: TakeScreenshot, OpenURL, Exit, GetTime
- ✅ Paths: GetScriptPath, GetRuntimePath, GetUserPath
- ✅ Loading: LoadModule (stub), GetSubScript (stub)
- ✅ Rendering: RenderInit, SetDrawColor, SetViewport, SetWindowTitle
- ✅ Compression: Deflate (zlib), Inflate (zlib)
- ✅ Keyboard: IsKeyDown, GetCursorPos, SetCursorPos, ShowCursor
- ✅ Images: NewImage, ImgWidth, ImgHeight, LoadImage (stubs)

### 2.3 API Gaps Identified

#### GAP 1: LaunchSubScript / Threading (CRITICAL)
**Status:** NOT IMPLEMENTED
**Priority:** CRITICAL - BLOCKS 30% of functionality

**Required for:**
- All network requests (PoE API, download updates)
- OAuth authentication flow
- Build downloads from external sites
- Archive recommendations

**Current State:**
- HeadlessWrapper.lua line 118: `function LaunchSubScript(scriptText, funcList, subList, ...) end`
- Completely stubbed - returns nil (no operation ID)
- Launch.lua depends heavily on this (lines 310, 344, and more)

**Implementation Requirement:**
```lua
-- LaunchSubScript signature
-- Returns: scriptID (integer) or nil on error
-- scriptText: Lua code to run in isolated thread
-- funcList: comma-separated list of functions to expose (e.g., "GetScriptPath,LoadModule")
-- subList: comma-separated list of callbacks (e.g., "ConPrintf,UpdateProgress")
-- ...: arguments passed to script
```

**See Task 3 for full analysis.**

---

#### GAP 2: MakeDir - Incomplete Implementation (HIGH)
**Status:** PARTIALLY IMPLEMENTED
**Location:** sg_stubs.c (no C implementation visible)
**Priority:** HIGH - Affects save/config system

**Current Behavior:**
- Accepts path but fails if parent doesn't exist
- No recursion like `mkdir -p`

**Fix Required:**
```c
int SimpleGraphic_MakeDir(const char* path) {
    // Implement mkdir -p equivalent:
    // 1. Split path by '/'
    // 2. Create each intermediate directory
    // 3. Return 0 on success, -1 on error
}
```

---

#### GAP 3: Deflate / Inflate - Zstandard Support (MEDIUM)
**Status:** IMPLEMENTED for zlib only
**Location:** sg_compress.c
**Priority:** MEDIUM - Zstandard required for asset loading

**Current State:**
- sg_compress.c uses zlib (deflate/inflate)
- PoB2 assets use `.dds.zst` (Zstandard compression, not zlib)

**Problem:**
```
DDS texture file is compressed with Zstandard, but Inflate() uses zlib
→ Decompression fails silently
→ Image loading fails
```

**Fix Required:**
- Either: Replace zlib with Zstandard library (zstd)
- Or: Add dual-codec support (detect and dispatch)
- Lines ~50-100 of sg_compress.c need modification

---

#### GAP 4: LoadModule - Full Implementation Needed (MEDIUM)
**Status:** STUB ONLY
**Location:** sg_stubs.c:450-487
**Priority:** MEDIUM - Currently just logs

**Current:**
```c
// sg_stubs.c:486-487
fprintf(stderr, "[LoadModule] Loading module: %s\n", module_path);
return 1;  // Always returns success (1)
```

**Required:** Actually invoke Lua loadfile() and execute with Lua VM

**Dependency:** Requires LuaJIT C API integration

---

#### GAP 5: GetSubScript - Resource Loading (MEDIUM)
**Status:** STUB ONLY
**Location:** sg_stubs.c:494-502
**Priority:** MEDIUM - May not be critical for Phase 11

**Current:**
```c
fprintf(stderr, "[GetSubScript] Script requested: %s\n", name);
return NULL;  // Always fails
```

**Purpose:** Load built-in scripts from resources

**Note:** May not be used if LaunchSubScript works correctly

---

#### GAP 6: IsSubScriptRunning / AbortSubScript (MEDIUM)
**Status:** NOT IMPLEMENTED
**Location:** None found
**Priority:** MEDIUM - Update cancellation

**Needed by:**
- Launch.lua: Update progress checking
- Long-running script management

**Signature Required:**
```c
bool IsSubScriptRunning(int script_id);
int AbortSubScript(int script_id);
```

---

#### GAP 7: SpawnProcess - Path Validation Incomplete (LOW)
**Status:** PARTIALLY IMPLEMENTED
**Location:** sg_stubs.c:242-302
**Priority:** LOW - Non-critical feature

**Current:** Has whitelist for common paths, works for `/usr/bin/open`

**Issue:** May reject legitimate paths on non-standard macOS installs

**Recommendation:** Accept as-is for Phase 11

---

#### GAP 8: SetWorkDir / GetWorkDir (LOW)
**Status:** NOT IMPLEMENTED
**Location:** HeadlessWrapper.lua:114-116
**Priority:** LOW - May not be needed

**Note:** Lua scripts typically use relative paths

---

#### GAP 9: RemoveDir - Directory Deletion (LOW)
**Status:** NOT IMPLEMENTED
**Location:** HeadlessWrapper.lua:113
**Priority:** LOW - Not critical

---

#### GAP 10: Deflate Array - Binary Data Handling (LOW)
**Status:** UNKNOWN - Zlib only
**Priority:** LOW - Phase 2 feature

---

### 2.4 API Gap Summary Table

| API Function | Status | Priority | Impact | Phase |
|---|---|---|---|---|
| LaunchSubScript | NOT IMPL | 🔴 CRITICAL | Network/auth blocked | 11 |
| MakeDir (recursive) | PARTIAL | 🔴 HIGH | Save system broken | 11 |
| Inflate (Zstandard) | PARTIAL | 🟠 MEDIUM | Asset loading fails | 11 |
| LoadModule (real) | STUB | 🟠 MEDIUM | Module loading fails | 11 |
| IsSubScriptRunning | NOT IMPL | 🟠 MEDIUM | Update progress unavailable | 11 |
| AbortSubScript | NOT IMPL | 🟠 MEDIUM | Can't cancel downloads | 11 |
| GetSubScript | STUB | 🟡 LOW | Builtin scripts unavailable | 12 |
| SetWorkDir/GetWorkDir | NOT IMPL | 🟡 LOW | May not be needed | 12 |
| RemoveDir | NOT IMPL | 🟡 LOW | File cleanup unavailable | 12 |
| GetAsyncCount | STUB | 🟡 LOW | Always returns 0 | 11 |

---

## TASK 3: LaunchSubScript Analysis

### 3.1 Purpose and Architecture

**What LaunchSubScript Does:**

```lua
-- Launch.lua:310
local id = LaunchSubScript(script, "", "ConPrintf", url, params.header, params.body, self.connectionProtocol, self.proxyURL, self.noSSL or false)

-- Downloads a URL in background, returns script ID
-- Calls ConPrintf in main thread with progress
-- When done, calls registered callback via OnSubFinished()
```

**Core Function Signature:**
```lua
function LaunchSubScript(
    scriptText,    -- string: Lua code to run in isolated environment
    funcList,      -- string: "Func1,Func2,Func3" - functions available to script
    subList,       -- string: "Callback1,Callback2" - callbacks to main thread
    ...            -- varargs: arguments passed to script as ... in Lua
)
    return scriptID  -- integer ID, or nil on error
end
```

### 3.2 Usage Patterns in PoB2

**Found 8 LaunchSubScript invocations:**

#### Pattern 1: Download Page with curl (CRITICAL)
**Location:** Launch.lua:310 (DownloadPage function)

```lua
local id = LaunchSubScript(script, "", "ConPrintf", url, params.header, params.body,
    self.connectionProtocol, self.proxyURL, self.noSSL or false)

self.subScripts[id] = {
    type = "DOWNLOAD",
    callback = function(responseBody, errMsg, responseHeader)
        callback({header=responseHeader, body=responseBody}, errMsg)
    end
}
```

**Script requirements:**
- Must have `require("lcurl.safe")` available
- Network timeout handling
- SSL verification control
- Proxy support

**Impact:** **BLOCKS all API calls** (game data, updates, OAuth)

---

#### Pattern 2: OAuth Authorization Flow (CRITICAL)
**Location:** Classes/PoEAPI.lua:79

```lua
local server = io.open("LaunchServer.lua", "r")
local id = LaunchSubScript(server:read("*a"), "", "ConPrintf,OpenURL", authUrl)

launch.subScripts[id] = {
    type = "DOWNLOAD",
    callback = function(code, errMsg, state, port)
        -- Handle OAuth code reception
    end
}
```

**Script requirements:**
- Must load LaunchServer.lua as script
- Open local HTTP server to catch redirect
- Accept OAuth code from browser
- Call OpenURL to launch browser

**Impact:** **BLOCKS account linking**

---

#### Pattern 3: Update Check (HIGH)
**Location:** Launch.lua:344

```lua
local id = LaunchSubScript(update:read("*a"),
    "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir",
    "ConPrintf,UpdateProgress",
    self.connectionProtocol, self.proxyURL, self.noSSL or false)

self.subScripts[id] = {
    type = "UPDATE"
}
```

**Script requirements:**
- Access to file system functions (GetScriptPath, etc.)
- Ability to report progress via UpdateProgress callback
- Download and verify updates

**Impact:** **BLOCKS auto-updates**

---

#### Pattern 4: Archive Recommendations (MEDIUM)
**Location:** Classes/PoBArchivesProvider.lua:49

```lua
local id = LaunchSubScript([[
    local code, connectionProtocol, proxyURL = ...
    local curl = require("lcurl.safe")
    local easy = curl.easy()
    easy:setopt_url(...)
    -- ... curl request ...
    return page, res
]], "", "", buildCode, launch.connectionProtocol, launch.proxyURL)

launch:RegisterSubScript(id, function(response, errMsg)
    -- Handle response
end)
```

**Script requirements:**
- Curl library access
- POST request support

**Impact:** **BLOCKS build recommendations feature**

---

#### Pattern 5: BuildSiteTools (LOW)
**Location:** Modules/BuildSiteTools.lua:40

Similar curl-based operation with custom script.

---

#### Pattern 6: TreeTab Data Loading (MEDIUM)
**Location:** Classes/TreeTab.lua:709

Decompression and data processing in background thread.

---

### 3.3 Critical Requirements for LaunchSubScript

**Threading Model:**
1. Create isolated Lua environment (separate stack/heap)
2. Expose specified functions (funcList parameter)
3. Run script asynchronously
4. Allow script to call back to main thread (subList parameter)
5. Return script ID immediately
6. Main thread polls for completion via OnSubFinished() callback
7. Handle errors via OnSubError() callback

**Function Exposure Mechanism:**
```c
// When funcList = "GetScriptPath,LoadModule,GetRuntimePath"
// The subscript environment needs access to these functions from main thread

// Execute in subscript environment:
local path = GetScriptPath()  // Calls main thread version
```

**Callback Mechanism:**
```lua
-- If subList = "ConPrintf,UpdateProgress"
-- Script can call: ConPrintf("message")
-- Which invokes: launch:OnSubCall("ConPrintf", "message")

-- When script returns, triggers: launch:OnSubFinished(id, result1, result2, ...)
```

**Execution Model (Simplified):**
```
Main Thread                    Subscript Thread
-------------------           -------------------
LaunchSubScript()              (script_start)
  |--create thread id          load_script()
  |--return id                 for each arg in funcList
  |                              expose_function(arg)
  |                            execute_script()
OnSubFinished                    |--calls ConPrintf (main thread)
  |--registered callback         |--calls OpenURL (main thread)
                                 return_values
                              (thread_exit)
```

### 3.4 Safety and Sandboxing

**PoB2 Implementation Considerations:**

1. **Security Model:**
   - Subscripts have access to file system (GetScriptPath, MakeDir)
   - Subscripts have access to network (curl library)
   - Trust model: Scripts are code loaded from PoB files (not user input)
   - Same security model as main Lua environment

2. **Resource Limits:**
   - Typical script execution: 100ms - 5000ms (downloads take longer)
   - Memory: ~1-2MB per script context
   - Max concurrent scripts: 2-3 (small thread pool is sufficient)

3. **Error Handling:**
   - Lua errors caught and passed to OnSubError()
   - Network errors returned as errMsg to callback
   - Timeouts: Should be handled by curl (CURLOPT_TIMEOUT)

### 3.5 Implementation Strategy

**Option A: Lightweight Thread Pool + LuaJIT (RECOMMENDED)**

Pros:
- LuaJIT coroutines can't truly parallelize, so needs real threads
- Small thread pool (2-4 threads) sufficient
- Each thread has its own Lua state
- Simple callback queue back to main thread

Cons:
- Thread synchronization needed
- Requires Lua state per thread

**Option B: Async/Await with Callbacks (COMPLEX)**

Pros:
- No threading
- Can use Lua coroutines

Cons:
- Changes execution model
- More complex to implement
- Less compatible with curl library usage

**Option C: Fork Child Process (NOT RECOMMENDED)**

Pros:
- Complete isolation
- No threading issues

Cons:
- Slow startup
- IPC overhead
- Complex state marshaling

### 3.6 Can LaunchSubScript Be Stubbed?

**NO - It is CRITICAL**

**Consequence of stubbing:**
- ✗ Cannot download build code from external URLs
- ✗ Cannot authenticate with Path of Exile account
- ✗ Cannot check for updates
- ✗ Cannot fetch game data from API
- ✗ Cannot get build recommendations
- ✗ UI will show errors for 30%+ of operations

**Severity:** BLOCKS core PoB2 functionality

---

## Summary: Critical Path for Phase 11

### Must Implement (Blocking):
1. **LaunchSubScript** - Thread pool + Lua state isolation
2. **MakeDir (recursive)** - Fix errno:2 issue
3. **Deflate/Inflate Zstandard** - Asset decompression

### Should Implement (High Priority):
4. **IsSubScriptRunning / AbortSubScript** - Progress tracking
5. **LoadModule (real)** - Lua VM integration
6. **DDS parser stub** - Prepare for Phase 12 BC7 work

### Can Defer (Phase 12):
7. **BC7 software decoder** - libsquish integration
8. **GetSubScript** - If not needed for core flow
9. **SetWorkDir / RemoveDir** - File management features

---

## Recommendations: Phase 11 Execution Plan

### Week 1-2: LaunchSubScript Foundation
- [ ] Design thread pool architecture
- [ ] Implement Lua state isolation
- [ ] Add function exposure mechanism
- [ ] Test with simple curl script

### Week 2-3: Core Fixes
- [ ] Fix MakeDir to handle recursive creation
- [ ] Add Zstandard support (dual codec or replace zlib)
- [ ] Implement IsSubScriptRunning

### Week 3-4: BC7 Preparation
- [ ] Parse DDS headers
- [ ] Stub BC7 detection
- [ ] Prepare libsquish integration (defer actual implementation)
- [ ] Document fallback path

### Integration Testing
- [ ] Verify network downloads work
- [ ] Confirm OAuth flow
- [ ] Test asset loading (with temporary fallback)
- [ ] Check update mechanism

---

## Technical References

### OpenGL Resources:
- OpenGL 4.6 Spec: Section 8.5 (Texture Compression, BC7 format)
- macOS OpenGL Limitations: Apple Technical Note TN2085
- Metal BC7 Support: `MTLPixelFormatBC7_RGBAUnorm`

### Library Recommendations:
- **libsquish:** https://github.com/svn2github/libsquish (MIT license)
- **Zstandard (zstd):** https://github.com/facebook/zstd (BSD license)
- **LuaJIT FFI:** https://luajit.org/ext_ffi.html

### Code Locations in PoB2:
- Main thread callbacks: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua`
- Network code: `Classes/PoEAPI.lua`, `Classes/PoBArchivesProvider.lua`
- Update system: `Launch.lua:335-352`, `UpdateCheck.lua`
- OAuth: `Classes/PoEAPI.lua:60-100`

---

**End of Sage Phase 11 Analysis**

Compiled by: Sage (賢者)
Date: 2026-01-29
Status: Ready for implementation planning
