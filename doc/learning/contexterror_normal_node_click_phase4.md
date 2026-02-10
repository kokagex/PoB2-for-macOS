# Context Error: Normal Node Click Non-Responsive - Phase 4

**Date**: 2026-02-05
**Status**: INVESTIGATING - Multiple fix attempts, still non-responsive
**Phase**: Phase 4 - Normal Passive Node Allocation

---

## Symptom

**Observed Behavior**:
- ✅ Ascendancy nodes respond to clicks (Phase 3 functionality intact)
- ❌ Normal passive nodes do not respond to clicks (no visual change, no allocation)

**Expected Behavior**:
- Click unallocated normal node → Node becomes highlighted (allocated)
- Click allocated normal node → Node becomes unhighlighted (deallocated)

---

## Work History - Fix Attempts

### Attempt 1: Build.itemsTab Guard in BuildAllDependsAndPaths()
**File**: PassiveSpec.lua line 1275
**Change**: Added guard around `self.build.itemsTab.items` access
**Rationale**: MINIMAL mode doesn't have itemsTab, could cause crash
**Result**: ❌ Still non-responsive
**Analysis**: Prevented potential crash, but didn't fix click issue

### Attempt 2: MINIMAL Mode Path Check in AllocNode()
**File**: PassiveSpec.lua line 929-930
**Change**: `if not node.path and not _G.MINIMAL_PASSIVE_TEST then return end`
**Rationale**: AllocNode() requires path, but normal nodes don't have path in MINIMAL mode
**Result**: ❌ Still non-responsive
**Analysis**: Correct fix for AllocNode(), but AllocNode() wasn't being called

### Attempt 3: MINIMAL Mode Path Check in Click Handler
**File**: PassiveTreeView.lua line 556-557
**Change**: `if (hoverNode.path or _G.MINIMAL_PASSIVE_TEST) and not shouldBlockGlobalNodeAllocation(hoverNode) then`
**Rationale**: Click handler requires path, skip this requirement in MINIMAL mode
**Result**: ❌ Still non-responsive
**Analysis**: Correct change, but had indentation issue

### Attempt 4: Fix Indentation
**File**: PassiveTreeView.lua line 557
**Change**: Fixed indentation from 3 tabs to 4 tabs
**Rationale**: Line 557 was outside else block due to wrong indentation
**Result**: ❌ Still non-responsive
**Analysis**: Indentation fixed, but still doesn't work

---

## Current State

### Verified Facts
1. ✅ Syntax errors: None (luajit -bl passes for both files)
2. ✅ _G.MINIMAL_PASSIVE_TEST: Set to true in Launch.lua line 106
3. ✅ File synchronization: Changes in app bundle (git diff confirms)
4. ✅ Ascendancy clicks: Still working (Phase 3 functionality intact)

### Modified Files
1. **PassiveTreeView.lua**:
   - Line 557: Path check with MINIMAL mode exception
   - Line 559-579: DEBUG logging and guards
   - Line 586-622: RIGHT-click guards

2. **PassiveSpec.lua**:
   - Line 929-930: MINIMAL mode path check in AllocNode()
   - Line 940-956: MINIMAL mode direct allocation
   - Line 1275-1322: build.itemsTab guard in BuildAllDependsAndPaths()
   - Line 1810-1843: DEBUG logging in BuildAllDependsAndPaths()

### Unknown Factors
1. ❓ Are normal node clicks being detected as LEFT clicks?
2. ❓ Is hoverNode being set for normal nodes?
3. ❓ Is the condition on line 557 actually being evaluated as true?
4. ❓ Is AllocNode() actually being called?
5. ❓ Which specific normal node is the user clicking?

---

## Hypotheses

### Hypothesis A: Click Detection Issue
**Theory**: Normal node clicks are not being detected as LEFT clicks, or hoverNode is nil
**Evidence**: No logs visible (ConPrintf not reaching terminal)
**Likelihood**: Medium
**Test**: Add file-based logging to confirm click detection

### Hypothesis B: Visual State Not Updating
**Theory**: AllocNode() is being called, but visual state is not updating
**Evidence**: Phase 3 ascendancy visual updates work, suggests rendering pipeline is fine
**Likelihood**: Low
**Test**: Check if node.alloc is being set, verify rendering updates

