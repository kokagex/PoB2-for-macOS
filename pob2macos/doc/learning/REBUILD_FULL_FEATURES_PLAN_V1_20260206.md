# Full Feature Rebuild Plan (Preserve Passive Tree)

**Date**: 2026-02-06
**Version**: V1
**Status**: Awaiting Approval

---

## 1. Root Cause Analysis

### Current Situation

**Working Components** ✅:
- Passive Tree display (PassiveTree, PassiveTreeView, PassiveSpec, TreeTab)
- UI rendering system (SimpleGraphic FFI 100% complete)
- Image loading, text rendering
- Build List screen (Stage 4 complete)
- Main application flow (Main.lua)

**Broken Components** ❌:
- Build calculation system (CalcSetup, CalcActiveSkill, CalcPerform)
- Item management (ItemsTab - partially working but depends on calcs)
- Skill management (SkillsTab - depends on calcs)
- Config system (ConfigOptions - PoE1 constants missing)
- Stats display (Build:RefreshStatList - requires mainEnv)

### Root Cause

**PoE1 → PoE2 Migration Incomplete**:
- Calculation system assumes PoE1 data structures
- 50+ missing characterConstants/monsterConstants
- activeGrantedEffect nil (skill system incompatible)
- mainEnv not initialized (calc environment broken)

**Why Individual Fixes Failed**:
- Each fix reveals next missing constant
- Cascade of nil-safety errors
- Core architecture incompatible with PoE2

---

## 2. Proposed Solution: Minimal Viable Build (MVB)

### Strategy

**Build from scratch, minimal first, then add features**:

1. **Phase 1: Minimal Stub** (Day 1)
   - Display "Under Construction" in BUILD mode
   - Show only Passive Tree (working)
   - No calculations, no items, no skills

2. **Phase 2: Basic Character Info** (Day 2)
   - Display level, class, ascendancy
   - Show base stats (Life, Mana, ES)
   - No modifiers, no calculations

3. **Phase 3: Passive Tree Integration** (Day 3)
   - Allocate/deallocate passive nodes
   - Display node count
   - Basic stat bonuses (manually calculated)

4. **Phase 4: Item Stubs** (Day 4-5)
   - Display item slots
   - No actual items (placeholders)
   - No stat calculation

5. **Phase 5: Calculation System** (Week 2+)
   - New PoE2-compatible calc engine
   - ModDB with PoE2 data
   - Skill system redesign

### Why This Approach

**Advantages**:
- Testable at each phase (visual verification)
- No breaking existing passive tree
- Can ship MVB quickly (Passive Tree Viewer)
- Incremental complexity

**Risks Mitigated**:
- No "3 days zero progress" (visual at each step)
- No cascade nil errors (stub data)
- Clear rollback points

---

## 3. Implementation Steps

### Phase 1: Minimal Stub (4 hours)

**Goal**: BUILD mode shows only Passive Tree + "Under Construction" message

**Files to Modify**:
1. `Build.lua:Init()` - Skip all tab creation except TreeTab
2. `Build.lua:OnFrame()` - Simple draw, no calculations
3. `Build.lua:RefreshStatList()` - Empty stub

**Deliverables**:
- App launches to BUILD mode
- Passive Tree displays
- "Under Construction" message at top
- Zero Lua errors

**Success Criteria**:
- Screenshot shows passive tree
- Log shows 0 errors
- App runs for 30+ seconds without crash

---

### Phase 2: Basic Character Info (6 hours)

**Goal**: Display level, class, base stats (hardcoded values)

**Files to Create**:
1. `Modules/BuildStub.lua` - Minimal build data structure
2. `Classes/CharacterStub.lua` - Character info (level, class)

**Files to Modify**:
1. `Build.lua` - Use BuildStub instead of full Build
2. `Build.lua:OnFrame()` - Draw character info panel

**Data Structure**:
```lua
-- BuildStub.lua
self.characterLevel = 1
self.className = "Ranger"
self.ascendClassName = "None"
self.baseLife = 50
self.baseMana = 40
self.baseES = 0
```

**Deliverables**:
- Left panel shows: Level, Class, Ascendancy
- Shows: Life, Mana, Energy Shield (base values)
- Passive Tree still works
- Zero calculation errors

**Success Criteria**:
- Screenshot shows character info + tree
- All displayed values are correct
- No crashes, 0 errors

---

### Phase 3: Passive Tree Integration (8 hours)

**Goal**: Allocate nodes, update stat display (manual calc)

