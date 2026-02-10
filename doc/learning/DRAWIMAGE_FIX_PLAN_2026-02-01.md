# Implementation Plan: DrawImage() Rendering Failure Fix
**Date**: 2026-02-01 23:30
**Prophet**: Claude Opus 4.5
**Status**: REQUIRES_DIVINE_APPROVAL
**Project**: PRJ-003 pob2macos

---

## Executive Summary

**Problem**: DrawImage() produces NO visible output. Even with TEST 1 shader (returns pure red `float4(1,0,0,1)` unconditionally), the image rectangle is invisible. DrawString() works perfectly with the same shader, same TextVertex struct, same batch buffer, same Metal pipeline.

**Critical Insight**: Since TEST 1 shader ignores ALL inputs (texture, color, UV coordinates) and returns pure red unconditionally, the problem CANNOT be in:
- Fragment shader logic
- Texture binding/loading
- Vertex color values
- Texture coordinate calculations

The problem MUST be that **DrawImage's 6 vertices never trigger any fragment shader invocations on the GPU**. Either the vertices are never submitted, the draw call is aborted, or the triangles are degenerate/clipped.

---

## Root Cause Analysis

### Code Path Comparison: metal_draw_glyph vs metal_draw_image

Both functions follow IDENTICAL structure:
1. Check texture change -> flush if needed
2. Set currentTexture if nil
3. Calculate NDC from screen coordinates
4. Fill 6 vertices (2 triangles) in shared buffer
5. Call `didModifyRange:` on vertex buffer
6. Increment `textVertexCount += 6`

The functions share:
- Same TextVertex struct (36 bytes)
- Same vertex buffer (MTLResourceStorageModeShared)
- Same pipeline state
- Same flush logic (drawPrimitives with currentTexture)

### Key Differences Found

| Aspect | metal_draw_glyph | metal_draw_image |
|--------|-----------------|------------------|
| Texture source | Direct `void* texture` parameter | `handle->texture` or dummyWhiteTexture |
| NDC calc input | `int x, y, width, height` (integers) | `float left, top, width, height` (floats) |
| Layer index | Always 0.0f | Computed (heuristic for array textures) |
| Extra logic | None | Tiling detection, layer index heuristic |
| Debug logging | None | Extensive static counter logging |
| `didModifyRange:` | Same call | Same call |

### BUG HYPOTHESIS (PRIMARY, 70% probability)

**`didModifyRange:` on MTLResourceStorageModeShared buffer throws NSInvalidArgumentException**

Line 275: Vertex buffer created with `MTLResourceStorageModeShared`
Lines 803, 1023: Both draw functions call `didModifyRange:` on this buffer

According to Apple Metal API documentation:
> `didModifyRange:` is only valid for `MTLStorageModeManaged` resources.
> Calling it on `StorageModeShared` resources raises `NSInvalidArgumentException`.

**However**: metal_draw_glyph ALSO calls didModifyRange and works. This means either:
1. On Apple Silicon, this is silently ignored (no-op) -- BOTH work
2. The exception is thrown but caught by Objective-C runtime -- BOTH should fail

**Conclusion**: This is NOT the differentiator. But it IS a bug that should be fixed (remove the calls or switch to Managed storage).

### BUG HYPOTHESIS (SECONDARY, 25% probability): Batch Flush Timing

The execution trace from visual_test_20sec.lua:

```
1. ProcessEvents() -> begin_frame: textVertexCount=0, currentTexture=nil
2. DrawString (many glyphs) -> currentTexture = atlas, vertices accumulate
3. DrawImage -> texture change detected -> FLUSH (draws glyphs)
                 -> textVertexCount=0, currentTexture=imageTexture
                 -> 6 image vertices added, textVertexCount=6
4. DrawString (more glyphs) -> texture change detected -> FLUSH (draws image vertices)
                 -> textVertexCount=0, currentTexture=atlas
                 -> glyph vertices accumulate
5. end_frame -> FLUSH (draws remaining glyphs)
```

At step 3, the flush correctly draws the glyph batch. At step 4, the flush SHOULD draw the 6 image vertices. But what if the image texture is somehow invalid, causing the GPU to silently skip the draw?

**Key test**: If we make DrawImage use the SAME texture as glyphs (atlas), does it work? If yes, the image texture is the problem (even though shader ignores it).

### BUG HYPOTHESIS (TERTIARY, 5% probability): Static Variable Corruption

Lines 903-922 in metal_draw_image have static variables:
```cpp
static int drawImageCount = 0;
static int frameNum = 0;
static int lastLoggedFrame = -1;
```

These should not affect rendering, but their presence is unique to metal_draw_image.

---

## Implementation Plan

### Phase 1: Diagnostic Insertion (Artisan)
**Duration**: 10 minutes
**Purpose**: Insert targeted printf diagnostics to trace EXACT execution flow

**Step 1.1**: Add diagnostic at EVERY critical point in metal_draw_image:

