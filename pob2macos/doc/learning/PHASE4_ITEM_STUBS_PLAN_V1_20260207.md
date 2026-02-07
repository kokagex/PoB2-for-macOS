# Phase 4: Item Stubs - Implementation Plan

**Date**: 2026-02-07
**Version**: V1
**Status**: Awaiting Approval
**Estimated Duration**: 4 hours (Original: 12h, Optimized based on Phase 3 success)

---

## 1. Current Situation

### Phase 3 Complete ✅
- Passive Tree display functional
- Character Info Panel displayed (left side)
- Node allocation working
- Stats calculated from nodes
- Zero errors, stable operation

### What's Missing
- Item slot display (equipment visualization)
- No actual items (Phase 5)
- No item stats (Phase 5)

### Goal of Phase 4
Display **13 item slots** as placeholders:
1. Weapon (Main Hand)
2. Weapon (Off Hand)
3. Helmet
4. Body Armour
5. Gloves
6. Boots
7. Amulet
8. Ring 1
9. Ring 2
10. Belt
11. Charm 1
12. Charm 2
13. Charm 3

---

## 2. Proposed Solution

### Strategy: Simple Grid Layout

**Right Side Panel** (opposite of Character Info Panel):
- Display 13 item slots in grid
- Each slot: Icon + Label ("Weapon", "Helmet", etc.)
- Placeholder text: "Empty Slot"
- No click handlers (Phase 5)
- No item data (Phase 5)

**Visual Layout**:
```
Right side of screen:
┌─────────────────┐
│  [Weapon]       │  Main Hand
│  [Weapon]       │  Off Hand
│  [Helmet]       │
│  [Body Armour]  │
│  [Gloves]       │
│  [Boots]        │
│  [Amulet]       │
│  [Ring]         │  Ring 1
│  [Ring]         │  Ring 2
│  [Belt]         │
│  [Charm]        │  Charm 1
│  [Charm]        │  Charm 2
│  [Charm]        │  Charm 3
└─────────────────┘
```

---

## 3. Implementation Steps

### Step 1: BuildStub Data Structure (30 minutes)

**Goal**: Add item slots data to BuildStub

**Files to Modify**:
- `BuildStub.lua` - Add itemSlots table

**Implementation**:
```lua
function BuildStubClass:Init()
    -- Existing character data...

    -- Phase 4: Item slots (stub for now)
    self.itemSlots = {
        { id = "Weapon1", name = "Weapon", label = "Main Hand", empty = true },
        { id = "Weapon2", name = "Weapon", label = "Off Hand", empty = true },
        { id = "Helmet", name = "Helmet", label = "Helmet", empty = true },
        { id = "Body", name = "Body Armour", label = "Body Armour", empty = true },
        { id = "Gloves", name = "Gloves", label = "Gloves", empty = true },
        { id = "Boots", name = "Boots", label = "Boots", empty = true },
        { id = "Amulet", name = "Amulet", label = "Amulet", empty = true },
        { id = "Ring1", name = "Ring", label = "Ring 1", empty = true },
        { id = "Ring2", name = "Ring", label = "Ring 2", empty = true },
        { id = "Belt", name = "Belt", label = "Belt", empty = true },
        { id = "Charm1", name = "Charm", label = "Charm 1", empty = true },
        { id = "Charm2", name = "Charm", label = "Charm 2", empty = true },
        { id = "Charm3", name = "Charm", label = "Charm 3", empty = true },
    }
end
```

**Success Criteria**:
- BuildStub.itemSlots initialized
- 13 slots defined
- Each slot has id, name, label, empty fields

**Testing**:
- Log: `ConPrintf("BuildStub: %d item slots", #self.itemSlots)` → 13

---

### Step 2: Item Slots Display (2 hours)

**Goal**: Draw item slots on right side of screen

**Files to Modify**:
- `Build.lua` - Add DrawItemSlots() in OnFrameMinimal()

