# Tooltip Z-Order Unified Fix - Plan V2

**Date**: 2026-02-08
**Task**: Fix ALL tooltip z-order issues so tooltips render above ALL controls

## Root Cause Analysis

### Core Problem
`SetDrawLayer` is a **NO-OP** in our Metal backend (see `sg_state.cpp:93-100`):
```cpp
void SetDrawLayer(int layer, int sublayer) {
    // Layer sorting not implemented in MVP
}
```

This means the ONLY way to control z-order is **actual draw call order**. Whatever is drawn LAST appears on top.

### Complete Draw Order (current)

```
1. Build.lua OnFrame:
   a. Tab content: itemsTab:Draw() → includes ItemsTab:DrawControls()
      - ALL ItemsTab controls drawn here (buttons, slots, item lists)
      - ListControl tooltips drawn here (SetDrawLayer(nil,100) is no-op)
      - DropDownControl tooltips drawn here
      - BUT displayItemTooltip NOT drawn here (moved to Build.lua)
   b. Top bar background (SetDrawLayer(5) also no-op)
   c. Sidebar background
   d. Build:DrawControls() → Build-level controls (tab buttons, dropdowns)
   e. displayItemTooltip → drawn LAST in Build.lua ✓

2. Main.lua OnFrame (AFTER Build.lua):
   a. Toast messages
   b. Bottom bar background
   c. Main:DrawControls() → Main-level controls ← DRAWS AFTER Build.lua!
   d. Popups (overlay + popup draw)
   e. Drag text

3. Launch.lua OnFrame (AFTER Main.lua):
   a. Error/restart overlays (SetDrawLayer(1000) also no-op)
```

### Issue Identification

**Issue 1: "Craft item..." / "Create custom..." buttons appearing above tooltip**
These are ItemsTab controls (L260, L266), drawn by `ItemsTab:DrawControls()` at step 1a.
The displayItemTooltip at step 1e draws AFTER them. So the tooltip SHOULD be above.
However, the buttons themselves could have tooltips (from TooltipHost) - this is separate.

Wait - the user says these buttons appear ON TOP. Let me re-examine. The buttons are drawn at step 1a inside `itemsTab:Draw()` → `self:DrawControls(viewPort)` at ItemsTab.lua L1216.
The displayItemTooltip is drawn at step 1e, which is AFTER. So it should be on top.

The actual issue might be:
- The "Craft item" and "Create custom" button TEXT/background overlaps with the tooltip area
- These buttons are NOT re-drawn after the tooltip
- So the tooltip SHOULD cover them

Let me check if Main.lua controls or bottom bar draws on top at step 2.

Main:DrawControls at step 2c draws AFTER Build.lua, so any Main-level control that
overlaps with tooltip area would appear on top. But Main controls are at the bottom.

**WAIT**: Let me re-read the issue. The user says the buttons "appear ABOVE the tooltip".
This means the tooltip renders UNDERNEATH those buttons. But those buttons are drawn
at step 1a and the tooltip at step 1e. Unless... the tooltip is being drawn somewhere
ELSE too, or the buttons are being drawn AFTER the tooltip.

Possible cause: The "Craft item" and "Create custom" buttons might be Build-level controls
(registered in Build.controls), not ItemsTab.controls. Let me verify.

Actually, they are at ItemsTab.lua L260-266: `self.controls.craftDisplayItem` and
`self.controls.newDisplayItem`. These are ItemsTab controls.

But Build.lua at step 1d calls `self:DrawControls(main.viewPort)` - which draws
Build-level controls. The Build controls include tab buttons at the top.

**KEY INSIGHT**: The ItemsTab controls (Craft item, Create custom) are drawn at step 1a
inside itemsTab:Draw(). Then the Build controls (top bar tab buttons) are drawn at step 1d.
Then the displayItemTooltip is drawn at step 1e.

So the displayItemTooltip SHOULD be on top of EVERYTHING in Build.lua.

But the user reports it's not on top of "Craft item" / "Create custom" buttons.
This could mean those buttons are somehow drawn LATER than step 1a.

HMMMM - unless these controls' position overlaps with the top bar area (y < 32),
and the top bar background (step 1b) covers them. Then the Build controls re-draw
buttons in the top bar area (step 1d).

OR: The issue is that ALL tooltips from controls drawn at step 1a (hover tooltips from
ItemSlotControl, ListControl, DropDownControl) are drawn during step 1a, BEFORE the
top bar (step 1b), sidebar (step 1c), and Build controls (step 1d). So hover tooltips
from item slots and item lists appear UNDER the top bar and sidebar.

### Multiple Tooltip Sources

1. **displayItemTooltip** - Fixed in Build.lua (step 1e) ✓
2. **ItemSlotControl hover tooltip** - Drawn during ItemsTab:DrawControls() (step 1a) ✗
3. **ItemListControl hover tooltip** - Drawn during ListControl:Draw() (step 1a) ✗
4. **ItemDBControl hover tooltip** - Drawn during ListControl:Draw() (step 1a) ✗
5. **ButtonControl tooltip** - Drawn during ButtonControl:Draw() (step 1a) ✗
6. **PassiveTreeView tooltip** - Drawn during treeTab:Draw() (step 1a, separate tab) ✗
7. **All other control tooltips** - Drawn inline during Draw() methods

