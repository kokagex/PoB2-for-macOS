# S/A Filter Button Verification Plan (v2) - 2026-02-08

## Root Cause (Confirmed)
S/A click → sortGemsBy set → PopulateGemList/BuildList → falls through to EditControl:OnKeyDown → OnFocusGained → UpdateSortCache → BuildList("") → filter overwritten

## Fix Applied
In GemSelectControl.lua OnKeyDown (~line 817):
- When sortGemsBy is non-nil (S/A clicked):
  - `self.dropped = true` (manually open dropdown)
  - `self:UpdateSortCache()` (filter gems)
  - `self:BuildList("")` (build filtered list)
  - `return self` (prevent EditControl propagation)
- When sortGemsBy is nil (gem name area click): falls through to EditControl as before

## Verification Steps
1. Launch app → Skills tab → hover gem slot
2. Click S button → dropdown opens with Support gems only
3. Click A button → dropdown opens with Active gems only  
4. Click gem name area → unfiltered dropdown (existing behavior preserved)

## Success Criteria
- S click: only Support gems in dropdown
- A click: only Active gems in dropdown
- Normal click: all gems shown

## Risk: Low
- Single file change, early return only on specific condition
- Rollback: remove the if-block, restore original PopulateGemList/BuildList call

## Timeline: 5 minutes (visual verification only)
