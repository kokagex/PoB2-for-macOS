# Ascendancy Click Crash - Root Cause Identified
**Date**: 2026-02-05
**Status**: ROOT CAUSE CONFIRMED

## Error Details

```
ERROR: SelectAscendClass failed: src/Classes/PassiveSpec.lua:1242:
attempt to index field 'modList' (a nil value)
```

## Root Cause

**Location**: `PassiveSpec.lua` BuildAllDependsAndPaths() method, lines 1239-1246

```lua
for id, node in pairs(self.allocNodes) do
    if node.ascendancyName then
        self.tree:ProcessStats(node)  ← Line 1241: ProcessStats modifies node
        if node.modList:HasMod("LIST", nil, "AllocateFromNodeRadius") then  ← Line 1242: CRASH HERE
            for _, radius in ipairs(node.modList:List(nil, "AllocateFromNodeRadius")) do
                t_insert(intuitiveLeapLikeNodes, radius)
            end
        end
        processed[id] = true
    end
end
```

**Problem**:
1. In MINIMAL mode, we set `node.modList = getMinimalModList()` when allocating nodes
2. `BuildAllDependsAndPaths()` is called after SelectClass/SelectAscendClass
3. At line 1241, `self.tree:ProcessStats(node)` processes the node
4. ProcessStats likely clears or doesn't set node.modList in MINIMAL mode
5. At line 1242, `node.modList:HasMod()` tries to access nil modList → CRASH

## Technical Context

**BuildAllDependsAndPaths Purpose**:
- Checks for "intuitive leap-like" nodes (allocate from radius mods)
- Builds dependency tree for node connections
- Identifies switchable nodes

**MINIMAL Mode Issue**:
- `self.tree:ProcessStats()` expects full PassiveTree infrastructure
- In MINIMAL mode, we don't have full modDB/modParser support
- ProcessStats might not initialize modList properly

## Solutions

### Option A: Guard modList Access (SAFEST, MINIMAL CHANGE)
**Approach**: Check if modList exists before calling HasMod

**File**: `PassiveSpec.lua` line 1242

```lua
for id, node in pairs(self.allocNodes) do
    if node.ascendancyName then
        self.tree:ProcessStats(node)
        -- Guard against missing modList (MINIMAL mode compatibility)
        if node.modList and node.modList:HasMod("LIST", nil, "AllocateFromNodeRadius") then
            for _, radius in ipairs(node.modList:List(nil, "AllocateFromNodeRadius")) do
                t_insert(intuitiveLeapLikeNodes, radius)
            end
        end
        processed[id] = true
    end
end
```

**Pros**:
- Minimal code change
- Doesn't affect full app functionality
- Graceful degradation in MINIMAL mode

**Cons**:
- Doesn't fix ProcessStats issue
- Might miss other modList accesses in BuildAllDependsAndPaths

### Option B: Ensure modList After ProcessStats (TARGETED)
**Approach**: Re-initialize modList after ProcessStats call

**File**: `PassiveSpec.lua` line 1241-1242

```lua
for id, node in pairs(self.allocNodes) do
    if node.ascendancyName then
        self.tree:ProcessStats(node)
        -- Ensure modList exists after ProcessStats (MINIMAL mode fix)
        if not node.modList then
            node.modList = getMinimalModList()
        end
        if node.modList:HasMod("LIST", nil, "AllocateFromNodeRadius") then
            for _, radius in ipairs(node.modList:List(nil, "AllocateFromNodeRadius")) do
                t_insert(intuitiveLeapLikeNodes, radius)
            end
        end
        processed[id] = true
    end
end
```

**Pros**:
- Fixes the immediate issue
- Ensures modList is always available after ProcessStats
- Prevents similar crashes elsewhere

**Cons**:
- Might not be the "proper" fix if ProcessStats should set modList
- Band-aid over deeper ProcessStats issue

### Option C: Skip Intuitive Leap Processing in MINIMAL Mode (CLEANEST)
**Approach**: Skip the entire intuitive leap check in MINIMAL mode since it's not needed for visual testing

**File**: `PassiveSpec.lua` lines 1235-1249

```lua
-- First check for mods that affect intuitive leap-like properties of other nodes
local processed = { }
local intuitiveLeapLikeNodes = self.intuitiveLeapLikeNodes
wipeTable(intuitiveLeapLikeNodes)

-- Skip intuitive leap processing in MINIMAL mode (requires full modDB support)
if not _G.MINIMAL_PASSIVE_TEST then
    for id, node in pairs(self.allocNodes) do
        if node.ascendancyName then
            self.tree:ProcessStats(node)
            if node.modList:HasMod("LIST", nil, "AllocateFromNodeRadius") then
                for _, radius in ipairs(node.modList:List(nil, "AllocateFromNodeRadius")) do
                    t_insert(intuitiveLeapLikeNodes, radius)
                end
            end
            processed[id] = true
        end
    end
end
```

**Pros**:
- Clean separation of MINIMAL vs full mode
- No risk of partial functionality breaking
- Clearly documents that intuitive leap doesn't work in MINIMAL mode

**Cons**:
- Skips ProcessStats entirely (might be needed elsewhere)
- Might need to skip more sections of BuildAllDependsAndPaths

## Additional Context

### ProcessStats Method
Located in `PassiveTree.lua`, this method:
- Processes node mods using modLib and modParser
- Generates modList from node.sd (stat descriptions)
- Requires full modDB infrastructure

**MINIMAL Mode Incompatibility**:
- modLib and modParser are not loaded in MINIMAL mode
- ProcessStats likely returns early or doesn't set modList
- This breaks downstream code expecting modList

### Previous Working State
Before class switching, nodes had modList stubs from:
- Launch.lua line 254-257: emptyModList initialization
- PassiveSpec.lua line 688, 752: `node.modList = node.modList or getMinimalModList()`

After SelectClass → BuildAllDependsAndPaths → ProcessStats, the modList stub is lost.

## Recommendation

**Priority**: Option B (Ensure modList After ProcessStats)

**Rationale**:
1. Targeted fix that doesn't skip functionality
2. Ensures modList exists after any ProcessStats call
3. Minimal risk to full app behavior
4. Can be applied to other modList access points if needed

**Implementation**:
1. Add `if not node.modList then node.modList = getMinimalModList() end` after line 1241
2. Test ascendancy click to verify crash is fixed
3. Monitor log for any additional modList errors
4. Document in LESSONS_LEARNED.md

## Follow-up Actions
1. Search for other `node.modList:` calls in BuildAllDependsAndPaths
2. Consider wrapping entire BuildAllDependsAndPaths in MINIMAL mode guard
3. Document ProcessStats incompatibility in MINIMAL mode notes