```cpp
// At line 835, BEFORE flush decision
printf("DIAG-1: needFlush=%d, bufferFull=%d, vertexCount=%lu, currentTex=%p, newTex=%p\n",
       needFlush, bufferFull, (unsigned long)metal->textVertexCount,
       metal->currentTexture, texture);

// At line 844, INSIDE flush block (after drawPrimitives)
printf("DIAG-2: FLUSHED %lu vertices with texture %p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);

// At line 925-926, AFTER vertex buffer write
printf("DIAG-3: Added 6 vertices at idx=%lu, NDC=(%.3f,%.3f)-(%.3f,%.3f)\n",
       (unsigned long)idx, x0_ndc, y0_ndc, x1_ndc, y1_ndc);

// At line 1025, AFTER textVertexCount increment
printf("DIAG-4: textVertexCount now=%lu\n", (unsigned long)metal->textVertexCount);
```

**Step 1.2**: Add diagnostic at flush points in metal_draw_glyph and metal_end_frame:

```cpp
// In metal_draw_glyph flush (line 704)
printf("DIAG-GLYPH-FLUSH: Drawing %lu vertices with texture %p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);

// In metal_end_frame flush (line 366)
printf("DIAG-END-FLUSH: Drawing %lu vertices with texture %p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);
```

**Step 1.3**: Clean rebuild, deploy, run test, capture output

**Deliverable**: Console log showing exact execution trace for one frame

### Phase 2: Bypass Test (Artisan)
**Duration**: 10 minutes
**Purpose**: Test if DrawImage works when bypassing the batch system entirely

**Step 2.1**: Replace the entire batch logic in metal_draw_image with an IMMEDIATE draw call:

```cpp
// After filling 6 vertices (line 1016), IMMEDIATELY draw them:
// Reset vertex count first since we're doing immediate draw
metal->textVertexCount = 0;

// Write 6 vertices at offset 0
TextVertex* verts = (TextVertex*)[metal->textVertexBuffer contents];
// ... (copy the 6 vertices to offset 0) ...

[metal->renderEncoder setRenderPipelineState:metal->pipelineState];
[metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
[metal->renderEncoder setFragmentTexture:texture atIndex:0];
[metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
[metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];
printf("DIAG-IMMEDIATE: Drew 6 vertices immediately for DrawImage\n");

// DON'T increment textVertexCount (already drawn)
```

