# Stage 5: Build Screen Detailed Features - Implementation Plan V1

**Date**: 2026-02-06
**Status**: DRAFT - Awaiting Approval
**Previous Stage**: Stage 4 Complete (Build List fully functional)

---

## 1. Current State Analysis

### ✅ What's Already Working

**From Stage 4 Completion**:
- Build List screen fully functional (file discovery, search, CRUD operations)
- All 8 tabs initialized in Build.lua (lines 583-590)
- Tab switching logic implemented (lines 1188-1204)
- App launches successfully, 1120+ frames rendered with 0 errors
- Item.lua nil safety fixed (2 locations)

**Tab System Discovery**:
```lua
// Build.lua lines 583-590
self.importTab = new("ImportTab", self)
self.notesTab = new("NotesTab", self)
self.partyTab = new("PartyTab", self)
self.configTab = new("ConfigTab", self)
self.itemsTab = new("ItemsTab", self)
self.treeTab = new("TreeTab", self)
self.skillsTab = new("SkillsTab", self)
self.calcsTab = new("CalcsTab", self)

// lines 1188-1204: viewMode switching
if self.viewMode == "TREE" then
    self.treeTab:Draw(tabViewPort, inputEvents)
elseif self.viewMode == "SKILLS" then
    self.skillsTab:Draw(tabViewPort, inputEvents)
// ... all 8 tabs
```

### ❓ What Needs Investigation

**Unknown**: Do the tabs actually WORK when you click on them?
- Code shows initialization ✓
- Code shows Draw() calls ✓
- Unknown: Do tabs render correctly when switched?
- Unknown: Are tab buttons clickable?
- Unknown: Does each tab's UI display properly?

**Risk**: We might be implementing features for tabs that don't visually work yet.

---

## 2. Root Cause Analysis: Why Investigation First?

### Observation
- User requested: "タブシステム実装時にUIが正常かテストを行ってください"
- Translation: "When implementing tab system, test if UI is working properly"

### Critical Learning Applied
> **Lesson from MEMORY.md**: "Past failure: 3 days of work with zero visual progress"
> **Key lesson**: Never assume success without verification

### Hypothesis Ranking

**Hypothesis A** (80% likelihood): **Tabs are already functional, just need verification**
- Evidence FOR: All tab classes exist, Draw() methods implemented
- Evidence FOR: Build.lua has complete switching logic
- Evidence AGAINST: No visual confirmation yet
- **Action**: Quick verification test (5-10 minutes)

**Hypothesis B** (15% likelihood): **Tabs initialize but have rendering issues**
- Evidence FOR: Complex UI code could have edge cases
- Evidence AGAINST: Stage 4 completed successfully with similar UI
- **Action**: Debug specific tab rendering issues

**Hypothesis C** (5% likelihood): **Tabs don't work at all**
- Evidence FOR: None
- Evidence AGAINST: Code structure looks complete
- **Action**: Major implementation work needed

### Conclusion
**Start with Hypothesis A verification** before implementing new features.

---

## 3. Proposed Solution: Two-Phase Approach

### Phase A: Tab System Verification (FIRST)
**Duration**: 30 minutes max
**Goal**: Confirm tabs are clickable and display correctly

**Steps**:
1. Launch app manually: `open PathOfBuilding.app`
2. Click "Open" on existing build (or create new build)
3. Observe tab buttons at top of screen
4. Click each tab: TREE → SKILLS → ITEMS → CALCS → CONFIG
5. Take screenshots or note visual state
6. Check logs for errors during tab switches

**Success Criteria**:
- ✅ Tab buttons visible
- ✅ Tabs clickable
- ✅ Each tab displays different content
- ✅ No errors in log during tab switching
- ✅ Frame rendering continues smoothly

**Failure Criteria**:
- ❌ Tabs not visible
- ❌ Clicks don't switch tabs
- ❌ Crashes or errors when switching
- ❌ All tabs show same content

**Deliverable**: Verification report (oral or written)

### Phase B: Feature Implementation (AFTER VERIFICATION)
**Duration**: Varies based on Phase A results
**Goal**: Implement detailed features for working tabs

**Only proceed if Phase A succeeds.**

