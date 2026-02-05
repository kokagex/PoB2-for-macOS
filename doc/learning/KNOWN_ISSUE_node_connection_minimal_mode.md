# Known Issue: Normal Passive Node Connection Problem

**Reported**: 2026-02-05
**Status**: ON HOLD - May be resolved in full app implementation
**Severity**: MEDIUM
**Phase**: Discovered during Phase 4/5 testing

---

## Issue Description

**Symptom**:
通常パッシブツリーノードにおいて、本来つながるべきノードに繋がらない。

**Context**:
- Phase 3 (Ascendancy click): ✅ Working
- Phase 4 (Normal node allocation): ✅ Working (can allocate/deallocate)
- Phase 5 (Tooltip): ❌ Failed (incompatible with MINIMAL mode)
- **Node Connection**: ⚠️ Issues observed

---

## Observed Behavior

**What Works**:
- Clicking nodes allocates them correctly
- Allocated nodes light up visually
- Deallocation works correctly

**What Doesn't Work**:
- Normal passive nodes don't connect to nodes they should connect to
- Expected: Nodes form visible paths/connections in the tree
- Actual: Connections may not display or form correctly

---

## Possible Root Causes

### Hypothesis 1: BuildAllDependsAndPaths() Skipped (HIGH)
**Theory**: In Phase 4, we skipped BuildAllDependsAndPaths() in MINIMAL mode (line 999-1009 of PassiveSpec.lua) to fix allocation issues. This function is responsible for building node paths and dependencies.

**Code Reference**:
```lua
-- PassiveSpec.lua line 999-1009
if not _G.MINIMAL_PASSIVE_TEST then
    self:BuildAllDependsAndPaths()
else
    -- Skipped in MINIMAL mode
end
```

**Impact**: Node paths and connections are not calculated, so visual connections between nodes may not be drawn.

**Likelihood**: HIGH

---

### Hypothesis 2: Path Rendering Not Implemented (MEDIUM)
**Theory**: MINIMAL mode may not include the rendering code for drawing connections between nodes.

**Likelihood**: MEDIUM

---

### Hypothesis 3: node.path Not Populated (HIGH)
**Theory**: Since we allow allocation without `node.path` in MINIMAL mode (Phase 4 fix), the path data structure is never populated, causing connection rendering to fail.

**Code Reference**:
```lua
-- PassiveSpec.lua line 929-930
if not node.path and not _G.MINIMAL_PASSIVE_TEST then
    return
end

-- PassiveSpec.lua line 940-956
if not node.path and _G.MINIMAL_PASSIVE_TEST then
    node.alloc = true  -- Direct allocation without path
    -- ...
end
```

**Impact**: Nodes are allocated but have no path information, so connections cannot be drawn.

**Likelihood**: HIGH

---

## Why On Hold?

**Reason**: This issue may be naturally resolved when full application mode is implemented, because:
1. Full app mode will have BuildAllDependsAndPaths() enabled
2. Full app mode will have proper path calculation and rendering
3. MINIMAL mode is primarily for basic testing, not complete functionality

**Alternative**: If MINIMAL mode needs connection display:
- Implement simplified path rendering without full dependency calculation
- Or accept limitation and document that connections are not shown in MINIMAL mode

---

## Reproduction Steps

1. Launch app in MINIMAL mode
2. Allocate multiple normal passive nodes in the tree
3. Observe connections between nodes
4. **Expected**: Visible lines/paths connecting allocated nodes
5. **Actual**: Connections may not display correctly

---

## Workaround

**For Testing**: Focus on individual node allocation/deallocation functionality rather than connection visualization.

**For Full Functionality**: Implement/test in full application mode where BuildAllDependsAndPaths() is enabled.

---

## Related Code Locations

1. **PassiveSpec.lua line 999-1009**: BuildAllDependsAndPaths() skip in MINIMAL mode
2. **PassiveSpec.lua line 929-945**: AllocNode() MINIMAL mode path handling
3. **PassiveTreeView.lua**: Node rendering (connections may be drawn here)

---

## Future Action Items

**When Implementing Full App Mode**:
1. Test node connections with BuildAllDependsAndPaths() enabled
2. Verify path calculation works correctly
3. Check if connection rendering works as expected

**If Issue Persists in Full Mode**:
1. Investigate path calculation logic in BuildAllDependsAndPaths()
2. Check connection rendering code in PassiveTreeView.lua
3. Verify node.path data structure is populated correctly

---

**Status**: 📋 DOCUMENTED - On hold until full app implementation
**Priority**: MEDIUM (affects visual clarity but not core functionality)
**Assignee**: Future investigation