## Proposed Solution

### Approach: Deferred Tooltip Drawing

Since we can't use SetDrawLayer for z-ordering, we need to defer ALL tooltip drawing
to the very end of the frame. The simplest approach:

**Add a tooltip queue to the main object:**
1. During controls' Draw methods, instead of drawing tooltips immediately, queue them
2. At the very end of Build.lua OnFrame, draw ALL queued tooltips

**Implementation:**
- Add `main.tooltipDrawQueue = {}` reset at start of each frame
- Modify tooltip drawing to queue instead of direct draw
- Draw queue at end of Build.lua OnFrame (after Build:DrawControls)

**BUT this requires modifying many control files** (ButtonControl, DropDownControl,
ListControl, etc.) which is invasive.

### Simpler Approach: Two-Pass Drawing

A simpler approach that requires fewer changes:

The ControlHost:DrawControls iterates controls and calls control:Draw().
Each control's Draw method draws the control AND its tooltip.

We can modify ControlHost:DrawControls to do TWO passes:
1. First pass: Draw all controls (with noTooltip=true to suppress tooltips)
2. Second pass: Draw only tooltips for hovered controls

But this ALSO requires changes to DrawControls and all control Draw methods.

### Simplest Approach: Override DrawControls for ItemsTab

The ItemsTab.Draw method calls `self:DrawControls(viewPort)` at L1216.
We can intercept this to collect tooltip draw info:

1. In ItemsTab:Draw, call DrawControls with noTooltip=true for the first pass
2. Then call DrawControls tooltip-only at the end of Build.lua OnFrame

Actually, looking at the code more carefully:

- ButtonControl:Draw passes `noTooltip` from DrawControls to suppress tooltips
- ListControl:Draw also receives `noTooltip` from viewPort context
- DropDownControl:Draw also respects noTooltip

Wait, let me re-read ControlHostClass:DrawControls:

```lua
function ControlHostClass:DrawControls(viewPort, selControl)
    for _, control in pairs(self.controls) do
        if control:IsShown() and control.Draw then
            control:Draw(viewPort, (self.selControl and self.selControl.hasFocus ...) or ...)
        end
    end
end
```

The second argument to control:Draw is `noTooltip` (a boolean derived from focus state).
This is not a simple true/false suppress - it's "don't draw tooltip if another control has focus".

For our use case, we'd want a way to say "draw everything EXCEPT tooltips" then later
"draw ONLY tooltips".

### RECOMMENDED Approach: Direct tooltip queue

Add a lightweight tooltip queue mechanism:

1. Add `main.deferTooltips = false` and `main.tooltipQueue = {}`
2. When `main.deferTooltips = true`, tooltip:Draw() adds draw info to queue instead of drawing
3. At end of Build.lua OnFrame, set `main.deferTooltips = false` and draw all queued tooltips

This only requires modifying:
- Tooltip.lua:Draw() - check main.deferTooltips
- Build.lua:OnFrame() - set flag and flush queue

**Risk**: LOW - The change is isolated. Only Tooltip:Draw needs modification.
**Rollback**: Remove the deferral flag check.

## Implementation Steps

### Step 1: Modify Tooltip.lua:Draw to support deferred mode
- Check `main.deferTooltips` at start of Draw
- If true, store draw params in `main.tooltipQueue` and return
- If false, draw normally (existing behavior)

### Step 2: Modify Build.lua OnFrame
- At start of tab content drawing, set `main.deferTooltips = true`
- After `self:DrawControls(main.viewPort)`, set `main.deferTooltips = false`
- Flush and draw all queued tooltips
- Keep existing displayItemTooltip code (it's already at the right place)

### Step 3: Test with visual verification
- Launch app, navigate to Items tab
- Hover over item in list - tooltip should be above top bar
- Select item - displayItemTooltip should be above all buttons
- Check Tree tab tooltips still work

### Step 4: Clean up
- Remove SetDrawLayer(nil, 100) / SetDrawLayer(nil, 0) calls that were no-ops
- Remove debug code if any

## Timeline
- Step 1: 15 minutes
- Step 2: 15 minutes
- Step 3: 10 minutes (requires user verification)
- Step 4: 5 minutes
- Total: ~45 minutes

## Risk Assessment
- LOW risk: Tooltip.Draw modification is additive (new code path, existing path unchanged)
- Rollback: Set main.deferTooltips = false permanently
- Edge case: Nested tooltips (unlikely in this UI)
- Edge case: Tooltip queue not cleared between frames (mitigated by clearing at start)

## Success Criteria
- displayItemTooltip renders above ALL UI elements
- Hover tooltips on item slots render above top bar/sidebar
- Hover tooltips on item list render above top bar/sidebar
- Passive tree tooltips still work
- No regressions in other tabs