**Implementation targets** (priority order):

1. **TreeTab** (Highest priority - core feature):
   - Passive tree node selection
   - Allocated nodes persistence
   - Search functionality
   - Visual feedback on hover

2. **SkillsTab** (High priority):
   - Skill gem selection from dropdown
   - Support gem addition/removal
   - Level/quality sliders
   - Skill group management

3. **ItemsTab** (High priority):
   - Equipment slot displays (20 icons added in Stage 4)
   - Item tooltip on hover
   - Basic item equip/unequip

4. **CalcsTab** (Medium priority):
   - DPS display (calculation already works from Stage 4)
   - Defense stats (Armour/Evasion/ES)
   - Life/Mana display
   - Resistance summary

5. **ConfigTab** (Low priority):
   - Conditional toggles (simple checkboxes)
   - Enemy configuration

**Note**: Import/Notes/Party tabs are low priority for MVP.

---

## 4. Implementation Steps

### Step 1: Tab Verification Test (Phase A)
**Owner**: User (manual testing)
**Duration**: 10 minutes
**Dependencies**: None

**Actions**:
1. User launches app: `open PathOfBuilding.app`
2. User opens or creates a build
3. User clicks each tab and observes
4. User reports results to Claude

**Deliverable**: Verification status (working/broken/partial)

### Step 2: Decision Point
**Owner**: Claude + User
**Duration**: 2 minutes

**IF Phase A shows tabs are fully functional**:
→ Proceed to Step 3 (feature implementation)

**IF Phase A shows tabs are partially working**:
→ Document issues, create targeted fix plan

**IF Phase A shows tabs are broken**:
→ Abort Stage 5, fix tab system first

### Step 3: Analyze Tab Rendering Code (IF NEEDED)
**Owner**: Claude
**Duration**: 15 minutes
**Dependencies**: Step 2 decision

**Actions**:
1. Read TreeTab.lua Draw() method
2. Read SkillsTab.lua Draw() method
3. Read ItemsTab.lua Draw() method
4. Identify rendering patterns
5. Check for nil safety issues

**Deliverable**: Code analysis report

### Step 4: Implement Priority Features
**Owner**: Claude
**Duration**: 1-2 hours (depending on scope)
**Dependencies**: Step 2 success

**For each tab** (TreeTab, SkillsTab, ItemsTab, CalcsTab):
1. Read existing Draw() implementation
2. Identify missing features vs. Windows version
3. Implement highest-value features first
4. Sync to app bundle after EACH change
5. Test after EACH change (manual launch)
6. Document results

**Deliverable**: Working tab features

### Step 5: Integration Test
**Owner**: User + Claude
**Duration**: 15 minutes
**Dependencies**: Step 4 complete

**Actions**:
1. Launch app
2. Test all implemented features
3. Verify frame stability (300+ frames)
4. Check log for errors
5. Document success metrics

**Deliverable**: Integration test report

---

## 5. Timeline

| Step | Task | Duration | Total |
|------|------|----------|-------|
| 1 | Tab verification test (manual) | 10 min | 10 min |
| 2 | Decision point | 2 min | 12 min |
| 3 | Code analysis (if needed) | 15 min | 27 min |
| 4 | Feature implementation | 60-120 min | 87-147 min |
| 5 | Integration test | 15 min | 102-162 min |

**Total estimated time**: **1.5 - 2.5 hours**

**Timebox**: Maximum 3 hours. If not complete, reassess scope.

---

## 6. Risk Assessment

### Risk 1: Tabs don't work at all
**Likelihood**: Low (5%)
**Impact**: High (blocks Stage 5)
**Mitigation**: Phase A verification catches this early
**Rollback**: Abort Stage 5, create tab fix plan

### Risk 2: Tabs work but have rendering bugs
**Likelihood**: Medium (20%)
**Impact**: Medium (slows progress)
**Mitigation**: Fix bugs incrementally, test after each fix
**Rollback**: Revert specific tab changes, keep working tabs

### Risk 3: Feature implementation breaks existing functionality
**Likelihood**: Medium (25%)
**Impact**: High
**Mitigation**: Test after EVERY change, keep backups
**Rollback**: `git checkout` specific files

