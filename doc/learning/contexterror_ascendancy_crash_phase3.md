# Context Error: Ascendancy Click Crash - Phase 3
**Date**: 2026-02-05
**Status**: CRASH CONTINUES AFTER ALL METHODS COMPLETE

## Current Error Context

### Log Evidence
```
[2026-02-05 00:34:23] DEBUG: Cross-class switch fully completed
[LOG ENDS - NO FURTHER OUTPUT]
```

**Critical Finding**: ALL methods complete successfully (SelectClass, SelectAscendClass, allocateClickedAscendancy, AddUndoState, SetWindowTitleWithBuildClass), but crash occurs AFTER return from click handler, BEFORE next OnFrame.

### Previous Fix Attempts

#### Attempt 1: pcall Error Wrapping
**Action**: Added pcall around SelectAscendClass, allocateClickedAscendancy, AddUndoState, SetWindowTitleWithBuildClass
**Result**: Identified crash in SelectAscendClass → BuildAllDependsAndPaths → modList nil access

#### Attempt 2: modList Guard (Option A)
**Action**: Added `if node.modList and node.modList:HasMod()` guard at line 1243
**Result**: SelectAscendClass now completes, but crash moved to AFTER all methods complete

### Current Crash Location

**Narrowed Down To**:
1. After "Cross-class switch fully completed" logs
2. Before next "OnFrame starting" can be logged
3. Somewhere in the return path from click handler OR in native code

**Possible Crash Points**:
1. **Return from click handler** - Some code after the treeClick processing block
2. **PassiveTreeView.lua Draw() method** - After processing all input events
3. **Native C++ side** - ProcessEvents(), rendering pipeline
4. **Next frame's Draw call** - State corruption causing crash on next render

## Root Cause Hypothesis

### Hypothesis 1: Click Handler Return Path (HIGH PROBABILITY)
**Suspected Issue**: Code after the cross-class switch block (lines 520+) might be trying to access changed state

**Evidence**:
- All methods within the click handler complete successfully
- Log ends immediately after "fully completed" message
- No frame rendering happens after

**Code Location**: PassiveTreeView.lua, after line 527 (end of cross-class switch block)

### Hypothesis 2: State Corruption for Next Frame (MEDIUM PROBABILITY)
**Suspected Issue**: SelectClass/SelectAscendClass changes spec.nodes or spec.allocNodes in a way that breaks the next Draw call

**Evidence**:
- Class switch modifies fundamental tree structure
- spec.nodes might have references to old class's nodes
- Next Draw iteration over spec.nodes might hit invalid state

**Code Location**: Next frame's hover detection or node rendering loop

### Hypothesis 3: Native Crash (LOW PROBABILITY)
**Suspected Issue**: Crash in C++ ProcessEvents() or rendering code

**Evidence**:
- No Lua error captured
- Sudden stop without any error message
- Could be native code issue

**Unlikely because**: Lua logging works up until the very end of click handler

## Work History Analysis

### Previous Successful Fixes
1. IsKeyDown() truthiness bug → Added `== 1` comparisons
2. Missing popups/calcsTab/itemsTab stubs → Added stubs to Launch.lua
3. colorCodes scope issue → Moved to global scope
4. modList nil in BuildAllDependsAndPaths → Added existence check

### Pattern Recognition
- Each crash has been Lua-side, not native
- Each crash has been due to missing stubs or nil access in MINIMAL mode
- Each crash has been capturable by DEBUG logging

### Current Pattern Break
- **This crash is NOT captured by logging**
- **Happens AFTER all Lua code completes**
- **No error message at all**

This suggests either:
1. Crash is in code we haven't logged yet (after click handler return)
2. Crash is in native code (C++/Objective-C)
3. Application is being terminated externally (signal, exception)

## Fix Candidates

### Option A: Add Extensive Post-Click Logging (DIAGNOSTIC)
**Approach**: Add DEBUG logs at EVERY possible return point after the click handler

**Locations**:
1. Right after the cross-class switch if-else block ends
2. Right after the treeClick processing if-block ends
3. At the very end of the input event loop (line ~178)
4. At the very end of the Draw method before return

**Goal**: Identify exactly where control flow stops

**Implementation**:
```lua
-- After line 527 (end of cross-class switch block)
ConPrintf("DEBUG: Exiting cross-class switch block")

-- After line ~560 (end of treeClick processing)
ConPrintf("DEBUG: treeClick processing completed, continuing to rest of Draw")

-- Before line 178 (end of input event loop)
ConPrintf("DEBUG: Input event loop completed")

-- Before line 1249 (end of Draw method)
ConPrintf("DEBUG: About to return from Draw()")
```

**Pros**: Will pinpoint exact crash location
**Cons**: Doesn't fix the issue, just narrows it down further

### Option B: Simplify Class Switch - Skip BuildAllDependsAndPaths (TARGETED)
**Approach**: In MINIMAL mode, skip BuildAllDependsAndPaths entirely in SelectClass/SelectAscendClass

**Rationale**:
- BuildAllDependsAndPaths is complex and requires full infrastructure
- MINIMAL mode doesn't need path calculation for visual testing
- Might be causing state corruption even if it "completes"

**Implementation**:
```lua
-- In SelectClass MINIMAL branch (line 691)
-- self:BuildAllDependsAndPaths()  ← COMMENT OUT
ConPrintf("MINIMAL: Skipping BuildAllDependsAndPaths in SelectClass")

-- In SelectAscendClass MINIMAL branch (line 755)
-- self:BuildAllDependsAndPaths()  ← COMMENT OUT
ConPrintf("MINIMAL: Skipping BuildAllDependsAndPaths in SelectAscendClass")
```

**Pros**: Removes complex dependency calculation that might be corrupting state
**Cons**: Tree paths won't be calculated (acceptable for MINIMAL mode)

### Option C: Force Frame Continuation After Click (ROBUST)
**Approach**: Wrap entire treeClick processing in pcall and ensure execution continues even if something fails silently

**Implementation**:
```lua
if treeClick then
    local success, err = pcall(function()
        -- All the existing treeClick processing code
        ...
    end)
    if not success then
        ConPrintf("ERROR: treeClick processing failed: %s", tostring(err))
    end
    ConPrintf("DEBUG: treeClick processing finished (success=%s)", tostring(success))
    treeClick = nil  -- Clear click state
end
ConPrintf("DEBUG: Continuing after treeClick processing")
```

**Pros**: Ensures application continues even if click processing fails
**Cons**: Might hide the real error

## Recommendation Priority

1. **Option A** (Add extensive logging) - IMMEDIATE: Find exact crash location
2. **Option B** (Skip BuildAllDependsAndPaths) - LIKELY FIX: State corruption prevention
3. **Option C** (Force continuation) - FALLBACK: If A and B don't work

## Additional Investigation Needed

1. Check system crash logs for native errors: `Console.app` → filter by "PathOfBuilding"
2. Run app with lldb debugger to catch native crashes
3. Check if application actually crashes or just hangs/freezes
4. Verify app is still running: `ps aux | grep PathOfBuilding`
