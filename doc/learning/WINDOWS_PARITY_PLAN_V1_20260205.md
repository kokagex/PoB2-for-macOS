# Windows版パリティ達成計画 - Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet + Exploration Agent
**目標**: macOS MINIMAL mode (10-15% complete) → Windows版完全パリティ (100%)

---

## 1. Current State Analysis

### ✅ What Works (macOS MINIMAL - 10-15% Complete)

**Graphics & Rendering**:
- ✅ Metal backend fully functional
- ✅ Image rendering, text rendering
- ✅ UI framework (Controls, ControlHost)

**Passive Tree (TreeTab)**:
- ✅ Phase 3: Ascendancy click
- ✅ Phase 4: Normal node allocation
- ✅ Phase A: Node connections display
- ✅ Visual display, zoom/pan

**Minimal Infrastructure**:
- ✅ PassiveTree, PassiveSpec, PassiveTreeView
- ✅ Basic build object with minimal stubs

### ❌ What's Missing (85-90% of Windows Version)

**Major Systems (0% Implemented)**:
- ❌ **Calculation Pipeline**: No damage/defense/stat calculations
- ❌ **Item System**: No gear, no mods, no affixes
- ❌ **Skill System**: No gems, no links, no skill selection
- ❌ **Configuration**: No enemy config, no conditions
- ❌ **Data Loading**: Only 2/40+ data files loaded
- ❌ **Module Loading**: Only 1/25+ modules loaded
- ❌ **Save/Load**: No build persistence
- ❌ **Import/Export**: No build sharing

**UI Tabs (1/8 Working)**:
- ✅ TreeTab: Working
- ❌ SkillsTab: Stubbed (0%)
- ❌ ItemsTab: Stubbed (0%)
- ⚠️ CalcsTab: Minimal stub (~5%)
- ❌ ConfigTab: Stubbed (0%)
- ❌ ImportTab: Stubbed (0%)
- ❌ NotesTab: Stubbed (0%)
- ❌ PartyTab: Stubbed (0%)

**Infrastructure Bottlenecks**:
1. **ModCache**: Pre-parsed modifier cache (critical for performance)
2. **Calculation Engine**: 24 specialized modules (2000+ lines each)
3. **Data Files**: 40+ files to load and maintain
4. **Configuration**: 100+ interconnected settings

---

## 2. Strategic Approach

### Philosophy: Incremental Enablement (Proven Success Pattern)

**Lesson from Phase A**: Gradual approach succeeded (node connections enabled without breaking Phase 3, 4)

**Anti-Pattern**: Trying to enable everything at once (risk of breaking working features)

### 4-Stage Roadmap

#### Stage 1: Data Foundation (Week 1-2)
**Goal**: Load core data files without breaking TreeTab

**Deliverables**:
- Load Data/Misc.lua, Data/Global.lua, Data/Gems.lua
- Initialize data.* tables properly
- Verify TreeTab still works

**Risk**: Low (additive, no removal)

---

#### Stage 2: Calculation Infrastructure (Week 3-4)
**Goal**: Enable basic calculation pipeline

**Deliverables**:
- Load Modules/Data.lua
- Load Modules/CalcSetup.lua
- Enable Modules/Calcs.lua (basic)
- Implement CalcsTab basic display

**Risk**: Medium (may conflict with MINIMAL mode stubs)

---

#### Stage 3: Skills & Items (Week 5-8)
**Goal**: Enable gem and gear systems

**Deliverables**:
- Implement SkillsTab (gem selection, linking)
- Implement ItemsTab (gear slots, mod parsing)
- Load Modules/ItemTools.lua
- Load Modules/ModTools.lua

**Risk**: High (requires ModCache, complex dependencies)

---

#### Stage 4: Configuration & Polish (Week 9-12)
**Goal**: Complete remaining systems

**Deliverables**:
- Implement ConfigTab (enemy config, conditions)
- Implement ImportTab, NotesTab, PartyTab
- Save/load system
- Build import/export

**Risk**: Medium (independent systems)

---

## 3. Detailed Implementation Steps - Stage 1

### Stage 1: Data Foundation (2 weeks)

#### Step 1: Analyze Data Loading Architecture (Day 1)

**Objective**: Understand how Windows version loads data files

**Actions**:
1. Read Modules/Data.lua (lines 7-613) completely
2. Identify load order and dependencies
3. Document which data tables are created
4. Identify PoE1 vs PoE2 compatibility issues

**Deliverable**: Data loading architecture document

**Dependencies**: None
**Risk**: Low (read-only analysis)

---

#### Step 2: Load Minimal Data Files (Day 2-3)

**Objective**: Load 3 core data files without breaking TreeTab

**Files to Load**:
1. `Data/Global.lua` - Global constants, skill types
2. `Data/Misc.lua` - Game constants (already partially loaded)
3. `Data/Gems.lua` - Gem definitions

