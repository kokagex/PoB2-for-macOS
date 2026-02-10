# Implementation Plan: Metal Shader/C++ Vertex Attribute Mismatch Fix
**Date**: 2026-02-01 23:00
**Prophet**: Claude Opus 4.5
**Status**: REQUIRES_DIVINE_APPROVAL
**Project**: PRJ-003 pob2macos

---

## Executive Summary

**Problem**: DrawImage() is completely non-functional. Test 1 (pure red shader returning `float4(1,0,0,1)`) does not display a red rectangle, meaning the problem is NOT in the fragment shader logic but in the vertex pipeline or render command submission.

**Artisan's Finding (Confidence 95%)**: Shader/C++ vertex attribute mismatch:
- C++ sends 4 attributes (position, texCoord, color, layerIndex)
- Historical shader mismatch between texture2d and texture2d_array

**Prophet's Analysis**: After reading the current code, the shader and C++ vertex descriptor ARE already aligned (4 attributes, texture2d_array). However, Test 1 still fails. This means the root cause is DEEPER than the attribute mismatch -- the problem is that DrawImage vertices are never reaching the GPU or are being rendered invisibly.

---

## Current State Analysis

### What Works
- DrawString() renders text correctly (glyphs visible)
- Metal shader compiles without errors
- Render pipeline state creation succeeds
- Textures load successfully
- metal_end_frame() presents drawables

