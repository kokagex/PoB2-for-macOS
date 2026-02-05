# Stage 2: Calculation Infrastructure - Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet
**前提**: Stage 1完了（900 gems, 910 bases, 1242 uniques loaded）

---

## 1. Current State Analysis

### ✅ What We Have (Stage 1 Complete)

**Data Foundation**:
- ✅ 900 gems loaded (data.gems)
- ✅ 910 item bases loaded (data.itemBases)
- ✅ 1,242 unique items loaded (data.uniques)
- ✅ Empty data tables initialized (data.skills, data.minions, etc.)
- ✅ TreeTab working (Phase 3, 4, A)

**Minimal Infrastructure**:
- ✅ build.calcsTab stub exists (Launch.lua lines 218-224)
- ✅ build.itemsTab stub exists (Launch.lua lines 225-235)

### ❌ What's Missing (Stage 2 Goal)

**Calculation System (0% Implemented)**:
- ❌ Skills not loaded (data.skills empty)
- ❌ CalcSetup not loaded (no build environment)
- ❌ Calcs not loaded (no calculation engine)
- ❌ CalcsTab has no display (stub only)
- ❌ No stat calculations (Life, ES, damage all = 0)

**Impact**: Can't calculate build stats, CalcsTab shows nothing

---

## 2. Strategic Approach

### Philosophy: Apply Stage 1 Success Pattern

**Stage 1 Achievement**: 予定10日 → 実績1時間（95%短縮）

**Success Factors to Replicate**:
1. ✅ Exploration Agent for analysis
2. ✅ pcall error handling
3. ✅ Detailed logging
4. ✅ Incremental verification
5. ✅ Simple data loading first, complex logic later

### Stage 2 Strategy: Data First, Then Logic