**Implementation**:
```lua
function buildMode:OnFrameMinimal(inputEvents)
    -- Existing code...

    -- Draw TreeTab (passive tree)
    if self.treeTab then
        self.treeTab:Draw(main.viewPort, inputEvents)
    end

    -- Phase 4: Set draw layer for UI elements on top of tree
    SetDrawLayer(10)

    -- Phase 2: Draw Character Info Panel (left side)
    if self.buildStub then
        local panelX = 20
        local panelY = 100
        -- ... existing Character Info Panel code ...
    end

    -- Phase 4: Draw Item Slots (right side)
    if self.buildStub and self.buildStub.itemSlots then
        self:DrawItemSlots()
    end
end

function buildMode:DrawItemSlots()
    local screenW, screenH = GetScreenSize()
    local panelX = screenW - 250  -- 250px from right edge
    local panelY = 100
    local lineHeight = 40  -- Larger for item slots
    local slotWidth = 200
    local slotHeight = 32

    SetDrawColor(1, 1, 1)  -- White

    -- Header
    DrawString(panelX, panelY, "LEFT", 18, "FIXED", "^xFFFF70Item Slots")
    panelY = panelY + lineHeight

    -- Draw each slot
    for i, slot in ipairs(self.buildStub.itemSlots) do
        -- Slot background (dark gray rectangle)
        SetDrawColor(0.2, 0.2, 0.2)
        DrawImage(nil, panelX, panelY, slotWidth, slotHeight)

        -- Slot border (light gray)
        SetDrawColor(0.5, 0.5, 0.5)
        -- Top border
        DrawImage(nil, panelX, panelY, slotWidth, 2)
        -- Bottom border
        DrawImage(nil, panelX, panelY + slotHeight - 2, slotWidth, 2)
        -- Left border
        DrawImage(nil, panelX, panelY, 2, slotHeight)
        -- Right border
        DrawImage(nil, panelX + slotWidth - 2, panelY, 2, slotHeight)

        -- Slot label
        SetDrawColor(1, 1, 1)
        local labelText = slot.empty and (slot.name .. " (Empty)") or slot.name
        DrawString(panelX + 5, panelY + 8, "LEFT", 14, "FIXED", labelText)

        panelY = panelY + slotHeight + 5
    end
end
```

**Success Criteria**:
- 13 item slots visible on right side
- Each slot has gray background + border
- Labels show "Weapon (Empty)", "Helmet (Empty)", etc.
- No overlap with Passive Tree

**Testing**:
- Visual verification: Screenshot shows 13 slots
- No crashes, zero errors

---

### Step 3: Visual Refinement (1 hour)

**Goal**: Improve visual appearance

**Enhancements**:
1. Color-code slot types:
   - Weapons: Red tint
   - Armour (Helmet/Body/Gloves/Boots): Blue tint
   - Accessories (Amulet/Ring/Belt): Green tint
   - Charms: Yellow tint

2. Add slot icons (if available):
   - Check `Assets/` for item slot icons
   - If not available, use colored rectangles

**Implementation**:
```lua
function buildMode:DrawItemSlots()
    -- ... existing code ...

    for i, slot in ipairs(self.buildStub.itemSlots) do
        -- Color-code by slot type
        local slotColor = {1, 1, 1}  -- Default white
        if slot.name == "Weapon" then
            slotColor = {1, 0.5, 0.5}  -- Red tint
        elseif slot.name == "Helmet" or slot.name == "Body Armour" or slot.name == "Gloves" or slot.name == "Boots" then
            slotColor = {0.5, 0.5, 1}  -- Blue tint
        elseif slot.name == "Amulet" or slot.name == "Ring" or slot.name == "Belt" then
            slotColor = {0.5, 1, 0.5}  -- Green tint
        elseif slot.name == "Charm" then
            slotColor = {1, 1, 0.5}  -- Yellow tint
        end

        SetDrawColor(slotColor[1], slotColor[2], slotColor[3])
        -- Draw slot background with color tint...
    end
end
```

**Success Criteria**:
- Slots have color-coded backgrounds
- Visual distinction between slot types
- Clean, readable layout

**Testing**:
- Screenshot shows color-coded slots
- User confirms: "I can see different slot types clearly"

---

### Step 4: Integration Test (30 minutes)

**Goal**: Verify all Phase 1-4 features work together

**Test Cases**:
1. ✅ Passive Tree displays correctly
2. ✅ Character Info Panel (left side) visible
3. ✅ Item Slots (right side) visible
4. ✅ Node allocation still works
5. ✅ Stats update after node allocation
6. ✅ No overlap between UI elements
7. ✅ Zero crashes, zero errors

**Testing**:
- Launch app
- Allocate 5 nodes
- Take screenshot showing all UI elements
- Verify Character Info Panel stats increase
- Verify Item Slots remain visible

---

## 4. Timeline

| Step | Duration | Deliverable | Checkpoint |
|------|----------|-------------|------------|
| **Step 1: Data Structure** | 30 min | BuildStub.itemSlots | Log shows 13 slots |
| **Step 2: Display** | 2 hours | Item Slots visible | Screenshot: 13 slots right side |
| **Step 3: Refinement** | 1 hour | Color-coded slots | Screenshot: color distinction |
| **Step 4: Integration** | 30 min | All features work | Screenshot: full UI |
| **Total** | **4 hours** | **Functional Item Slots** | **User approval** |

**Milestones**:
- End of Step 1: Data structure ready (no visual change)
- End of Step 2: Item Slots displayed (13 gray rectangles)
- End of Step 3: Color-coded, visually refined
- End of Step 4: All Phase 1-4 features verified

**Optimizations from Phase 3**:
- Original estimate: 12 hours
- Optimized estimate: 4 hours (67% reduction)
- Reason: Phase 3 patterns (SetDrawLayer, simple data structures) proven successful

---

## 5. Risk Assessment

### Risks

