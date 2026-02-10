# Ascendancy Click Crash Analysis
**Date**: 2026-02-05
**Status**: CRASH CONFIRMED - Post-SelectClass Failure

## Crash Location Identified

### Debug Log Evidence
```
[2026-02-05 00:25:11] DEBUG: Allowed - calling SelectClass
[2026-02-05 00:25:11] DEBUG: SelectClass completed
[LOG ENDS - NO FURTHER OUTPUT]
```

**Critical Finding**: SelectClass completes successfully, but application crashes IMMEDIATELY AFTER, before next frame can start.

### Code Path Analysis
**File**: `PassiveTreeView.lua` lines 485-493

```lua
485: ConPrintf("DEBUG: Allowed - calling SelectClass")
486: spec:SelectClass(targetBaseClassId)
487: ConPrintf("DEBUG: SelectClass completed")  ← Last logged line
488: spec:SelectAscendClass(targetAscendClassId)  ← CRASH OCCURS HERE OR AFTER
489: ConPrintf("DEBUG: SelectAscendClass completed")
490: allocateClickedAscendancy()
491: spec:AddUndoState()
492: spec:SetWindowTitleWithBuildClass()
493: build.buildFlag = true
```

### Crash Occurs Between Lines 487-489
The crash happens in one of these method calls:
1. **SelectAscendClass** (line 488)
2. **allocateClickedAscendancy → AllocNode** (line 490)
3. **AddUndoState** (line 491)
4. **SetWindowTitleWithBuildClass** (line 492)

## Root Cause Hypotheses

### Hypothesis 1: SelectAscendClass Crash (HIGH PROBABILITY)
**Location**: `PassiveSpec.lua` line 741-756 (MINIMAL mode branch)

**Suspected Issue**: After class switch, `self.curClass.classes` might be invalid or SelectAscendClass tries to access fields that don't exist.

**Evidence**:
- SelectClass changes `self.curClass` to new class
- SelectAscendClass then tries to access `self.curClass.classes[ascendClassId]`
- If new class data is incomplete, this could fail

**Technical Details**:
```lua
-- SelectAscendClass in MINIMAL mode (line 741-756)
function PassiveSpecClass:SelectAscendClass(ascendClassId)
    if _G.MINIMAL_PASSIVE_TEST then
        self:ResetAscendClass()
        self.curAscendClassId = ascendClassId
        local ascendClass = (self.curClass and self.curClass.classes and self.curClass.classes[ascendClassId])
                         or (self.curClass and self.curClass.classes and self.curClass.classes[0])
                         or { name = "None" }
        self.curAscendClass = ascendClass
        self.curAscendClassName = ascendClass.name or "None"
        self.curAscendClassBaseName = ascendClass.id
        if ascendClass.startNodeId and self.nodes[ascendClass.startNodeId] then
            local startNode = self.nodes[ascendClass.startNodeId]
            startNode.alloc = true
            startNode.modList = startNode.modList or getMinimalModList()
            self.allocNodes[startNode.id] = startNode
        end
        self:BuildAllDependsAndPaths()  ← Could crash here
        return
    end
    ...
end
```

**Failure Point**: `BuildAllDependsAndPaths()` might crash if node structure is invalid after class switch.

### Hypothesis 2: AllocNode Crash (MEDIUM PROBABILITY)
**Location**: `allocateClickedAscendancy()` calls `spec:AllocNode(targetNode)`

**Suspected Issue**: AllocNode might try to:
- Update modList calculations (not available in MINIMAL mode)
- Trigger build updates (build.buildFlag, calcsTab dependencies)
- Access UndoHandler features that aren't initialized

**Evidence**:
- AllocNode is a complex method that updates multiple systems
- MINIMAL mode has many missing stubs

### Hypothesis 3: AddUndoState Crash (LOW PROBABILITY)
**Location**: Inherited from UndoHandler class

**Suspected Issue**: Undo system not initialized in MINIMAL mode

**Evidence**:
- UndoHandler might require full build context
- MINIMAL mode may not initialize undo state properly

### Hypothesis 4: SetWindowTitleWithBuildClass Crash (VERY LOW)
**Location**: `PassiveSpec.lua` line 2386-2388

```lua
function PassiveSpecClass:SetWindowTitleWithBuildClass()
    main:SetWindowTitleSubtext(string.format("%s (%s)",
        self.build.buildName,
        self.curAscendClassId == 0 and self.curClassName or self.curAscendClassName))
end
```

**Suspected Issue**: `self.build.buildName` might be nil

**Evidence**:
- buildName is set in Launch.lua line 217: `self.build.buildName = "Passive Tree Test"`
- Should be available, but string.format could fail if curClassName/curAscendClassName is nil

## Previous Failed Attempts

### Attempt 1: Nil-Safety Checks (Lines 442-472)
**Action**: Added checks for `spec.curClass.classes`, `classData.classes`, etc.
**Result**: Crash continues - these checks prevent crashes BEFORE SelectClass, not after

### Attempt 2: DEBUG Logging
**Action**: Added comprehensive logging throughout draw pipeline
**Result**: Successfully identified crash location (post-SelectClass)

