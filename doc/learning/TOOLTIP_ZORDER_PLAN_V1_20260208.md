# Items Tab displayItemTooltip Z-Order Fix - Plan V1

**Date**: 2026-02-08
**Task**: Fix tooltip being drawn under other controls in Items tab

## Root Cause Analysis

### Current State
- Previous session moved tooltip drawing from ItemsTab.lua to Build.lua OnFrame (L1946-1957)
- ItemsTab.lua L1224: tooltip draw code commented out, replaced with note
- Build.lua draws tooltip AFTER all other rendering including DrawControls
- Debug code added: red rectangle + "TOOLTIP DEBUG" text at tooltip position
- **NOT YET TESTED** - previous session ended before visual verification

### Drawing Order (confirmed via code read)
1. Build.lua L1921: `itemsTab:Draw()` - tab content + controls
2. Build.lua L1928-1942: Top bar/sidebar backgrounds
3. Build.lua L1944: `Build:DrawControls()` - Build level controls (top bar, sidebar)
4. Build.lua L1946-1957: **Tooltip debug + tooltip draw** ← LAST in Build
5. Main.lua L443-449: Bottom bar + Main controls (bottom of screen only)
6. Launch.lua L126: Error popups (normally none)

### Hypothesis
- **H1 (HIGH)**: The tooltip fix IS working. Previous session never tested. Visual verification will confirm.
- **H2 (MEDIUM)**: `self.itemsTab.displayItem` is nil when code runs (item not properly selected)
- **H3 (LOW)**: Tooltip position is off-screen or at (0,0)

## Proposed Solution

### Step 1: Visual Verification
1. Sync files to app bundle
2. Launch app
3. Navigate to Items tab, select an item
4. Take screenshot to verify debug red rectangle
5. Check ConPrintf output in terminal for coordinates

### Step 2: Analyze Result
- If red rectangle visible ON TOP → Fix is working, clean up debug code
- If red rectangle visible but UNDER → Something draws after Build.OnFrame that overlaps
- If red rectangle NOT visible → Condition not met or coordinates wrong
- If no item selected → Check displayItem population

### Step 3: Clean Up
- Remove debug code (red rectangle, ConPrintf)
- Keep tooltip draw in Build.lua OnFrame

## Success Criteria
- Red debug rectangle renders on top of all other UI elements
- Tooltip renders on top when item is selected
- No regressions in other tabs

## Timeline
- Step 1: 5 minutes (sync + launch + screenshot)
- Step 2: 5-15 minutes (depends on findings)
- Step 3: 5 minutes (cleanup)
- Total: 15-25 minutes

## Risk
- LOW: Changes are isolated to draw order, easily reversible
- Rollback: Restore tooltip draw to ItemsTab.lua
