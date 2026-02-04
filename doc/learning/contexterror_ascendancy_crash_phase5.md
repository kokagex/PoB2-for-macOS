# Context Error: Ascendancy Click Crash - Phase 5
**Date**: 2026-02-05
**Status**: renderConnector nil guard FAILED - Crash before connector loop

## Test Result: Phase 4 Fix Failed

**Fix Applied**: Added nil guard in renderConnector (line 717)
```lua
if not node1 or not node2 then
    return  -- Skip this connector
end
```

**Result**: Crash still occurs at same location
```
[2026-02-05 00:46:33] DEBUG: Ascendancy backgrounds drawn  ← LAST SUCCESS
[LOG ENDS]
```

**Conclusion**: Crash happens BEFORE renderConnector is ever called

## Narrowed Crash Location

Crash occurs in code between lines 680-774 (before connector loop starts):
1. **Group backgrounds drawing (lines 693-698)** ← MOST LIKELY NOW
2. Connector line setup (lines 700-770)
3. SetDrawLayer(nil, 20) (line 773)

## Root Cause Analysis - Updated

### Most Likely: Group Backgrounds Crash

**Code (lines 693-698)**:
```lua
-- Draw the group backgrounds
for _, group in pairs(tree.groups) do
    if not group.isProxy then
        renderGroup(group)  ← Line 696: CRASH HERE
    end
end
```

**renderGroup function (lines 682-691)**:
```lua
local function renderGroup(group)
    if group.background then
        local scrX, scrY = treeToScreen(group.x * tree.scaleImage, group.y * tree.scaleImage)  ← Line 684
        local bgAsset = tree:GetAssetByName(group.background.image)  ← Line 685: LIKELY CRASH
        if group.background.offsetX and group.background.offsetY then
            scrX, scrY = treeToScreen(group.x + group.background.offsetX, group.y + group.background.offsetY)
        end
        self:DrawAsset(bgAsset, scrX, scrY, scale * tree.scaleImage, group.background.isHalfImage ~= nil)  ← Line 689
    end
end
```

**Why This Crashes After Class Switch**:
1. SelectClass changes `spec.curClassId` from 0 to 5
2. tree.groups contains ALL groups across ALL classes
3. After class switch, some groups belong to the OLD class
4. Old class groups might have:
   - Invalid `group.background.image` asset names
   - Missing `group.background` fields
   - Coordinates that cause treeToScreen to fail
5. `tree:GetAssetByName(group.background.image)` might fail or return nil
6. `self:DrawAsset(bgAsset, ...)` tries to access nil asset → CRASH

**Alternative Crash Points**:
- Line 684: `treeToScreen()` might fail with invalid coordinates
- Line 685: `GetAssetByName()` might return nil or crash
- Line 689: `DrawAsset()` might crash with nil bgAsset

### Secondary: Connector Setup Functions

**Code (lines 700-770)**: Function definitions (setConnectorColor, getState, renderConnector)
- These are just function definitions, shouldn't crash
- Unless Lua has syntax errors (unlikely)

### Tertiary: SetDrawLayer Call

**Code (line 773)**: `SetDrawLayer(nil, 20)`
- Simple C function call
- Shouldn't fail unless renderer is in bad state

## Work History Pattern

**Pattern Observed**:
1. Each crash is due to accessing objects that don't exist after class switch
2. After SelectClass, many references become stale:
   - Node IDs in connectors (fixed by renderConnector guard, but crash was earlier)
   - Group backgrounds for old class
   - Asset references

**Key Insight**: SelectClass changes the active class, but PassiveTreeView still tries to render ALL tree-wide objects (groups, connectors) which include old class data.

## Fix Candidates - Phase 5

### Option A: Guard group.background Access (TARGETED)
**Approach**: Add nil/validity checks in renderGroup

**File**: `PassiveTreeView.lua` lines 682-691

```lua
local function renderGroup(group)
    -- MINIMAL mode fix: Skip group if background is invalid
    if not group or not group.background then
        return
    end
    -- Additional safety: Check required fields
    if not group.background.image or not group.x or not group.y then
        return
    end

    local scrX, scrY = treeToScreen(group.x * tree.scaleImage, group.y * tree.scaleImage)
    local bgAsset = tree:GetAssetByName(group.background.image)

    -- Check if asset was successfully retrieved
    if not bgAsset or not bgAsset.handle then
        return  -- Skip if asset not found
    end

    if group.background.offsetX and group.background.offsetY then
        scrX, scrY = treeToScreen(group.x + group.background.offsetX, group.y + group.background.offsetY)
    end
    self:DrawAsset(bgAsset, scrX, scrY, scale * tree.scaleImage, group.background.isHalfImage ~= nil)
end
```

**Pros**:
- Comprehensive guards against all failure points
- Gracefully skips invalid groups
- Doesn't affect valid groups

**Cons**:
- Multiple checks, slightly verbose
- Might skip groups that should be drawn

### Option B: Filter Groups by Current Class (AGGRESSIVE)
**Approach**: Only draw groups that belong to current class

**File**: `PassiveTreeView.lua` lines 693-698

```lua
-- Draw the group backgrounds
ConPrintf("DEBUG: About to draw group backgrounds, total groups=%d",
    tree.groups and #tree.groups or 0)
local drawnGroups = 0
for _, group in pairs(tree.groups) do
    if not group.isProxy then
        -- Only draw groups for current class in MINIMAL mode
        if _G.MINIMAL_PASSIVE_TEST then
            -- In MINIMAL mode, skip groups that might be for other classes
            -- This is safe because we only need current class's groups visible
            local isCurrentClass = true  -- Default to drawing
            if group.classId and group.classId ~= spec.curClassId then
                isCurrentClass = false  -- Skip if explicitly for different class
            end
            if isCurrentClass then
                renderGroup(group)
                drawnGroups = drawnGroups + 1
            end
        else
            renderGroup(group)
            drawnGroups = drawnGroups + 1
        end
    end
end
ConPrintf("DEBUG: Drew %d group backgrounds", drawnGroups)
```

**Pros**:
- Filters at loop level
- Only draws relevant groups for current class
- Adds diagnostic logging

**Cons**:
- Assumes groups have classId field (might not exist)
- Might skip too many groups

### Option C: Add Diagnostic Logging + Option A (RECOMMENDED)
**Approach**: Combine logging with guards to identify exact failure

**File**: `PassiveTreeView.lua`

**Step 1 - Add logging around group loop**:
```lua
ConPrintf("DEBUG: About to draw group backgrounds")
-- Draw the group backgrounds
for _, group in pairs(tree.groups) do
    if not group.isProxy then
        ConPrintf("DEBUG: Drawing group, has background=%s",
            tostring(group.background ~= nil))
        renderGroup(group)
    end
end
ConPrintf("DEBUG: Group backgrounds drawn, about to draw connectors")
```

**Step 2 - Add guards in renderGroup (Option A)**

**Pros**:
- Identifies exact crashing group
- Guards prevent crash
- Most diagnostic approach

**Cons**:
- Verbose logging (can be removed after fix)

## Recommendation

**Priority**: Option C (Logging + Guards)

**Rationale**:
1. We need to confirm crash is in renderGroup
2. Logging will show which group causes crash
3. Guards ensure crash won't repeat
4. Can refine fix after seeing diagnostic data

## Next Steps

1. Implement Option C (logging + guards)
2. Test to see which group crashes
3. If crash continues, investigate connector setup functions
4. Document findings and final fix in LESSONS_LEARNED.md
