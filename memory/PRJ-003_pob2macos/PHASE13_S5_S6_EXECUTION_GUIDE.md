# Phase 13 S5-S6 Execution Guide
## BC7 Software Decoder Integration for PoB2 macOS

**Date**: 2026-01-29
**Status**: Ready for Implementation
**Owner**: Sage (賢者)
**Duration**: 90 minutes estimated

---

## Quick Start

This guide provides step-by-step instructions to integrate BC7 software decoder into PoB2 macOS image loader.

### Files Provided

1. **phase13_s5_s6_bc7_implementation.md** - Complete technical specification
2. **image_loader_bc7_patch.md** - Detailed patch instructions
3. **create_bcdec.sh** - Automated script to create bcdec.h
4. **This file** - Step-by-step execution guide

---

## Pre-Implementation Checklist

- [ ] Working directory: `/Users/kokage/national-operations/pob2macos/`
- [ ] Git repository accessible
- [ ] CMake installed (`cmake --version`)
- [ ] Compiler working (`gcc --version` or `clang --version`)
- [ ] Build tools available (`make --version`)

---

## Task S5: Integration

### Step 1: Create bcdec.h Header File

**Method A: Using provided script** (recommended)
```bash
bash /Users/kokage/national-operations/claudecode01/memory/create_bcdec.sh
```

**Method B: Manual creation**

Copy the full bcdec.h code from `phase13_s5_s6_bc7_implementation.md` (section "Task S5: Integrate bcdec.h") into:
```
/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
```

**Verification**:
```bash
ls -l /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
file /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
```

Expected output: Regular file, ~140 lines

### Step 2: Modify image_loader.c - Add Include

**File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

**Location**: Line 54 (after `#include "stb_image.h"`)

**Action**: Add two lines:
```c
// BC7 decoder (header-only library)
#include "bcdec.h"
```

**Verification**:
```bash
grep -n "include \"bcdec.h\"" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c
```

Expected: Line number around 56-57

### Step 3: Add decode_bc7_software() Function

**File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

**Location**: After line 313 (after `create_sized_fallback()` function)

**Action**: Paste entire `decode_bc7_software()` function from `image_loader_bc7_patch.md` Change 2

**Function Code** (~60 lines):
```c
// BC7 software decoder - decodes BC7 blocks to RGBA on CPU
static unsigned char* decode_bc7_software(const uint8_t* bc7_data,
                                          uint32_t width, uint32_t height,
                                          uint32_t block_w, uint32_t block_h) {
    unsigned char* result = (unsigned char*)malloc(width * height * 4);
    // ... [see image_loader_bc7_patch.md for full code] ...
}
```

**Verification**:
```bash
grep -n "decode_bc7_software" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c
```

Expected: Function definition around line 314-373

### Step 4: Modify GPU Upload Failure Handling

**File**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

**Location**: Lines 482-485 (in `load_dds_texture()` function)

**Current Code**:
```c
    printf("[DDS] %s GPU upload failed, using fallback (%u x %u)\n", format_name, width, height);
    glDeleteTextures(1, &texture);
    return create_sized_fallback(width, height, out_width, out_height);
```

**New Code**: Replace with modified version from `image_loader_bc7_patch.md` Change 3

The new code:
1. Checks if format is BC7
2. Attempts software decode
3. Uploads decoded RGBA if successful
4. Falls back to gray if decode fails

**Verification**:
```bash
grep -A 5 "BC7 GPU upload failed for BC7" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c
```

Expected: Code present with proper flow

---

## Task S6: Build Verification

### Step 1: Prepare Build Environment

```bash
cd /Users/kokage/national-operations/pob2macos
mkdir -p build
cd build
```

