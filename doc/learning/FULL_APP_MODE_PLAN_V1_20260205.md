# Full Application Mode Implementation - Plan V1

**作成日**: 2026-02-05
**作成者**: Planning
**ステータス**: Planning - Awaiting Approval

---

## 1. Current State Analysis

### ✅ What Works (MINIMAL Mode - Phase 3, 4)
- Ascendancy click functionality
- Normal node allocation/deallocation
- Basic visual feedback
- No crashes during basic operations

### ❌ What's Limited (MINIMAL Mode Restrictions)
- **Tooltip**: Disabled - requires full app infrastructure
- **Node Connections**: Missing - requires BuildAllDependsAndPaths()
- **Calculations**: Absent - no build.calcsTab infrastructure
- **Full Game Data**: Not loaded - minimal data only

### 🎯 Goal
Transition from MINIMAL mode to full application mode, enabling:
1. Node connections (visual paths between nodes)
2. Tooltip functionality (with calculations)
3. Full calculation infrastructure (build.calcsTab)
4. Complete game data loading

---

## 2. Proposed Solution

### Strategy: Gradual Infrastructure Enablement (3 Phases)

#### Phase A: BuildAllDependsAndPaths Fix (CRITICAL FIRST)
**Problem**: BuildAllDependsAndPaths() resets node.alloc to false (Phase 4, 6 discovery)

**Solution**: Preserve allocation state before/after path calculation
```lua
function PassiveSpecClass:AllocNode(node, ...)
    -- Save allocation states
    local allocStates = {}
    for nodeId, n in pairs(self.nodes) do
        if n.alloc then
            allocStates[nodeId] = true
        end
    end

    -- ... existing allocation logic ...

    -- Run path calculation
    self:BuildAllDependsAndPaths()

    -- Restore allocation states
    for nodeId, _ in pairs(allocStates) do
        if self.nodes[nodeId] then
            self.nodes[nodeId].alloc = true
        end
    end
end
```

**Why This Works**:
- BuildAllDependsAndPaths() can recalculate paths freely
- Allocation state is preserved across recalculation
- No conflict between path logic and allocation logic

---

#### Phase B: Initialize build.calcsTab Infrastructure
**Components Needed**:
1. **CalcSetup**: Initialize calculation environment
2. **CalcTab**: Create calculation tab structure
3. **ModDB**: Modifier database
4. **Output**: Calculation output structure

**Minimal Initialization**:
```lua
-- In Launch.lua or Main.lua
build.calcsTab = {
    mainOutput = {},
    mainEnv = {
        grantedPassives = {}
    }
}

function build.calcsTab:GetMiscCalculator(build)
    -- Return minimal calculator function
    return function(options)
        return {} -- Empty output for now
    end, {}
end
```

**Why Minimal First**:
- Tooltip only needs structure to exist (Phase 5 lesson)
- Full calculations can be implemented later
- Reduces initial complexity

---

#### Phase C: Re-enable Tooltip and Connections
**After Phase A, B Complete**:
1. Enable BuildAllDependsAndPaths (with alloc preservation)
2. Enable Tooltip rendering (with build.calcsTab check)
3. Test node connections (should appear automatically)
4. Test tooltip (should render without crash)

**Tooltip Re-enablement**:
```lua
-- PassiveTreeView.lua line 1255
if node == hoverNode and ... then  -- Remove "if false"
    -- Tooltip enabled for full app mode
end
```

---

## 3. Implementation Steps

### Step 1: Code Analysis (15 min)
**Deliverable**: Analysis of BuildAllDependsAndPaths internals

**Questions to Answer**:
1. Where exactly does BuildAllDependsAndPaths reset node.alloc?
2. What is the purpose of the reset?
3. Can we safely preserve alloc state?
4. Are there other state variables we need to preserve?

**Method**: Read PassiveSpec.lua BuildAllDependsAndPaths() method completely

**Dependencies**: None
**Risk**: Low (read-only)

---

