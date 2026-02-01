# Texture Format Fix - Implementation Plan

**Date**: 2026-02-01 23:45
**Task**: Fix ring.png not displaying due to texture format mismatch
**Prophet**: Mandatory Routine execution

## Executive Summary

**Root Cause Confirmed**: metal_create_texture cannot distinguish between R8 (glyph atlas) and RGBA (images) when both are 1024x1024.

**Impact**: ring.png loaded as RGBA but texture created as R8 → 75% data truncated → image invisible.

**Solution**: Delete heuristic lines 456-463 in metal_backend.mm, always create RGBA textures.

## Root Cause Analysis

### Data Flow

1. **sg_image.cpp line 273**: `stbi_load(filename, &width, &height, &channels, 4)` → Forces RGBA (4 bytes/pixel)
2. **sg_image.cpp line 290**: `create_texture(width, height, pixel_data)` → Passes RGBA data
3. **metal_backend.mm line 456**: Heuristic checks `if (width != 1024 || height != 1024)`
4. **metal_backend.mm line 462**: ring.png is 1024x1024 → Assumes R8 glyph atlas → **WRONG**

### Log Evidence

```
Loaded image ... 1024x1024, 2 channels (forced to RGBA)
Metal: Creating R8 texture (glyph atlas) 1024x1024  ← ERROR
```

### Data Integrity Violation

- **Expected**: R8 (1 byte/pixel), bytesPerRow = 1024
- **Actual**: RGBA (4 bytes/pixel), required bytesPerRow = 4096
- **Result**: Only 25% of each row uploaded → image corrupted

## Proposed Fix: Option A (Immediate)

**Change**: Delete lines 456-463 in metal_backend.mm

**Before**:
```cpp
if (width != 1024 || height != 1024) {
    // Likely an image, not glyph atlas
    pixelFormat = MTLPixelFormatRGBA8Unorm;
    bytesPerRow = width * 4;
    printf("Metal: Creating RGBA texture %dx%d\n", width, height);
} else {
    printf("Metal: Creating R8 texture (glyph atlas) %dx%d\n", width, height);
}
```

**After**:
```cpp
// Always create RGBA textures (glyph atlas will waste 3x memory but function correctly)
pixelFormat = MTLPixelFormatRGBA8Unorm;
bytesPerRow = width * 4;
printf("Metal: Creating RGBA texture %dx%d\n", width, height);
```

**File**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`

## Impact Assessment

### Positive
- ✅ ring.png displays correctly
- ✅ All images display correctly
- ✅ Glyph atlas still functions (RGBA is backwards-compatible with R8 data)
- ✅ Minimal code change (8 lines → 3 lines)

### Negative
- ⚠️ Glyph atlas memory usage: 1 MB → 4 MB (4x increase, acceptable for prototype)
- ⚠️ Slight performance hit for text rendering (4x data transfer, negligible on modern GPUs)

## Implementation Timeline

### Step 1: Code Modification (Artisan) - 2 minutes
- Delete lines 456-463 in metal_backend.mm
- Replace with always-RGBA logic

### Step 2: Clean Rebuild (Artisan) - 3 minutes
```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
```

### Step 3: Deploy (Artisan) - 1 minute
```bash
cp build/libSimpleGraphic.1.0.0.dylib ../runtime/SimpleGraphic.dylib
cp ../runtime/SimpleGraphic.dylib ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
shasum -a 256 build/libSimpleGraphic.1.0.0.dylib ../runtime/SimpleGraphic.dylib ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

### Step 4: **Visual Verification (Paladin + God)** - 5 minutes ⚠️ CRITICAL
```bash
cd /Users/kokage/national-operations/pob2macos/dev
luajit visual_test.lua
```

**Expected Result**:
- Blue background ✅
- White text at top ✅
- Yellow text in middle ✅
- **RED RECTANGLE** where ring image should be (TEST 1 shader outputs pure red)

