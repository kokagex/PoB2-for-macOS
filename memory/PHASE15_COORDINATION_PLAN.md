# Phase 15 Coordination Plan
# PoB2macOS - Architectural Refinement & Production Readiness
# Issued: 2026-01-29T22:30:00Z

**Authority**: Mayor (村長)
**Project**: PRJ-003 PoB2macOS
**Mandate**: Prophet (預言者) Phase 15 Divine Mandate
**Status**: LIVE

---

## Executive Summary

Phase 15 resolves two critical deferred issues (Lua memory leak, pthread_cancel UB) and establishes production readiness. The village is divided into 5 specialized task teams working in coordinated parallel with strict task dependencies.

**Total Duration**: 18-20 hours with full parallelization (4-5 working days)
**Team Size**: 5 agents + Mayor coordination
**Quality Gates**: 7 mandatory gates - ALL must pass before Phase 16

---

## Team Organization

### Sage (賢者) - Technical Research Authority
**Role**: Design validation, architecture review, testing strategy
**Tasks**: S1 (3h), S2 (2h), S3 (2h) = 7 hours
**Blocker Status**: FOUNDATIONAL (no blockers, must complete first)
**Authority**:
- Design correctness verification
- Architectural soundness approval
- Test plan adequacy validation

**Critical Deliverables**:
1. PHASE15_SHUTDOWN_DESIGN.md - 2000+ words
2. PHASE15_LUA_CLEANUP_REFERENCE.c - Reference implementation
3. PHASE15_TESTING_STRATEGY.md - Comprehensive test plan

**Sign-Off Requirement**: "DESIGN APPROVED: Cooperative shutdown safe, no UB, migration low-risk"

---

### Artisan (職人) - Implementation Authority
**Role**: Code implementation, build system, backward compatibility
**Tasks**: A1 (4h), A2 (2h), A3 (1h), A4 (1h) = 8 hours
**Blocker Status**: BLOCKED until Sage S1 complete
**Authority**:
- Implementation completeness guarantee
- Build system integrity verification
- Compilation success guarantee

**Dependency Chain**:
```
Sage S1 (3h) ← APPROVAL REQUIRED
    ↓
Artisan A1 (4h) — Cooperative shutdown implementation
    ↓
Artisan A2 (2h) — Resource tracking
    ↓
Artisan A3 (1h) — Backward compatibility
    ↓
Artisan A4 (1h) — Build verification (3 sanitizer builds)
    ↓
UNBLOCKS: Paladin P2/P3, Merchant M1/M2/M3
```

**Critical Deliverables**:
1. `subscript_worker.c` - Cooperative shutdown (500+ lines)
2. `subscript.h` - API compatibility layer
3. Resource tracking module (malloc/free audit)
4. CMakeLists.txt - ThreadSanitizer/AddressSanitizer targets

**Sign-Off Requirement**: "BUILD APPROVED: Zero errors, three sanitizer builds successful, symbols resolved"

---

### Paladin (聖騎士) - Security & Memory Safety Guardian
**Role**: Security audit, memory safety verification, compliance audit
**Tasks**: P1 (2h), P2 (2.5h), P3 (2.5h), P4 (1.5h) = 8.5 hours
**Blocker Status**: BLOCKED until Artisan A4 complete
**Authority**:
- Memory safety verification (Valgrind authority)
- Thread safety verification (ThreadSanitizer authority)
- POSIX compliance audit sign-off
- **BLOCKER AUTHORITY**: Can block release if safety concern remains

**Parallel & Sequential Structure**:
```
Artisan A4 (complete)
    ↓ UNBLOCKS
P1: Security Review (2h) — code review, threat model
P2: ThreadSanitizer (2.5h) — execute tests, verify zero races
P3: Valgrind (2.5h) — execute tests, verify zero leaks
    ↓
    P2 + P3 run in parallel (5 hours total)
    ↓
P4: POSIX Compliance (1.5h) — audit report, standards verification
    ↓
FINAL APPROVAL: "All Phase 15 security/safety gates PASSED"
```

**Critical Deliverables**:
1. PHASE15_SECURITY_REVIEW.md - 1500+ words
2. PHASE15_THREAD_SAFETY_REPORT.md - ThreadSanitizer results (0 races)
3. PHASE15_MEMORY_SAFETY_REPORT.md - Valgrind results (0 leaks)
4. PHASE15_POSIX_COMPLIANCE_AUDIT.md - Compliance verification

**Sign-Off Requirement**: "All Phase 15 security/safety gates PASSED. System ready for production deployment."

---