### Hypothesis C: User Clicking Wrong Node
**Theory**: User is clicking an already-allocated node or a non-normal node
**Evidence**: No specific node identified in tests
**Likelihood**: Medium
**Test**: Provide clear instructions on which exact node to click

### Hypothesis D: Additional Blocking Condition
**Theory**: There's another condition blocking normal node allocation that we haven't identified
**Evidence**: Multiple fixes applied, all logically correct, but still doesn't work
**Likelihood**: High
**Test**: Systematic elimination with file logging

---

## Code Context

### Normal Node Click Flow (Expected)
```
1. LEFT click detected (line 390)
2. hoverNode exists (line 392)
3. hoverNode.alloc is false (line 396 → goes to else at 413)
4. hoverNode.ascendancyName is nil (line 415 → skips ascendancy block)
5. Line 557 condition: (hoverNode.path or _G.MINIMAL_PASSIVE_TEST) → should be TRUE
6. shouldBlockGlobalNodeAllocation(hoverNode) → should be FALSE for normal nodes
7. Enter normal node allocation block (line 558+)
8. Call AllocNode() (line 575)
9. AllocNode() allocates node (line 940-945 for MINIMAL mode without path)
```

### Why Ascendancy Clicks Work
- Ascendancy nodes go through different path (line 415-555)
- Ascendancy allocation calls SelectAscendClass() and AllocNode()
- AllocNode() is called for ascendancy start nodes
- Visual update happens correctly

---

## Next Steps - Fix Candidates Needed

Following CLAUDE.md protocol:
1. Create 3 fix candidates (Diagnostic, Targeted, Robust)
2. Present to user with AskUserQuestion tool
3. Implement only selected option
4. Test and iterate

---

## Fix Attempt 5: shouldBlockGlobalNodeAllocation() MINIMAL Mode Bypass (Option B)

**Date**: 2026-02-05
**File**: PassiveTreeView.lua line 361-363
**Change**: Added early return `if _G.MINIMAL_PASSIVE_TEST then return false end`
**Rationale**: shouldBlockGlobalNodeAllocation() might be blocking normal nodes
**Result**: ⚠️ **CRASH ON NORMAL NODE CLICK**
**Analysis**:
- ✅ SUCCESS: Click processing now reaches normal node handler
- ❌ CRASH: Application crashes during/after AllocNode() call
- 🎯 PROGRESS: We've moved from "no response" to "crash" - handler is executing

**New Symptom**: Crash on normal node click (ascendancy still works)

---

## Updated Hypothesis - Crash Location

Now that processing reaches AllocNode(), the crash is likely in one of these locations:

1. **AllocNode() itself** (PassiveSpec.lua line 928-980)
2. **BuildAllDependsAndPaths()** called by AllocNode() (line 976)
3. **AddUndoState()** after AllocNode() (PassiveTreeView.lua line 577)
4. **build.buildFlag assignment** (line 578)

**Most Likely**: BuildAllDependsAndPaths() has uncaught nil access for normal nodes that differs from ascendancy nodes

---

---

## Fix Attempt 6: Skip BuildAllDependsAndPaths() in MINIMAL Mode (SUCCESSFUL!)

**Date**: 2026-02-05
**File**: PassiveSpec.lua line 999-1009
**Change**: Skip BuildAllDependsAndPaths() in AllocNode() when MINIMAL_PASSIVE_TEST is true
**Rationale**: Elimination method revealed BuildAllDependsAndPaths() was resetting node.alloc to false
**Result**: ✅ **SUCCESS!**

**Evidence**:
- Before skip: node.alloc = nil → AllocNode() → node.alloc = false (reset by BuildAllDependsAndPaths)
- After skip: node.alloc = nil → AllocNode() → node.alloc = true (preserved)
- Visual confirmation: Nodes now light up when clicked
- Multiple nodes: Can allocate multiple nodes successfully
- Deallocation: Can deallocate nodes by clicking again
- Phase 3 preserved: Ascendancy clicks still work

**Root Cause**: BuildAllDependsAndPaths() was resetting node.alloc during path recalculation

---

**Status**: ✅ RESOLVED - Phase 4 Complete

**Note**: Current fix skips BuildAllDependsAndPaths() in MINIMAL mode. This is a working solution for testing, but BuildAllDependsAndPaths() may be needed for full functionality (multi-node paths, dependency tracking). For production, may need to fix BuildAllDependsAndPaths() to preserve node.alloc in MINIMAL mode.