**Implementation**:
```lua
-- In Launch.lua after line 100
LoadModule("Data/Global", data)
LoadModule("Data/Gems", data)
-- Misc already loaded at line 100
```

**Verification**:
1. Check `data.gems` table exists and has entries
2. Check `data.skillTypes` table exists
3. **Visual Test**: Verify TreeTab still works (Phase 3, 4, A)

**Deliverable**: Data foundation loaded, TreeTab still functional

**Dependencies**: Step 1 complete
**Risk**: Low (additive changes only)

---

#### Step 3: Initialize Data Tables (Day 4)

**Objective**: Create empty data tables for future modules

**Tables to Initialize**:
```lua
data.itemBases = {}
data.itemMods = {}
data.itemUniques = {}
data.clusters = {}
data.essences = {}
data.enchantments = {}
data.costs = {}
```

**Why Now**: Prevents nil errors when modules access these tables

**Verification**:
1. Verify all tables exist (not nil)
2. Visual test: TreeTab still works

**Deliverable**: Data structure foundation ready

**Dependencies**: Step 2 complete
**Risk**: Low (empty tables)

---

#### Step 4: Load Item Base Data (Day 5-7)

**Objective**: Load item base definitions

**Files to Load**:
1. `Data/Bases.lua` - Base item definitions
2. `Data/Uniques.lua` - Unique item database

**Implementation**:
```lua
LoadModule("Data/Bases", data.itemBases)
LoadModule("Data/Uniques", data.itemUniques)
```

**Verification**:
1. Check `data.itemBases.weapon` exists
2. Check `data.itemUniques[1]` exists
3. Visual test: TreeTab still works

**Deliverable**: Item database loaded

**Dependencies**: Step 3 complete
**Risk**: Low (data tables only, no logic changes)

---

#### Step 5: File Synchronization & Testing (Day 8-10)

**Objective**: Ensure all changes deployed correctly

**Process**:
1. Sync Launch.lua to app bundle
2. Sync all new data files to app bundle
3. Verify file timestamps match
4. **Visual Test**: Full Phase 3, 4, A verification
5. **Data Test**: Print data.gems[1] to verify loading

**Success Criteria**:
- ✅ data.gems table populated (100+ gems)
- ✅ data.itemBases table populated (500+ bases)
- ✅ TreeTab still fully functional
- ✅ No crashes, no errors
- ✅ User confirms "動作OK"

**Deliverable**: Stage 1 complete, documented

**Dependencies**: Steps 1-4 complete
**Risk**: Low (verification phase)

---

## 4. Timeline Estimate

### Stage 1: Data Foundation
- Step 1: Data architecture analysis - 1 day
- Step 2: Load minimal data files - 2 days
- Step 3: Initialize data tables - 1 day
- Step 4: Load item base data - 3 days
- Step 5: Testing & synchronization - 3 days

**Total Stage 1**: 10 days (2 weeks)

### Stage 2: Calculation Infrastructure
**Estimate**: 10-12 days (2-3 weeks)

### Stage 3: Skills & Items
**Estimate**: 20-25 days (4-5 weeks)

### Stage 4: Configuration & Polish
**Estimate**: 20-25 days (4-5 weeks)

### **Total Project Estimate**: 60-72 days (12-14 weeks / 3 months)

**Note**: This is a LARGE project. Each stage should be approved separately.

---

## 5. Risk Assessment

### Risk 1: Data File PoE1 vs PoE2 Incompatibility (HIGH)

**Likelihood**: High (codebase has PoE1 legacy code)
**Impact**: High (data may be wrong for PoE2)

**Mitigation**:
- Audit each data file for PoE1-specific content
- Compare with current PoE2 game data
- Add PoE2 version checks where needed

**Rollback**: Use PoE2-specific data files if available

---

### Risk 2: ModCache Generation Complexity (CRITICAL)