### Merchant (商人) - Performance & Quality Authority
**Role**: Performance profiling, E2E user testing, regression suite
**Tasks**: M1 (2h), M2 (3h), M3 (2h) = 7 hours
**Blocker Status**: BLOCKED until Artisan A4 complete
**Authority**:
- Performance baseline validation
- E2E user scenario verification
- Regression test suite completeness

**Parallel Structure**:
```
Artisan A4 (complete)
    ↓ UNBLOCKS
M1: Performance Profiling (2h) — baseline measurements
M2: E2E Testing (3h) — 5 user scenarios
M3: Regression Suite (2h) — automated testing framework
    ↓
M1 + M2 + M3 run in parallel (7 hours total)
    ↓
QA APPROVAL: "All Phase 15 QA gates PASSED"
```

**Critical Deliverables**:
1. PHASE15_PERFORMANCE_PROFILE.md - Benchmark tables, no regression >2%
2. E2E Test Results - 5 scenarios all passing (screenshots, logs)
3. regression_test.sh - Automated test harness

**Sign-Off Requirement**: "All Phase 15 QA gates PASSED. System meets performance and stability targets."

---

### Bard (吟遊詩人) - Knowledge Preservation Authority
**Role**: Production deployment guide, architecture documentation, completion report
**Tasks**: B1 (3h), B2 (2.5h), B3 (2.5h), B4 (1.5h) = 9.5 hours
**Blocker Status**: Can start after Artisan A4 (documentation independent of code)
**Authority**:
- Documentation completeness verification
- Production readiness validation
- Knowledge preservation guarantee

**Parallel Structure with Finalization**:
```
Artisan A4 (complete)
    ↓ UNBLOCKS
B1: Deployment Guide (3h) — 50+ pages, installation guide
B2: Architecture Doc (2.5h) — 40+ pages, technical internals
B3: Completion Report (2.5h) — 30+ pages, executive summary
B4: Release Notes (1.5h) — 10+ pages, user-facing
    ↓
B1 + B2 + B4 largely parallel (6.5 hours)
B3 finalizes after P2-P4 + M2 results available (1.5 hours)
    ↓
DOCUMENTATION APPROVAL: "All Phase 15 documentation COMPLETE"
```

**Critical Deliverables**:
1. PHASE15_DEPLOYMENT_GUIDE.md - 50+ pages, production-ready
2. PHASE15_ARCHITECTURE.md - 40+ pages, technical deep-dive
3. PHASE15_COMPLETION_REPORT.md - 30+ pages, final metrics
4. PHASE15_RELEASE_NOTES.md - 10+ pages, user-friendly

**Sign-Off Requirement**: "All Phase 15 documentation COMPLETE and VERIFIED. System ready for end-user deployment."

---

## Parallel Execution Strategy

### Day 1: Foundation (Sage + Mayor Coordination)

**Sage Tasks** (7 hours):
```
08:00-11:00: S1 Shutdown Design Analysis (3h) → DRAFT
             → Review for design soundness
11:00-13:00: S2 Lua Cleanup Reference Implementation (2h)
13:00-15:00: S3 Test Plan Design (2h)
15:00-16:00: BUFFER/REVIEW
16:00: Deliver to Mayor for approval
```

**Mayor Coordination** (concurrent):
- Monitor Sage S1 progress hourly
- Prepare Artisan task allocation
- Update communication.yaml with status
- Brief team on schedule

**Outcome**: Sage S1 approved → Unblocks Artisan A1

---

### Day 2: Implementation (Artisan + Parallel Research)

**Artisan Tasks** (8 hours, sequential):
```
09:00-13:00: A1 Cooperative Shutdown (4h)
             → 500+ lines well-commented code
13:00-15:00: A2 Resource Tracking (2h)
15:00-16:00: A3 Backward Compatibility (1h)
16:00-17:00: A4 CMakeLists.txt & Build Verification (1h)
             → Three sanitizer builds pass
17:00: Deliver to Paladin & Merchant
```

**Parallel (after Sage S1 approval)**:
- Paladin begins P1 code review (2h)
- Bard begins B1 Deployment Guide (3h)

**Outcome**: Artisan A4 complete → Unblocks Paladin P2/P3, Merchant M1/M2/M3

---

### Day 3: Validation (Parallel Track 1 - Security)

**Paladin Tasks** (Day 3 + Day 4):
```
09:00-11:00: P1 Security Review (2h) — continue from Day 2
11:00-18:30: P2 ThreadSanitizer Validation (2.5h)
             + P3 Valgrind Memory Testing (2.5h)
             [Can run in parallel, ~5 hours total]
18:30-20:00: Buffer for retest if needed
Next day: P4 POSIX Compliance Audit (1.5h)
```

