# Mayor's Implementation Plan: DrawImage() Batch Bypass Diagnostic
**Date**: 2026-02-01 23:55
**Author**: Mayor
**Status**: AWAITING_PROPHET_REVIEW
**Project**: PRJ-003 pob2macos

---

## Oracle Received from Prophet

**Problem**: DrawImage() produces NO visible output even with TEST 1 shader (pure red float4(1,0,0,1)).
DrawString() works perfectly. The problem is in the vertex pipeline or batch system, NOT the fragment shader.

**Mandate**: Execute batch bypass diagnostic test to identify root cause.

---

## Source Code Analysis (Mayor's Assessment)

After reading `metal_backend.mm` (1191 lines), I identified the following critical observations:

### Observation 1: `didModifyRange:` on StorageModeShared (BUG)

**Lines 803, 1023, 1161**: All three draw functions call `didModifyRange:` on the vertex buffer.
**Line 275**: Buffer created with `MTLResourceStorageModeShared`.

According to Apple Metal documentation, `didModifyRange:` is ONLY valid for `MTLStorageModeManaged` resources. Calling it on `StorageModeShared` is either a no-op or throws `NSInvalidArgumentException`.

**Both** `metal_draw_glyph` (line 803) AND `metal_draw_image` (line 1023) call this. Since glyph works, this is likely a no-op on Apple Silicon. However, it is still a bug to fix.

### Observation 2: Batch Flush Logic is Identical

Both `metal_draw_glyph` and `metal_draw_image` use the EXACT same flush pattern:
1. Check if texture changed or buffer full
2. If yes: flush current batch, reset count, set new texture
3. If no currentTexture: set it
4. Write 6 vertices
5. didModifyRange
6. Increment textVertexCount

The flush logic itself is identical. The only differences are:
- NDC calculation: int vs float inputs (but same formula)
- Texture source: direct pointer vs handle->texture
- Layer index: always 0 vs computed heuristic
- Tiling detection in draw_image

### Observation 3: The "Flickering" Clue

God saw "something flickering in upper left" -- this suggests vertices ARE being drawn for at least one frame, then cleared. This could mean:
- Image is drawn but immediately overwritten
- Image vertices accumulate in batch but are flushed with WRONG texture
- Texture is invalid causing GPU to silently skip

### KEY INSIGHT: Batch Flush Execution Order

When the test script calls:
```
1. DrawString("text1") -> glyph atlas texture set, vertices accumulate
2. DrawImage(ring.png)  -> texture change! -> FLUSH glyphs -> set image texture -> 6 image vertices added
3. DrawString("text2") -> texture change! -> FLUSH image vertices -> set atlas -> glyph vertices accumulate
4. end_frame            -> FLUSH remaining glyphs
```

At step 3, the flush SHOULD draw the 6 image vertices. But: what if the image texture was never properly set as `currentTexture`? Let me trace the code:

Line 835: `needFlush = (metal->currentTexture && metal->currentTexture != texture)`
- currentTexture = atlas (from glyphs), texture = image -> needFlush = true

Line 838-850: Flush happens, textVertexCount = 0, currentTexture = texture (image)

Line 853-855: currentTexture is now image (not nil), so skip

Lines 957-1016: 6 image vertices written at idx=0 (since count was reset)

Line 1025: textVertexCount = 6

Then at step 3 (next DrawString):
Line 700: needFlush = (currentTexture=image != atlas) -> true
Lines 704-714: FLUSH with textVertexCount=6, currentTexture=image

**This should work correctly.** The flush at step 3 draws 6 image vertices with the image texture.

**BUT**: What if the flush is happening BEFORE the 6 image vertices are written? If textVertexCount is still 0 when the flush happens...

Wait - the textVertexCount IS 0 at line 848 after the flush. Then 6 vertices are added at lines 957-1016. Then textVertexCount becomes 6 at line 1025. This is correct.

**New Insight**: The bypass test will definitively prove or disprove the batch hypothesis by drawing vertices IMMEDIATELY, completely bypassing the batch system.

---

## Task Breakdown (Minimal Units)

### Task A: Insert diagnostic printf at flush points (Artisan)
**Duration**: 3 minutes
**File**: `metal_backend.mm`
**Changes**:

1. After line 846 (draw_image flush), add:
```cpp
printf("DIAG-IMG-FLUSH: Flushed %lu image/glyph vertices with tex=%p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);
```

2. After line 711 (draw_glyph flush), add:
```cpp
printf("DIAG-GLY-FLUSH: Flushed %lu glyph vertices with tex=%p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);
```

3. After line 373 (end_frame flush), add:
```cpp
printf("DIAG-END-FLUSH: Flushed %lu remaining vertices with tex=%p\n",
       (unsigned long)metal->textVertexCount, metal->currentTexture);
```

4. After line 1025 (draw_image vertex count increment), add:
```cpp
printf("DIAG-IMG-ADD: Added 6 vertices at idx=%lu, NDC=(%.3f,%.3f)-(%.3f,%.3f), tex=%p\n",
       (unsigned long)idx, x0_ndc, y0_ndc, x1_ndc, y1_ndc, texture);
```

**Success Criteria**: Console output shows exact execution trace with vertex counts and texture pointers.

### Task B: Remove didModifyRange calls (Artisan)
**Duration**: 2 minutes
**File**: `metal_backend.mm`
**Changes**: Comment out lines 801-803, 1018-1023, 1157-1161

These are incorrect for `MTLResourceStorageModeShared`. On Apple Silicon with unified memory, `StorageModeShared` does not need manual synchronization.

**Success Criteria**: No NSInvalidArgumentException thrown (may have been silently caught).