**Step 2.2**: Also remove the `didModifyRange:` call (it's wrong for Shared storage anyway)

**Step 2.3**: Build, deploy, run test

**Expected Results**:
- **If image appears**: Batch flush logic has a subtle timing/ordering bug
- **If image still invisible**: Problem is in vertex data, NDC calculation, or texture

### Phase 3: Isolation Tests (Artisan + Sage)
**Duration**: 10 minutes
**Purpose**: Isolate the exact failing component based on Phase 2 results

**If Phase 2 PASSED (image visible with immediate draw)**:
- Root cause is batch flush timing
- Fix: Ensure DrawImage vertices are always flushed before next texture change
- Could be a race condition or state corruption during flush

**If Phase 2 FAILED (image still invisible)**:
- **Test 3A**: Replace DrawImage NDC with HARDCODED values covering full screen:
  ```cpp
  float x0_ndc = -0.5f;  // Center quarter of screen
  float y0_ndc = 0.5f;
  float x1_ndc = 0.5f;
  float y1_ndc = -0.5f;
  ```
  **If visible**: NDC calculation is wrong
  **If invisible**: Problem is elsewhere

- **Test 3B**: Call metal_draw_glyph from inside metal_draw_image:
  ```cpp
  // Replace entire metal_draw_image body with:
  metal_draw_glyph(metal->dummyWhiteTexture,
                   (int)left, (int)top, (int)width, (int)height,
                   0, 0, 1, 1,
                   1.0f, 0.0f, 0.0f, 1.0f);  // Red color
  ```
  **If visible**: Something specific to metal_draw_image's code path is broken
  **If invisible**: The draw_glyph path also fails when called from draw_image context (very unlikely)

### Phase 4: Fix Implementation (Artisan)
**Duration**: 10 minutes
**Purpose**: Apply targeted fix based on Phase 2-3 results

**Fix Strategy depends on diagnosis**:

**Strategy A** (Batch timing bug):
- Make DrawImage always flush immediately after adding vertices
- Remove batching for images (images are infrequent, perf impact minimal)

**Strategy B** (didModifyRange crash):
- Remove ALL `didModifyRange:` calls for the Shared vertex buffer
- `StorageModeShared` does NOT need this call
- This fixes both draw_glyph and draw_image (even if glyph appears to work)

**Strategy C** (NDC calculation bug):
- Fix the NDC calculation for float inputs
- Verify screen_w and screen_h are correct

**Strategy D** (Texture-related):
- If image texture causes GPU error, switch to using dummyWhiteTexture
- Then investigate texture creation separately

### Phase 5: Production Shader + Visual Verification (Artisan + Paladin)
**Duration**: 5 minutes
**Purpose**: Restore correct shader and verify complete rendering

**Step 5.1**: Replace TEST 1 shader with production shader:
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));
    return texColor * in.color;
}
```

**Step 5.2**: Clean rebuild, deploy, run test
**Step 5.3**: God confirms images are visible

---

## Recommended First Action: Combined Phase 1+2

To save time, implement Phase 1 diagnostics AND Phase 2 bypass test simultaneously. The bypass test will immediately reveal whether the batch system is the problem. The diagnostics will explain WHY.

**Specific code change for Artisan**:

In `metal_draw_image`, after line 1016 (after all 6 vertices are filled), BEFORE `didModifyRange:` call, insert:

```cpp
// ===== DIAGNOSTIC BYPASS: Immediate draw instead of batching =====
// Temporarily bypass batch system to test if vertices reach GPU
{
    // Save current state
    NSUInteger saved_count = metal->textVertexCount;

    // Immediately draw the 6 vertices we just added
    [metal->renderEncoder setRenderPipelineState:metal->pipelineState];
    [metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
    [metal->renderEncoder setFragmentTexture:texture atIndex:0];
    [metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
    [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                              vertexStart:idx  // Start from where we wrote
                              vertexCount:6];
    printf("DIAG-BYPASS: Immediate draw of 6 vertices at offset %lu with texture %p\n",
           (unsigned long)idx, texture);

    // Reset state so the batch system doesn't try to draw these again
    metal->textVertexCount = saved_count;  // Don't add our 6 vertices to batch count
}
// ===== END DIAGNOSTIC BYPASS =====
```

This is the MINIMUM code change needed to test the hypothesis. If the image becomes visible with this change, the batch flush is confirmed as the root cause.

Also: Remove the three `didModifyRange:` calls (lines 803, 1023, 1161) since they are incorrect for StorageModeShared buffers.

---

## Agent Assignment

| Phase | Agent | Task | Duration |
|-------|-------|------|----------|
| 1+2 | Artisan | Insert diagnostics + bypass test | 10 min |
| 1+2 | Sage | Analyze console output | 5 min |
| 1+2 | Paladin | Visual verification with God | 2 min |
| 3 | Artisan | Isolation tests (if needed) | 10 min |
| 4 | Artisan | Apply targeted fix | 10 min |
| 5 | Artisan | Restore production shader | 5 min |
| 5 | Paladin | Final visual verification | 2 min |

**Total Estimated Time**: 30-45 minutes

---

## Critical Learning Applied

From LESSONS_LEARNED.md and CRITICAL_FAILURE_ANALYSIS.md:

1. **Visual verification MANDATORY** after each phase (Lesson #1, #3, #15)
2. **One change at a time** -- diagnostic first, then fix (Lesson #5)
3. **Clean rebuild every time** -- eliminate stale binary (Lesson #7)
4. **Time-box: 45 minutes max** -- escalate to Xcode Metal Debugger if no progress (Lesson #10)
5. **Empirical over theoretical** -- the bypass test will give immediate evidence (Lesson from Option B failure)
6. **File sync protocol** -- deploy to BOTH runtime/ and app bundle (Lesson #7)

---

## Risk Assessment

**Risk Level**: MEDIUM-LOW (systematic approach with minimal code changes)

**Success Probability**: 85%
- Phase 2 bypass test has very high probability of isolating the issue
- Even if bypass doesn't work, Phase 3 isolation tests will narrow it down
- Only risk is an unknown Metal API behavior we haven't considered

**Failure Contingency**:
- If all phases fail: Use Xcode Metal GPU Debugger for frame capture
- GPU frame capture will show EXACTLY what commands were submitted and whether vertices were processed

**Reversibility**: COMPLETE
- All changes are to metal_backend.mm
- Diagnostic code is clearly marked and easily removed
- Production shader is documented in this plan

---

## Files Affected

1. `pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
   - Lines 803, 1023, 1161: Remove `didModifyRange:` calls (wrong for Shared storage)
   - Lines 1016-1025: Insert diagnostic bypass block
   - Lines 838-849: Add diagnostic printf in flush logic
2. `pob2macos/dev/runtime/SimpleGraphic.dylib` (rebuild)
3. `pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib` (deploy)

---

## Success Criteria

**Phase 1+2 Success**: Console output shows diagnostic trace, AND image is either visible or confirmed invisible
**Phase 3 Success**: Root cause identified with evidence
**Phase 4 Success**: DrawImage renders a red rectangle (TEST 1 shader)
**Phase 5 Success**: God confirms ring.png image is visible in the test window

**Ultimate Success**: God says "I can see the ring image"

---

## Approval

**Status**: REQUIRES_DIVINE_APPROVAL

**Rationale**:
- Previous 3 attempts failed (Option A, Option B, attribute mismatch)
- However, this is the FIRST plan to use the bypass test approach (test batch system directly)
- Success probability 85% (below 90% auto-approval threshold)
- Systematic diagnostic approach with clear evidence-based progression

**Recommendation**: APPROVE -- The bypass test in Phase 2 will provide immediate, actionable evidence within 15 minutes.

---

**Plan Status**: READY FOR REVIEW
**Author**: Prophet (Claude Opus 4.5)
**Estimated Completion**: T+45 minutes from approval
