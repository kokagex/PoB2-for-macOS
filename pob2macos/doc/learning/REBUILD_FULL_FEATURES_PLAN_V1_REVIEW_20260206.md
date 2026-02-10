# Full Feature Rebuild Plan - Review Document

**Date**: 2026-02-06
**Plan Version**: V1
**Reviewer**: Claude (Auto-Review)

---

## 1. Learning Integration Check ✅

**Score**: ✅ PASS

### Lessons Applied

✅ **Lesson 1: "3 days zero progress" prevention**
- Plan includes visual verification at each phase
- Each phase = screenshot + user approval
- No phase proceeds without working display

✅ **Lesson 2: Preserve working components**
- Passive tree files explicitly marked "DO NOT MODIFY"
- Only Build.lua modified, tree rendering untouched
- TreeTab only adds click handler, no core changes

✅ **Lesson 3: Incremental implementation**
- 5 phases, each independently shippable
- Phase 1 = 4 hours, immediate value (Tree Viewer)
- Can stop at any phase, ship what works

✅ **Lesson 4: PoE1→PoE2 data structure incompatibility**
- Plan acknowledges 50+ missing constants
- Builds PoE2-native stubs from scratch
- No dependency on PoE1 characterConstants

✅ **Lesson 5: Nil-safety by design**
- Stub data structures always initialized
- No nil references in manual calculations
- Simple, predictable data flow

### Past Failures Avoided

- ❌ **Past**: Fixed one nil error, next error appeared
- ✅ **Now**: Build stubs with no dependencies on missing data

- ❌ **Past**: Worked for hours, no visual progress
- ✅ **Now**: Screenshot required after each phase (4-12 hours each)

- ❌ **Past**: Modified passive tree, broke display
- ✅ **Now**: Passive tree files explicitly preserved

---

## 2. Role Clarity Check ✅

**Score**: ✅ PASS

### Role Assignments

**Analysis** (Phase 1-2): Claude
- Clear: Review Build.lua, create stubs
- Forbidden: Do NOT modify PassiveTree files

**Implementation** (All Phases): Claude
- Clear: Write BuildStub, CharacterStub, ItemStub
- Clear: Modify Build.lua to use stubs
- Forbidden: Do NOT assume success without testing

**Testing** (All Phases): User (God)
- Clear: Visual verification via screenshot
- Clear: Interact with tree, report issues
- Decision: Approve phase before proceeding

**Review** (After Each Phase): User (God)
- Clear: Verify screenshot quality
- Decision: Continue or ship current phase

### Workflow Logic

✅ **Phase 1 → Screenshot → User Approval → Phase 2**
- Sequential, logical flow
- No parallel steps (avoids coordination issues)
- Clear approval gates

✅ **Each Phase = Git Commit**
- Rollback points defined
- No ambiguity about "current state"

---

## 3. Technical Accuracy Check ✅

**Score**: ✅ PASS (with minor notes)

### Root Cause Analysis

✅ **Accurate**: PoE1→PoE2 migration incomplete
✅ **Accurate**: 50+ missing constants confirmed (contexterror file)
✅ **Accurate**: activeGrantedEffect nil, mainEnv nil (logged)

### Proposed Solution

✅ **Technically Sound**: Stub-based approach
- BuildStub replaces full Build init
- Manual stat calculation avoids nil dependencies
- Simple data structures (level, class, stats)

✅ **Passive Tree Integration**:
- TreeTab click → BuildStub:AllocateNode(nodeId)
- Lookup node in spec.nodes (already working)
- Manual bonus calculation (no ModDB)

⚠️ **Minor Note**: TreeTab click handler
- Current TreeTab likely has existing click logic
- Need to verify: Does TreeTab already handle clicks?
- May need to hook into existing handler, not replace

**Mitigation**: Phase 3 step 1 is "Review TreeTab click handling"

### Edge Cases Considered

✅ **Case 1: User clicks unallocatable node**
- Handled: Check node.isKeystone, node.isNotable before allocating
- Simple validation in BuildStub:AllocateNode()

✅ **Case 2: Passive point limit**
- Handled: Track allocatedNodes count
- Compare to (characterLevel - 1) + questPoints

✅ **Case 3: Node deallocate**
- Handled: BuildStub:DeallocateNode(nodeId)
- Remove from allocatedNodes table, recalculate stats

---

## 4. Risk Assessment Check ✅