**Phase A: Load Skills Data** (Similar to Stage 1 - Data loading only)
- Load Data/Skills/* (10 files)
- Verify data.skills populated
- **Risk**: LOW (data loading, proven pattern)
- **Estimate**: 1-2 hours

**Phase B: Load Calc Modules** (Complex - Logic loading)
- Load Modules/CalcSetup.lua
- Load Modules/Calcs.lua (basic only)
- Initialize calculation environment
- **Risk**: MEDIUM-HIGH (complex modules, dependencies)
- **Estimate**: 2-3 hours

**Phase C: Implement CalcsTab Display** (UI Implementation)
- Create or modify CalcsTab display
- Show basic stats (Life, ES, resistances)
- **Risk**: MEDIUM (UI work, may need new code)
- **Estimate**: 1-2 hours

**Total Estimate**: 4-7 hours (vs original 10-12 days)

---

## 3. Detailed Implementation Steps

### Step 1: Analyze Skills & Calc Module Architecture (30 min)

**Objective**: Understand Skills data structure and Calcs dependencies

**Actions**:
1. Use Exploration Agent to analyze:
   - Data/Skills/* structure and dependencies
   - Modules/CalcSetup.lua requirements
   - Modules/Calcs.lua basic functions
   - CalcsTab current implementation (if any)

2. Identify:
   - Which Skills files are essential vs optional
   - What CalcSetup needs to initialize
   - What Calcs functions are needed for basic stats
   - PoE1 vs PoE2 compatibility issues

**Deliverable**: Architecture analysis document

**Dependencies**: None
**Risk**: Low (read-only analysis)

---

### Step 2: Load Skills Data (1 hour)

**Objective**: Load all skill definitions into data.skills

**Files to Load** (10 files):
```
Data/Skills/act_str    - Strength active skills
Data/Skills/act_dex    - Dexterity active skills
Data/Skills/act_int    - Intelligence active skills
Data/Skills/other      - Other active skills
Data/Skills/glove      - Glove skills
Data/Skills/minion     - Minion skills
Data/Skills/spectre    - Spectre skills
Data/Skills/sup_str    - Strength support gems
Data/Skills/sup_dex    - Dexterity support gems
Data/Skills/sup_int    - Intelligence support gems
```

**Implementation** (Launch.lua):
```lua
-- Stage 2 Step 2: Load Skills data
ConPrintf("Stage 2: Loading skill definitions...")

local skillTypes = {
    "act_str", "act_dex", "act_int", "other", "glove",
    "minion", "spectre", "sup_str", "sup_dex", "sup_int"
}

data.skills = {}
local skillsLoaded = 0
for _, skillType in ipairs(skillTypes) do
    local ok, result = pcall(LoadModule, "Data/Skills/" .. skillType)
    if ok then
        -- Merge skills into data.skills table
        if type(result) == "table" then
            for skillId, skill in pairs(result) do
                data.skills[skillId] = skill
                skillsLoaded = skillsLoaded + 1
            end
        end
    else
        ConPrintf("WARNING: Failed to load Data/Skills/%s: %s",
                  skillType, tostring(result))
    end
end

ConPrintf("Stage 2: Skills loaded (%d skills)", skillsLoaded)
```

**Verification**:
1. Count skills: `data.skills` should have 500+ entries
2. Sample skill: Print first skill ID and name
3. **Visual test**: TreeTab still works

**Success Criteria**:
- ✅ Skills loaded: 500+ skills
- ✅ TreeTab still works (Phase 3, 4, A)
- ✅ No crashes

**Dependencies**: Step 1 complete
**Risk**: LOW (same pattern as Stage 1 gems loading)

---

### Step 3: Load SkillStatMap (15 min)

**Objective**: Load skill stat mapping template

**Implementation**:
```lua
-- Stage 2 Step 3: Load SkillStatMap
local ok, result = pcall(LoadModule, "Data/SkillStatMap")
if ok then
    data.skillStatMap = result
    ConPrintf("Stage 2: SkillStatMap loaded")
else
    ConPrintf("WARNING: Failed to load SkillStatMap: %s", tostring(result))
    data.skillStatMap = {}
end
```

**Verification**:
- data.skillStatMap exists and is not empty
- TreeTab still works

**Dependencies**: Step 2 complete
**Risk**: LOW

---

### Step 4: Link Gems to Skills (15 min)

**Objective**: Establish gem → skill references

**Implementation**:
```lua
-- Stage 2 Step 4: Link gems to skills
ConPrintf("Stage 2: Linking gems to skills...")

local gemsLinked = 0
if data.gems and data.skills then
    for gemId, gem in pairs(data.gems) do
        if gem.grantedEffectId and data.skills[gem.grantedEffectId] then
            gem.grantedEffect = data.skills[gem.grantedEffectId]
            gemsLinked = gemsLinked + 1
        end
    end
end

ConPrintf("Stage 2: Gems linked to skills (%d linked)", gemsLinked)
```

**Verification**:
- gemsLinked should be > 0 (most gems have skills)
- Sample: data.gems[firstGem].grantedEffect should not be nil
- TreeTab still works

**Dependencies**: Steps 2-3 complete
**Risk**: LOW

---

### Step 5: Load CalcSetup Module (1 hour)

**Objective**: Load build environment setup module

**Challenge**: CalcSetup is complex (500+ lines), may have many dependencies

**Implementation**:
```lua
-- Stage 2 Step 5: Load CalcSetup
ConPrintf("Stage 2: Loading CalcSetup module...")

local ok, CalcSetup = pcall(LoadModule, "Modules/CalcSetup")
if not ok then
    ConPrintf("ERROR: Failed to load CalcSetup: %s", tostring(CalcSetup))
    -- Cannot proceed without CalcSetup
else
    ConPrintf("Stage 2: CalcSetup loaded successfully")
    -- Store in global or build object
    _G.CalcSetup = CalcSetup
end
```

**Potential Issues**:
- CalcSetup may depend on other modules (ModTools, ItemTools)
- May have PoE1-specific code
- May require full build infrastructure

**Mitigation**:
- Start with pcall to catch errors
- If fails, analyze error message
- May need to load dependencies first (use Exploration Agent)
- Accept partial failure (skip optional features)

**Verification**:
- CalcSetup module loaded without error
- TreeTab still works
- Log shows "CalcSetup loaded successfully"

**Dependencies**: Steps 1-4 complete
**Risk**: MEDIUM-HIGH (complex module, many dependencies)

---

### Step 6: Load Calcs Module (Basic Only) (1-2 hours)

**Objective**: Load main calculation orchestrator (basic functions only)

**Challenge**: Calcs is very complex, depends on CalcSetup

**Implementation**:
```lua
-- Stage 2 Step 6: Load Calcs module (basic)
ConPrintf("Stage 2: Loading Calcs module...")

local ok, Calcs = pcall(LoadModule, "Modules/Calcs")
if not ok then
    ConPrintf("ERROR: Failed to load Calcs: %s", tostring(Calcs))
    -- May need to provide stubs or skip
else
    ConPrintf("Stage 2: Calcs loaded successfully")
    _G.Calcs = Calcs
end
```

**Potential Issues**:
- Calcs depends on CalcSetup, CalcOffence, CalcDefence, etc.
- May try to run calculations immediately
- May have PoE1-specific logic

**Mitigation**:
- Load basic functions only (not full pipeline)
- Stub out complex calc functions if needed
- Accept errors for advanced features (focus on Life/ES/resistances)

**Verification**:
- Calcs module loaded
- TreeTab still works
- No immediate crashes

**Dependencies**: Step 5 complete (CalcSetup loaded)
**Risk**: HIGH (very complex module)

---

### Step 7: Initialize Calculation Environment (30 min)

**Objective**: Set up build.calcsTab with real calculation functions

**Current State**: build.calcsTab is minimal stub (Launch.lua lines 218-224)

**Implementation**:
```lua
-- Stage 2 Step 7: Initialize calculation environment
ConPrintf("Stage 2: Initializing calculation environment...")

if _G.CalcSetup and self.build then
    -- Replace stub with real calcsTab
    self.build.calcsTab = {
        -- Basic infrastructure
        mainEnv = { grantedPassives = {} },
        powerStat = nil,
        powerMax = { offence = 1, defence = 1, singleStat = 1 },

        -- Calculation functions (if available)
        BuildPower = function(self)
            -- Stub or basic implementation
            ConPrintf("CalcsTab:BuildPower() called")
        end,

        GetMiscCalculator = function(self, build)
            -- Stub or basic implementation
            return function(options) return {} end, {}
        end,
    }

    ConPrintf("Stage 2: Calculation environment initialized")
else
    ConPrintf("WARNING: CalcSetup not available, keeping stub")
end
```

**Verification**:
- build.calcsTab exists and has functions
- TreeTab still works
- No crashes when accessing calcsTab

**Dependencies**: Steps 5-6 complete
**Risk**: MEDIUM

---

### Step 8: Implement Basic CalcsTab Display (1-2 hours)

**Objective**: Show basic stats in CalcsTab

**Challenge**: May need to create CalcsTab UI from scratch, or modify existing

**Investigation First**:
1. Check if CalcsTab class exists in Classes/
2. If exists, check current implementation
3. If not, create minimal version

**Minimal Implementation**:
```lua
-- Create minimal CalcsTab that displays basic stats
local CalcsTab = newClass("CalcsTab", function(self, build)
    self.build = build
end)

function CalcsTab:Draw(viewPort)
    -- Draw basic stats
    local y = 50
    SetDrawColor(1, 1, 1, 1)
    DrawString(20, y, "LEFT", 14, "", "=== Build Stats ===")
    y = y + 20

    -- Life
    local life = (self.build.spec and self.build.spec.allocNodes) and 100 or 0
    DrawString(20, y, "LEFT", 12, "", string.format("Life: %d", life))
    y = y + 16

    -- ES
    DrawString(20, y, "LEFT", 12, "", "Energy Shield: 0")
    y = y + 16

    -- Resistances
    DrawString(20, y, "LEFT", 12, "", "Fire Res: 0%")
    y = y + 16
    DrawString(20, y, "LEFT", 12, "", "Cold Res: 0%")
    y = y + 16
    DrawString(20, y, "LEFT", 12, "", "Lightning Res: 0%")
end

return CalcsTab
```

**Full Implementation** (if Calcs module works):
- Use Calcs functions to calculate real stats
- Display Life, ES, damage, resistances
- Format with proper colors and layout

**Verification**:
- CalcsTab displays without crash
- Shows placeholder or real stats
- TreeTab still works

**Dependencies**: Steps 1-7 complete
**Risk**: MEDIUM (UI work, may need iteration)

---

### Step 9: File Synchronization (15 min)

**Objective**: Sync all changes to app bundle

**Process**:
```bash
# Launch.lua already in app bundle (edited directly)
# If created new CalcsTab class:
cp src/Classes/CalcsTab.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# Verify sync
diff src/Launch.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua
```

**Verification**:
- All files synced
- Timestamps match
- diff shows no differences

**Dependencies**: Steps 1-8 complete
**Risk**: LOW (proven process)

---

### Step 10: Final Verification & Testing (30 min)

**Objective**: Comprehensive test of Stage 2 implementation

**Test Scenarios**:
1. ✅ App launches without crash
2. ✅ TreeTab works (Phase 3, 4, A preserved)
3. ✅ CalcsTab can be opened (if tab system exists)
4. ✅ CalcsTab displays stats (placeholder or real)
5. ✅ No errors in log

**Log Verification**:
```
Stage 2: Skills loaded (XXX skills)
Stage 2: Gems linked to skills (XXX linked)
Stage 2: CalcSetup loaded successfully
Stage 2: Calcs loaded successfully
Stage 2: Calculation environment initialized
Stage 2: CalcsTab display ready
```

**Data Verification**:
```lua
-- Print counts
ConPrintf("Skills count: %d", count(data.skills))
ConPrintf("Gems with skills: %d", count linked gems)
```

**Success Criteria**:
- ✅ All modules loaded (or graceful failures logged)
- ✅ TreeTab preserved (Phase 3, 4, A)
- ✅ CalcsTab shows something (even placeholder)
- ✅ No crashes
- ✅ User confirms "動作OK"

**Dependencies**: Steps 1-9 complete
**Risk**: LOW (verification only)

---

## 4. Timeline Estimate

### Conservative Estimate (with potential issues)

| Step | Description | Estimate | Cumulative |
|------|-------------|----------|------------|
| 1 | Architecture Analysis | 30 min | 30 min |
| 2 | Load Skills Data | 1 hour | 1.5 hours |
| 3 | Load SkillStatMap | 15 min | 1.75 hours |
| 4 | Link Gems to Skills | 15 min | 2 hours |
| 5 | Load CalcSetup | 1 hour | 3 hours |
| 6 | Load Calcs | 1-2 hours | 4-5 hours |
| 7 | Init Calc Environment | 30 min | 4.5-5.5 hours |
| 8 | CalcsTab Display | 1-2 hours | 5.5-7.5 hours |
| 9 | File Sync | 15 min | 5.75-7.75 hours |
| 10 | Final Testing | 30 min | 6.25-8.25 hours |

**Total**: 6-8 hours (vs Stage 1: 1 hour)

**Why Slower than Stage 1**:
- Complex modules (CalcSetup, Calcs) vs simple data files
- Dependencies between modules
- UI implementation (CalcsTab display) vs data loading only
- Higher risk of errors/debugging needed

**Optimistic Estimate** (if everything goes smoothly):
- 4-5 hours (applying Stage 1 pattern perfectly)

**Timebox Limit**: 2 days maximum
- If stuck > 4 hours on one step, reassess approach

---

## 5. Risk Assessment

### Risk 1: CalcSetup/Calcs Module Complexity (HIGH)

**Likelihood**: High (modules are 500-2000+ lines, many dependencies)
**Impact**: High (can't calculate stats without these)

**Potential Issues**:
- ModTools, ItemTools dependencies not loaded
- PoE1-specific code incompatible with current state
- Full app infrastructure expected (not MINIMAL mode)

**Mitigation**:
- Use Exploration Agent to identify dependencies first
- Load dependencies before CalcSetup/Calcs
- Stub out complex features, focus on basic (Life, ES)
- Accept partial functionality for Stage 2

**Rollback**: If CalcSetup fails, keep Stage 1 state, document as blocker

---

### Risk 2: PoE1 vs PoE2 Skills Incompatibility (MEDIUM)

**Likelihood**: Medium (Skills are PoE1, like Gems/Bases)
**Impact**: Medium (calculations may be wrong for PoE2)

**Mitigation**:
- Accept PoE1 skills for Stage 2 (like Stage 1)
- Document limitation
- Plan PoE2 migration for Stage 3-4

**Acceptable**: Stage 2 proves calculation pipeline works, even if data is PoE1

---

### Risk 3: Breaking TreeTab (MEDIUM)

**Likelihood**: Medium (loading complex modules may interfere)
**Impact**: High (lose Phase 3, 4, A functionality)

**Mitigation**:
- Test TreeTab after every major step
- Use pcall for all LoadModule calls
- Keep Stage 1 git commit as rollback point

**Rollback**: Git revert to Stage 1 commit (afe57e2)

---

### Risk 4: CalcsTab UI Implementation (MEDIUM)

**Likelihood**: Medium (may need significant UI code)
**Impact**: Medium (CalcsTab shows nothing, but calcs still work)

**Mitigation**:
- Start with minimal placeholder display
- Iterate on display after calculations work
- Accept "shows placeholder" as Stage 2 success

**Fallback**: Show stats in log only, defer UI to Stage 3

---

### Risk 5: Time Underestimate (MEDIUM)

**Likelihood**: Medium (Stage 2 is 6-8x more complex than Stage 1)
**Impact**: Medium (takes 2 days instead of 6-8 hours)

**Mitigation**:
- Timebox at 2 days maximum
- If stuck > 4 hours on one step, present options to user
- Accept partial success (e.g., Skills loaded but Calcs not working)

**Acceptable**: Stage 2 may take longer than Stage 1, that's expected

---

## 6. Success Criteria

### Minimum Success (Stage 2 Complete)

**Data**:
- ✅ data.skills populated (500+ skills)
- ✅ Skills linked to gems (gem.grantedEffect exists)
- ✅ CalcSetup module loaded (or documented why not)
- ✅ Calcs module loaded (or documented why not)

**Functional**:
- ✅ Calculation environment initialized
- ✅ CalcsTab shows something (placeholder or real stats)

**Preservation**:
- ✅ TreeTab works (Phase 3, 4, A)
- ✅ No crashes
- ✅ App stable

**User Confirmation**:
- ✅ User confirms "動作OK"

### Stretch Goals (Bonus)

- ✅ Real stat calculations work (Life, ES calculated from tree)
- ✅ CalcsTab shows formatted stats (colors, layout)
- ✅ Multiple stats displayed (Life, ES, resistances, damage)

---

## 7. Rollback Strategy

### If Stage 2 Fails

**Immediate Rollback**:
```bash
git checkout afe57e2  # Stage 1 commit
./run_pob2.sh
# Verify TreeTab works
```

**Partial Rollback** (if only one step fails):
- Revert specific LoadModule calls
- Keep successful steps (e.g., Skills loaded, but not Calcs)
- Document as "Stage 2 Partial"

**Fallback Options**:
1. **Option A**: Accept Skills loaded, skip Calcs (defer to Stage 3)
2. **Option B**: Use simplified calc functions (custom, not full Calcs module)
3. **Option C**: Document blockers, reassess approach

---

## 8. Stage 2 Deliverables Checklist

- [ ] Architecture analysis complete (Step 1)
- [ ] Skills data loaded (Step 2)
- [ ] SkillStatMap loaded (Step 3)
- [ ] Gems linked to skills (Step 4)
- [ ] CalcSetup loaded (Step 5) [or documented failure]
- [ ] Calcs loaded (Step 6) [or documented failure]
- [ ] Calculation environment initialized (Step 7)
- [ ] CalcsTab display implemented (Step 8) [placeholder acceptable]
- [ ] Files synced (Step 9)
- [ ] Final testing complete (Step 10)
- [ ] LESSONS_LEARNED.md updated
- [ ] Stage 2 result document created
- [ ] Git commit created

---

## 9. Comparison to Original Plan

### Original Windows Parity Plan

**Stage 2 Original Estimate**: 10-12 days

**This Plan**: 6-8 hours (6-16x faster)

**Why Faster**:
- Stage 1 pattern proved data loading is fast
- Exploration Agent cuts analysis time
- Focus on basic functionality (not full calculation pipeline)
- Accept partial success (placeholder CalcsTab ok)

**Why Not as Fast as Stage 1**:
- Complex modules (not just data files)
- Module dependencies (need to load in order)
- UI work (CalcsTab display)
- Higher error risk

---

## 10. Integration with Stage 1

### Stage 1 Provides

**Data Foundation** (Ready to Use):
- data.gems (900 items) with gem definitions
- data.itemBases (910 items) for items
- data.uniques (1,242 items) for build testing

**Infrastructure**:
- LoadModule function with pcall pattern
- ConPrintf logging
- Empty data tables (data.skills, etc.)

### Stage 2 Adds

**Calculation Foundation**:
- data.skills (500+ items) skill definitions
- CalcSetup module (build environment)
- Calcs module (calculation engine)
- CalcsTab display (basic stats)

### Stage 3 Will Need

**Skills & Items Integration**:
- SkillsTab (gem selection, linking)
- ItemsTab (gear slots, mods)
- Full calculations (damage, defense)

---

**Plan Status**: ✅ Complete - Ready for Review
**Next Step**: Phase 4 Review
