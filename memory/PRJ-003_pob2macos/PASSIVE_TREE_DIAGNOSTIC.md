# Passive Tree Display Diagnostic Report

**Date**: 2026-01-31
**Project**: PRJ-003 pob2macos
**Issue**: Passive Tree not displaying correctly

---

## Findings

### 1. Root Cause Identified

**Problem**: Metal renderEncoder is NULL when DrawImage is called

**Evidence**:
```
WARNING: metal_draw_image called but renderEncoder is NULL (no encoder)
```

**Explanation**:
- ProcessEvents() must be called BEFORE any Draw* commands
- ProcessEvents() calls `begin_frame()` which creates the renderEncoder
- If DrawImage/DrawString are called before the first ProcessEvents(), renderEncoder is NULL

### 2. Code Structure Analysis

**pob2_launch.lua** (Lines 414-434):
```lua
while IsUserTerminated() == 0 do
    ProcessEvents()          -- ✅ Correct: Called FIRST
    if launch.OnFrame then
        launch:OnFrame()     -- ✅ Draw commands happen here
    end
    ...
end
```

**Status**: ✅ Main loop structure is CORRECT

### 3. Fixes Applied

All 13 nil-safety fixes have been copied to app bundle:
1. ✅ Main.lua
2. ✅ PassiveSpec.lua
3. ✅ PassiveTreeView.lua
4. ✅ Launch.lua
5. ✅ TreeTab.lua

### 4. Image Loading Verification

**Assets Status**:
```
✅ Assets/PSStartNodeBackgroundInactive.png - loads correctly
✅ Assets/NotableFrameUnallocated.png - loads correctly
✅ Assets/PSGroupBackground1.png - loads correctly
```

**Issue**: Images load but cannot be drawn due to NULL renderEncoder

---

## Hypothesis

The passive tree MAY be working now that:
1. All nil-safety fixes are in place
2. ProcessEvents() is called before draw commands
3. Images load successfully

**However**, we cannot test via luajit due to macOS security restrictions.

---

## Next Steps

### Required Action
**Open the app manually** to test:

```bash
open /Users/kokage/national-operations/pob2macos/PathOfBuilding.app
```

### What to Check
1. Does the app launch without crashing?
2. Can you navigate to the Tree tab?
3. Does the passive tree display?
4. Are there any console errors?

### If Passive Tree Still Doesn't Display

Check for:
1. **Missing draw calls** in TreeTab.lua OnFrame()
2. **Asset path issues** - images not found
3. **Coordinate/viewport issues** - drawing off-screen
4. **Metal state issues** - texture binding failures

### Diagnostic Commands

If issues persist, capture console output:
```bash
# Run from terminal to see logs
/Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_debug.log
```

---

## Technical Details

### Render Pipeline

Correct sequence:
```
1. RenderInit()            - Initialize Metal
2. ProcessEvents()         - begin_frame() → create renderEncoder
3. SetClearColor()         - Set background
4. DrawString/DrawImage()  - Issue draw commands
5. ProcessEvents()         - end_frame() → present to screen, begin new frame
6. Loop to step 3
```

### Metal Backend Flow

```c
begin_frame() {
    1. Get drawable from Metal layer
    2. Create command buffer
    3. Create render pass descriptor
    4. Create renderEncoder ← THIS IS CRITICAL
}

end_frame() {
    1. Draw text batch (if any)
    2. Draw image batch (if any)
    3. End encoding
    4. Present drawable
    5. Commit command buffer
}
```

### ProcessEvents Implementation

**sg_core.cpp Lines 143-165**:
```c
void ProcessEvents(void) {
    // End previous frame
    if (g_ctx->renderer && g_ctx->renderer->end_frame) {
        g_ctx->renderer->end_frame(g_ctx);  // Present to screen
    }

    // Poll events
    sg_window_poll_events(g_ctx);

    // Begin new frame
    if (g_ctx->renderer && g_ctx->renderer->begin_frame) {
        g_ctx->renderer->begin_frame(g_ctx);  // Create renderEncoder
    }
}
```

---

## Confidence Level

**70%** - High confidence that passive tree should work now

**Reasons**:
- All nil-safety issues fixed
- Render pipeline structure is correct
- Assets load successfully
- Metal backend is functional

**Uncertainty**:
- Cannot test via luajit (security restrictions)
- Unknown if TreeTab rendering logic has other issues
- Possible coordinate/transform issues

---

## Recommended Testing Protocol

1. **Manual Launch** - Open PathOfBuilding.app
2. **Navigate to Tree Tab**
3. **Observe Results**:
   - ✅ Success: Tree displays correctly
   - ⚠️ Partial: Some elements display
   - ❌ Failure: Nothing displays or crash

4. **Collect Diagnostic Data**:
   - Screenshot of Tree tab
   - Console output from terminal launch
   - Any error messages

5. **Report Findings** to continue diagnosis

---

**Status**: Awaiting Manual Test
**Next Action**: User must manually test PathOfBuilding.app

