# Integration Testing Plan - Task #5

**Date**: 2026-01-31
**Build Status**: ✓ Complete (libSimpleGraphic.dylib updated)
**Test Status**: Ready for validation

---

## Test Objectives

### Primary Objectives
1. Verify DrawImage rendering works (was completely broken)
2. Confirm DrawString still works (was already working)
3. Ensure no regression or data corruption
4. Validate performance meets requirements

### Secondary Objectives
1. Test compatibility with full PoB2 UI
2. Performance profiling
3. Edge case handling
4. Document expected behavior vs actual

---

## Test Cases

### Test Case #1: Minimal DrawImage Test
**File**: `test_drawimage_minimal.lua`
**Purpose**: Verify basic DrawImage functionality
**Duration**: 10 seconds

#### Test Steps
1. Initialize window (800x600)
2. Set black background
3. Draw reference text
4. Render 5 rectangles using DrawImage:
   - (300, 200) size (200, 150) - WHITE
   - (50, 50) size (100, 100) - WHITE
   - (150, 400) size (150, 100) - RED
   - (650, 50) size (100, 100) - GREEN
   - (600, 400) size (150, 150) - BLUE

#### Expected Results
```
✓ Black background visible
✓ Reference text visible at top
✓ White rectangle at center
✓ White rectangle at top-left
✓ Red rectangle at bottom-left
✓ Green rectangle at top-right
✓ Blue rectangle at bottom-right
✓ No visual corruption or glitches
✓ No rendering artifacts
```

#### Failure Criteria
```
✗ No rectangles visible (DrawImage completely broken)
✗ Only some rectangles visible (selective failure)
✗ Corrupted/glitched rectangles (memory issues)
✗ Application crashes
```

#### Acceptance Criteria
Minimum 4 colored rectangles must be visible without corruption.

---

### Test Case #2: Text + Image Integration
**Purpose**: Verify DrawString and DrawImage work together
**Duration**: 5 seconds

#### Test Steps
1. Render text using DrawString
2. Render images using DrawImage
3. Mix both in same frame
4. Verify no data corruption

#### Expected Results
```
✓ Both text and images visible
✓ No character corruption
✓ No image flickering
✓ Correct layering/blending
```

---

### Test Case #3: Performance Validation
**Purpose**: Ensure fixes don't introduce significant overhead
**Metrics**: FPS, GPU/CPU timing

#### Baseline (Before Fixes)
- DrawString: Working (baseline)
- DrawImage: 0 FPS (completely broken)

#### Expected (After Fixes)
- Both: >30 FPS target
- No frame drops >20ms
- No CPU-GPU sync stalls

#### Measurement Method
```
Frame count / elapsed time >= 30 FPS
```

---

### Test Case #4: Multiple Draw Calls
**Purpose**: Stress test with many rectangles
**Duration**: 5 seconds

#### Test Steps
1. Draw 100 rectangles in grid pattern
2. Vary colors
3. Verify no corruption

#### Expected Results
```
✓ All rectangles visible
✓ Colors correct
✓ No memory corruption
✓ Performance acceptable (>20 FPS)
```

---

## Detailed Test Execution

### Phase 1: Compilation Verification (5 mins)

#### Check 1: Source Changes
```bash
# Verify struct size
echo "sizeof(TextVertex) should be 32:"
xxd simplegraphic/src/backend/metal/metal_backend.mm | grep -A 2 "typedef struct TextVertex"
```

#### Check 2: Build Output
```bash
cd simplegraphic/build && make clean && make
# Should complete without errors
```

#### Check 3: Binary Updated
```bash
ls -la runtime/SimpleGraphic.dylib
# Timestamp should be recent (after fixes)
```

---

### Phase 2: Minimal Test Execution (5 mins)

#### Command
```bash
cd /Users/kokage/national-operations/pob2macos
luajit test_drawimage_minimal.lua 2>&1 | tee test_results.log
```

#### Expected Output
```
=== DrawImage Minimal Test ===
Testing DrawImage with null handle (solid color rectangles)

1. Initializing SimpleGraphic...
   ✓ Initialized

2. Running render loop (10 seconds)...
   Expected: White rectangles on black background
   Actual: [Observing...]

   Frame 30 (3.0/10.0 sec) - Check window for rectangles
   Frame 60 (6.0/10.0 sec) - Check window for rectangles

3. Test completed
   Total frames: ~600 (at 60 FPS)
   Elapsed time: 10.0 seconds

4. Shutting down...
   ✓ Shutdown complete
```

#### Visual Verification
During execution, visually inspect window:
- [ ] Black background
- [ ] White text at top
- [ ] 5 colored rectangles
- [ ] No glitches or artifacts
- [ ] Smooth animation

---

### Phase 3: Log Analysis (3 mins)

#### Command
```bash
tail -200 /Users/kokage/Library/Logs/PathOfBuilding.log | grep -E "Metal|ERROR|WARNING"
```

#### Expected Patterns
```
Metal: Initialization complete
Metal: Using device: AMD Radeon Pro 5500M
Metal: Shaders compiled successfully
DEBUG: Metal presenting drawable #0,1,2,...
DEBUG: [Frame X] metal_draw_image #1 - ...
```

#### Red Flags
```
Metal: Failed to...
ERROR - TextVertex size is [not 32]
WARNING: metal_draw_image called but renderEncoder is NULL
```

---

### Phase 4: Integration Testing (15 mins)

#### Test 4a: PoB2 Basic UI
```bash
# Start PoB2 application
cd /Users/kokage/national-operations/pob2macos
open PathOfBuilding.app
```

