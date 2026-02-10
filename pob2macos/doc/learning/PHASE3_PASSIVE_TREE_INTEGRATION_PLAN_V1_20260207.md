# Phase 3: Passive Tree Integration - Implementation Plan

**Date**: 2026-02-07
**Version**: V1
**Status**: Awaiting Approval
**Estimated Duration**: 8 hours

---

## 1. Root Cause Analysis

### Current Situation

**Phase 1-2 Complete** ✅:
- Passive Tree displays correctly (TreeTab functional)
- Character Info Panel shows: Level, Class, Life, Mana, Attributes
- BuildStub initialized with base values
- Zero errors, stable operation

**What's Missing**:
- Node allocation functionality (click node → nothing happens)
- Stat calculation from allocated nodes (Life/Mana/Attributes don't increase)
- Visual feedback for allocated nodes

### Observations

**TreeTab.lua Current Behavior**:
- Nodes are displayed correctly
- Node images load and render
- BUT: No click handler calls BuildStub:AllocateNode()

**BuildStub.lua Current State**:
- `AllocateNode(nodeId)` exists but is a stub (line 61-73)
- `CalculateStats()` exists but hardcoded (line 91-105)
- Currently: +10 Life per node (placeholder, line 103)

**Expected Behavior (Phase 3)**:
1. User clicks passive node → AllocateNode() called
2. AllocateNode() → CalculateStats() → stat bonuses applied
3. Character Info Panel updates (Life increases by node bonus)
4. Visual feedback: allocated node highlighted

---

## 2. Proposed Solution

### Strategy: Three-Step Implementation

**Step 1: TreeTab Click Handler** (2 hours)
- Detect node click in TreeTab:OnFrame()
- Identify clicked nodeId from coordinates
- Call `build.buildStub:AllocateNode(nodeId)`

**Step 2: BuildStub Stat Calculation** (4 hours)
- Parse node.sd (stat descriptions) for bonuses
- Extract Life/Mana/Str/Dex/Int values
- Manual calculation (no ModDB dependency)
- Update BuildStub stats (life, mana, str, dex, int)

**Step 3: Visual Feedback** (2 hours)
- Update Character Info Panel display (Build.lua:OnFrameMinimal)
- Passive point counter update (Total/Used/Free)
- Visual verification: stat changes visible

### Why This Approach

**Advantages**:
- Incremental (test at each step)
- No dependency on full calculation system
- Simple, predictable logic
- Visual verification at each step

**Risks Mitigated**:
- No breaking passive tree display (TreeTab.lua modification is minimal)
- No nil-safety errors (explicit checks for node existence)
- Clear rollback point (each step is a git commit)

---

## 3. Implementation Steps

### Step 1: TreeTab Click Handler (2 hours)

**Goal**: Detect node clicks, call BuildStub:AllocateNode()

**Files to Modify**:
1. `src/Classes/TreeTab.lua` - Add click detection

**Implementation**:

```lua
-- TreeTab.lua (in OnFrame, after tree rendering)
function TreeTabClass:OnFrame(viewPort, inputEvents)
    -- Existing tree rendering code...

    -- NEW: Node click detection
    if self.build.buildStub and inputEvents.leftButtonDown then
        local x, y = inputEvents.x, inputEvents.y

        -- Convert screen coords to tree coords
        local treeX = (x - self.zoomX) / self.zoom
        local treeY = (y - self.zoomY) / self.zoom

        -- Find node near click position
        for nodeId, node in pairs(self.build.spec.nodes) do
            if node.group and node.x and node.y then
                local dx = node.x - treeX
                local dy = node.y - treeY
                local dist = math.sqrt(dx*dx + dy*dy)

                -- Node radius check (typical: 20-30 units)
                if dist < 25 then
                    -- Node clicked!
                    if node.alloc then
                        -- Deallocate
                        self.build.buildStub:DeallocateNode(nodeId)
                    else
                        -- Allocate
                        self.build.buildStub:AllocateNode(nodeId)
                    end
                    break
                end
            end
        end
    end
end
```

**Success Criteria**:
- Click node → ConPrintf "DEBUG: AllocateNode called with nodeId=..."
- No crash on node click
- Log shows correct nodeId

**Testing**:
- Click 5 different nodes
- Verify log shows 5 AllocateNode calls
- Visual: no crash, app stable

---

### Step 2: BuildStub Stat Calculation (4 hours)

**Goal**: Calculate stat bonuses from allocated nodes

**Files to Modify**:
1. `src/Modules/BuildStub.lua` - Implement CalculateStats()

**Implementation**:

```lua
-- BuildStub.lua:CalculateStats() (replace lines 91-105)
function BuildStubClass:CalculateStats()
    -- Reset to base values
    self.life = self.baseLife
    self.mana = self.baseMana
    self.energyShield = self.baseEnergyShield
    self.str = self.baseStr
    self.dex = self.baseDex
    self.int = self.baseInt

    -- Iterate allocated nodes
    for nodeId in pairs(self.allocatedNodes) do
        local node = self.spec.nodes[nodeId]
        if node and node.sd then
            -- Parse stat descriptions (node.sd is array of strings)
            for _, statDesc in ipairs(node.sd) do
                local stat = tostring(statDesc)

                -- Life bonuses
                if stat:match("(%d+) to maximum Life") then
                    local value = tonumber(stat:match("(%d+) to maximum Life"))
                    if value then
                        self.life = self.life + value
                    end
                elseif stat:match("(%d+)%% increased maximum Life") then
                    local percent = tonumber(stat:match("(%d+)%% increased maximum Life"))
                    if percent then
                        self.life = self.life * (1 + percent/100)
                    end
                end

                -- Mana bonuses
                if stat:match("(%d+) to maximum Mana") then
                    local value = tonumber(stat:match("(%d+) to maximum Mana"))
                    if value then
                        self.mana = self.mana + value
                    end
                elseif stat:match("(%d+)%% increased maximum Mana") then
                    local percent = tonumber(stat:match("(%d+)%% increased maximum Mana"))
                    if percent then
                        self.mana = self.mana * (1 + percent/100)
                    end
                end

                -- Attribute bonuses
                if stat:match("(%d+) to Strength") then
                    local value = tonumber(stat:match("(%d+) to Strength"))
                    if value then
                        self.str = self.str + value
                    end
                end

                if stat:match("(%d+) to Dexterity") then
                    local value = tonumber(stat:match("(%d+) to Dexterity"))
                    if value then
                        self.dex = self.dex + value
                    end
                end

                if stat:match("(%d+) to Intelligence") then
                    local value = tonumber(stat:match("(%d+) to Intelligence"))
                    if value then
                        self.int = self.int + value
                    end
                end

                -- +10 to all Attributes
                if stat:match("(%d+) to all Attributes") then
                    local value = tonumber(stat:match("(%d+) to all Attributes"))
                    if value then
                        self.str = self.str + value
                        self.dex = self.dex + value
                        self.int = self.int + value
                    end
                end
            end
        end
    end

    -- Round final values
    self.life = math.floor(self.life)
    self.mana = math.floor(self.mana)
    self.str = math.floor(self.str)
    self.dex = math.floor(self.dex)
    self.int = math.floor(self.int)
end
```

**Nil-Safety**:
- Check `if node and node.sd then` before accessing
- Use `tostring(statDesc)` to handle non-string values
- Use `tonumber()` with validation

**Success Criteria**:
- Allocate node with "+10 to maximum Life" → Life increases by 10
- Allocate node with "+5 to Strength" → Str increases by 5
- Allocate 5 nodes → stats accumulate correctly
- No crashes, no nil errors

**Testing**:
- Allocate known Life node → verify stat increase
- Allocate known Dex node → verify attribute increase
- Deallocate node → verify stat decrease
- Log: `ConPrintf("Calculated: Life=%d, Mana=%d", self.life, self.mana)`

---

### Step 3: Visual Feedback (2 hours)

**Goal**: Update Character Info Panel with new stats

**Files to Modify**:
1. `src/Modules/Build.lua` - Update OnFrameMinimal() display

**Implementation**:

```lua
-- Build.lua:OnFrameMinimal() (update Character Info Panel section)
-- Add after existing character info display (around line 100-150)

-- Call CalculateStats to refresh (if needed)
if self.buildStub then
    self.buildStub:CalculateStats()
end

-- Display stats with color-coding
local y = 100  -- Starting Y position

-- Character Section (Blue)
SetDrawColor(0.5, 0.7, 1.0)  -- Light blue
DrawString(20, y, "LEFT", 16, "FIXED", "=== Character ===")
y = y + 20
SetDrawColor(1, 1, 1)
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Level: %d", self.buildStub.characterLevel))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Class: %s", self.buildStub.className))
y = y + 25

-- Stats Section (Red)
SetDrawColor(1.0, 0.5, 0.5)  -- Light red
DrawString(20, y, "LEFT", 16, "FIXED", "=== Stats ===")
y = y + 20
SetDrawColor(1, 1, 1)
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Life: %d", self.buildStub.life))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Mana: %d", self.buildStub.mana))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("ES: %d", self.buildStub.energyShield))
y = y + 25

-- Attributes Section (Green)
SetDrawColor(0.5, 1.0, 0.5)  -- Light green
DrawString(20, y, "LEFT", 16, "FIXED", "=== Attributes ===")
y = y + 20
SetDrawColor(1, 1, 1)
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Strength: %d", self.buildStub.str))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Dexterity: %d", self.buildStub.dex))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Intelligence: %d", self.buildStub.int))
y = y + 25

-- Passive Points Section (Yellow)
SetDrawColor(1.0, 1.0, 0.5)  -- Yellow
DrawString(20, y, "LEFT", 16, "FIXED", "=== Passive Points ===")
y = y + 20
SetDrawColor(1, 1, 1)
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Total: %d", self.buildStub.totalPassivePoints))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Used: %d", self.buildStub.usedPassivePoints))
y = y + 18
DrawString(20, y, "LEFT", 14, "FIXED", string.format("Free: %d", self.buildStub.freePassivePoints))
```

**Success Criteria**:
- Character Info Panel shows updated stats
- Stats change when nodes allocated/deallocated
- Passive point counter updates correctly
- Color-coding visible

**Testing**:
- Take screenshot BEFORE allocating node
- Allocate 1 node
- Take screenshot AFTER allocating node
- Compare: Life/Mana should increase, Used points should increase

---

## 4. Timeline

| Step | Duration | Deliverable | Checkpoint |
|------|----------|-------------|------------|
| **Step 1: Click Handler** | 2 hours | TreeTab calls AllocateNode | Screenshot: Log shows node clicks |
| **Step 2: Stat Calculation** | 4 hours | Stats increase from nodes | Screenshot: Life +10 per node |
| **Step 3: Visual Feedback** | 2 hours | Character Panel updates | Screenshot: Stats visible |
| **Total** | **8 hours** | **Functional node allocation** | **User approval** |

**Milestones**:
- End of Step 1: Node clicks detected, log shows AllocateNode calls
- End of Step 2: Stats calculated correctly, log shows values
- End of Step 3: Visual display working, screenshot confirms

---

## 5. Risk Assessment

### Risks

**Risk 1: TreeTab Click Detection Breaks Tree Display**
- **Likelihood**: Low
- **Impact**: Medium (passive tree display broken)
- **Mitigation**: Test tree display BEFORE adding click logic
- **Rollback**: Revert TreeTab.lua to Phase 2 version

**Risk 2: node.sd Parsing Fails (nil or wrong format)**
- **Likelihood**: Medium
- **Impact**: Low (stat calculation incorrect, no crash)
- **Mitigation**: Nil-safety checks, use `tostring()`, log parsed values
- **Rollback**: Use placeholder calculation (+10 Life per node)

**Risk 3: Stat Calculation Performance Issue (100+ nodes)**
- **Likelihood**: Low
- **Impact**: Low (slight lag on allocation)
- **Mitigation**: Limit to simple string matching, avoid complex regex
- **Rollback**: Simplify calculation logic

### Impact on Existing Functionality

**Zero Risk to Working Components**:
- PassiveTree.lua, PassiveTreeView.lua, PassiveSpec.lua NOT modified
- Build List screen NOT modified
- Phase 1-2 (Passive Tree display, Character Info Panel) preserved

**Modified Files**:
- TreeTab.lua (click handler added, minimal change)
- BuildStub.lua (CalculateStats implementation)
- Build.lua (Character Info Panel display update)

**Rollback Strategy**:
- Step 1 = git commit → rollback to Phase 2
- Step 2 = git commit → rollback to Step 1
- Step 3 = git commit → rollback to Step 2

---

## 6. Success Criteria

### Step 1: TreeTab Click Handler
- [ ] Click node → Log shows "AllocateNode called with nodeId=..."
- [ ] Click 5 nodes → 5 log entries
- [ ] No crashes on click
- [ ] Passive tree still displays correctly

### Step 2: BuildStub Stat Calculation
- [ ] Allocate Life node (+10 Life) → Life increases by 10
- [ ] Allocate Dex node (+5 Dex) → Dex increases by 5
- [ ] Allocate 10 nodes → stats accumulate correctly
- [ ] Deallocate node → stats decrease correctly
- [ ] Log shows: "Calculated: Life=X, Mana=Y"
- [ ] No nil errors

### Step 3: Visual Feedback
- [ ] Character Info Panel displays updated stats
- [ ] Allocate node → stats visually increase
- [ ] Deallocate node → stats visually decrease
- [ ] Passive point counter updates (Total/Used/Free)
- [ ] Screenshot saved (BEFORE and AFTER allocation)

### Overall Phase 3 Success
- [ ] Zero crashes during 5-minute test
- [ ] Zero Lua errors in log
- [ ] Passive tree fully functional
- [ ] Can allocate 20+ nodes without issues
- [ ] Stats visually change with each allocation
- [ ] User confirms: "I can see stats increasing"

---

## 7. Role Assignments

**Analysis** (Step 1-2): Claude
- Review TreeTab.lua click handling
- Analyze node.sd structure
- Design stat parsing logic

**Implementation** (All Steps): Claude
- Modify TreeTab.lua (click handler)
- Implement BuildStub:CalculateStats()
- Update Build.lua (visual display)
- File synchronization to app bundle

**Testing** (All Steps): User (God)
- Visual verification via screenshot
- Click nodes, verify stats change
- Report any crashes or incorrect calculations
- Approve each step before proceeding

**Review** (After Each Step): User (God)
- Verify screenshot quality
- Confirm stat calculations correct
- Decide to continue or rollback

---

## 8. Implementation Notes

### File Synchronization Protocol

**After Each Modification**:
```bash
# Sync TreeTab.lua
cp src/Classes/TreeTab.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# Sync BuildStub.lua
cp src/Modules/BuildStub.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/

# Sync Build.lua
cp src/Modules/Build.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/

# Verify sync
ls -lh PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/TreeTab.lua
ls -lh PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/BuildStub.lua
ls -lh PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/Build.lua
```

### Debugging Protocol

**If Node Click Detection Fails**:
1. Add file logging: `io.open("/tmp/treetab_debug.txt", "a")`
2. Log: click coordinates, node search results
3. Use elimination method to identify issue

**If Stat Calculation Fails**:
1. Add ConPrintf for each stat type found
2. Log: `ConPrintf("Found stat: %s", tostring(statDesc))`
3. Verify node.sd structure with sample node

**If Visual Display Fails**:
1. Add ConPrintf for display values
2. Verify CalculateStats() called before display
3. Check SetDrawColor, DrawString coordinates

### Code Patterns

**Nil-Safety Pattern**:
```lua
-- Always check before access
if node and node.sd then
    for _, statDesc in ipairs(node.sd) do
        local stat = tostring(statDesc)
        -- Parse stat
    end
end
```

**String Matching Pattern**:
```lua
-- Use simple pattern matching
if stat:match("(%d+) to maximum Life") then
    local value = tonumber(stat:match("(%d+) to maximum Life"))
    if value then
        self.life = self.life + value
    end
end
```

**File Logging Pattern** (if ConPrintf doesn't show):
```lua
local logFile = io.open("/tmp/phase3_debug.txt", "a")
if logFile then
    logFile:write(string.format("AllocateNode: nodeId=%s\n", tostring(nodeId)))
    logFile:close()
end
```

---

## 9. Alternatives Considered

### Alternative A: Use ModDB for Stat Calculation
- **Rejected**: ModDB requires full calculation system (not available in Phase 3)
- **Reason**: Too complex, depends on CalcSetup/CalcPerform

### Alternative B: Hardcode All Node Bonuses
- **Rejected**: 4000+ nodes, impractical to hardcode
- **Reason**: Manual parsing from node.sd is more flexible

### Alternative C: Skip Click Handler, Auto-allocate Nodes
- **Rejected**: User wants to click nodes, not auto-allocate
- **Reason**: User interaction is core feature

---

## 10. Future Enhancements (Post-Phase 3)

### Phase 4: Item Stubs
- Display item slots
- Placeholder items
- No stat calculations from items

### Phase 5: Full Calculation System
- ModDB integration
- Complex stat calculations
- Item modifiers
- Skill system

---

**Plan End**

Total Estimated Time: 8 hours
Risk Level: Low (incremental, testable at each step)
Rollback: Easy (git commit per step, passive tree never broken)

**Next Step**: Create review document, request God's approval
