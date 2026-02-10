# DropDown List Z-Order Fix Plan V1 (2026-02-08)

## Task
Fix DropDown list z-order so open dropdown lists render ABOVE all other controls in the Skills tab (and everywhere else).

## Root Cause Analysis

### Issue
- `DropDownControl:Draw()` uses `SetDrawLayer(nil, 5)` for the open dropdown list (lines 258, 279, 328)
- On Windows, `SetDrawLayer` works correctly so dropdown lists render above other controls
- On our Metal backend, `SetDrawLayer` is a NO-OP, so draw order = z-order
- `ControlHost:DrawControls()` uses `pairs(self.controls)` which is UNORDERED in Lua
- When the "Socketed in" dropdown draws its open list, and another control (GemSelectControl) draws after it, the gem control covers the dropdown list

### Solution: Two-Pass DrawControls

Modify `ControlHost:DrawControls()` to do two passes:
1. **Pass 1**: Draw all controls normally
2. **Pass 2**: Re-draw any open DropDownControl or GemSelectControl dropdown lists

This is analogous to the deferred tooltip pattern already in Build.lua.

**Key insight**: DropDownControl:Draw() already has a `self.dropped` flag. We just need to call it again after all other controls are drawn, but ONLY the dropped portion. However, redrawing the entire DropDownControl is simpler and the duplicate background draw is invisible.

**Simplest approach**: After the main DrawControls loop, iterate again and for any control that has `dropped == true`, call its Draw() again. The second draw will overlay on top, ensuring the dropdown list appears above everything.

Wait - this would re-draw the entire control including its closed portion, causing double-rendering. Better approach:

**Best approach**: Two-pass in DrawControls:
1. Pass 1: Draw all controls, but skip controls that have `dropped == true`
2. Pass 2: Draw only controls that have `dropped == true`

This ensures open dropdowns draw LAST (on top of everything).

## Implementation

### File: ControlHost.lua (line 88-94)

Change from:
```lua
function ControlHostClass:DrawControls(viewPort, selControl)
    for _, control in pairs(self.controls) do
        if control:IsShown() and control.Draw then
            control:Draw(viewPort, ...)
        end
    end
end
```

To:
```lua
function ControlHostClass:DrawControls(viewPort, selControl)
    -- Pass 1: Draw non-dropped controls first
    for _, control in pairs(self.controls) do
        if control:IsShown() and control.Draw and not control.dropped then
            control:Draw(viewPort, ...)
        end
    end
    -- Pass 2: Draw dropped controls last (on top)
    for _, control in pairs(self.controls) do
        if control:IsShown() and control.Draw and control.dropped then
            control:Draw(viewPort, ...)
        end
    end
end
```

### Risk Assessment
- **Low risk**: Only changes draw order, not logic
- **No behavioral change on Windows**: Same controls drawn, just in different order
- **Works for ALL dropdowns**: Not just Skills tab - fixes Items tab, Config tab, etc.
- **Rollback**: Revert to single-pass loop

### Success Criteria
1. "Socketed in" dropdown list renders above gem name fields
2. GemSelectControl dropdown renders above other controls
3. No visual regressions in other tabs
4. No new errors in logs

### Timeline
- Implementation: 5 minutes
- Sync to app bundle: 1 minute
- Testing: 5 minutes (launch + screenshot)
- Total: ~11 minutes