### What Fails
- DrawImage() produces NO visible output
- Even pure red shader (Test 1) shows nothing for images
- "Something flickering" in upper left corner (God's observation)

### Code Analysis

**File**: `pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`

#### Current Shader (lines 86-118)
```metal
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
    float layerIndex [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 texCoord;
    float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = float3(in.texCoord, in.layerIndex);
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    return float4(1.0, 0.0, 0.0, 1.0);  // TEST 1: Pure red
}
```

#### C++ TextVertex (lines 22-28)
```cpp
typedef struct TextVertex {
    float position[2];      // 8 bytes (offset 0)
    float texCoord[2];      // 8 bytes (offset 8)
    float color[4];         // 16 bytes (offset 16)
    float layerIndex;       // 4 bytes (offset 32)
    // Total: 36 bytes
} TextVertex;
```

#### C++ Vertex Descriptor (lines 209-237)
```cpp
// 4 attributes matching shader VertexIn
attribute[0]: Float2, offset 0   // position
attribute[1]: Float2, offset 8   // texCoord
attribute[2]: Float4, offset 16  // color
attribute[3]: Float,  offset 32  // layerIndex
layout[0].stride = 36
```

**Conclusion**: The shader and C++ vertex attributes ARE currently aligned. The mismatch has already been fixed in the source code. But the TEST 1 still fails, indicating a deeper problem.

---

## Root Cause Hypotheses (Priority Order)

### Hypothesis 1: Binary NOT Rebuilt After Code Change (Probability: 30%)
**Evidence**: Build timestamp (21:26:35) and source timestamp (21:26:27) are very close, but the shader is hardcoded as a string in C++ -- it compiles WITH the library.

**Check**: SHA256 of all three library locations match. Build appears current.

**Verdict**: UNLIKELY but should verify by doing a clean rebuild.

### Hypothesis 2: Batch Rendering Logic Bug (Probability: 35%)
**Evidence**:
- DrawString works, DrawImage does not
- Both use the same TextVertex struct and batch rendering system
- The flush mechanism in end_frame should handle remaining vertices
- BUT: If texture switching between glyph and image causes a flush that resets vertexCount, and then the image vertices are accumulated but never flushed...

**Critical Observation**: In `metal_draw_image`, the `currentTexture` is compared with the new image texture. If they differ, a flush occurs. But what if the flush command doesn't properly set up the pipeline state for the NEW texture? After flush, `metal->currentTexture = texture` is set, but the actual draw call for the image vertices only happens at the NEXT flush or at end_frame.

This is the CORRECT behavior, so this is unlikely the root cause.

### Hypothesis 3: DrawImage Never Called or Called Too Late (Probability: 15%)
**Evidence**: "Something flickering" suggests SOME rendering is occurring.

**Check**: Debug logs show DrawImage IS being called with correct parameters.

**Verdict**: DrawImage IS being called. Problem is in the rendering, not in the calling.

### Hypothesis 4: Vertex Data Corruption or Wrong NDC Coordinates (Probability: 10%)
**Evidence**:
- Position calculation uses `g_ctx->width` and `g_ctx->height`
- If these are 0 or wrong, NDC coordinates would be garbage
- Glyph rendering works with the same NDC calculation

**Check**: Debug logs show reasonable position values.

### Hypothesis 5: The "Flickering" IS the Image, But It's Cleared Immediately (Probability: 10%)
**Evidence**: God saw "something flickering in upper left"
- This could be the image being drawn in one frame and cleared in the next
- If ProcessEvents() calls begin_frame() which clears the screen, and the draw order is wrong...

**Critical**: The main loop calls ProcessEvents() first, then draws. If an extra ProcessEvents() call happens, the screen gets cleared between draw and present.

---

## Implementation Plan

### Phase 1: Clean Rebuild and Verify (Artisan + Sage)
**Duration**: 10 minutes
**Purpose**: Eliminate Hypothesis 1 completely

**Steps**:
1. Clean rebuild of SimpleGraphic library
2. Deploy to runtime AND app bundle
3. Verify SHA256 match across all locations
4. Run the app with Test 1 shader

**Artisan Tasks**:
```bash
# Clean rebuild
cd pob2macos/dev/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build

# Deploy
cp build/libSimpleGraphic.1.0.0.dylib ../runtime/SimpleGraphic.dylib
cp ../runtime/SimpleGraphic.dylib \
   ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# Verify
shasum -a 256 build/libSimpleGraphic.1.0.0.dylib ../runtime/SimpleGraphic.dylib \
   ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

**Sage Task**: Verify the build output timestamp is current.

### Phase 2: Diagnostic Shader Tests (Sage + Artisan)
**Duration**: 15 minutes
**Purpose**: Isolate which component is failing

**Test 2A**: Replace shader with SOLID GREEN for ALL fragments:
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    return float4(0.0, 1.0, 0.0, 1.0);  // Pure green
}
```
**Expected**: EVERYTHING (text AND images) should be green rectangles
**If text is green but images are not**: Vertex data for images is not reaching the shader

**Test 2B**: Add debug logging to metal_draw_image to confirm vertices are in buffer:
```cpp
// After adding vertices, log
printf("DEBUG: metal_draw_image added 6 vertices at idx=%lu, total=%lu, texture=%p, currentTexture=%p\n",
       (unsigned long)idx, (unsigned long)metal->textVertexCount, texture, metal->currentTexture);
```

**Test 2C**: Force immediate flush after every draw call (bypass batching):
```cpp
// At end of metal_draw_image, FORCE flush
if (metal->textVertexCount > 0 && metal->currentTexture) {
    [metal->renderEncoder setRenderPipelineState:metal->pipelineState];
    [metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
    [metal->renderEncoder setFragmentTexture:metal->currentTexture atIndex:0];
    [metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
    [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:0
                              vertexCount:metal->textVertexCount];
    metal->textVertexCount = 0;
}
```

**If Test 2C makes images visible**: The batching/flush logic is the root cause.

### Phase 3: Fix Implementation (Artisan)
**Duration**: 10 minutes
**Purpose**: Apply the targeted fix based on Phase 2 results

**Scenario A**: If batching is the issue
- Fix the flush logic in metal_draw_image
- Ensure proper flush before texture changes
- Potentially flush after every draw call (simpler, less performant but correct)

**Scenario B**: If vertex data is the issue
- Verify NDC coordinate calculation
- Check if drawWidth/drawHeight are 0
- Check if vertex buffer is properly sized

**Scenario C**: If the shader is correct and vertices reach GPU but are invisible
- Check blend mode (alpha blending might make pure red transparent)
- Check depth testing
- Check scissor rect

### Phase 4: Restore Production Shader (Artisan)
**Duration**: 5 minutes
**Purpose**: Replace Test 1 shader with correct production shader

```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));
    return texColor * in.color;
}
```

### Phase 5: Visual Verification (Paladin)
**Duration**: 5 minutes
**Purpose**: God confirms images are visible

**Success Criteria**:
- God confirms: "I can see colored rectangles/images"
- Both DrawString AND DrawImage produce visible output
- No flickering or artifacts

---

## Agent Assignment

| Phase | Agent | Task | Duration |
|-------|-------|------|----------|
| 1 | Artisan | Clean rebuild, deploy, verify | 10 min |
| 1 | Sage | Verify build timestamp | 2 min |
| 2 | Artisan | Implement diagnostic shaders | 10 min |
| 2 | Sage | Analyze test results | 5 min |
| 3 | Artisan | Apply targeted fix | 10 min |
| 4 | Artisan | Restore production shader | 5 min |
| 5 | Paladin | Visual verification | 5 min |

**Note**: Artisan is the primary executor. Sage assists with analysis. This task is Artisan-heavy, so Sage MUST help by analyzing results in parallel while Artisan implements the next test.

**Total Estimated Time**: 35-45 minutes

---

## Critical Learning Applied

From LESSONS_LEARNED.md and CRITICAL_FAILURE_ANALYSIS.md:

1. **Visual verification MANDATORY** after each phase
2. **No assumptions** -- test empirically
3. **One change at a time** -- test between changes
4. **Clean rebuild** to eliminate stale binary issues
5. **Time-box**: If no progress in 45 minutes, escalate to completely different approach

---

## Risk Assessment

**Risk Level**: MEDIUM (requires systematic debugging, root cause not yet confirmed)

**Mitigation**:
- Systematic Test 2A/2B/2C will isolate the exact failing component
- Each test is reversible (just change shader string)
- No data loss risk (all changes to C++ shader string)

**Success Probability**: 80% (conservative -- systematic approach should identify root cause)

**Failure Contingency**: If all Phase 2 tests pass but images still invisible, escalate to GPU frame capture using Metal Debugger (Xcode Instruments).

---

## Files Affected

1. `pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
   - Shader string modification (lines 86-118)
   - Potentially flush logic modification
2. `pob2macos/dev/runtime/SimpleGraphic.dylib` (rebuild)
3. `pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib` (deploy)

---

## Approval

**Status**: REQUIRES_DIVINE_APPROVAL

**Rationale**:
- Success probability is 80% (below 90% threshold for auto-approval)
- Previous attempts to fix this issue have failed twice
- Systematic debugging approach is correct but outcome is uncertain
- God's visual confirmation needed at each phase

**Recommendation**: APPROVE -- This systematic approach is the most efficient path to identifying and fixing the root cause. The alternative (guessing) has already failed twice.

---

**Plan Status**: READY FOR REVIEW
**Author**: Prophet (Claude Opus 4.5)
**Estimated Completion**: T+45 minutes from approval