**Implementation**:
1. Connect TreeTab node click to BuildStub
2. Track allocated nodes in BuildStub
3. Manually calculate stat bonuses:
   - Life: +10 per allocated life node
   - Mana: +6 per allocated mana node
   - Stats: +10 Str/Dex/Int per allocated stat node

**Files to Modify**:
1. `BuildStub.lua` - Add allocatedNodes table
2. `BuildStub:AllocateNode(nodeId)` - Simple allocation logic
3. `BuildStub:CalculateStats()` - Manual bonus calculation
4. `TreeTab.lua` - Call BuildStub:AllocateNode on click

**Deliverables**:
- Click node → allocates
- Stat display updates (Life increases by +10 per node)
- Passive point counter works
- Tree visualization shows allocated nodes

**Success Criteria**:
- Allocate 10 nodes, verify stat increase
- Deallocate node, verify stat decrease
- Screenshot shows allocated tree + updated stats
- No crashes

---

### Phase 4: Item Stubs (12 hours)

**Goal**: Display item slots with placeholders

**Implementation**:
1. Create ItemStub class (minimal item data)
2. Display item slots (Weapon, Armor, Jewelry)
3. No actual items, just "Empty Slot" placeholders
4. No stat calculations from items

**Files to Create**:
1. `Classes/ItemStub.lua` - Minimal item structure
2. `Classes/ItemsTabStub.lua` - Simplified item UI

**Deliverables**:
- Right panel shows item slots
- "Empty Slot" for each slot
- No item editing (future phase)
- Visual layout matches PoE2

**Success Criteria**:
- Screenshot shows item slots + tree
- All slots displayed correctly
- No crashes

---

### Phase 5: Calculation System Redesign (2-3 weeks)

**Goal**: Full PoE2-compatible calculation engine

**Out of Scope for MVB** (defer to later):
- Skill system
- Item modifiers
- Full ModDB
- Damage calculations

**In Scope for MVB**:
- Basic stat aggregation (Life, Mana, Stats)
- Passive tree modifiers only
- No items, no skills

**Design Principles**:
- No dependency on PoE1 constants
- Nil-safe by default
- PoE2 data structures

---

## 4. Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Stub | 4 hours | Passive Tree + message |
| Phase 2: Character | 6 hours | Level, Class, Base Stats |
| Phase 3: Tree Integration | 8 hours | Node allocation works |
| Phase 4: Item Stubs | 12 hours | Item slots displayed |
| **Total MVB** | **30 hours** | **Functional Passive Tree Viewer** |
| Phase 5: Calc Engine | 2-3 weeks | Full calculations (future) |

**Milestones**:
- End of Day 1: Phase 1 complete, can ship "Tree Viewer"
- End of Day 2: Phase 2 complete, basic character display
- End of Day 3: Phase 3 complete, tree allocation works
- End of Week 1: Phase 4 complete, MVB shipped

---

## 5. Risk Assessment

### Risks

**Risk 1: Passive Tree Integration Breaks Tree Display**
- **Mitigation**: Test tree display BEFORE adding allocation logic
- **Rollback**: Revert to Phase 1 stub

**Risk 2: Manual Stat Calculation Incorrect**
- **Mitigation**: Start with simple +10 Life per node, verify visually
- **Rollback**: Show "Calculation Disabled" message

**Risk 3: Timeline Overrun**
- **Mitigation**: Ship Phase 1 immediately (4 hours), each phase independently shippable
- **Rollback**: Ship current phase, defer next

### Impact on Existing Functionality

**Zero Risk to Working Components**:
- Passive tree files NOT modified (except TreeTab click handler)
- Build List screen NOT modified
- SimpleGraphic NOT modified

**Modified Files**:
- Build.lua (major refactor, but preserve passive tree rendering)
- TreeTab.lua (add node click → BuildStub call)

**Rollback Strategy**:
- Each phase = git commit
- Can rollback to any previous phase
- Passive tree always functional

---

## 6. Success Criteria

### Phase 1 (Minimal Stub)
- [ ] App launches to BUILD mode
- [ ] Passive Tree displays correctly
- [ ] "Under Construction" message visible
- [ ] Zero Lua errors in log
- [ ] Screenshot saved

### Phase 2 (Character Info)
- [ ] Character info panel displayed
- [ ] Level, Class, Ascendancy shown
- [ ] Base Life/Mana/ES shown
- [ ] Values are correct (hardcoded)
- [ ] Screenshot saved

### Phase 3 (Tree Integration)
- [ ] Click node → allocates
- [ ] Stat display updates
- [ ] Deallocate node works
- [ ] Passive point counter correct
- [ ] Screenshot shows allocated tree
- [ ] Visual verification: stats increase by expected amount

