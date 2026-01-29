# Phase 10 Analysis: PoB2 macOS Integration Requirements

**Created**: 2026-01-29
**Project**: PRJ-003 (PoB2macOS)
**Context**: Phase 9 achieved functional PoB2 startup with UI rendering. Phase 10 addresses critical blockers: image formats, compression, and interactive loop.

---

## T10-S1: Image Loading Requirements Analysis

### Current State
- **Image Loader**: Uses `stb_image.h` v2.27 (PNG, JPG, BMP formats only)
- **Supported Extensions**: `.png`, `.jpg`, `.jpeg`, `.bmp` (case-insensitive)
- **Location**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`
- **Validation**: Path validation rejects absolute paths and `..` traversal

### PoB2 Image Assets Inventory

#### 1. Assets Directory (`/src/Assets/`)
**Total Files**: 77 PNG files
- **All Assets**: PNG format exclusively
- **Examples**:
  - `ring.png` (1024 x 1024, 8-bit gray+alpha)
  - `small_ring.png`
  - `ShadedOuterRing.png`, `ShadedInnerRing.png`, `ShadedOuterRingFlipped.png`
  - `game_ui_small.png` (UI components)
  - Item/passive skill headers: `normalpassiveheaderleft.png`, `ascendancypassiveheaderleft.png`, etc.
  - Separator/divider assets

**Usage Pattern**: PassiveTreeView loads these on initialization (lines 19-29):
```lua
self.ring = NewImageHandle()
self.ring:Load("Assets/ring.png", "CLAMP")
self.highlightRing = NewImageHandle()
self.highlightRing:Load("Assets/small_ring.png", "CLAMP")
-- etc.
```

#### 2. TreeData Directory Structure
**Location**: `/src/TreeData/` with versions: `0_1`, `0_2`, `0_3`, `0_4`, `legion`

**TreeData/0_4 (Current Version)**:
- **PNG Files**: 90 files
- **DDS.ZST Files**: 29 files (Zstandard-compressed DirectDraw Surface)

**PNG Files** (mostly character/skill orbit visualization):
- `Character_orbit_normal0.png` through `Character_orbit_normal9.png` (10 variations)
- `Character_orbit_intermediate0.png` through `Character_orbit_intermediate9.png`
- `Character_orbit_intermediateactive0.png` through `Character_orbit_intermediateactive9.png`
- `CharacterAscendancy_orbit_*` variants
- `CharacterPlanned_orbit_*` variants

**DDS.ZST Files** (texture atlases, mostly compressed):
- Background textures: `background_1024_1024_BC7.dds.zst`
- Ascendancy backgrounds: `ascendancy-background_1500_1500_BC7.dds.zst`, `ascendancy-background_4000_4000_BC7.dds.zst`
- Group backgrounds: `group-background_*_BC7.dds.zst` (various sizes)
- Skill icons: `skills-disabled_*_BC1.dds.zst`
- Oil/jewel data: `oils_108_108_RGBA.dds.zst`
- Legion assets: `legion_*_BC7.dds.zst`, `legion_*_BC1.dds.zst`

### DDS.ZST Format Requirements

#### Zstandard Compression (`.zst`)
- **Algorithm**: Zstandard (RFC 8878)
- **Compression Ratio**: Better than gzip, still fast decompression
- **Header**: Magic number `28 B5 2F FD` (4 bytes)
- **Library Required**: `libzstd` (not currently included)

#### DirectDraw Surface (`.dds`)
- **Format**: Microsoft's texture container format
- **Compression Formats in PoB2**:
  - `BC1` (DXT1): RGB, 6:1 compression, small file size
  - `BC7`: RGBA, better quality, larger files
  - `RGBA`: Uncompressed RGBA channels
- **Structure**: File header + mip levels + pixel data
- **GPU Decoding**: Modern GPUs support hardware BC1/BC7 decompression

#### Current Problem
- Image loader calls `stbi_load()` which does NOT support DDS format
- No ZST decompression library integrated
- Result: All tree background/skill icon textures fail to load, showing placeholder (white 1x1) texture

### Image Path Resolution

**PassiveTree.lua** (lines 550-560):
```lua
function PassiveTreeClass:LoadImage(imgName, data, ...)
    local imgFile = io.open("TreeData/"..self.treeVersion.."/"..imgName, "r")
    if imgFile then
        imgFile:close()
    else
        ConPrintf("Image '%s' not found...", imgName)
    end
    data.handle = NewImageHandle()
    data.handle:Load("TreeData/"..self.treeVersion.."/"..imgName, ...)
    data.width, data.height = data.handle:ImageSize()