**Risk 1: Item Slots Overlap with Passive Tree**
- **Likelihood**: Low
- **Impact**: Medium (visual clutter)
- **Mitigation**: Position at screenW - 250px, test with different screen sizes
- **Rollback**: Adjust panelX position

**Risk 2: Too Many Slots (UI Crowding)**
- **Likelihood**: Medium
- **Impact**: Low (visual density)
- **Mitigation**: Use compact layout (40px per slot), scrolling if needed
- **Rollback**: Reduce slot height to 30px

**Risk 3: SetDrawLayer Conflict**
- **Likelihood**: Low
- **Impact**: Low (slots behind tree)
- **Mitigation**: Use same layer as Character Info Panel (SetDrawLayer(10))
- **Rollback**: Increase to SetDrawLayer(15)

### Impact on Existing Functionality

**Zero Risk to Working Components**:
- Passive Tree NOT modified
- Character Info Panel NOT modified (separate draw section)
- PassiveSpec NOT modified

**Modified Files**:
- BuildStub.lua (data structure addition)
- Build.lua (new DrawItemSlots() method)

**Rollback Strategy**:
- Step 1 = git commit → rollback to Phase 3
- Step 2 = git commit → rollback to Step 1
- Step 3 = git commit → rollback to Step 2

---

## 6. Success Criteria

### Step 1: Data Structure
- [ ] BuildStub.itemSlots contains 13 entries
- [ ] Each slot has id, name, label, empty fields
- [ ] Log shows "BuildStub: 13 item slots"

### Step 2: Display
- [ ] 13 item slots visible on right side of screen
- [ ] Each slot has gray background + border
- [ ] Labels show slot names
- [ ] No overlap with Passive Tree
- [ ] Screenshot saved

### Step 3: Refinement
- [ ] Slots color-coded by type (Weapon=red, Armour=blue, etc.)
- [ ] Visual distinction clear
- [ ] Screenshot saved

### Step 4: Integration
- [ ] Passive Tree still works
- [ ] Character Info Panel still works
- [ ] Node allocation still works
- [ ] Stats still update
- [ ] Item Slots remain visible during interaction
- [ ] Screenshot shows all UI elements together
- [ ] Zero crashes, zero errors

### Overall Phase 4 Success
- [ ] Zero crashes during 5-minute test
- [ ] Zero Lua errors in log
- [ ] All Phase 1-4 features functional
- [ ] User confirms: "I can see 13 item slots clearly"

---

## 7. Role Assignments

**Analysis** (Step 1): Claude
- Review PoE2 item slot requirements
- Design itemSlots data structure

**Implementation** (All Steps): Claude
- Modify BuildStub.lua (data)
- Modify Build.lua (display)
- File synchronization to app bundle

**Testing** (All Steps): User (God)
- Visual verification via screenshot
- Verify no overlap with existing UI
- Approve each step before proceeding

**Review** (After Each Step): User (God)
- Verify screenshot quality
- Confirm layout acceptable
- Decide to continue or adjust

---

## 8. Implementation Notes

### File Synchronization Protocol

**After Each Modification**:
```bash
# Sync BuildStub.lua
ls -lh /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/BuildStub.lua

# Sync Build.lua
ls -lh /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/Build.lua

# Verify timestamps match current time
date
```

### Code Patterns

**Nil-Safety**:
```lua
if self.buildStub and self.buildStub.itemSlots then
    self:DrawItemSlots()
end
```

**Rectangle Drawing** (for slot backgrounds):
```lua
-- DrawImage(handle, x, y, width, height) - handle=nil for solid color
SetDrawColor(r, g, b)
DrawImage(nil, x, y, width, height)
```

**Screen Size Query**:
```lua
local screenW, screenH = GetScreenSize()
local panelX = screenW - 250  -- Right side positioning
```

---

## 9. Alternatives Considered

### Alternative A: Use Existing ItemsTab
- **Rejected**: ItemsTab requires full calculation system (Phase 5)
- **Reason**: Phase 4 is stubs only, no dependencies on complex systems

### Alternative B: Single Column Layout
- **Rejected**: Too tall, would extend off-screen
- **Reason**: 13 slots × 40px = 520px height, screen may be < 800px

### Alternative C: Horizontal Layout (Bottom of Screen)
- **Rejected**: Conflicts with TreeTab controls (bottom bar)
- **Reason**: Right side is empty, no conflicts

---

## 10. Future Enhancements (Post-Phase 4)

### Phase 5: Full Item System
- Actual item creation UI
- Item stat parsing
- Equipment stat calculation
- Drag-and-drop item management

### Phase 6: Item Icons
- Load item slot icons from Assets/
- Display actual item images
- Tooltip on hover (requires tooltip system)

---

**Plan End**

Total Estimated Time: 4 hours (optimized from 12h)
Risk Level: Low (simple UI display, no complex logic)
Rollback: Easy (git commit per step, no breaking changes)

**Next Step**: Create review document, request God's approval