### Phase 4 (Item Stubs)
- [ ] Item slots displayed
- [ ] All 13 slots visible (Weapons, Armor, Jewelry)
- [ ] "Empty Slot" placeholders
- [ ] Layout matches PoE2
- [ ] Screenshot saved

### Overall MVB Success
- [ ] Zero crashes during 5-minute test
- [ ] Zero Lua errors in log
- [ ] Passive tree fully functional
- [ ] Character info accurate
- [ ] Can allocate/deallocate 50+ nodes without crash

---

## 7. Role Assignments

**Analysis** (Phase 1-2): Claude
- Review Build.lua structure
- Identify minimum viable implementation
- Create stub data structures

**Implementation** (All Phases): Claude
- Write BuildStub, CharacterStub, ItemStub
- Modify Build.lua to use stubs
- Implement minimal UI drawing

**Testing** (All Phases): User (God)
- Visual verification via screenshot
- Interact with tree (allocate nodes)
- Report any crashes or visual issues

**Review** (After Each Phase): User (God)
- Approve screenshot quality
- Verify functionality before next phase
- Decide to continue or ship current phase

---

## 8. Implementation Notes

### File Organization

**New Files**:
```
src/Modules/BuildStub.lua           - Minimal build data
src/Classes/CharacterStub.lua       - Character info
src/Classes/ItemStub.lua            - Item placeholders
src/Classes/ItemsTabStub.lua        - Simplified item UI
```

**Modified Files**:
```
src/Modules/Build.lua               - Use stubs, skip full init
src/Modules/TreeTab.lua             - Connect clicks to BuildStub
```

**Preserved Files** (DO NOT MODIFY):
```
src/Classes/PassiveTree.lua         - NO CHANGES
src/Classes/PassiveTreeView.lua     - NO CHANGES
src/Classes/PassiveSpec.lua         - NO CHANGES
```

### Code Patterns

**Stub Pattern**:
```lua
-- BuildStub.lua
function BuildStub:Init()
    self.characterLevel = 1
    self.className = "Ranger"
    self.allocatedNodes = {}
    self.stats = {
        life = 50,
        mana = 40,
        str = 0, dex = 0, int = 0
    }
end

function BuildStub:AllocateNode(nodeId)
    self.allocatedNodes[nodeId] = true
    self:CalculateStats()
end

function BuildStub:CalculateStats()
    -- Manual calculation
    local lifeNodes = 0
    for nodeId in pairs(self.allocatedNodes) do
        local node = self.spec.nodes[nodeId]
        if node and node.name:match("Life") then
            lifeNodes = lifeNodes + 1
        end
    end
    self.stats.life = 50 + (lifeNodes * 10)
end
```

**Draw Pattern**:
```lua
-- Build.lua:OnFrame()
function buildMode:OnFrame()
    -- Draw Passive Tree (already working)
    if self.treeTab then
        self.treeTab:Draw(self.viewPort)
    end

    -- Draw Character Info (stub)
    SetDrawColor(1, 1, 1)
    DrawString(20, 20, "LEFT", 16, "FIXED", "Level: " .. self.characterLevel)
    DrawString(20, 40, "LEFT", 16, "FIXED", "Class: " .. self.className)
    DrawString(20, 60, "LEFT", 16, "FIXED", "Life: " .. self.stats.life)
end
```

---

## 9. Alternatives Considered

### Alternative A: Fix All Nil-Safety Errors
- **Rejected**: 50+ missing constants, cascade errors
- **Reason**: Spent hours fixing, new errors keep appearing

### Alternative B: Port PoE1 Calculations as-is
- **Rejected**: PoE1 data structures incompatible with PoE2
- **Reason**: Would require rewriting all PoE2 data to match PoE1 format

### Alternative C: Use Existing Build.lua with Stubs
- **Partially Accepted**: Reuse Build.lua structure, replace internals
- **Reason**: Build.lua OnFrame/Draw logic is sound, just replace data source

---

## 10. Future Enhancements (Post-MVB)

### Week 2-3: Item System
- Real item creation UI
- Item stat calculation
- Equipment slot functionality

### Week 4-5: Skill System
- Skill gem display
- Socket groups
- Support gems

### Week 6+: Full Calculation Engine
- Damage calculations
- Defense calculations
- PoE2 mechanic support

---

**Plan End**

Total Estimated Time: 30 hours for MVB (Phases 1-4)
Risk Level: Low (each phase independently shippable)
Rollback: Easy (git commit per phase, passive tree never broken)

**Next Step**: Create review document, request God's approval
