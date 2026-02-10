# Texture Format Bug Analysis - Ring Image Not Displaying

**Date**: 2026-02-01 23:30
**Root Cause**: metal_create_texture cannot distinguish between R8 and RGBA formats

## Problem Summary

DrawImage() does not display ring.png due to **texture format mismatch**:
- Image data: RGBA (4 bytes/pixel)
- Texture created: R8 (1 byte/pixel)
- Result: 75% of image data is truncated, causing corrupted/invisible rendering

## Data Flow Analysis

### 1. Image Loading (sg_image.cpp)
```cpp
Line 273: unsigned char* pixel_data = stbi_load(filename, &width, &height, &channels, 4);
// ring.png: 1024x1024, 2 channels → forced to RGBA
// Data size: 1024 * 1024 * 4 = 4,194,304 bytes

Line 290: img->texture = g_ctx->renderer->create_texture(width, height, pixel_data);
// Passes RGBA data to Metal backend
```

### 2. Glyph Atlas Creation (sg_text.cpp)
```cpp
Line 16-17: #define ATLAS_WIDTH 1024
            #define ATLAS_HEIGHT 1024

Line 127: atlas->buffer = (unsigned char*)calloc(ATLAS_WIDTH * ATLAS_HEIGHT, 1);
// R8 format: 1 byte/pixel
// Data size: 1024 * 1024 * 1 = 1,048,576 bytes

Line 135: atlas->texture = ctx->renderer->create_texture(ATLAS_WIDTH, ATLAS_HEIGHT, atlas->buffer);
// Passes R8 data to Metal backend
```

### 3. Metal Texture Creation (metal_backend.mm)
```cpp
Line 456-463: Heuristic to detect format
if (width != 1024 || height != 1024) {
    // RGBA texture
    pixelFormat = MTLPixelFormatRGBA8Unorm;
    bytesPerRow = width * 4;
} else {
    // R8 texture (assumes glyph atlas)
    pixelFormat = MTLPixelFormatR8Unorm;
    bytesPerRow = width;  // ← WRONG for ring.png!
}
```

**Problem**: Both glyph atlas and ring.png are 1024x1024, so the heuristic fails!

## Error Evidence from Logs

```
Loading image: ../PathOfBuilding.app/Contents/Resources/pob2macos/src/Assets/ring.png
Loaded image ... 1024x1024, 2 channels (forced to RGBA)
Metal: Creating R8 texture (glyph atlas) 1024x1024  ← WRONG FORMAT!
Created Metal texture for ... ring.png: 0x7fc2e3008e80
```

## Data Integrity Violation

**Expected** (R8 format):
- Pixel format: R8 (1 byte/pixel)
- bytesPerRow: 1024
- bytesPerImage: 1024 * 1024 = 1,048,576 bytes

**Actual** (ring.png RGBA data):
- Data format: RGBA (4 bytes/pixel)
- Required bytesPerRow: 1024 * 4 = 4096
- Data size: 1024 * 1024 * 4 = 4,194,304 bytes

**Result**:
- Only 25% of each row is uploaded correctly
- 75% of pixel data is truncated
- Image rendering is corrupted/invisible

## Why Batch Bypass Test Failed

The batch bypass test (immediate draw after vertex write) also failed because:
1. Vertices were written correctly (NDC coordinates valid)
2. Draw call executed correctly
3. **But texture data was corrupted from the start**

The fragment shader tries to sample a corrupted texture:
- TEST 1 shader (pure red): Should ignore texture, but Metal may still validate texture format
- Original shader (texture sampling): Samples corrupted R8 texture with wrong coordinates

## Solution Options

### Option A: Always Create RGBA Textures (Simplest)
**Change**: Remove heuristic in metal_backend.mm lines 456-463
**Result**: All textures created as RGBA
**Pros**:
- Minimal code change (delete 8 lines)
- Guaranteed to work for all images
**Cons**:
- Glyph atlas wastes 3x memory (4 MB → 16 MB per atlas)
- Slightly slower glyph rendering (4x data transfer)

### Option B: Explicit Format Parameter (Proper Solution)
**Change**: Add format parameter to create_texture()
**Signature**: `void* create_texture(int width, int height, const void* data, PixelFormat format)`
**Pros**:
- Precise control over format
- No memory waste
**Cons**:
- Requires changes to:
  - sg_renderer.h (interface)
  - metal_backend.mm (implementation)
  - sg_text.cpp (pass R8)
  - sg_image.cpp (pass RGBA)

### Option C: Separate Function for Glyph Atlas
**Change**: Create `create_glyph_texture()` for R8 textures
**Signature**: `void* create_glyph_texture(int width, int height, const void* data)`
**Pros**:
- Clear separation of concerns
- No ambiguity
**Cons**:
- New function in renderer interface
- Changes to sg_text.cpp

## Recommended Fix: Option A (Immediate), then Option B (Long-term)

### Immediate Fix (5 minutes)
Delete lines 456-463 in metal_backend.mm to always create RGBA textures.

**Impact**:
- ✅ ring.png displays correctly
- ✅ Other images display correctly
- ⚠️ Glyph atlas uses 4x memory (acceptable for prototype)
- ⚠️ Slight performance hit for text rendering

### Long-term Fix (30 minutes)
Implement Option B (explicit format parameter) for production code.

## Files to Modify

### Immediate Fix
1. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
   - Delete lines 456-463 (heuristic)
   - Always use `MTLPixelFormatRGBA8Unorm` and `bytesPerRow = width * 4`

### Long-term Fix
1. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/include/simplegraphic.h`
   - Add pixel format enum
2. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/rendering/sg_renderer.cpp`
   - Update create_texture signature
3. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
   - Accept format parameter
4. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/rendering/sg_text.cpp`
   - Pass R8 format
5. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/rendering/sg_image.cpp`
   - Pass RGBA format

## Verification Steps

After immediate fix:
1. Clean rebuild and deploy
2. Run `luajit visual_test.lua`
3. **Expected**: Red rectangle visible (TEST 1 shader)
4. Revert shader to original (texture sampling)
5. **Expected**: Ring image visible with correct colors

## Conclusion

The batch bypass test was **not the root cause**. The real issue was:
1. ❌ Texture format mismatch (RGBA data → R8 texture)
2. ❌ Data integrity violation (4x data size mismatch)
3. ✅ Vertex data was correct
4. ✅ Draw calls were correct
5. ✅ Flush system was working

**Next Action**: Apply immediate fix (Option A) and verify.