### Risk 4: Scope creep (trying to implement too much)
**Likelihood**: Medium (30%)
**Impact**: Medium (wastes time)
**Mitigation**: Strict priority order, timebox enforcement
**Rollback**: Stop implementation, document progress

### Risk 5: File sync forgotten
**Likelihood**: Low (10%) - CLAUDE.md warns about this
**Impact**: High (changes don't take effect)
**Mitigation**: Document sync step AFTER EVERY EDIT
**Rollback**: Sync correct files

---

## 7. Success Criteria

### Phase A Success (Tab Verification)
- ✅ All 8 tab buttons visible in Build screen
- ✅ Clicking tab buttons switches content
- ✅ Each tab displays unique content (not blank screens)
- ✅ No crashes or errors during tab switching
- ✅ Log shows 0 Lua errors

### Phase B Success (Feature Implementation)
- ✅ TreeTab: Can allocate at least 1 passive node
- ✅ SkillsTab: Can select at least 1 skill gem
- ✅ ItemsTab: Equipment slots visible
- ✅ CalcsTab: DPS number displays
- ✅ App runs 300+ frames without errors
- ✅ All changes synced to app bundle

### Overall Stage 5 Success
- ✅ Build screen usable for basic build editing
- ✅ User can interact with passive tree
- ✅ User can configure skills
- ✅ User can see calculation results
- ✅ Zero errors in production usage

---

## 8. Rollback Strategy

### If verification fails (Phase A)
1. Document failure mode
2. Capture screenshots/logs
3. Create targeted fix plan
4. DO NOT proceed to Phase B

### If feature implementation breaks app
1. Identify last working state
2. `git diff` to see recent changes
3. Revert specific changes: `git checkout <file>`
4. Test again
5. Re-implement more carefully

### If out of time (timebox exceeded)
1. Document current progress
2. List completed features
3. List remaining features
4. Propose revised timeline or descope

---

## 9. Role Assignments

### Analysis Role
**Who**: Claude
**Responsibilities**:
- Read tab class code
- Identify rendering patterns
- Analyze feature completeness
- Report findings

### Implementation Role
**Who**: Claude
**Responsibilities**:
- Write/modify Lua code
- Sync files to app bundle
- Create minimal changes
- Document each change

### Testing Role
**Who**: User (manual) + Claude (logs)
**Responsibilities**:
- User: Launch app, click tabs, observe behavior
- Claude: Monitor logs, check for errors
- Both: Verify success criteria

### Review Role
**Who**: Claude
**Responsibilities**:
- Check code quality
- Verify nil safety
- Ensure file sync happened
- Validate against success criteria

---

## 10. Deliverables

### Phase A Deliverables
1. **Tab Verification Report**:
   - List of tabs tested
   - Visual confirmation (working/broken)
   - Error log check results
   - Go/No-Go decision for Phase B

### Phase B Deliverables (if Phase A succeeds)
1. **Modified Tab Files** (synced to app bundle):
   - TreeTab.lua changes (if any)
   - SkillsTab.lua changes (if any)
   - ItemsTab.lua changes (if any)
   - CalcsTab.lua changes (if any)

2. **Integration Test Report**:
   - Features implemented
   - Frame count achieved
   - Error count (should be 0)
   - Visual confirmation

3. **LESSONS_LEARNED.md Update**:
   - New lessons from Stage 5
   - Successful patterns
   - Pitfalls avoided

---

## 11. Key Learnings Applied

1. **"Never assume success without verification"**
   → Phase A verification BEFORE implementation

2. **"Logs don't lie"**
   → Check passive_tree_app.log after every test

3. **"File sync is manual"**
   → Document sync step explicitly

4. **"Test after EVERY change"**
   → No batch changes without testing

5. **"Timebox investigations"**
   → 30 min max for Phase A, 3 hours total max

---

## 12. Next Steps After Approval

1. **Immediate**: User performs Phase A verification (10 min)
2. User reports results to Claude
3. Claude makes Go/No-Go decision
4. If Go: Begin Phase B implementation
5. If No-Go: Create tab fix plan

---

**END OF PLAN**
