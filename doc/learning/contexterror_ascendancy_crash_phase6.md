# Context Error: Ascendancy Click Crash - Phase 6
**Date**: 2026-02-05
**Status**: All sections passed - Crash after connectors

## Test Result: All Previous Sections Successful

**Successful sections**:
- ✅ Cross-class switch fully completed
- ✅ Background artwork drawn
- ✅ Class background drawing completed
- ✅ Ascendancy backgrounds drawn
- ✅ Group backgrounds drawn successfully
- ✅ SetDrawLayer completed
- ✅ tree.connectors drawn
- ✅ All connectors drawn successfully

**Crash Location**: Immediately after line 804 "All connectors drawn successfully"

## New Finding: Non-Start Ascendancy Node Click

**Important**: User clicked a regular ascendancy node (Sanguimancy, type=Notable), NOT the ascendancy start node, and same crash occurred.

**Log Evidence**:
```
[2026-02-05 00:51:38] DEBUG: Hover detection complete, hoverNode=Sanguimancy
[2026-02-05 00:51:38] DEBUG: Node type=Notable, alloc=nil, ascendancyName=Blood Mage
```

**Implication**: The crash is NOT specific to ascendancy start nodes - it affects ANY ascendancy node click that triggers class switch.

## Narrowed Crash Location

Crash occurs in code after line 804, likely in one of these sections:

### Section 1: showHeatMap (Lines 806-810)
```lua
if self.showHeatMap then
    -- Build the power numbers if needed
    build.calcsTab:BuildPower()
    self.heatMapStat = build.calcsTab.powerStat
end
```

**Potential Issue**:
- `self.showHeatMap` might be true
- `build.calcsTab:BuildPower()` requires full calculation infrastructure
- In MINIMAL mode, this will fail

**Likelihood**: MEDIUM (depends on showHeatMap state)

### Section 2: Update Cached Node Data (Lines 812-838)
```lua
if self.searchStrCached ~= self.searchStr or self.searchNeedsForceUpdate == true then
    self.searchStrCached = self.searchStr
    self.searchNeedsForceUpdate = false

    local function prepSearch(search)
        search = search:lower()
        ...
    end
    self.searchParams = prepSearch(self.searchStr)

    -- PRJ-003: Use spec.tree.nodes directly instead of spec.nodes
    for nodeId, node in pairs(tree.nodes) do
        self.searchStrResults[nodeId] = #self.searchParams > 0 and self:DoesNodeMatchSearchParams(node)
    end
end
```

**Potential Issue**:
- String manipulation might fail with nil searchStr
- `DoesNodeMatchSearchParams(node)` might crash with invalid node state after class switch

**Likelihood**: MEDIUM

### Section 3: Dev Mode Orbit Drawing (Lines 839+)
```lua
if launch.devModeAlt and hoverNode then
    -- Draw orbits of the group node
    local groupNode = hoverNode.group
    ...
end
```

**Potential Issue**:
- `hoverNode.group` might be nil after class switch
- Group node access might fail

**Likelihood**: LOW (devModeAlt usually false)

### Section 4: Main Node Rendering Loop (Line 830+)
Already confirmed to start successfully in previous tests, but crash might be WITHIN the loop after class switch.

**Likelihood**: HIGH - This is the most complex section with many node accesses

## Elimination Method - Next Steps

Add logging at these boundaries:
1. After line 804: "Connectors done, checking showHeatMap"
2. Before/after showHeatMap block
3. Before/after cached node data update
4. Before main node rendering loop (line 830+)

## Fix Candidates - Phase 6

### Option A: Add Elimination Logging (REQUIRED FIRST)
**Approach**: Add DEBUG logs between line 804 and main node rendering

**File**: `PassiveTreeView.lua` lines 804-840

```lua
ConPrintf("DEBUG: All connectors drawn successfully")

ConPrintf("DEBUG: Checking showHeatMap, value=%s", tostring(self.showHeatMap))
if self.showHeatMap then
    ConPrintf("DEBUG: Building heat map power")
    build.calcsTab:BuildPower()
    self.heatMapStat = build.calcsTab.powerStat
    ConPrintf("DEBUG: Heat map power built")
end

ConPrintf("DEBUG: Checking cached node data update")
if self.searchStrCached ~= self.searchStr or self.searchNeedsForceUpdate == true then
    ConPrintf("DEBUG: Updating cached node data")
    self.searchStrCached = self.searchStr
    self.searchNeedsForceUpdate = false

    local function prepSearch(search)
        ...
    end
    self.searchParams = prepSearch(self.searchStr)

    for nodeId, node in pairs(tree.nodes) do
        self.searchStrResults[nodeId] = #self.searchParams > 0 and self:DoesNodeMatchSearchParams(node)
    end
    ConPrintf("DEBUG: Cached node data updated")
end

ConPrintf("DEBUG: Checking dev mode orbits")
if launch.devModeAlt and hoverNode then
    ConPrintf("DEBUG: Drawing dev mode orbits")
    ...
end
ConPrintf("DEBUG: About to start main node rendering")
```

**Pros**: Will pinpoint exact crash section
**Cons**: Requires another test cycle

### Option B: Skip showHeatMap in MINIMAL Mode (PREVENTIVE)
**Approach**: Disable heat map functionality in MINIMAL mode

```lua
if self.showHeatMap and not _G.MINIMAL_PASSIVE_TEST then
    build.calcsTab:BuildPower()
    self.heatMapStat = build.calcsTab.powerStat
end
```

**Pros**: Prevents potential crash in BuildPower
**Cons**: Might not be the actual crash location

### Option C: Guard Cached Node Data Update (PREVENTIVE)
**Approach**: Add nil checks for searchStr and node validation

```lua
if self.searchStrCached ~= self.searchStr or self.searchNeedsForceUpdate == true then
    self.searchStrCached = self.searchStr or ""
    self.searchNeedsForceUpdate = false

    local function prepSearch(search)
        if not search then return {} end
        search = search:lower()
        ...
    end
    self.searchParams = prepSearch(self.searchStr)

    for nodeId, node in pairs(tree.nodes) do
        if node then  -- Guard against nil nodes
            self.searchStrResults[nodeId] = #self.searchParams > 0 and self:DoesNodeMatchSearchParams(node)
        end
    end
end
```

**Pros**: Guards against nil access
**Cons**: Might not be the actual crash location

## Recommendation

**MANDATORY**: Option A (Elimination Logging)

**Rationale**:
1. We've successfully narrowed down to after line 804
2. Multiple potential crash locations remain
3. Need confirmation before applying targeted fix
4. Elimination method requires systematic logging

**After Option A confirms location**: Apply Option B or C as appropriate

## Work History Pattern

**Successful Eliminations**:
1. Phase 4: Narrowed to between ascendancy backgrounds and node rendering
2. Phase 5: Confirmed renderGroup guards worked, crash was after
3. Phase 6: Confirmed connectors work, crash is after line 804

**Pattern**: Systematic elimination is working - continue this approach