**Verify**:
- [ ] Window opens
- [ ] UI text renders
- [ ] No visual glitches
- [ ] Application responds to input
- [ ] No crashes

#### Test 4b: UI Elements Rendering
**Check**:
- [ ] Buttons visible and clickable
- [ ] Lists render correctly
- [ ] Images/icons display
- [ ] Tooltips work
- [ ] Scrolling smooth

#### Test 4c: Performance Monitoring
**Metrics to track**:
- Frame time (should be <16.67ms for 60 FPS)
- No frame drops >20ms
- CPU usage reasonable
- GPU utilization reasonable

---

## Expected Outcomes

### Success Scenario
```
✓ DrawImage renders colored rectangles
✓ DrawString renders text correctly
✓ No visual corruption
✓ FPS >30 (performance acceptable)
✓ Application stable
✓ All tests pass
```

**Result**: Metal rendering bug fixed. Ready for production.

---

### Partial Success Scenario
```
✓ Some rectangles visible (maybe white only)
⚠ Colors not working properly
⚠ Some visual artifacts
? FPS unclear
```

**Result**: Partial fix. Need additional investigation.
**Action**: Check color blending, vertex attributes.

---

### Failure Scenario
```
✗ No rectangles visible
✗ Application crashes
✗ Severe visual corruption
```

**Result**: Fixes incomplete. Deeper issues remain.
**Action**: Return to debugging, check:
1. CAMetalLayer attachment
2. Render pass descriptor
3. Drawable synchronization
4. NDC coordinate calculation

---

## Troubleshooting Guide

### Issue: Black screen (no rectangles)
**Likely Causes**:
1. CAMetalLayer not attached to view
2. Render encoder not created
3. Pipeline state not set

**Debug Steps**:
```objc
// Add in metal_begin_frame():
printf("DEBUG: drawable=%p, encoder=%p\n",
       metal->currentDrawable, metal->renderEncoder);
```

### Issue: Colored text visible but no rectangles
**Likely Causes**:
1. DrawImage code path not executing
2. Texture binding issue
3. Memory barrier not working

**Debug Steps**:
```objc
// Add in metal_draw_image():
printf("DEBUG: Drawing image at (%.0f,%.0f) size (%.0f,%.0f)\n",
       left, top, width, height);
```

### Issue: Rectangles partially visible/corrupted
**Likely Causes**:
1. Vertex buffer alignment (should be fixed)
2. NDC coordinate calculation error
3. Vertex attribute offset mismatch

**Debug Steps**:
```objc
// Verify struct alignment
printf("sizeof(TextVertex)=%zu, stride=%zu\n",
       sizeof(TextVertex), sizeof(TextVertex));
```

### Issue: Performance degradation
**Likely Causes**:
1. `didModifyRange:` causing GPU stalls
2. Memory sync overhead

**Debug Steps**:
- Profile GPU vs CPU time
- Measure frame latency before/after
- Consider alternative: dedicated buffer for images

---

## Validation Checklist

### Pre-Test
- [ ] Code changes compiled without errors
- [ ] Binary updated (timestamp recent)
- [ ] Test file created and valid
- [ ] Log file accessible
- [ ] Display working

### During Test
- [ ] Window opens successfully
- [ ] Rectangles appear as expected
- [ ] No crashes or hangs
- [ ] FPS visible (if displayed)
- [ ] Text renders correctly

### Post-Test
- [ ] Logs reviewed for errors
- [ ] No crash logs generated
- [ ] Performance metrics recorded
- [ ] Screenshots taken (if needed)
- [ ] Test duration verified (10 sec)

---

## Final Verification Steps

### Step 1: Functional Test
```bash
luajit test_drawimage_minimal.lua
# Expected: Colored rectangles visible for 10 seconds
```

### Step 2: Stress Test
```lua
-- Multiple DrawImage calls in single frame
for i = 1, 100 do
    sg.DrawImage(nil, x, y, w, h, 0, 0, 1, 1)
end
```
**Expected**: All 100 rectangles rendered without corruption.

### Step 3: Integration Test
```bash
open PathOfBuilding.app
# Navigate UI, verify rendering
```
**Expected**: Full PoB2 interface renders correctly.

---

## Success Criteria Summary

| Criterion | Before Fixes | After Fixes | Status |
|-----------|--------------|-------------|--------|
| DrawString | Working | Working | ✓ No regression |
| DrawImage | Broken (0%) | Working (100%) | ✓ Fixed |
| Performance | N/A | >30 FPS | ✓ Acceptable |
| Visual Quality | N/A | No corruption | ✓ Clean |
| Stability | N/A | No crashes | ✓ Stable |

---

## Next Phase

After successful integration testing:
1. Create git commit with all fixes
2. Update documentation
3. Deploy to production
4. Monitor for issues
5. Close PRJ-003

---

## Test Result Template

```
Date: 2026-01-31
Tester: [Name]
Build: [Commit Hash]
Result: [PASS/FAIL/PARTIAL]

Test Case #1 (Minimal DrawImage):
  - Status: [PASS/FAIL]
  - Rectangles visible: [COUNT]
  - FPS: [VALUE]
  - Notes: [OBSERVATIONS]

Test Case #2 (Text + Image):
  - Status: [PASS/FAIL]
  - Notes: [OBSERVATIONS]

Test Case #3 (Performance):
  - Status: [PASS/FAIL]
  - FPS: [VALUE]
  - Frame time: [MS]

Test Case #4 (Multiple calls):
  - Status: [PASS/FAIL]
  - Notes: [OBSERVATIONS]

Overall Result: [PASS/FAIL/PARTIAL]
Issues Found: [LIST]
Recommendations: [LIST]
```

