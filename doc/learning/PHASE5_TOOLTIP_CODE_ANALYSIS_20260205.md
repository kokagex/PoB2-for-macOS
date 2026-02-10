# Phase 5: Tooltip Code Analysis - Step 1

**Date**: 2026-02-05
**Analyst**: Code Analysis
**Duration**: 15 minutes

---

## 1. AddNodeTooltip Method Location

**File**: `PassiveTreeView.lua`
**Line**: 1649-2007 (358 lines)

---

## 2. Tooltip Class Dependencies

### External Dependencies Found

1. **build.itemsTab** (Multiple accesses):
   - Line 1655, 1863: `GetSocketAndJewelForNodeID(node.id)`
   - Line 1657, 1865: `AddItemTooltip(tooltip, jewel, { nodeId = node.id })`
   - Line 1796: `activeItemSet.useSecondWeaponSet`
   - Line 1828: `sockets`
   - Line 1829: `activeSocketList`
   - **Usage**: Jewel socket handling, weapon set detection

2. **build.calcsTab** (CRITICAL - Most likely to crash in MINIMAL mode):
   - Line 1890: `GetMiscCalculator(build)` - Called when `self.showStatDifferences` is true
   - Line 1899: `mainEnv.grantedPassives[node.id]`
   - Line 1916: `AddStatComparesToTooltip()`
   - **Usage**: Stat difference calculations (allocate vs unallocate)

3. **build.spec** (Deep tree access):
   - Line 1802, 1814: `build.spec` passed to mergeStats()
   - Line 1819: `build.spec.tree:ProcessStats(mNode)`
   - Line 1831: `build.spec.nodes[id]`
   - Line 1958, 1986: `build.spec.nodes[nodeId]`
   - **Usage**: Jewel radius processing, node processing

4. **Node Properties** (Safe - always available):
   - `node.dn` - Display name
   - `node.sd` - Stat descriptions array
   - `node.reminderText` - Reminder text array
   - `node.flavourText` - Flavour text string
   - `node.mods` - Mod information array
   - `node.type`, `node.alloc`, `node.path`, etc.

---

## 3. modList, build.treeTab, build.itemsTab Accesses

**modList**: No direct access found (used indirectly through build.spec processing)

**build.treeTab**: No direct access found in AddNodeTooltip

**build.itemsTab**: YES - Extensive access (see section 2.1 above)
- **Risk**: MEDIUM - Used for jewel socket handling
- **Mitigation**: Skip jewel socket sections in MINIMAL mode

**build.calcsTab**: YES - Critical access
- **Risk**: HIGH - Likely not initialized in MINIMAL mode
- **Mitigation**: Skip stat difference section entirely in MINIMAL mode

---

## 4. MINIMAL Mode Safe Tooltip Design

### Minimal Viable Tooltip

Show only node properties that don't require full build infrastructure:

1. **Node Name** (Lines 1676-1677)
   - `self:AddNodeName(tooltip, node, build)`
   - Safe: Uses only node.dn and node properties

2. **Node Stat Descriptions** (Lines 1849-1858)
   - `node.sd` array (basic stat lines)
   - Potentially safe if we skip jewel radius processing (line 1852-1853)
   - **Decision**: Show node.sd directly, skip processTimeLostModsAndGetLocalEffect()

3. **Reminder Text** (Lines 1875-1880)
   - `node.reminderText` array
   - Safe: No external dependencies

4. **Flavour Text** (Lines 1882-1886)
   - `node.flavourText` string
   - Safe: No external dependencies

5. **Tips** (Lines 2002-2006)
   - Simple string tips
   - Safe: No external dependencies

### Sections to SKIP in MINIMAL Mode

1. **Jewel Socket Handling** (Lines 1654-1673, 1860-1872)
   - Requires build.itemsTab

2. **Dev Mode Info** (Lines 1679-1702)
   - Not critical, can keep if launch.devModeAlt is available

3. **Jewel Radius Processing** (Lines 1852-1853)
   - Calls isNodeInARadius() and processTimeLostModsAndGetLocalEffect()
   - Requires build.itemsTab and build.spec

4. **Stat Differences** (Lines 1889-1931)
   - CRITICAL: Requires build.calcsTab
   - MUST skip in MINIMAL mode

5. **Pathing Distance** (Lines 1933-1947)
   - Uses node.path and node.pathDist
   - Potentially safe, but node.path may not exist in MINIMAL mode
   - **Decision**: Skip if node.path is nil

6. **Gold Cost Calculation** (Lines 1948-1979)
   - Requires data.goldRespecPrices and build.characterLevel
   - Potentially safe, but not critical
   - **Decision**: Skip in MINIMAL mode

7. **Unlock Constraints** (Lines 1983-1999)
   - Requires build.spec.nodes
   - **Decision**: Skip in MINIMAL mode

---

## 5. Recommended MINIMAL Tooltip Implementation

```lua
function PassiveTreeViewClass:AddNodeTooltip(tooltip, node, build, incSmallPassiveSkillEffect)
    -- MINIMAL mode: Show basic tooltip only
    if _G.MINIMAL_PASSIVE_TEST then
        -- 1. Node name
        tooltip:AddLine(20, node.dn or "Unknown Node")

        -- 2. Basic stat descriptions (if available)
        if node.sd and #node.sd > 0 then
            tooltip:AddLine(16, "")
            for _, line in ipairs(node.sd) do
                tooltip:AddLine(16, "^7" .. line)
            end
        end

        -- 3. Reminder text (if available)
        if node.reminderText then
            tooltip:AddSeparator(14)
            for _, line in ipairs(node.reminderText) do
                tooltip:AddLine(14, "^xA0A080" .. line)
            end
        end

        -- 4. Flavour text (if available and enabled)
        if node.flavourText and main.showFlavourText then
            tooltip:AddSeparator(14)
            tooltip:AddLine(16, colorCodes.UNIQUE .. node.flavourText)
        end

        -- 5. Tips
        tooltip:AddSeparator(14)
        tooltip:AddLine(14, colorCodes.TIP .. "Tip: Hold Ctrl to hide this tooltip.")

        return  -- Early return, skip full tooltip logic
    end

    -- ... Full tooltip logic for non-MINIMAL mode (existing code)
end
```

---

## 6. Analysis Summary

**Question 1: AddNodeTooltip メソッドはどこで何をしているか？**
- Location: PassiveTreeView.lua lines 1649-2007
- Purpose: Generates tooltip content for passive tree nodes
- Complexity: 358 lines, highly dependent on full build infrastructure

**Question 2: Tooltip クラスの依存関係は何か？**
- Tooltip class itself is safe (just content container)
- AddNodeTooltip method requires: build.itemsTab, build.calcsTab, build.spec
- Most critical: build.calcsTab for stat difference calculations

**Question 3: modList, build.treeTab, build.itemsTab へのアクセスはあるか？**
- modList: Indirect access through build.spec processing
- build.treeTab: No direct access
- build.itemsTab: YES - extensive access for jewel sockets
- **Additional**: build.calcsTab - CRITICAL dependency

**Question 4: MINIMAL mode で安全に実装できる最小限の Tooltip は何か？**
- Node name (node.dn)
- Basic stat descriptions (node.sd) - without jewel processing
- Reminder text (node.reminderText)
- Flavour text (node.flavourText)
- Simple tips
- **Total lines**: ~25 lines for MINIMAL mode implementation

---

**Status**: ✅ Analysis Complete
**Next Step**: Step 2 - Implementation (Artisan)
**Estimated Risk**: MEDIUM (if we skip all build.* dependencies correctly)
