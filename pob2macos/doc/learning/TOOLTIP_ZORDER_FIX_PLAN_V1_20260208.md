# Tooltip Z-Order Fix Plan V1 (2026-02-08)

## Task
Fix displayItemTooltip z-order so it renders ABOVE Build.lua's top bar/sidebar backgrounds and controls.
Fix tooltip boundary clamping so large tooltips don't extend below screen edge.

## Root Cause Analysis

### Issue 1: Z-Order
**Drawing order (current)**:
1. ItemsTab:Draw() at ~L1216-1228:
   - DrawControls(viewPort)
   - scrollBars
   - **displayItemTooltip:Draw()** ← drawn here, at default draw layer
2. Build.lua OnFrame continues at L1926-1944:
   - L1928: `SetDrawLayer(5)` ← raises layer
   - L1929: `ResetViewport()`
   - L1931-1936: Draw top bar background (solid rectangles)
   - L1938-1942: Draw side bar background (solid rectangles)
   - L1944: `self:DrawControls(main.viewPort)` ← Build's buttons (Back, Save, etc.)

Because the tooltip is drawn before `SetDrawLayer(5)`, the layer-5 content (backgrounds + Build controls) covers it.

### Issue 2: Boundary Clamping
Tooltip:Draw() has boundary clamping (L320-331) but ONLY when `w` and `h` are provided.
ItemsTab calls `self.displayItemTooltip:Draw(x, y, nil, nil, viewPort)` with nil w/h, so no clamping occurs.

## Proposed Solution

### Strategy: Move tooltip drawing to Build.lua OnFrame (LAST position, highest layer)

**Step 1**: Remove tooltip drawing from ItemsTab:Draw() (L1224-1228)
- But keep the `displayItem` and `displayItemTooltip` objects - they're still set up there

**Step 2**: Add tooltip drawing at the very END of Build.lua OnFrame, AFTER L1944
- Set a higher draw layer (e.g., layer 10) so it's above everything
- Add boundary clamping before calling Draw

**Step 3**: Add boundary clamping
- When w/h are nil, the Tooltip:Draw doesn't clamp
- We'll add manual clamping of the position BEFORE calling Draw

### Implementation Details

#### ItemsTab.lua changes (L1224-1228):
```lua
-- REMOVE these lines:
-- Draw display item tooltip AFTER DrawControls so it renders on top of all controls
if self.displayItem then
    local x, y = self.controls.displayItemTooltipAnchor:GetPos()
    self.displayItemTooltip:Draw(x, y, nil, nil, viewPort)
end
```

#### Build.lua changes (after L1944):
```lua
    self:DrawControls(main.viewPort)

    -- Draw Items tab display tooltip LAST (on top of everything)
    if self.viewMode == "ITEMS" and self.itemsTab and self.itemsTab.displayItem then
        SetDrawLayer(nil, 100)
        local x, y = self.itemsTab.controls.displayItemTooltipAnchor:GetPos()
        local ttW, ttH = self.itemsTab.displayItemTooltip:GetSize()
        -- Boundary clamping
        if x + ttW > main.screenW then
            x = main.screenW - ttW
        end
        if y + ttH > main.screenH then
            y = main.screenH - ttH
        end
        if x < 0 then x = 0 end
        if y < 0 then y = 0 end
        self.itemsTab.displayItemTooltip:Draw(x, y, nil, nil, main.viewPort)
        SetDrawLayer(nil, 0)
    end
end
```

### Diagnostic approach
Before the if-block, add a temporary debug ConPrintf to verify the condition evaluates correctly:
```lua
ConPrintf("TOOLTIP_ZORDER: viewMode=%s itemsTab=%s displayItem=%s",
    tostring(self.viewMode),
    tostring(self.itemsTab ~= nil),
    tostring(self.itemsTab and self.itemsTab.displayItem ~= nil))
```

## Risk Assessment
- **Low risk**: Only moving drawing code, not changing logic
- **Rollback**: Re-add the lines to ItemsTab if it fails
- **Edge cases**: Need to verify `self.itemsTab.controls.displayItemTooltipAnchor` is accessible from Build.lua

## Success Criteria
1. Tooltip appears ABOVE top bar buttons
2. Tooltip doesn't extend below screen bottom
3. No new errors in logs
4. Visual verification via screenshot

## Timeline
- Implementation: 10 minutes
- Testing: 5 minutes (launch + screenshot)
- Total: 15 minutes
