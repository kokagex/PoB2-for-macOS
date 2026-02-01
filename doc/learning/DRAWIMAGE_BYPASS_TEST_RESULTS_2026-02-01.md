# DrawImage() Batch Bypass Test - Results

**Date**: 2026-02-01 23:05
**Test**: Diagnostic batch bypass for DrawImage() rendering issue

## Test Implementation

### Changes Made

1. **Added diagnostic printf statements** (4 locations):
   - Line 713: DIAG-GLYPH-FLUSH (after glyph batch flush)
   - Line 849: DIAG-IMAGE-FLUSH (after image batch flush)
   - Line 376: DIAG-END-FRAME-FLUSH (after end_frame flush)
   - Line 1030: DIAG-IMG-ADD (after image vertices written)

2. **Removed incorrect didModifyRange calls** (3 locations):
   - Lines 801-803 (metal_draw_glyph)
   - Lines 1024-1028 (metal_draw_image)
   - Lines 1159-1161 (metal_draw_quad)
   - **Reason**: didModifyRange is only valid for MTLStorageModeManaged, but buffer uses MTLResourceStorageModeShared

3. **Inserted batch bypass immediate draw** (after line 1033):
   ```cpp
   // ===== DIAGNOSTIC BYPASS =====
   {
       [metal->renderEncoder setRenderPipelineState:metal->pipelineState];
       [metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
       [metal->renderEncoder setFragmentTexture:texture atIndex:0];
       [metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
       [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                                 vertexStart:idx
                                 vertexCount:6];
       printf("DIAG-BYPASS: Immediate draw of 6 vertices at idx=%lu with tex=%p\n",
              (unsigned long)idx, texture);
   }
   // ===== END DIAGNOSTIC BYPASS =====
   ```

### Build and Deployment

```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
# Build succeeded with warnings (ARC bridge casts, unused variables)

# Deployment
cp build/libSimpleGraphic.1.0.0.dylib ../runtime/SimpleGraphic.dylib
cp ../runtime/SimpleGraphic.dylib /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# SHA256 verification - ALL MATCH
# 4ad39afd98922d98d8b99782a26048bc913839aec0800827f86df00ee40876bf
```

## Diagnostic Output Analysis

### Key Findings

**Frame Structure** (repeating pattern):
```
DIAG-GLYPH-FLUSH: Flushed 198 glyph vertices with tex=0x7fc2e300add0
DIAG-GLYPH-FLUSH: Flushed 288 glyph vertices with tex=0x7fc2e3407d30
DIAG-GLYPH-FLUSH: Flushed 42 glyph vertices with tex=0x7fc2e3011770
DIAG-IMAGE-FLUSH: Flushed 126 image vertices with tex=0x7fc2e3407d30
DIAG-IMG-ADD: Added 6 vertices at idx=0, NDC=[(-0.888,0.753) to (-0.746,0.500)], tex=0x7fc2e3008e80
DIAG-BYPASS: Immediate draw of 6 vertices at idx=0 with tex=0x7fc2e3008e80
DIAG-GLYPH-FLUSH: Flushed 6 glyph vertices with tex=0x7fc2e3008e80  <-- ANOMALY
DIAG-END-FRAME-FLUSH: Flushed 180 vertices with tex=0x7fc2e3407d30
```

### Critical Observations

1. ✅ **Image vertices are written correctly**
   - NDC coordinates: (-0.888, 0.753) to (-0.746, 0.500)
   - Valid range [-1, 1]
   - Texture pointer: 0x7fc2e3008e80 (valid)

2. ✅ **Bypass draw executes**
   - Immediate draw called after vertices written
   - Uses correct vertex start index (idx=0)
   - Uses correct vertex count (6)

3. ❌ **ANOMALY: Unexpected DIAG-GLYPH-FLUSH after bypass**
   - After DIAG-BYPASS, there's a glyph flush with the SAME texture (0x7fc2e3008e80)
   - This suggests the bypass draw is triggering a flush
   - The flush reports 6 vertices (the ones we just drew)

4. ⚠️ **Texture change triggers flush**
   - DIAG-IMAGE-FLUSH shows 126 vertices flushed before the ring image
   - This is expected behavior (texture change from glyph to image atlas)

### Hypothesis Update

**Original hypothesis**: Batch flush system is broken, vertices are written but never drawn.

**New hypothesis based on diagnostics**:
- Vertices ARE being flushed (DIAG-GLYPH-FLUSH with image texture proves this)
- The bypass is causing a texture switch that triggers the flush
- The issue might be:
  1. **Texture binding confusion**: Ring texture (0x7fc2e3008e80) is being flushed via glyph path
  2. **Render pipeline state**: Wrong pipeline state when drawing images
  3. **Fragment shader output**: TEST 1 shader should output pure red, but might not be executing

## CRITICAL QUESTION FOR VISUAL VERIFICATION

**User/Paladin must answer**:

When running `luajit visual_test.lua`, what do you see on screen?

### Expected with TEST 1 shader (if bypass works):
- Blue background ✅
- White text at top ✅
- Yellow text in middle ✅
- **RED RECTANGLE** where ring image should be (pure red from fragment shader)

### If no red rectangle visible:
- Bypass did NOT solve the issue
- Problem is NOT in batch flush system
- Must investigate: pipeline state, shader execution, or vertex data corruption

### If red rectangle IS visible:
- ✅ Bypass confirmed batch flush as root cause
- Fix: Make DrawImage flush immediately (disable batching for images)
- Revert to original shader and verify actual image rendering

## Next Steps

### If Bypass Shows Red Rectangle (SUCCESS)
1. Remove bypass code
2. Modify DrawImage to flush immediately after adding vertices
3. Revert shader to original (texture sampling)
4. Verify ring image displays correctly

### If Bypass Shows NO Red Rectangle (FAILURE)
1. Escalate to Phase 3 isolation tests:
   - Test A: Hardcode NDC coordinates [-0.5, -0.5, 0.5, 0.5]
   - Test B: Use glyph code path for image (prove pipeline works)
   - Test C: Check if fragment shader is even executing

## Files Modified

- `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
  - Lines modified: 376, 713, 801-803, 849, 1024-1028, 1030-1047, 1159-1161

## Deployment Status

✅ Build succeeded
✅ SHA256 verification passed
✅ Diagnostic output captured
⏳ **AWAITING VISUAL VERIFICATION FROM USER**

---

**Action Required**: User must report whether red rectangle is visible on screen.