### Step 2: Implement Allocation State Preservation (30 min)
**Deliverable**: Modified AllocNode() with state preservation

**Actions**:
1. Add allocStates dictionary before BuildAllDependsAndPaths
2. Save all node.alloc = true states
3. Restore states after BuildAllDependsAndPaths
4. Add logging to verify preservation

**Code Location**: PassiveSpec.lua line 999-1009 (AllocNode method)

**Dependencies**: Step 1 complete
**Risk**: Medium (modifies core logic)

**Verification**:
```lua
-- Log before/after
ConPrintf("Before BuildAll: node %d alloc=%s", nodeId, tostring(node.alloc))
-- ... BuildAllDependsAndPaths ...
ConPrintf("After restore: node %d alloc=%s", nodeId, tostring(node.alloc))
```

---

### Step 3: Initialize Minimal build.calcsTab (20 min)
**Deliverable**: build.calcsTab structure initialized

**Actions**:
1. Find where build object is created (Launch.lua or Main.lua)
2. Add minimal calcsTab initialization
3. Create stub GetMiscCalculator function
4. Add mainOutput and mainEnv structures

**Code Pattern**:
```lua
build.calcsTab = {
    mainOutput = {},
    mainEnv = { grantedPassives = {} }
}
build.calcsTab.GetMiscCalculator = function(self, build)
    return function() return {} end, {}
end
```

**Dependencies**: Step 2 complete
**Risk**: Low (additive, no removal)

---

### Step 4: File Synchronization (5 min)
**Deliverable**: All changes synced to app bundle

```bash
cp PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
cp PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/
# Verify with diff
diff ...
```

**Dependencies**: Steps 1-3 complete
**Risk**: Low (proven process)

---

### Step 5: Test Phase A - Node Connections (15 min)
**Test Scenarios**:
1. ✅ Allocate normal node → Visual feedback
2. ✅ Allocate second node → Connection line appears
3. ✅ Deallocate node → Allocation reverts, connection updates
4. ✅ Phase 3 (Ascendancy) still works
5. ✅ No crashes

**Success Criteria**:
- Node connections display correctly
- Phase 3, 4 functionality preserved
- No regression

**If Issues**: Use elimination logging to identify problem

**Dependencies**: Step 4 complete
**Risk**: Medium (new functionality)

---

### Step 6: Test Phase B - Tooltip Structure (10 min)
**Test Scenarios**:
1. ✅ Hover over node → Tooltip attempts to render
2. ✅ No crash (build.calcsTab exists)
3. ✅ Tooltip shows basic info (node name, stats)

**Note**: Full tooltip content may be incomplete (stub calculator)

**Success Criteria**:
- No crash on hover
- Tooltip appears (even if content is minimal)
- Application remains stable

**Dependencies**: Step 5 complete
**Risk**: Medium (previously crashed)

---

### Step 7: Re-enable Tooltip Rendering (10 min)
**Deliverable**: Tooltip fully enabled

**Actions**:
1. Change PassiveTreeView.lua line 1255: Remove `if false`
2. Remove MINIMAL mode early return from AddNodeTooltip
3. Keep existing nil guards for safety

**Dependencies**: Step 6 shows no crashes
**Risk**: Medium (Phase 5 failed here)

---

### Step 8: Final Verification (15 min)
**Comprehensive Test**:
1. ✅ Ascendancy click (Phase 3)
2. ✅ Normal node allocation (Phase 4)
3. ✅ Node connections display (Phase A)
4. ✅ Tooltip renders (Phase B/C)
5. ✅ No crashes during normal operation

**Success Criteria**: All 5 tests pass

**Dependencies**: Steps 1-7 complete
**Risk**: Low (verification only)

---

## 4. Timeline

