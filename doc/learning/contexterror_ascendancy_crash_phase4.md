# Context Error: Ascendancy Click Crash - Phase 4
**Date**: 2026-02-05
**Status**: CRASH LOCATION NARROWED TO CONNECTOR/GROUP DRAWING

## Exact Crash Location Identified

### Log Evidence
```
[2026-02-05 00:43:55] DEBUG: Ascendancy backgrounds drawn  ← LAST SUCCESS
[LOG ENDS - NO FURTHER OUTPUT]
Expected next: "Starting main node rendering loop"  ← NEVER REACHED
```

**Crash occurs between lines 680-830**, specifically in one of:
1. Group backgrounds drawing (lines 693-698)
2. **Connector lines drawing (lines 772-781)** ← MOST LIKELY
3. Search params update (lines 790-815)
4. Dev mode orbit drawing (lines 817-828)

## Root Cause Analysis

### Most Likely: Connector Lines Crash (Lines 772-781)

**Code**:
```lua
-- Draw the connecting lines between nodes
SetDrawLayer(nil, 20)
for _, connector in pairs(tree.connectors) do
    renderConnector(connector)  ← Line 775: CRASH HERE
end
```

**renderConnector function (line 716-770)**:
```lua
local function renderConnector(connector)
    local node1, node2 = spec.nodes[connector.nodeId1], spec.nodes[connector.nodeId2]  ← Line 717
    setConnectorColor(1, 1, 1)
    local state = getState(node1, node2)  ← Line 719: Accesses node1/node2
    ...
end
```

**Why This Crashes After Class Switch**:
1. `SelectClass(targetBaseClassId)` changes `spec.curClassId` from 0 to 5
2. `SelectClass` calls `BuildAllDependsAndPaths()` which rebuilds node structure
3. `spec.nodes` now contains nodes for the NEW class
4. BUT `tree.connectors` still references OLD class's node IDs
5. `connector.nodeId1` or `connector.nodeId2` no longer exists in `spec.nodes`
6. `spec.nodes[connector.nodeId1]` returns `nil`
7. `getState(node1, node2)` tries to access `node1.alloc` → **nil access crash**

**Evidence Supporting This**:
- Log shows: "Drawing class-specific background for classId=5" ← Class changed successfully
- Crash happens during connector drawing phase
- tree.connectors is tree-wide, not class-specific
- After class switch, many node IDs become invalid

### Alternative: Group Backgrounds Crash (Lines 693-698)

**Code**:
```lua
-- Draw the group backgrounds
for _, group in pairs(tree.groups) do
    if not group.isProxy then
        renderGroup(group)  ← Line 696
    end
end
```

**renderGroup function (line 682-691)**:
```lua
local function renderGroup(group)
    if group.background then
        local scrX, scrY = treeToScreen(group.x * tree.scaleImage, group.y * tree.scaleImage)  ← Line 684
        local bgAsset = tree:GetAssetByName(group.background.image)  ← Line 685
        ...
    end
end
```

**Potential Issues**:
- `group.background` might be nil for new class's groups
- `group.background.image` might be invalid asset name
- GetAssetByName might fail for missing assets

**Less Likely Because**:
- Group structure is tree-wide, shouldn't change with class switch
- Assets are pre-loaded, shouldn't fail suddenly

## Previous Fix Attempts Summary

1. **Phase 1**: pcall wrapping → Identified SelectAscendClass crash
2. **Phase 2**: modList guard → Fixed BuildAllDependsAndPaths crash
3. **Phase 3**: Extensive logging → Narrowed to post-click rendering
4. **Phase 4**: More detailed logging → Identified exact section (connector/group drawing)

## Fix Candidates

### Option A: Guard Node Access in renderConnector (SAFEST)
**Approach**: Check if nodes exist before accessing them

**File**: `PassiveTreeView.lua` line 717

```lua
local function renderConnector(connector)
    local node1, node2 = spec.nodes[connector.nodeId1], spec.nodes[connector.nodeId2]
    -- MINIMAL mode fix: Skip connector if nodes don't exist (after class switch)
    if not node1 or not node2 then
        return  -- Skip this connector
    end
    setConnectorColor(1, 1, 1)
    local state = getState(node1, node2)
    ...
end
```

**Pros**:
- Minimal code change
- Gracefully skips invalid connectors
- Doesn't break full app functionality

**Cons**:
- Doesn't fix root cause (tree.connectors still has stale IDs)
- Might leave some connectors not drawn

### Option B: Filter Connectors by Current Class (TARGETED)
**Approach**: Only draw connectors where both nodes exist in spec.nodes

**File**: `PassiveTreeView.lua` lines 772-781

```lua
-- Draw the connecting lines between nodes
SetDrawLayer(nil, 20)
ConPrintf("DEBUG: Drawing connectors, total=%d", #tree.connectors)
local drawnCount = 0
for _, connector in pairs(tree.connectors) do
    -- Only draw connector if both nodes exist in current spec
    if spec.nodes[connector.nodeId1] and spec.nodes[connector.nodeId2] then
        renderConnector(connector)
        drawnCount = drawnCount + 1
    end
end
ConPrintf("DEBUG: Drew %d connectors", drawnCount)

for _, subGraph in pairs(spec.subGraphs) do
    for _, connector in pairs(subGraph.connectors) do
        if spec.nodes[connector.nodeId1] and spec.nodes[connector.nodeId2] then
            renderConnector(connector)
        end
    end
end
```

**Pros**:
- Filters at the loop level, cleaner
- Adds diagnostic logging
- More explicit about what's being skipped

**Cons**:
- Slightly more code changes

### Option C: Add Diagnostic Logging First (RECOMMENDED)
**Approach**: Add DEBUG log right before connector loop to confirm this is the crash point

**File**: `PassiveTreeView.lua` line 772

```lua
ConPrintf("DEBUG: About to draw group backgrounds")
-- Draw the group backgrounds
for _, group in pairs(tree.groups) do
    if not group.isProxy then
        renderGroup(group)
    end
end
ConPrintf("DEBUG: Group backgrounds drawn, about to draw connectors")

-- Draw the connecting lines between nodes
SetDrawLayer(nil, 20)
ConPrintf("DEBUG: Drawing connectors, total tree.connectors=%d",
    tree.connectors and #tree.connectors or 0)
for _, connector in pairs(tree.connectors) do
    renderConnector(connector)
end
ConPrintf("DEBUG: Connectors drawn")
```

**Pros**:
- Confirms exact crash location (group vs connector)
- Minimal risk
- Provides data for next fix

**Cons**:
- Requires another test cycle

## Recommendation

**Priority**: Option C → Then Option B

**Rationale**:
1. Option C confirms if crash is in group or connector drawing
2. Once confirmed, Option B provides robust fix with filtering
3. Option A is fallback if Option B doesn't work

## Expected Next Steps

1. **If Option C shows crash before "Drawing connectors"**:
   - Crash is in group backgrounds → Guard group.background access

2. **If Option C shows crash after "Drawing connectors" log but before "Connectors drawn"**:
   - Crash is in connector loop → Apply Option B (filter connectors)

3. **If neither**:
   - Crash is in search params or dev mode orbits → Add more logging