### Step 2: Configure CMake

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
```

**Expected Output**:
```
-- Building for macOS
-- Using OpenGL backend
-- Build Configuration:
--   Platform: macOS
--   ...
-- Configuring done
-- Generating done
```

**Troubleshooting**:
- If CMake fails: Check dependencies with `cmake --version`
- If paths wrong: `pwd` should be `/Users/kokage/national-operations/pob2macos/build`

### Step 3: Compile

```bash
make -j4
```

**Expected Output**:
```
[  5%] Building C object ...
...
[ 50%] Linking C library libsimplegraphic.a
...
[100%] Built target mvp_test
```

**No Errors Expected**: Compilation should complete cleanly

### Step 4: Check for BC7 Symbols

```bash
nm libsimplegraphic.a | grep bcdec
nm libsimplegraphic.a | grep decode_bc7_software
```

**Expected Output**:
```
bcdec_bc7
bcdec_bc1
bcdec_bc3
decode_bc7_software
```

### Step 5: Verify Include Path

```bash
grep -r "bcdec.h" src/
grep -r "include.*bcdec" src/
```

**Expected Output**:
```
src/simplegraphic/backend/image_loader.c:#include "bcdec.h"
src/simplegraphic/backend/bcdec.h: ... header content ...
```

---

## Build Verification Checklist

| Item | Status | Notes |
|------|--------|-------|
| bcdec.h file exists | [ ] | `/src/simplegraphic/backend/bcdec.h` |
| image_loader.c includes bcdec.h | [ ] | Line ~56 |
| decode_bc7_software() present | [ ] | Lines 314-373 |
| GPU failure path modified | [ ] | Lines 482-512 |
| CMake configuration succeeds | [ ] | No errors |
| Make compilation succeeds | [ ] | No errors/warnings |
| BC7 symbols in library | [ ] | nm output shows functions |
| No undefined references | [ ] | Linker succeeds |

---

## Testing & Validation

### Test 1: Syntax Verification

```bash
cd /Users/kokage/national-operations/pob2macos/build
grep -c "void bcdec_bc7" ../src/simplegraphic/backend/bcdec.h
```

Expected: 1 (function declaration)

### Test 2: Symbol Resolution

```bash
nm libsimplegraphic.a | grep -E "bcdec|decode_bc7"
```

Expected: Multiple entries for BC decoder functions

### Test 3: Include Guard Check

```bash
grep "#ifndef BCDEC_H" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
grep "#endif.*BCDEC_H" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h
```

Expected: Both found (include guards present)

### Test 4: Memory Check

Verify decode function allocates and frees properly:
```bash
grep -A 2 "malloc.*width.*height.*4" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c
grep -B 2 "free(decoded)" /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c
```

Expected: Allocation and deallocation paired

---

## Troubleshooting Guide

### Compilation Error: "bcdec.h: No such file or directory"

**Cause**: bcdec.h not created or in wrong location

**Solution**:
```bash
# Verify file exists
ls -l /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h

# If missing, run creation script
bash /Users/kokage/national-operations/claudecode01/memory/create_bcdec.sh
```

### Compilation Error: "undefined reference to bcdec_bc7"

**Cause**: Function declarations missing or incomplete

**Solution**:
1. Check bcdec.h has all three function declarations
2. Verify implementations not wrapped in #ifdef that's not defined
3. Rebuild with clean:
```bash
cd /Users/kokage/national-operations/pob2macos/build
make clean
cmake ..
make -j4
```

### Linker Error: "multiple definitions of bcdec_bc1"

**Cause**: Implementation defined in both header and .c file

**Solution**: Ensure BCDEC_IMPLEMENTATION is only defined once, or bcdec.h functions are static

### Build Succeeds but No BC7 Symbols

**Cause**: image_loader.c not including bcdec.h

**Solution**:
1. Verify line ~56 in image_loader.c: `#include "bcdec.h"`
2. Rebuild with clean
3. Check nm output again

---

## Expected Build Output

### Successful CMake Configuration
```
-- Building for macOS - Using OpenGL backend
-- Found Lua: /usr/local/opt/lua/lib/liblua.a
-- Found GLFW: ...
-- Found FreeType: ...
-- Found ZSTD: ...
-- Build Configuration:
--   Platform: macOS
--   Graphics Backend: opengl
--   [all dependencies listed]
-- Configuring done
-- Generating done
```

### Successful Make Build
```
[  5%] Building C object src/simplegraphic/sg_core.c.o
...
[ 45%] Linking C library libsimplegraphic.a
...
[ 95%] Building C executable mvp_test
[100%] Linking C executable mvp_test
[100%] Built target mvp_test
Built target simplegraphic
Built target simplegraphic_shared
```

### Successful Symbol Check
```
$ nm libsimplegraphic.a | grep bcdec
0000000000000000 T _bcdec_bc1
0000000000000120 T _bcdec_bc3
0000000000000280 T _bcdec_bc7
0000000000000400 T _decode_bc7_software
```

---

## Completion Checklist

### S5: Integration
- [ ] bcdec.h created at correct path
- [ ] bcdec.h contains all three function implementations
- [ ] image_loader.c includes bcdec.h
- [ ] decode_bc7_software() function added
- [ ] GPU upload failure path modified
- [ ] Error handling and logging implemented

### S6: Verification
- [ ] Project builds without errors
- [ ] Project builds without warnings
- [ ] All symbols resolve correctly
- [ ] No undefined references
- [ ] Library contains BC7 symbols
- [ ] Header guards present and correct
- [ ] Memory allocation/deallocation paired

---

## Next Steps

After S5-S6 Completion:
1. Runtime testing with actual BC7 textures
2. Performance profiling (target <20 ms)
3. Memory usage validation
4. Integration with full PoB2 application

---

## Reference Files

- Implementation Spec: `phase13_s5_s6_bc7_implementation.md`
- Patch Details: `image_loader_bc7_patch.md`
- Creation Script: `create_bcdec.sh`
- Research: `sage_phase12_bc7_research.md`

---

## Support

If issues arise:
1. Check troubleshooting section above
2. Review modification against provided patch files
3. Consult Phase 12 BC7 research document
4. Verify file locations and permissions

**Estimated Time**: 90 minutes total (S5: 30 min, S6: 60 min)