end
```

**Path Structure**:
- Base: `TreeData/<version>/<filename>`
- Version: Typically `0_4` (current PoE2 tree)
- Examples: `TreeData/0_4/background_1024_1024_BC7.dds.zst`

**Critical Issue**: Current path validation in `sg_image.c` line 79-85:
```c
if (strcmp(lower_ext, ".png") != 0 &&
    strcmp(lower_ext, ".jpg") != 0 &&
    strcmp(lower_ext, ".jpeg") != 0 &&
    strcmp(lower_ext, ".bmp") != 0) {
    printf("[SG] Error: Unsupported image format: %s\n", ext);
    return false;
}
```

This rejects `.dds` and `.dds.zst` extensions entirely.

---

## T10-S2: Deflate/Inflate (Compression) Usage Analysis

### Current State
- **Implementation**: Stubbed in `HeadlessWrapper.lua` (lines 4-9)
- **Status**: Returns empty string (`""`) - non-functional

```lua
function Deflate(data)
    -- TODO: Might need this
    return ""
end
function Inflate(data)
    -- TODO: And this
    return ""
end
```

### Usage Patterns in PoB2

#### 1. Build Export/Import (Primary Use Case)
**Files**:
- `src/Classes/ImportTab.lua` - Build code generation
- `src/Classes/PartyTab.lua` - Party build sharing
- `src/Modules/Build.lua` - Build management
- `src/Modules/Main.lua` - Main module

**Pattern**: Base64-encoded, URL-safe variant with deflate compression
```lua
-- Export
common.base64.encode(Deflate(self.build:SaveDB("code"))):gsub("+","-"):gsub("/","_")

-- Import
local xmlText = Inflate(common.base64.decode(buf:gsub("-","+"):gsub("_","/")))
```

**Workflow**:
1. Build XML → `SaveDB("code")` produces raw XML string
2. Compress → `Deflate()` produces binary (raw deflate stream)
3. Encode → `base64.encode()` + URL-safe substitution (`+` → `-`, `/` → `_`)
4. Result: Shareable code string

**Import Reverse**:
1. URL-safe string → Substitute back (`-` → `+`, `_` → `/`)
2. Decode → `base64.decode()` produces binary
3. Decompress → `Inflate()` produces original XML
4. Parse → Load XML into build

#### 2. Legion Data (Secondary Use Case)
**File**: `src/Modules/DataLegionLookUpTableHelper.lua`

**Pattern**: Compressed file handling
```lua
jewelData = Inflate(compressedFile:read("*a"))
-- ... process jewelData ...
compressedFileData = Deflate(jewelData)
```

**Usage**: Legion atlas/jewel data storage in compressed format

#### 3. Update Checking (Tertiary Use Case)
**File**: `src/Modules/Common.lua`

**Pattern**: Compressed data from update servers
```lua
callback(Inflate(common.base64.decode(data:gsub("-", "+"):gsub("_", "/"))), urlText)
```

**Usage**: Checking for PoB2 updates via HTTP, data sent compressed to save bandwidth

### Compression Format Specification

#### Deflate vs Gzip vs Zlib
- **Deflate (raw)**: Pure deflate stream, no header
- **Zlib**: Deflate + 2-byte header (`78 9c`, `78 da`, etc.) + Adler-32 checksum
- **Gzip**: Deflate + gzip header/footer + CRC-32 + file metadata

**PoB2 Behavior**: Based on code patterns and compatibility with LuaJIT's `zlib` library (standard on most systems):
- Most likely uses **zlib format** (deflate + zlib wrapper)
- Reason: LuaJIT's zlib binding expects zlib format by default
- Fallback: Raw deflate with manual header handling

#### Library Requirements
- **Windows/Linux**: LuaJIT has built-in `zlib` binding
- **macOS Current**: No zlib binding in PoB2macOS codebase
- **Solution Options**:
  1. Link `libz` (system zlib) and create Lua binding
  2. Use `miniz` (single-header zlib implementation)
  3. Implement stubs that error gracefully (defer to Phase 11)

### Data Flow Examples

**Example 1: Build Export (ImportTab.lua)**
```
Build Object (Tree, Items, Config)
  ↓
SaveDB("code") → XML string (5-50 KB typical)
  ↓
Deflate() → Binary (1-10 KB, 80-90% compression)
  ↓
base64.encode() → ASCII string (2-13 KB)
  ↓
gsub("+","-"):gsub("/","_") → URL-safe (2-13 KB)
  ↓
Copy to clipboard / Share code
```

**Example 2: Build Import (PartyTab.lua)**
```
Clipboard paste: "<url-safe-code>"
  ↓
gsub("-","+"):gsub("_","/") → Base64 (2-13 KB)
  ↓
base64.decode() → Binary (1-10 KB)
  ↓
Inflate() → XML string (5-50 KB)
  ↓