**User Confirmation Required**:
- "Can you see a red rectangle on screen?"
- Take screenshot if possible

### Step 5: Revert Shader to Original (Artisan) - 2 minutes
**File**: `metal_backend.mm` line 116
**Change**:
```metal
// Before (TEST 1)
return float4(1.0, 0.0, 0.0, 1.0);

// After (texture sampling)
float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));
return in.color * texColor;
```

### Step 6: Final Visual Verification (Paladin + God) - 5 minutes ⚠️ CRITICAL
```bash
cd /Users/kokage/national-operations/pob2macos/dev
luajit visual_test.lua
```

**Expected Result**:
- Blue background ✅
- White text at top ✅
- Yellow text in middle ✅
- **RING IMAGE** visible with correct colors and transparency

**User Confirmation Required**:
- "Can you see the ring image correctly?"
- Screenshot confirmation

## Risk Assessment

### Technical Risks
- **LOW**: RGBA is backwards-compatible with R8 data (R channel used, GBA ignored)
- **LOW**: Memory increase (4 MB) is negligible on modern systems
- **LOW**: Performance hit is negligible

### Execution Risks
- **MEDIUM**: Shader revert must be done correctly
- **MITIGATION**: Clear before/after code comparison, Sage review

### Verification Risks
- **CRITICAL**: Visual verification is MANDATORY (lesson from CRITICAL_FAILURE_ANALYSIS.md)
- **MITIGATION**: User screenshot confirmation required before "success" claim

## Success Criteria

1. ✅ Code change completed and reviewed
2. ✅ Clean rebuild successful
3. ✅ Files deployed and SHA256 verified
4. ✅ **Visual verification: Red rectangle visible (TEST 1 shader)**
5. ✅ Shader reverted to original
6. ✅ **Visual verification: Ring image visible with correct colors**
7. ✅ **User confirms both visual tests**

## Deliverables

1. Modified `metal_backend.mm` (lines 456-463 deleted)
2. Rebuilt and deployed `libSimpleGraphic.dylib`
3. **Screenshot of red rectangle (TEST 1)**
4. **Screenshot of ring image (original shader)**
5. Test log showing no errors
6. **User confirmation of visual success**

## Lessons Applied

### From CRITICAL_FAILURE_ANALYSIS.md
- ✅ RULE 2: Visual verification within 15 minutes of implementation
- ✅ RULE 3: Screenshots mandatory
- ✅ RULE 4: User confirmation required before "success" claim
- ✅ RULE 5: Visual change required for success

### From LESSONS_LEARNED.md
- ✅ File synchronization protocol (SHA256 verification)
- ✅ Clean rebuild for C++ changes
- ✅ Visual-first debugging approach

## Long-term Recommendation

After visual confirmation, implement **Option B (Explicit Format Parameter)**:
1. Add `PixelFormat` enum to `simplegraphic.h`
2. Modify `create_texture()` signature to accept format
3. Update all callers (sg_text.cpp passes R8, sg_image.cpp passes RGBA)
4. Remove memory waste from glyph atlas

**Timeline**: 30 minutes
**Priority**: Medium (after prototype validation)

## Rollback Plan

If fix fails:
1. Revert metal_backend.mm to previous version (git restore)
2. Clean rebuild
3. Report failure to Prophet with detailed log analysis

## Agent Assignment

| Task | Agent | Duration | Dependency |
|------|-------|----------|------------|
| Code modification | Artisan | 2 min | None |
| Clean rebuild | Artisan | 3 min | Code modification |
| Deploy | Artisan | 1 min | Rebuild |
| Visual verification (TEST 1) | Paladin + God | 5 min | Deploy |
| Shader revert | Artisan | 2 min | Visual verification |
| Visual verification (original) | Paladin + God | 5 min | Shader revert |

**Total Time**: ~18 minutes
**Critical Path**: Code → Build → Deploy → **Visual Verification** (MANDATORY)

---

**Status**: Plan ready for Prophet review and Mayor execution