### Task C: Insert batch bypass immediate draw (Artisan)
**Duration**: 5 minutes
**File**: `metal_backend.mm`
**Location**: After line 1025 (after `metal->textVertexCount += 6;`)

**Insert this code**:
```cpp
// ===== DIAGNOSTIC BYPASS: Draw image vertices immediately =====
// This bypasses the batch system entirely to test if vertices reach the GPU
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

    // Don't reset textVertexCount - let the batch system also try to draw these
    // This means they'll be drawn TWICE if the batch system works.
    // If we only see them from the bypass, the batch system is broken.
}
// ===== END DIAGNOSTIC BYPASS =====
```

**Why vertexStart=idx**: The 6 image vertices were written at position `idx` through `idx+5`. Metal's `drawPrimitives:vertexStart:` refers to vertex index (not byte offset), so starting at `idx` and drawing 6 is correct.

**Success Criteria**: Red rectangle visible for DrawImage calls.

### Task D: Clean rebuild and deploy (Artisan)
**Duration**: 5 minutes
**Commands**:
```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build

# Deploy
cp build/libSimpleGraphic.dylib ../runtime/SimpleGraphic.dylib
cp ../runtime/SimpleGraphic.dylib ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# Verify
ls -lh build/libSimpleGraphic.dylib ../runtime/SimpleGraphic.dylib ../PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

**Note**: The actual library name may be `libSimpleGraphic.1.0.0.dylib` or `libSimpleGraphic.dylib`. Artisan must check the actual output name.

**Success Criteria**: SHA256 matches across all three locations.

### Task E: Visual verification (Paladin + God)
**Duration**: 5 minutes
**Test**: Launch application and observe DrawImage output
```bash
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee /tmp/pob_diag.log
```

**Visual Check**:
- Is a red rectangle visible where DrawImage was called? (TEST 1 shader = pure red)
- Is text still visible? (DrawString should still work)

**Console Check** (Sage):
- Do DIAG-IMG-ADD lines appear? (vertices being written)
- Do DIAG-BYPASS lines appear? (immediate draw happening)
- Do DIAG-IMG-FLUSH / DIAG-GLY-FLUSH / DIAG-END-FLUSH appear? (batch system working)
- What are the NDC coordinates? (should be within [-1, 1])
- What texture pointers are used?

**Success Criteria**: Red rectangle visible AND console shows complete diagnostic trace.

### Task F: Analyze results and determine fix (Sage)
**Duration**: 5 minutes

**If bypass makes image visible**:
- Root cause CONFIRMED: batch flush system has a bug
- Fix: Make DrawImage always flush immediately (remove batching for images)
- Images are infrequent, performance impact is negligible

**If bypass does NOT make image visible**:
- Batch system is NOT the problem
- Need Phase 3 isolation tests (hardcoded NDC, use glyph path from draw_image)
- Escalate to Mayor for revised plan

---

## Execution Order

```
Task A + B + C: Sequential (same file, must be coordinated) -> Artisan
Task D: Sequential after A+B+C -> Artisan
Task E: Sequential after D -> Paladin + God
Task F: Parallel with E (analyze console while Paladin checks visuals) -> Sage
```

**Since all implementation tasks go to one agent (Artisan), Sage should assist by reviewing the code changes BEFORE the build.**

---

## Agent Assignment

| Task | Agent | Duration | Dependency |
|------|-------|----------|------------|
| A (diagnostics) | Artisan | 3 min | None |
| B (didModifyRange) | Artisan | 2 min | None |
| C (bypass) | Artisan | 5 min | None |
| A+B+C review | Sage | 3 min | After A+B+C |
| D (build+deploy) | Artisan | 5 min | After review |
| E (visual test) | Paladin + God | 5 min | After D |
| F (analysis) | Sage | 5 min | After E |

**Total**: ~28 minutes

**Note**: Per mandate, since Artisan is the sole implementer, Sage assists by reviewing code changes before build (Task A+B+C review).

---

## Risk Assessment

| Criterion | Assessment |
|-----------|-----------|
| Technical Correctness | CONDITIONAL - bypass test is sound, but root cause unconfirmed |
| Implementation Safety | PASS - all changes are additive printf + 1 immediate draw call |
| Risk Mitigation | PASS - Git managed, easily reversible |
| Success Probability | 85% (bypass test identifies issue) |
| Impact Scope | PASS - 1 file (metal_backend.mm) |
| Reversibility | PASS - remove diagnostic code |

**Overall**: REQUIRES_DIVINE_APPROVAL (success probability 85% < 90% threshold)

---

## Files Affected

1. `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`
   - Lines 711: Add DIAG-GLY-FLUSH printf
   - Lines 803: Comment out didModifyRange
   - Lines 846: Add DIAG-IMG-FLUSH printf
   - Lines 373: Add DIAG-END-FLUSH printf
   - Lines 1023: Comment out didModifyRange
   - Lines 1025: Add DIAG-IMG-ADD printf + bypass immediate draw
   - Lines 1161: Comment out didModifyRange

2. Build output: `libSimpleGraphic.dylib`
3. Runtime: `runtime/SimpleGraphic.dylib`
4. App bundle: `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib`

---

## Recommendation to Prophet

**Status**: REQUIRES_DIVINE_APPROVAL

This plan is the most promising approach yet. The bypass test has never been tried and will provide immediate, actionable evidence. If the image becomes visible with the bypass, we know the batch flush is the root cause and the fix is straightforward.

I recommend presenting this to God for approval.

---

**Plan Status**: READY FOR PROPHET REVIEW
**Author**: Mayor
**Estimated Completion**: T+28 minutes from approval