**Likelihood**: High (ModCache is complex, performance-critical)
**Impact**: Critical (without ModCache, item mods don't work)

**Mitigation**:
- Study ModParser.lua and ModCache.lua carefully
- Generate ModCache offline first, test loading
- Consider using pre-generated ModCache for PoE2

**Rollback**: Skip ModCache, use simplified mod system (Stage 3 degraded)

---

### Risk 3: Breaking TreeTab (MEDIUM)

**Likelihood**: Medium (adding modules may conflict)
**Impact**: High (lose working functionality)

**Mitigation**:
- Test TreeTab after every major change
- Use git branches for each stage
- Keep rollback plan ready (git revert)

**Rollback Strategy**:
```bash
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/
# Verify TreeTab works
```

---

### Risk 4: Time Underestimate (HIGH)

**Likelihood**: High (complex project, many unknowns)
**Impact**: Medium (takes longer than 3 months)

**Mitigation**:
- Approve each stage separately (don't commit to full 3 months)
- Set stage timeboxes (max 3 weeks per stage)
- If stuck > 1 week, reassess approach

**Fallback**: Accept partial parity (e.g., stop after Stage 2 if useful)

---

## 6. Success Criteria

### Stage 1 Success Criteria (Data Foundation)

**Visual**:
- ✅ TreeTab still works (Phase 3, 4, A)
- ✅ No visual regressions

**Data**:
- ✅ data.gems table populated (100+ entries)
- ✅ data.itemBases table populated (500+ entries)
- ✅ data.skillTypes table populated

**Code Quality**:
- ✅ All data loading in Launch.lua documented
- ✅ LuaJIT 5.1 compatible
- ✅ Files synced to app bundle

**User Confirmation**:
- ✅ User confirms "動作OK"

---

### Stage 2 Success Criteria (Calculation Infrastructure)

**Visual**:
- ✅ TreeTab still works
- ✅ CalcsTab shows basic stats (life, ES, damage)

**Functional**:
- ✅ Modules/Calcs.lua loaded
- ✅ CalcSetup creates build environment
- ✅ Basic calculations work (life, resistances)

**Code Quality**:
- ✅ No crashes during calculation
- ✅ Calculation results logged and verifiable

---

### Stage 3 Success Criteria (Skills & Items)

**Visual**:
- ✅ SkillsTab displays and allows gem selection
- ✅ ItemsTab displays gear slots

**Functional**:
- ✅ Can select gems and link supports
- ✅ Can equip items in slots
- ✅ Mods parsed and applied to build

**Code Quality**:
- ✅ ModCache loaded or generated
- ✅ Item system functional

---

### Stage 4 Success Criteria (Windows Parity)

**Visual**:
- ✅ All 8 tabs functional
- ✅ UI matches Windows version

**Functional**:
- ✅ Can configure enemy (level, resistances)
- ✅ Can save/load builds
- ✅ Can import builds from external sources

**Parity Check**:
- ✅ Side-by-side comparison with Windows version
- ✅ User confirms feature equivalence

---

## 7. Rollback Strategy

### Stage-Level Rollback

**If Stage N Fails**:
1. Git revert all changes from Stage N
2. Verify Stage N-1 still works
3. Document failure in contexterror
4. Present user with 3 options:
   - Option A: Try different approach for Stage N
   - Option B: Accept partial completion (stop at Stage N-1)
   - Option C: Reset entire project

**Rollback Commands**:
```bash
# Revert to last working state
git log --oneline -10  # Find last good commit
git checkout <commit_hash> -- PathOfBuilding.app/

# Verify rollback
./run_pob2.sh
# Test TreeTab
```

### Feature-Level Rollback

**If Individual Feature Breaks**:
1. Identify breaking change (git diff)
2. Revert specific file
3. Test incrementally

---

## 8. Stage 1 Deliverables Checklist

- [ ] Data loading architecture documented
- [ ] Data/Global.lua loaded
- [ ] Data/Gems.lua loaded
- [ ] Data/Bases.lua loaded
- [ ] Data/Uniques.lua loaded
- [ ] All data tables initialized
- [ ] Files synced to app bundle
- [ ] Visual test: TreeTab working
- [ ] Data test: gems/bases populated
- [ ] User confirms "動作OK"
- [ ] Stage 1 result document created
- [ ] Git commit with clear message

---

## 9. Approval Decision Points

**This Plan Requests Approval For**: Stage 1 Only (2 weeks)

**Future Stages Require Separate Approval**:
- Stage 2: After Stage 1 success, present Stage 2 plan
- Stage 3: After Stage 2 success, present Stage 3 plan
- Stage 4: After Stage 3 success, present Stage 4 plan

**Rationale**:
- This is a 3-month project, too large to approve all at once
- Each stage builds on previous stage success
- Allows reassessment after each stage completion

---

## 10. Alternative Approaches Considered

### Alternative A: Full Migration to Windows Codebase
**Pros**: Get all features immediately
**Cons**: Lose custom Metal backend, 3 months of work discarded
**Rejected**: Current approach preserves macOS-specific work

### Alternative B: Minimal Feature Set (No Full Parity)
**Pros**: Faster completion (4-6 weeks)
**Cons**: Not true Windows parity, missing features
**Rejected**: User requested "Windows版と同じ状態"

### Alternative C: Hybrid Approach (Cherry-Pick Features)
**Pros**: User chooses which features to implement
**Cons**: Unclear scope, may be incomplete
**Considered**: Could be fallback if full parity too costly

---

**Plan Status**: ✅ Complete - Ready for Review (Stage 1 Only)
**Next Step**: Phase 4 Review