**Score**: ✅ PASS

### Risks Identified

✅ **Risk 1: Passive Tree Integration Breaks Display**
- **Mitigation**: Test tree display BEFORE adding allocation
- **Rollback**: Revert to Phase 1
- **Severity**: Low (git commit per phase)

✅ **Risk 2: Manual Stat Calculation Incorrect**
- **Mitigation**: Start with simple +10 Life per node
- **Visual Verification**: User sees stat increase
- **Rollback**: Show "Calculation Disabled" message
- **Severity**: Low (display issue, no crash)

✅ **Risk 3: Timeline Overrun**
- **Mitigation**: Each phase independently shippable
- **Rollback**: Ship current phase, defer next
- **Severity**: Low (can stop at Phase 1, still valuable)

### Risk Level

**Overall Risk**: **LOW**
- No breaking changes to working components
- Incremental approach (test at each step)
- Clear rollback points

### Impact Analysis

✅ **Zero Impact on Passive Tree Display**
- PassiveTree.lua, PassiveTreeView.lua, PassiveSpec.lua NOT modified
- Tree rendering logic preserved

✅ **Zero Impact on Build List Screen**
- BuildList.lua NOT modified (Stage 4 complete)

⚠️ **Impact on Build.lua**
- **High Impact**: Major refactor (Init, OnFrame, RefreshStatList)
- **Mitigation**: Git commit before changes
- **Rollback**: Revert to current Build.lua (current=broken anyway)

---

## 5. Completeness Check ✅

**Score**: ✅ PASS

### Required Sections Present

✅ Root Cause Analysis - Clear, detailed
✅ Proposed Solution - MVB strategy with 5 phases
✅ Implementation Steps - Each phase detailed
✅ Timeline - 30 hours total, per-phase breakdown
✅ Risk Assessment - 3 risks, mitigations, rollback
✅ Success Criteria - Per-phase checklists
✅ Role Assignments - Clear separation of duties

### Implementation Detail

✅ **Code Examples**: BuildStub, Draw patterns provided
✅ **File Organization**: New files vs Modified files listed
✅ **Data Structures**: BuildStub structure defined

### Success Criteria

✅ **Measurable**:
- "Zero Lua errors in log" (objective)
- "Screenshot saved" (deliverable)
- "Allocate 50+ nodes without crash" (testable)

✅ **Visual Verification**:
- Every phase requires screenshot
- User approves visual quality

---

## 6. Auto-Approval Criteria (6-Point Check)

### Point 1: Root Cause Clear? ✅
**YES** - PoE1→PoE2 migration incomplete, 50+ missing constants, calculation system broken

### Point 2: Solution Technically Sound? ✅
**YES** - Stub-based approach avoids nil dependencies, manual calculations simple and testable

### Point 3: Risk Low/Manageable? ✅
**YES** - Low risk, incremental approach, no breaking changes to working tree, clear rollback

### Point 4: Rollback Easy? ✅
**YES** - Git commit per phase, can revert to any phase, passive tree always functional

### Point 5: Visual Verification Plan Exists? ✅
**YES** - Screenshot required after every phase, user approval before proceeding

### Point 6: Timeline Realistic? ✅
**YES** - 30 hours for MVB (4-12 hours per phase), each phase independently shippable

---

## Total Score: 6/6 ✅

**Judgment**: ✅ **AUTO-APPROVED**

---

## Review Summary

### Strengths

1. **Incremental Approach**: Each phase = working product
2. **Visual Verification**: Screenshot at every step
3. **Passive Tree Preserved**: Zero risk to working tree
4. **Clear Roles**: User tests, approves, Claude implements
5. **Low Risk**: Git commits, easy rollback, no breaking changes
6. **Realistic Timeline**: 4-12 hours per phase, 30 hours total

### Minor Concerns

⚠️ **TreeTab Click Handler**
- **Concern**: May need to hook into existing click logic
- **Mitigation**: Phase 3 step 1 reviews existing handler
- **Impact**: Low (adds 1-2 hours to Phase 3)

### Recommendations

✅ **Proceed to Phase 5: Request God's Approval**

**Reason**:
- All 6 auto-approval criteria met
- Plan is technically sound, low risk
- Visual verification at every step
- Passive tree protected
- Timeline realistic

---

## Approval Status

**Status**: ✅ **APPROVED** (Auto-Review)

**Next Step**: Present to User (God) for final approval

---

**Review End**