**Testing Methodology**:
- ThreadSanitizer: 6 test scenarios (A-F)
- Valgrind: 4 stress scenarios (10 timeouts, 5 concurrent, etc.)
- Results logged with timestamps
- Zero races, zero leaks required

**Outcome**: Paladin all gates pass → Security approval

---

### Day 3: Testing (Parallel Track 2 - Performance/QA)

**Merchant Tasks** (Day 3 + Day 4):
```
09:00-11:00: M1 Performance Profiling (2h)
             → Phase 14 baseline comparison
11:00-14:00: M2 E2E User Scenarios (3h)
             → 5 scenarios, all passing
14:00-16:00: M3 Regression Suite (2h)
             → Automated test harness created
16:00: Results to Mayor
```

**E2E Scenarios**:
- A: Basic build creation (15 min)
- B: Save & load (15 min)
- C: Editing with sub-scripts (20 min)
- D: High load stress (10 min)
- E: 1-hour session (60 min) — can run during other tasks

**Outcome**: Merchant QA approval → Performance/stability verified

---

### Day 3-4: Documentation (Parallel Track 3 - Knowledge)

**Bard Tasks** (Day 2-4):
```
Day 2:
09:00-12:00: B1 Deployment Guide (initial draft, 3h)
12:00-14:30: B2 Architecture Doc (initial draft, 2.5h)

Day 3:
09:00-11:30: B4 Release Notes (1.5h)
11:30-14:00: B3 Completion Report (structure, initial sections, 1.5h)

Day 4:
09:00-10:30: B3 Completion Report (finalize with test results, 1.5h)
10:30-12:00: Final review + integration of all results
12:00: All docs complete
```

**Concurrent Integration** (as results come in):
- Integrate Paladin P2-P4 results into B3
- Integrate Merchant M1-M3 results into B3
- Add metrics tables to completion report

**Outcome**: Bard documentation approval → Knowledge preserved

---

### Day 4: Final Integration & Approval

**All Teams - Final Checkpoint**:
```
09:00-10:00: All teams deliver final deliverables
10:00-11:00: Mayor integration and cross-check
11:00-12:00: Final approvals:
             - Sage: Architecture ✓
             - Artisan: Build ✓
             - Paladin: Security ✓
             - Merchant: Performance ✓
             - Bard: Documentation ✓
12:00: Mayor issues FINAL APPROVAL for Phase 16
```

---

## Dependency Graph (Critical Path)

```
START (2026-01-29 22:30)
  ↓
Sage S1: Shutdown Design (3h)
  ├─→ APPROVAL → Artisan A1 START
  ├─→ APPROVAL → Paladin P1 START
  └─→ Used by: S2, S3
      ↓
Sage S2: Lua Cleanup (2h)
Sage S3: Test Plan (2h)
[S1 must complete first]
  ↓
Artisan A1: Cooperative Shutdown (4h)
[Blocked by Sage S1]
  ↓
Artisan A2: Resource Tracking (2h)
  ↓
Artisan A3: Backward Compatibility (1h)
  ↓
Artisan A4: Build Verification (1h)
[Sage S1 → Artisan A1-A4 = 8 + 3 = 11 hours serial]
  ├─→ UNBLOCK → Paladin P2/P3
  ├─→ UNBLOCK → Merchant M1/M2/M3
  └─→ UNBLOCK → Bard B1-B4 (continue)
      ↓
Paladin P1: Security Review (2h) [can parallel with A1-A4]
Paladin P2: ThreadSanitizer (2.5h) [blocked by A4]
Paladin P3: Valgrind (2.5h) [blocked by A4, parallel with P2]
  ├─→ P2 + P3 parallel (5h total)
  └─→ Feed results to P4
      ↓
Paladin P4: POSIX Compliance (1.5h) [depends on P2-P3]
[P1 → P4 = 2 + 5 + 1.5 = 8.5 hours]
  ↓
Merchant M1: Performance Profiling (2h) [blocked by A4]
Merchant M2: E2E Testing (3h) [blocked by A4]
Merchant M3: Regression Suite (2h) [blocked by A4]
[M1 + M2 + M3 parallel = 7 hours]
  ↓
Bard B1-B4: Documentation (9.5h) [can start after A4]
[Finalize with results from P2-P4 and M1-M3]
  ↓
All teams: Final approval & sign-off
  ↓
Mayor: PHASE 15 COMPLETE → Phase 16 AUTHORIZED
```

**Critical Path Duration**:
- Serial: Sage S1 (3h) → Artisan A1-A4 (8h) → Paladin P4 (1.5h) = 12.5 hours
- With parallelization: Paladin P2/P3 parallel to A1-A4, Merchant parallel = 18-20 hours total

