# Texture Format Fix - Execution Issue

**Date**: 2026-02-01 23:59
**Status**: BLOCKED - Critical Issue Discovered
**Reporter**: Prophet (during execution)

## Issue Summary

The approved plan (TEXTURE_FORMAT_FIX_PLAN_2026-02-01.md) assumed that "RGBA textures are backwards-compatible with R8 data." This assumption is **INCORRECT** and causes segmentation faults.

## Root Cause

**Glyph Atlas Data Structure Mismatch:**

1. **Glyph atlas generation** (sg_text.cpp):
   - Generates R8 data (1 byte per pixel)
   - Total size: 1024×1024×1 = 1,048,576 bytes

2. **Texture creation** (metal_backend.mm):
   - Creates RGBA texture (expects 4 bytes per pixel)
   - Expected size: 1024×1024×4 = 4,194,304 bytes

3. **Data upload**:
   - Metal API: `replaceRegion:withBytes:bytesPerRow:bytesPerImage:`
   - bytesPerRow = width × 4 = 4096 bytes
   - bytesPerImage = 4,194,304 bytes
   - **Actual data available: 1,048,576 bytes** → Memory access violation

## Evidence

**Crash Log:**
```
Exit code 139 (Segmentation Fault)
Metal: Creating RGBA texture 1024x1024
<crash immediately after>
```

**Crash Location:**
- metal_backend.mm line 481-486: `replaceRegion:withBytes:`
- Called when uploading glyph atlas data

## Impact on Plan

**Original Plan Assumption:**
> "Always create RGBA textures (glyph atlas will use 4x memory but function correctly)"

**Reality:**
- ❌ Glyph atlas does NOT function correctly with RGBA
- ❌ Segmentation fault on texture upload
- ❌ Cannot proceed with current approach

## Correct Solution

### Option A: Add Format Parameter (Recommended)

**Modify** `create_texture()` signature:
```cpp
void* create_texture(int width, int height, const uint8_t* data, TextureFormat format);
```

**Enum:**
```cpp
enum TextureFormat {
    TEXTURE_FORMAT_R8,    // 1 byte/pixel (glyph atlas)
    TEXTURE_FORMAT_RGBA8  // 4 bytes/pixel (images)
};
```

**Call sites:**
- `sg_image.cpp`: `create_texture(..., TEXTURE_FORMAT_RGBA8)`
- `sg_text.cpp`: `create_texture(..., TEXTURE_FORMAT_R8)`

**Impact:**
- Multi-file change (metal_backend.mm, sg_image.cpp, sg_text.cpp, simplegraphic.h)
- Requires new plan and review
- ~30 minutes implementation

### Option B: Convert Glyph Atlas to RGBA

**Modify** `sg_text.cpp` glyph atlas generation to produce RGBA data:
```cpp
for (int i = 0; i < width * height; i++) {
    rgba_data[i*4 + 0] = r8_data[i];  // R
    rgba_data[i*4 + 1] = r8_data[i];  // G
    rgba_data[i*4 + 2] = r8_data[i];  // B
    rgba_data[i*4 + 3] = 255;         // A (opaque)
}
```

**Impact:**
- Single file change (sg_text.cpp)
- Memory overhead: 1 MB → 4 MB per glyph atlas
- Performance overhead: Data conversion on every font load
- ~15 minutes implementation

## Recommendation

**Option A** is technically superior:
- Explicit format specification
- No unnecessary memory waste
- Better long-term architecture

**Option B** is faster to implement:
- Single file change
- Aligns with current plan scope
- Acceptable for prototype phase

## Next Steps

1. **Mayor**: Evaluate options and recommend course of action
2. **Prophet**: If Option A chosen, create new plan and review
3. **Artisan**: Implement chosen solution
4. **Paladin**: Visual verification after implementation

## Lessons Learned

**Incorrect Assumption:**
> "Backwards compatibility means data formats are interchangeable"

**Correct Understanding:**
> Texture format must match data layout. R8 data cannot be uploaded to RGBA texture without conversion.

**Prevention:**
- Test data upload paths before claiming compatibility
- Verify assumptions with small prototypes
- Check crash logs for memory access patterns

## Status

**Current State:**
- ✅ Code modified (metal_backend.mm)
- ✅ Library rebuilt and deployed
- ❌ Visual test crashes (segfault)
- ⏸️ Tasks 4-7 blocked pending resolution

**Awaiting:** Mayor decision on Option A vs Option B