Parse XML → Build Object (Tree, Items, Config)
```

### Impact on Phase 10
- **Blocking**: Build export/import will not function
- **Severity**: MEDIUM - affects core PoB2 functionality
- **Workaround**: Disable ImportTab until Phase 11
- **Fallback**: Parse raw XML directly (skip compression)

---

## T10-S3: Interactive Loop Requirements Analysis

### Current Architecture

#### Callback Mechanism (`sg_callbacks.c`)
**File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_callbacks.c`

**Global State**:
- `lua_state`: Lua VM pointer
- `main_object_ref`: Lua table reference for main launch object
- Supports registry-based callback invocation

**Available Callbacks** (to be called from C):
1. `OnInit()` - Called once after main loop starts
2. `OnFrame()` - Called every frame
3. `OnKeyDown(key, is_double)` - Key press event
4. `OnKeyUp(key)` - Key release event
5. `OnChar(char_code)` - Character input (unicode)
6. `CanExit()` - Can application exit? (returns bool)
7. `OnExit()` - Shutdown cleanup

**Callback Registration**:
```c
SimpleGraphic_SetLuaState(L);  // Register Lua state
SimpleGraphic_SetMainObject(launch_table);  // Register main object
```

**Invocation Pattern**:
```c
void SimpleGraphic_CallOnFrame(void) {
    invoke_main_object_method("OnFrame", 0);
}
```

#### GLFW Window Management (`glfw_window.c`)
**File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/glfw_window.c`

**Initialization** (lines 109-166):
```c
int glfw_window_init(const char* flags) {
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);

    g_window = glfwCreateWindow(1920, 1080, "Path of Building 2", NULL, NULL);
    glfwMakeContextCurrent(g_window);
    glfwSwapInterval(1);  // VSync enabled
}
```

**Event Callbacks Registered**:
- `window_close_callback` → Sets `g_should_close = true`
- `key_callback` → Tracks `g_keys_pressed[key]` array (512 keys max)
- `cursor_callback` → Updates `g_cursor_x`, `g_cursor_y`

**Event Loop** (lines 206-217):
```c
bool glfw_window_poll_events(void) {
    if (!g_window) return false;

    glfwPollEvents();  // Poll input events
    glfwSwapBuffers(g_window);  // Present frame

    return !glfwWindowShouldClose(g_window) && !g_should_close;
}
```

**Key Name Mapping** (lines 55-106):
- Arrow keys: `up`, `down`, `left`, `right`
- Special keys: `escape`, `space`, `return`, `backspace`, `tab`, `delete`, `insert`, `home`, `end`, `pageup`, `pagedown`
- Function keys: `f1`-`f12`
- Modifier keys: `lshift`, `rshift`, `lctrl`, `rctrl`, `lalt`, `ralt`
- Letter keys: `a`-`z` (lowercase)
- Number keys: `0`-`9`

**Cursor Functions**:
```c
void glfw_window_get_cursor(int* x, int* y)  // Current position
bool glfw_window_is_key_down(const char* key_name)  // Check key state
```

### PoB2 Main Loop Integration

#### Expected Lua Interface (from launcher)
**File**: `/Users/kokage/national-operations/pob2macos/launcher/pob2_launcher.lua`

**Launcher FFI Declarations**:
```lua
bool SimpleGraphic_RunMainLoop(void);
bool SimpleGraphic_IsUserTerminated(void);
void SimpleGraphic_SetWindowTitle(const char* title);
bool SimpleGraphic_IsKeyDown(const char* key);
void SimpleGraphic_GetCursorPos(int* x, int* y);
```

#### Expected PoB2 Launch.lua Handlers
From PoB2 source, expected methods on launch object:
```lua
local launch = {
    OnInit = function(self)
        -- Initialize PoB2 UI, load assets
    end,

    OnFrame = function(self)
        -- Update state, process input, render
    end,

    OnKeyDown = function(self, key, is_double)
        -- Handle key press
    end,

    OnKeyUp = function(self, key)
        -- Handle key release
    end,

    OnChar = function(self, char_code)
        -- Handle character input (for text fields)
    end,

    CanExit = function(self)
        -- Check if application can close
        -- Return false to block exit
    end,

    OnExit = function(self)
        -- Cleanup, save state
    end
}
```

### Current Test Coverage

**Location**: `/Users/kokage/national-operations/pob2macos/tests/`

**Stage 1 Test** (`test_pob2_launch_stage1.lua`):
- Verifies FFI loading and basic initialization
- Calls `SimpleGraphic_RenderInit()`
- Tests 3 frames of `OnFrame()` calls
- **Status**: PASSING

**Missing**: Actual event dispatch testing
- No KeyDown/KeyUp injection tests
- No cursor position tracking tests
- No character input (OnChar) tests

### Event Dispatch Requirements for Phase 10

#### Must-Have Events
1. **OnKeyDown** - All navigation keys
   - Arrow keys for tree navigation
   - Shift/Ctrl modifiers for multi-select
   - Enter for node allocation
   - Search field support

2. **OnKeyUp** - Release tracking
   - End multi-select operations
   - Cancel dragging

3. **OnChar** - Text input
   - Search field in passive tree
   - Item name filters
   - Config string entries

4. **Cursor Position** - Mouse interaction
   - Passive tree zoom/pan
   - Button clicks
   - Tooltip positioning

#### Optional Events (Phase 11)
- Mouse wheel for zooming
- Mouse button press/release
- Right-click context menus
- Double-click detection

### Integration Checklist

#### C Side (SimpleGraphic Backend)
```
[x] GLFW window creation (1792x1012 per Phase 9)
[x] Event callback registration
[x] Key state tracking array
[x] Cursor position tracking
[ ] Key event dispatch to Lua (OnKeyDown/OnKeyUp)
[ ] Character event dispatch (OnChar)
[ ] Mouse button events (Phase 11)
```

#### Lua Side (PoB2 Launch.lua)
```
[ ] OnInit() handler - Initialize UI, load assets
[ ] OnFrame() handler - Game loop, render, input processing
[ ] OnKeyDown(key, is_double) handler
[ ] OnKeyUp(key) handler
[ ] OnChar(char_code) handler
[ ] CanExit() handler
[ ] OnExit() handler
```

#### Event Loop Main (`SimpleGraphic_RunMainLoop`)
```
[ ] Initialize window
[ ] Call OnInit()
[ ] Loop:
    [ ] Call OnFrame()
    [ ] Poll events from GLFW
    [ ] Dispatch key events to OnKeyDown/OnKeyUp
    [ ] Dispatch character input to OnChar
    [ ] Check CanExit()
    [ ] Render frame
    [ ] Swap buffers