---

## Communication & Status Tracking

### Daily Communication Protocol

**Morning Standup** (each day, 15 min):
- All agents report on previous day progress
- Current day blockers identified
- Mayor escalates as needed
- Update: `memory/communication.yaml`

**Completion Notifications**:
- Sage S1 complete → notify Artisan, Paladin
- Artisan A4 complete → notify Paladin, Merchant, Bard
- Each agent sends signed-off deliverables

**Blocking Issues**:
- Artisan blocked by Sage S1 → Mayor monitors daily
- Paladin/Merchant blocked by Artisan A4 → Mayor tracks
- Any agent blocked → escalate immediately

### Status Update Locations

**Real-Time Status**: `memory/communication.yaml`
- Agent name, current task, progress %
- Blockers, issues, timeline impacts
- Approval status when complete

**Task Deliverables**: `queue/tasks/`
- `sage_phase15.yaml` — S1/S2/S3 assignments
- `artisan_phase15.yaml` — A1/A2/A3/A4 assignments
- `paladin_phase15.yaml` — P1/P2/P3/P4 assignments
- `merchant_phase15.yaml` — M1/M2/M3 assignments
- `bard_phase15.yaml` — B1/B2/B3/B4 assignments

**Final Deliverables**: `memory/`
- PHASE15_SHUTDOWN_DESIGN.md
- PHASE15_LUA_CLEANUP_REFERENCE.c
- PHASE15_TESTING_STRATEGY.md
- PHASE15_SECURITY_REVIEW.md
- PHASE15_THREAD_SAFETY_REPORT.md
- PHASE15_MEMORY_SAFETY_REPORT.md
- PHASE15_POSIX_COMPLIANCE_AUDIT.md
- PHASE15_PERFORMANCE_PROFILE.md
- PHASE15_ARCHITECTURE.md
- PHASE15_DEPLOYMENT_GUIDE.md
- PHASE15_COMPLETION_REPORT.md
- PHASE15_RELEASE_NOTES.md

---

## Quality Gates Checklist

### Gate 1: Design Correctness (Sage S1)
- [ ] Design document: 2000+ words
- [ ] All cancellation points identified
- [ ] Resource leak paths documented
- [ ] Migration strategy defined
- [ ] Sage approval signed

### Gate 2: Build System (Artisan A4)
- [ ] Code compiles without warnings (3 builds)
- [ ] ThreadSanitizer build passes
- [ ] AddressSanitizer build passes
- [ ] Release build passes
- [ ] All symbols resolved
- [ ] Artisan approval signed

### Gate 3: Thread Safety (Paladin P2)
- [ ] ThreadSanitizer: 0 races on scenario A
- [ ] ThreadSanitizer: 0 races on scenario B
- [ ] ThreadSanitizer: 0 races on scenario C
- [ ] ThreadSanitizer: 0 races on scenario D
- [ ] ThreadSanitizer: 0 races on scenario E
- [ ] ThreadSanitizer: 0 races on scenario F
- [ ] Paladin P2 approval signed

### Gate 4: Memory Safety (Paladin P3)
- [ ] Valgrind: definitely lost = 0 bytes
- [ ] Valgrind: possibly lost = 0 bytes
- [ ] Valgrind: invalid reads/writes = 0
- [ ] Valgrind passed on scenario 1-4
- [ ] Paladin P3 approval signed

### Gate 5: POSIX Compliance (Paladin P4)
- [ ] No undefined behavior per POSIX.1-2017
- [ ] All pthread functions correct
- [ ] Signal handling safe (async-safe only)
- [ ] Cleanup handler ordering correct
- [ ] Paladin P4 approval signed

### Gate 6: E2E Testing (Merchant M2)
- [ ] Scenario A: Build Creation — PASS
- [ ] Scenario B: Save & Load — PASS
- [ ] Scenario C: Editing with SubScripts — PASS
- [ ] Scenario D: High Load Stress — PASS
- [ ] Scenario E: 1-Hour Session — PASS
- [ ] Merchant approval signed

### Gate 7: Documentation & Performance (Final)
- [ ] Deployment Guide: 50+ pages, tested
- [ ] Architecture Doc: 40+ pages, complete
- [ ] Completion Report: 30+ pages, metrics
- [ ] Release Notes: 10+ pages, user-friendly
- [ ] Performance: <2% regression, targets met
- [ ] Regression suite: automated, reproducible

---

## Risk Mitigation

