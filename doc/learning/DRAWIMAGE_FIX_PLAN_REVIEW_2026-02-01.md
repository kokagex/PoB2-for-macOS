# Implementation Plan Review: DrawImage() Rendering Failure Fix
**Reviewer**: Prophet (Claude Opus 4.5) -- Self-Review
**Plan**: DRAWIMAGE_FIX_PLAN_2026-02-01.md
**Date**: 2026-02-01 23:35

---

## Review Checklist

### 1. Learning Data Applied
- [x] CRITICAL_FAILURE_ANALYSIS.md read -- visual verification mandatory
- [x] LESSONS_LEARNED.md read -- 24 learning records applied
- [x] OPTION_B_FAILURE_REPORT read -- previous failure patterns avoided
- [x] DEEP_INVESTIGATION_PLAN read -- systematic approach adopted
- [x] SHADER_MISMATCH_FIX_PLAN read -- attribute alignment confirmed
- [x] Clean rebuild pattern applied (Lesson #7)
- [x] File sync protocol applied
- [x] Time-boxing applied (45 min max)
- [x] Empirical-first approach (learned from Option B 99% confidence failure)

### 2. Hierarchy Structure
- [x] Prophet creates plan (not implementation)
- [x] Artisan assigned for implementation
- [x] Sage assigned for analysis
- [x] Paladin assigned for verification
- [x] No hierarchy violations in agent assignments
- [x] Prophet does NOT execute builds or tests

### 3. Technical Analysis Quality
- [x] Current code read and analyzed (metal_backend.mm, 1191 lines)
- [x] Both draw paths compared side-by-side (metal_draw_glyph vs metal_draw_image)
- [x] Batch flush execution trace constructed step-by-step
- [x] `didModifyRange:` on StorageModeShared identified as potential issue
- [x] Correctly identifies that didModifyRange is NOT the differentiator (both paths call it)
- [x] Multiple hypotheses with probability estimates

### 4. Plan Structure
- [x] Phased approach (5 phases, with 1+2 combined for efficiency)
- [x] Each phase has clear deliverables
- [x] Visual verification after each phase
- [x] Agent assignments clear
- [x] Bypass test approach is novel (not tried in previous attempts)

### 5. Risk Assessment
- [x] Success probability conservative (85%)
- [x] Failure contingency defined (Xcode Metal GPU Debugger)
- [x] Rollback is trivial (remove diagnostic code)
- [x] Files affected clearly listed

---

## Critical Observations

### Strengths

1. **Novel Approach**: The "bypass test" (Phase 2) is the FIRST time we're testing the batch system directly. Previous plans focused on shader logic or attribute alignment, missing the possibility that the batch system itself is the problem.

2. **Minimum Viable Test**: The bypass test requires adding only ~15 lines of code. This is a minimal intervention that provides maximum diagnostic value.

3. **Correct Deduction**: The plan correctly identifies that with TEST 1 shader (pure red), the problem CANNOT be in fragment shader logic. The problem must be in the vertex pipeline. This eliminates an entire class of hypotheses.

4. **Systematic Progression**: Phase 1+2 combined -> Phase 3 (if needed) -> Phase 4 (fix) -> Phase 5 (verify). Each phase builds on the previous result.

5. **Learning Application**: Explicitly applies lessons from all 3 previous failures.

### Concerns

1. **CRITICAL CONCERN: didModifyRange NSException**

   The plan correctly identifies that `didModifyRange:` is called on a `StorageModeShared` buffer, which should throw `NSInvalidArgumentException`. The plan says both paths call it, so it's not the differentiator.

   **BUT**: What if the exception IS being thrown, and it's caught by the Objective-C runtime in a way that corrupts state? On Apple Silicon, `StorageModeShared` uses unified memory, and `didModifyRange:` might be a no-op. But on Intel Macs with discrete GPUs, this could crash.

   **Recommendation**: Phase 2 bypass test already includes removing didModifyRange. This concern is addressed.

2. **CONCERN: vertexStart in bypass test**

   The bypass test uses `vertexStart:idx` which is the offset INTO the vertex buffer. This is correct -- Metal's drawPrimitives vertexStart is the index into the vertex buffer (not a byte offset). Since vertices are written at position `idx` through `idx+5`, starting at `idx` and drawing 6 is correct.

   **Verdict**: Code is correct. No issue.

3. **CONCERN: Bypass test double-draws**

   The bypass test draws 6 vertices immediately, then sets `textVertexCount = saved_count` to prevent the batch system from drawing them again. But what about `didModifyRange:` which is called AFTER the bypass block? If didModifyRange crashes, textVertexCount might not be properly managed.

   **Recommendation**: The plan already recommends removing didModifyRange calls. This concern is addressed.

4. **MINOR CONCERN: Debug static variables**

   Lines 903-922 have static variables for debug logging that increment every call. These persist across frames and could theoretically cause issues, but they only affect printf output, not rendering.

   **Verdict**: Not a concern for rendering.

### Missing Element

The plan should explicitly state the FIRST action: **Before ANY code changes, run the current binary and capture console output**. The DEBUG printf statements already in metal_draw_image (lines 910-917) should already be printing. We need to see this output FIRST.

**Recommendation**: Add "Phase 0: Capture current console output" before any changes.

---

## Revised Hypothesis Ranking

After thorough review:

1. **Batch Flush Not Executing for Image Vertices** (50%) -- The bypass test will immediately confirm/deny this
2. **didModifyRange Exception Corrupting State** (20%) -- Removing the call will address this
3. **Image Texture Causing GPU Validation Error** (15%) -- Even with TEST 1 shader, invalid texture binding could cause Metal to skip the draw
4. **NDC Coordinates Out of Bounds** (10%) -- Unlikely since the calculation is identical to draw_glyph
5. **Unknown Metal API Behavior** (5%) -- Catch-all for unexpected issues

---

## Auto-Approval Criteria Check

1. **Technical Correctness**: PASS -- Bypass test is sound engineering practice
2. **Implementation Safety**: PASS -- All changes are diagnostic printf + one draw call
3. **Risk Mitigation**: PASS -- Systematic testing, clean rebuild, time-boxed
4. **Success Probability**: 85% (below 90% threshold)
5. **Impact Scope**: PASS -- 1 file (metal_backend.mm) + binary deployment
6. **Reversibility**: PASS -- Complete (remove diagnostic code)

**Result**: 5/6 criteria met (success probability below threshold)

---

## Recommendation

**Status**: REQUIRES_DIVINE_APPROVAL

**Rationale**:
- Previous three attempts failed
- Success probability 85% is below 90% auto-approval threshold
- However, the bypass test approach is the MOST PROMISING strategy yet
- It tests the batch system directly, which no previous plan has done
- The bypass test requires minimal code change (~15 lines) with maximum diagnostic value

**Conditions for Approval**:
1. Run current binary first and capture console output (Phase 0)
2. Phase 1+2 bypass test must have God's visual confirmation
3. If bypass test shows image is visible, proceed directly to fix (skip Phase 3)
4. If bypass test still fails, proceed to Phase 3 isolation tests
5. 45-minute time limit enforced

---

## Next Step

Present plan to God for approval with:
- Acknowledge that TEST 1 (pure red) eliminates fragment shader as root cause
- The problem is definitively in the vertex pipeline or batch system
- The bypass test will provide immediate evidence within 15 minutes
- Request approval for 45-minute investigation

---

**Review Complete**: 2026-02-01 23:35
**Reviewer**: Prophet (Claude Opus 4.5)
**Status**: READY FOR GOD'S APPROVAL