[ ] Call OnExit()
```

### LaunchSubScript Impact

**Current State**: Stubbed to return `nil`
```lua
function LaunchSubScript(scriptText, funcList, subList, ...) end
```

**Usage in PoB2**:
1. **Update Checking** (`Launch.lua`):
   ```lua
   local id = LaunchSubScript(update:read("*a"), "GetScriptPath,GetRuntimePath,GetWorkDir,MakeDir",
                              "ConPrintf,UpdateProgress", ...)
   ```
   Runs background update check script in separate execution context.

2. **PoE API** (`PoEAPI.lua`):
   ```lua
   local id = LaunchSubScript(server:read("*a"), "", "ConPrintf,OpenURL", authUrl)
   ```
   Runs OAuth authentication flow.

3. **Archive Provider** (`PoBArchivesProvider.lua`):
   ```lua
   local id = LaunchSubScript([[...script...]], ...)
   ```
   Fetches build archives from external sources.

**Impact on Phase 10**:
- **Severity**: LOW - functionality deferred
- **Workaround**: Disable update checking, OAuth (fallback to local)
- **Requirement**: Return 0 or valid subscription ID instead of nil

---

## Summary: Phase 10 Blockers

| Issue | Type | Severity | Impact | Mitigation |
|-------|------|----------|--------|-----------|
| DDS.ZST format unsupported | Format | HIGH | Tree backgrounds/skills don't render | Integrate zstd + DDS decoder |
| Deflate/Inflate stubbed | Compression | MEDIUM | Build export/import broken | Link zlib, implement Lua binding |
| No event dispatch | Input | MEDIUM | UI not interactive | Implement OnKeyDown/KeyUp/OnChar dispatch |
| LaunchSubScript stubbed | Feature | LOW | Update checks fail | Return valid subscription ID (0) |
| Path validation too strict | Path | LOW | DDS/ZST rejected | Update extension whitelist |

## Specifications for Phase 10 Implementation

### 1. Image Format Support (T10-I1)
- Add `.dds` and `.dds.zst` to path validation whitelist
- Integrate Zstandard decompression (`libzstd` or `miniz`)
- Implement basic DDS parser for BC1/BC7/RGBA formats
- Update `image_loader.c` to detect and handle DDS files

### 2. Compression Support (T10-I2)
- Link system `libz` on macOS
- Create Lua binding for zlib deflate/inflate
- Implement `Deflate(data)` and `Inflate(data)` functions
- Test with build export/import round-trip

### 3. Event Dispatch (T10-I3)
- Implement `SimpleGraphic_CallOnKeyDown(key, is_double)`
- Implement `SimpleGraphic_CallOnKeyUp(key)`
- Implement `SimpleGraphic_CallOnChar(char_code)`
- Integrate into main loop event processing
- Add keyboard input tests

### 4. Main Loop Integration (T10-I4)
- Implement `SimpleGraphic_RunMainLoop()` in full (not 3-frame test)
- Continuous event polling
- Frame rate management (vsync)
- Graceful shutdown on CanExit()

---

**End of Analysis**