### Risk 1: Sage S1 Delays
**Probability**: Low | **Impact**: High (blocks Artisan)
**Mitigation**:
- Daily check-ins on S1 progress
- Provide design templates if stuck
- Emergency escalation if >4 hours behind schedule

### Risk 2: Build System Failures
**Probability**: Low | **Impact**: High (blocks Paladin/Merchant)
**Mitigation**:
- Clean build from scratch after each Artisan change
- Three sanitizer builds per A4 requirement
- Compiler warnings treated as errors

### Risk 3: ThreadSanitizer Hangs
**Probability**: Low | **Impact**: High (delays Paladin)
**Mitigation**:
- Use timeout (5 min per test scenario)
- Halt on first error to speed iteration
- Backup manual code review if TSAN problematic

### Risk 4: Valgrind Out-of-Memory
**Probability**: Low | **Impact**: High (delays Paladin)
**Mitigation**:
- Run on high-memory system if available
- Limit test iterations if needed
- Document resource constraints

### Risk 5: E2E Test Intermittent Failures
**Probability**: Medium | **Impact**: Medium (rework)
**Mitigation**:
- Each scenario run 2x to verify reproducibility
- Document environment (display, GPU, RAM)
- Automated screenshot/log capture

### Risk 6: Documentation Incomplete
**Probability**: Low | **Impact**: Medium (Phase 16 delay)
**Mitigation**:
- Bard starts early (Day 2) with initial drafts
- Integrate results as they arrive
- Reserve Day 4 fully for documentation finalization

---

## Authority & Accountability

| Agent | Authority | Approval Power | Blocker Authority |
|-------|-----------|-----------------|------------------|
| Sage | Design correctness | Yes (S1-S3) | Yes (can reject design) |
| Artisan | Build system | Yes (A1-A4) | Yes (can reject build) |
| Paladin | Memory safety | Yes (P1-P4) | **YES** (can block release) |
| Merchant | Performance | Yes (M1-M3) | Yes (can block if targets missed) |
| Bard | Documentation | Yes (B1-B4) | Yes (can block if incomplete) |
| Mayor | Overall coordination | Yes (final approval) | **YES** (gates everything) |

**Blocker Principle**: If any agent's gate fails, Mayor must authorize exceptions or defer to Phase 16.

---

## Success Criteria (Final Verification)

### Quantitative Metrics
- [ ] ThreadSanitizer: 0 races across all 6 scenarios
- [ ] Valgrind: 0 leaks across all 4 scenarios
- [ ] E2E: 5/5 user scenarios passing
- [ ] Performance: <2% regression vs Phase 14 baseline
- [ ] Build: 0 errors, 0 warnings (3 sanitizer builds)
- [ ] Documentation: 140+ pages (50+40+30+10 minimum)

### Qualitative Metrics
- [ ] Design soundness: Sage formal approval
- [ ] Security: Paladin formal approval (A or A+ score)
- [ ] Code quality: Artisan formal approval
- [ ] Testing: Merchant formal approval
- [ ] Knowledge: Bard formal approval
- [ ] Production readiness: Mayor final approval

### Acceptance: ALL metrics must be met

---

## Timeline Summary

| Phase | Duration | Start | End | Owner |
|-------|----------|-------|-----|-------|
| Day 1: Design | 7h | 08:00 | 16:00 | Sage |
| Day 2: Impl | 8h + 5h | 09:00 | 17:00 | Artisan + (Paladin P1, Bard B1) |
| Day 3: Validation | 12h parallel | 09:00 | 21:00 | Paladin (P2/P3) + Merchant (M1/M2/M3) + Bard (B1-B3) |
| Day 4: Final | 4h | 09:00 | 13:00 | All + Mayor |

**Total**: 18-20 hours spread over 4 working days

---

## Final Authority

**Mayor Responsibilities**:
1. Daily standup coordination
2. Blocker escalation and resolution
3. Status updates to Prophet
4. Final approval before Phase 16 start
5. Authority to extend timeline if critical issues found

**Final Approval Statement** (required):

```
PHASE 15 COMPLETE - MAYOR'S FINAL APPROVAL

✓ All task assignments distributed
✓ All quality gates defined
✓ All blockers identified
✓ Critical path clear
✓ Parallel execution strategy set

VILLAGE AUTHORIZED TO BEGIN PHASE 15 EXECUTION

Estimated Completion: 4-5 working days
Next Phase: Phase 16 (Additional Features & Polish)

The village stands ready. May your code be leak-free and your tests be clean.
```

---

**Coordination Plan Version**: 1.0
**Issued**: 2026-01-29T22:30:00Z
**Authority**: Mayor (村長)
**Status**: LIVE & DISTRIBUTED