## Proposed Solutions

### Option A: Wrap Post-SelectClass Calls in pcall (SAFEST)
**Approach**: Add error handling around each suspect method call

```lua
ConPrintf("DEBUG: Allowed - calling SelectClass")
spec:SelectClass(targetBaseClassId)
ConPrintf("DEBUG: SelectClass completed")

local success, err = pcall(function()
    spec:SelectAscendClass(targetAscendClassId)
end)
if not success then
    ConPrintf("ERROR: SelectAscendClass failed: %s", tostring(err))
    return
end
ConPrintf("DEBUG: SelectAscendClass completed")

success, err = pcall(function()
    allocateClickedAscendancy()
end)
if not success then
    ConPrintf("ERROR: allocateClickedAscendancy failed: %s", tostring(err))
    return
end
ConPrintf("DEBUG: allocateClickedAscendancy completed")

success, err = pcall(function()
    spec:AddUndoState()
end)
if not success then
    ConPrintf("ERROR: AddUndoState failed: %s", tostring(err))
    -- Non-critical, continue
end

success, err = pcall(function()
    spec:SetWindowTitleWithBuildClass()
end)
if not success then
    ConPrintf("ERROR: SetWindowTitleWithBuildClass failed: %s", tostring(err))
    -- Non-critical, continue
end
```

**Pros**: Will capture exact error message, allows graceful degradation
**Cons**: Doesn't fix root cause, just makes it visible

### Option B: Stub Missing MINIMAL Mode Methods (TARGETED)
**Approach**: Add MINIMAL mode guards to suspect methods

**SelectAscendClass Fix**:
```lua
function PassiveSpecClass:SelectAscendClass(ascendClassId)
    if _G.MINIMAL_PASSIVE_TEST then
        -- Skip BuildAllDependsAndPaths if it causes issues
        self:ResetAscendClass()
        self.curAscendClassId = ascendClassId
        local ascendClass = (self.curClass and self.curClass.classes and self.curClass.classes[ascendClassId])
                         or (self.curClass and self.curClass.classes and self.curClass.classes[0])
                         or { name = "None" }
        self.curAscendClass = ascendClass
        self.curAscendClassName = ascendClass.name or "None"
        self.curAscendClassBaseName = ascendClass.id
        if ascendClass.startNodeId and self.nodes[ascendClass.startNodeId] then
            local startNode = self.nodes[ascendClass.startNodeId]
            startNode.alloc = true
            startNode.modList = startNode.modList or getMinimalModList()
            self.allocNodes[startNode.id] = startNode
        end
        -- Skip BuildAllDependsAndPaths in MINIMAL mode
        ConPrintf("MINIMAL: Skipping BuildAllDependsAndPaths in SelectAscendClass")
        return
    end
    ...
end
```

**AllocNode MINIMAL Guard**:
```lua
-- In PassiveTreeView click handler, after SelectAscendClass
if not _G.MINIMAL_PASSIVE_TEST then
    allocateClickedAscendancy()  -- Skip in MINIMAL mode
    spec:AddUndoState()          -- Skip in MINIMAL mode
end
spec:SetWindowTitleWithBuildClass()  -- Keep this
```

**Pros**: Targeted fix, maintains functionality where possible
**Cons**: Might miss the actual crashing method

### Option C: Simplify Post-SelectClass Logic (MINIMAL)
**Approach**: Skip ALL non-essential operations in MINIMAL mode

```lua
if _G.MINIMAL_PASSIVE_TEST then
    -- Minimal mode: Only do essential operations
    ConPrintf("DEBUG: Allowed - calling SelectClass")
    spec:SelectClass(targetBaseClassId)
    ConPrintf("DEBUG: SelectClass completed")

    -- Skip SelectAscendClass entirely - already set by SelectClass in MINIMAL mode
    -- Skip allocateClickedAscendancy - not needed for visual test
    -- Skip AddUndoState - not needed in MINIMAL mode

    -- Only update window title
    local success, err = pcall(function()
        spec:SetWindowTitleWithBuildClass()
    end)
    if not success then
        ConPrintf("ERROR: SetWindowTitleWithBuildClass failed: %s", tostring(err))
    end

    build.buildFlag = true
    ConPrintf("DEBUG: Cross-class switch completed (MINIMAL mode)")
else
    -- Full mode logic
    spec:SelectClass(targetBaseClassId)
    spec:SelectAscendClass(targetAscendClassId)
    allocateClickedAscendancy()
    spec:AddUndoState()
    spec:SetWindowTitleWithBuildClass()
    build.buildFlag = true
end
```

**Pros**: Simplest, most robust for MINIMAL mode
**Cons**: Loses some visual feedback (ascendancy node allocation)

## Recommendation Priority
1. **Option A** (pcall wrapping) - Use FIRST to identify exact crash point
2. **Option B or C** - Apply after identifying the crashing method

## Next Steps
1. Add pcall error handling to capture exact error message
2. Based on error, apply targeted fix (Option B or C)
3. Document findings in LESSONS_LEARNED.md