| Step | Duration | Cumulative |
|------|----------|------------|
| 1. Code Analysis | 15 min | 15 min |
| 2. State Preservation | 30 min | 45 min |
| 3. calcsTab Init | 20 min | 65 min |
| 4. File Sync | 5 min | 70 min |
| 5. Test Connections | 15 min | 85 min |
| 6. Test Tooltip Struct | 10 min | 95 min |
| 7. Enable Tooltip | 10 min | 105 min |
| 8. Final Verification | 15 min | 120 min |

**Total Estimated Time**: 120 minutes (2 hours)
**Timebox Limit**: 180 minutes (3 hours with debugging)

---

## 5. Risk Assessment

### Risk 1: BuildAllDependsAndPaths Complexity (HIGH)
**Likelihood**: High (function is complex, may reset more than node.alloc)
**Impact**: High (could break Phase 4 functionality)
**Mitigation**:
- Preserve all relevant state (alloc, allocMode, etc.)
- Add comprehensive logging
- Test each node type separately
**Rollback**: Revert BuildAllDependsAndPaths skip, return to MINIMAL mode

---

### Risk 2: build.calcsTab Insufficient (MEDIUM)
**Likelihood**: Medium (minimal stub may not be enough)
**Impact**: Medium (tooltip may crash or show errors)
**Mitigation**:
- Start with minimal stub
- Add more structure only if needed
- Use pcall wrapper during initial testing
**Rollback**: Disable tooltip again, keep node connections

---

### Risk 3: Tooltip Still Crashes (MEDIUM)
**Likelihood**: Medium (Phase 5 crashed even with simple implementation)
**Impact**: Medium (can't show tooltip, but connections still work)
**Mitigation**:
- Test with build.calcsTab first (Step 6)
- Re-enable gradually (Step 7)
- Keep Phase 5 learnings in mind
**Rollback**: Disable tooltip, document as "requires deeper infrastructure"

---

### Risk 4: Phase 3/4 Regression (LOW)
**Likelihood**: Low (not modifying those code paths directly)
**Impact**: High (loses working functionality)
**Mitigation**:
- Test Phase 3, 4 after each major change
- Visual verification mandatory
- Keep rollback plan ready
**Rollback**: Git revert to current stable commit

---

## 6. Success Criteria

### Visual Verification (Mandatory)
- ✅ **Phase 3 preserved**: Ascendancy click works
- ✅ **Phase 4 preserved**: Normal node allocation works
- ✅ **Phase A new**: Node connections display between allocated nodes
- ✅ **Phase B/C new**: Tooltip renders on hover without crash

### Log Verification (If DEBUG)
- ✅ "Before BuildAll: node X alloc=true"
- ✅ "After restore: node X alloc=true"
- ✅ No ERROR lines
- ✅ No nil access errors

### Code Quality
- ✅ All state preservation logic clear and commented
- ✅ LuaJIT 5.1 compatible
- ✅ No breaking changes to existing functionality
- ✅ Rollback strategy documented

---

## 7. Rollback Strategy

**If Full App Mode Fails**:
1. Revert PassiveSpec.lua BuildAllDependsAndPaths changes
2. Remove build.calcsTab initialization
3. Re-disable tooltip (if enabled)
4. Verify Phase 3, 4 still work
5. Document failure in contexterror file

**Rollback Commands**:
```bash
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveSpec.lua
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua
# Sync to bundle
cp ...
```

**Git Safety**:
```bash
# Create safety commit before starting
git add .
git commit -m "Pre-full-app-mode: Phase 3, 4 working stable"
git branch full-app-mode-attempt
```

---

## 8. Deliverable Checklist

- [ ] BuildAllDependsAndPaths analysis complete
- [ ] State preservation implemented
- [ ] build.calcsTab initialized
- [ ] Files synced to app bundle
- [ ] Node connections tested (Phase A)
- [ ] Tooltip structure tested (Phase B)
- [ ] Tooltip rendering enabled (Phase C)
- [ ] Final verification complete (all 5 tests)
- [ ] LESSONS_LEARNED.md updated
- [ ] Full app mode marked complete OR failure documented

---

**Plan Status**: ✅ Complete - Ready for Review
