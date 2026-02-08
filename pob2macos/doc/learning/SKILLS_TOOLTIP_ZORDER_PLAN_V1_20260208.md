# Skills Tab Tooltip Z-Order Fix Plan V1 (2026-02-08)

## Task
Extend deferred tooltip system to cover Skills tab (and all non-TREE tabs).

## Root Cause
Build.lua L1912: `main.deferTooltips = (self.viewMode == "ITEMS")`
Only ITEMS tab tooltips are deferred. In SKILLS tab, dropdown tooltips (e.g. weapon stats for "Socketed in" dropdown) render during tab Draw(), then Build.lua's top bar/sidebar backgrounds draw over them.

## Proposed Fix
Change L1912 from:
```lua
main.deferTooltips = (self.viewMode == "ITEMS")
```
To:
```lua
main.deferTooltips = (self.viewMode ~= "TREE")
```

This enables deferred tooltips for ALL tabs except TREE (which has known viewport/white rectangle issues with deferral).

## Risk Assessment
- **Very low risk**: Same mechanism already proven working for ITEMS tab
- **TREE exclusion**: Maintains existing behavior for TREE tab (known issue)
- **Other tabs**: SKILLS, CONFIG, CALCS, NOTES, PARTY, IMPORT all use standard viewports
- **Rollback**: Revert single line

## Success Criteria
1. Skills tab dropdown tooltips render above all UI elements
2. No regressions in ITEMS tab tooltip behavior
3. No white rectangle artifacts in TREE tab
4. Zero new errors in logs
