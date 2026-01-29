# Phase 15 Divine Mandate - Complete Documentation Index

**Issued**: 2026-01-29 22:30 UTC
**Authority**: Prophet (預言者)
**Project**: PRJ-003 PoB2macOS
**Status**: MANDATE ISSUED - AWAITING MAYOR ACKNOWLEDGMENT

---

## Quick Access Guide

### For Busy People (5 minutes)
- Read: `PHASE15_MANDATE_SUMMARY.txt` (16 KB text file)
- Contains: Executive summary, quality gates, task assignments, timeline

### For Project Managers (15 minutes)
- Read: `PHASE15_QUICK_REFERENCE.md` (9.1 KB markdown)
- Contains: Task matrix, dependencies, risk summary, coordination protocol

### For Technical Teams (1+ hours)
- Read: `queue/prophet_phase15_mandate.yaml` (34 KB, 1,077 lines)
- Contains: Complete technical specifications, architecture, test plans, all details

---

## Core Documents

### Main Mandate
**File**: `/Users/kokage/national-operations/claudecode01/queue/prophet_phase15_mandate.yaml`
**Size**: 34 KB (1,077 lines)
**Content**: 
- Complete technical specifications
- Detailed task assignments (Sage, Artisan, Paladin, Merchant, Bard)
- Architecture summary and design rationale
- Dependency graph with critical path
- Risk mitigation strategies
- Production readiness checklist
- Authority and accountability framework

**Key Sections**:
1. Divine Declaration (mission statement)
2. Phase 15 Objectives (goals and success criteria)
3. Architecture Summary (issue analysis, proposed solutions)
4. Detailed Task Assignment (24 subtasks across 5 agents)
5. Dependency Graph (critical path analysis)
6. Risk Mitigation (6 key risks identified)
7. Deliverables Checklist (all outputs required)
8. Success Metrics Table (achievement criteria)
9. Timeline & Milestones (4-5 day schedule)
10. Authority & Accountability (role definitions)
11. Production Readiness Gate (mandatory checklist)

### Executive Summary
**File**: `/Users/kokage/national-operations/claudecode01/PHASE15_MANDATE_SUMMARY.txt`
**Size**: 16 KB
**Content**:
- Mandate overview (Phase 14 achievements, Phase 15 mission)
- Quality gates (8 mandatory checkpoints)
- Task assignment summary (effort estimates per agent)
- Critical path and timeline
- Deliverables breakdown
- Risk mitigation matrix
- Sign-off requirements
- Next steps for Mayor

**Audience**: Executives, project managers, quality assurance

### Quick Reference
**File**: `/Users/kokage/national-operations/claudecode01/memory/PHASE15_QUICK_REFERENCE.md`
**Size**: 9.1 KB
**Content**:
- Executive summary (1 paragraph)
- Quick task summary (effort, blockers)
- Critical path (visual diagram)
- Quality gates (8 mandatory tests)
- Key deliverables (prioritized list)
- Deferred issues explained (simple language)
- Success criteria checklist
- Mayor's coordination items

**Audience**: Team leads, daily standups, quick reference

---

## Understanding the Deferred Issues

### Issue 1: CRITICAL - Lua State Memory Leak on pthread_cancel

**Problem Summary**:
- When a sub-script times out, `pthread_cancel()` terminates worker thread
- Worker thread exits immediately without cleanup
- Lua cleanup handler NOT registered → `lua_close()` never called
- Result: ~1KB memory leak per timeout
- After 16 timeouts: all 16 slots exhausted, no more sub-scripts can run

**Location in Code**:
```
File: /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/subscript_worker.c
Function: timeout_watchdog_thread()
Line: ~180 (pthread_cancel call)
```

**CWE Classification**:
- CWE-401: Missing Release of Memory after Effective Lifetime

**Solution Approach**:
1. Register `pthread_cleanup_push()` handler before user code
2. Handler calls `lua_close()` when thread exits
3. Add resource tracking to verify all cleanups occurred
4. Validate with valgrind: 100 sequential timeouts = 0 leaks

**Implementation Task**: 
- Artisan A1: Cooperative shutdown implementation (4 hours)

**Validation Task**:
- Paladin P3: Valgrind memory verification (2.5 hours) - MANDATORY GATE

### Issue 2: HIGH - Undefined Behavior (pthread_cancel on Detached Thread)

**Problem Summary**:
- POSIX Standard says: `pthread_cancel()` on detached thread = undefined behavior
- Current code creates worker threads as DETACHED, then cancels them
- Result: unpredictable behavior - may crash, leak, hang, or appear to work

**Location in Code**:
```
File: /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/subscript_worker.c
Function: subscript_worker_thread() creation
Lines: ~60-70 (pthread_attr_setdetachstate)
```

**Why It's a Problem**:
- Detached threads auto-deallocate their resources when they exit
- You can't safely cancel a thread that's deallocating itself
- Creates race conditions and unpredictable behavior
- Violates POSIX.1-2017 standard

**Solution Approach - Cooperative Shutdown**:
1. Change threads from DETACHED to JOINABLE
2. Each worker checks volatile flag: `while (!shutdown_requested)`
3. On timeout: set flag (atomic), optionally send SIGUSR1 to wake from I/O
4. Thread exits gracefully, cleanup handler called
5. Main thread calls `pthread_join()` to confirm exit
6. Result: 100% POSIX compliant, predictable, safe

**Benefits**:
- No undefined behavior (full POSIX compliance)
- Predictable cleanup order
- Thread can flush pending operations
- Works correctly with Lua cleanup
- Prevents crashes and hangs

**Implementation Task**:
- Artisan A1: Cooperative shutdown implementation (4 hours)

**Design Task**:
- Sage S1: Cooperative shutdown design (3 hours)

**Validation Task**:
- Paladin P2: ThreadSanitizer verification (2.5 hours) - MANDATORY GATE
- Paladin P4: POSIX compliance audit (1.5 hours)

---

## Agent Task Matrix

### SAGE (賢者) - Technical Research Authority
| Task | Duration | Deliverable | Status |
|------|----------|-------------|--------|
| S1: Shutdown Design | 3h | PHASE15_SHUTDOWN_DESIGN.md | [ ] |
| S2: Lua Cleanup Impl | 2h | Ref implementation code | [ ] |
| S3: Test Strategy | 2h | PHASE15_TESTING_STRATEGY.md | [ ] |
| **Total** | **7h** | **3 documents** | - |

### ARTISAN (職人) - Implementation Authority
| Task | Duration | Deliverable | Status |
|------|----------|-------------|--------|
| A1: Cooperative Shutdown | 4h | subscript_worker.c updates | [ ] |
| A2: Resource Tracking | 2h | Memory accounting module | [ ] |
| A3: Backward Compat | 1h | API compatibility layer | [ ] |
| A4: Build Verification | 1h | CMakeLists.txt + targets | [ ] |
| **Total** | **8h** | **Updated source + build** | - |

### PALADIN (聖騎士) - Security & Memory Guardian
| Task | Duration | Deliverable | **Gate?** | Status |
|------|----------|-------------|----------|--------|
| P1: Security Review | 2h | PHASE15_SECURITY_REVIEW.md | - | [ ] |
| P2: ThreadSanitizer | 2.5h | Zero races report | **YES** | [ ] |
| P3: Valgrind | 2.5h | Zero leaks report | **YES** | [ ] |
| P4: POSIX Audit | 1.5h | Compliance sign-off | - | [ ] |
| **Total** | **8.5h** | **4 reports + 2 gates** | - | - |

### MERCHANT (商人) - Performance & Quality
| Task | Duration | Deliverable | **Gate?** | Status |
|------|----------|-------------|----------|--------|
| M1: Perf Profile | 2h | PHASE15_PERFORMANCE_PROFILE.md | - | [ ] |
| M2: E2E Testing | 3h | 5 scenario results | **YES** | [ ] |
| M3: Regression Suite | 2h | Automated test harness | - | [ ] |
| **Total** | **7h** | **3 documents + tests** | - | - |

### BARD (吟遊詩人) - Documentation Authority
| Task | Duration | Deliverable | **Gate?** | Status |
|------|----------|-------------|----------|--------|
| B1: Deployment Guide | 3h | PHASE15_DEPLOYMENT_GUIDE.md | **YES** | [ ] |
| B2: Architecture | 2.5h | PHASE15_ARCHITECTURE.md | - | [ ] |
| B3: Completion Report | 2.5h | PHASE15_COMPLETION_REPORT.md | - | [ ] |
| B4: Release Notes | 1.5h | PHASE15_RELEASE_NOTES.md | - | [ ] |
| **Total** | **9.5h** | **4 documents (1 gate)** | - | - |

**Total Effort**: 40 hours serial, 18-20 hours with parallelization

---

## Quality Gates (MANDATORY)

These 5 gates MUST ALL pass before Phase 16 can begin:

### Gate 1: ThreadSanitizer Clean (Paladin P2)
- Requirement: Zero data races detected
- Test scenarios: 6 scenarios (S1-S6 from testing strategy)
- Acceptance: ThreadSanitizer output shows "0 races detected"
- Blocker: If fails, must fix race conditions

### Gate 2: Valgrind Clean (Paladin P3)
- Requirement: Zero memory leaks
- Test scenarios: 100+ sequential timeouts, stress tests
- Acceptance: "definitely lost: 0 bytes", "possibly lost: 0 bytes"
- Blocker: If fails, must fix memory leaks

### Gate 3: E2E User Scenarios (Merchant M2)
- Requirement: All 5 user workflows pass
  - A: Basic build creation
  - B: Save & load build
  - C: Build editing with subscripts
  - D: High load stress (3 clicks/second)
  - E: Long session (1 hour stability)
- Acceptance: All scenarios complete without crash
- Blocker: If any scenario fails, must fix

### Gate 4: Production Deployment Guide (Bard B1)
- Requirement: 50+ pages comprehensive guide
- Content: System requirements, installation, configuration, troubleshooting
- Acceptance: Tested on clean system, non-technical users can follow
- Blocker: If incomplete, must complete

### Gate 5: POSIX Compliance (Paladin P4)
- Requirement: No undefined behavior per POSIX.1-2017
- Verification: Paladin audit confirms compliance
- Acceptance: Written sign-off from Paladin
- Blocker: If fails, must address all compliance issues

**CRITICAL**: All 5 gates must show PASS before Mayor can approve Phase 16

---

## Critical Path Analysis

```
Start: Sage S1 (Design Analysis) - 3 hours
       ↓ (depends on)
Artisan A1 (Implementation) - 4 hours (parallel: A2, Merchant M1, Paladin P1)
       ↓
Artisan A2-A4 (Complete impl) - 4 hours
       ↓
Paladin P2/P3 (Validation gates) - 5 hours (CRITICAL GATES)
       ↓
Paladin P4 (POSIX audit) - 1.5 hours
       ↓
Bard B1-B4 (Documentation) - 9.5 hours (finalization)
       ↓
Mayor Approval (Phase 16 Go)

Minimum serial time: 26.5 hours
With full parallelization: 18-20 hours
Recommended realistic: 18-20 hours (4-5 working days)
```

**Critical Blockers**:
1. Artisan A1 blocks all Paladin validation (can't test what doesn't exist)
2. Paladin P2/P3 block Phase 16 (quality gates)
3. Sage S1 blocks Artisan A1 (need design first)

---

## Timeline Milestones

### Day 1: Foundation & Design
**Duration**: ~7 hours
- Sage S1: Cooperative shutdown design
- Sage S2: Lua cleanup handler reference
- Sage S3: Test strategy document
- **Outcome**: Design complete, ready for implementation

### Day 2: Implementation & Testing
**Duration**: ~12 hours
- Artisan A1-A4: Cooperative shutdown implementation
- Merchant M1: Performance profiling
- Paladin P1: Security review
- **Outcome**: Code implemented, build verified, ready for validation

### Day 3: Validation & Audit
**Duration**: ~11.5 hours
- Paladin P2: ThreadSanitizer validation (GATE 1)
- Paladin P3: Valgrind validation (GATE 2)
- Paladin P4: POSIX compliance audit
- Merchant M2: E2E user scenarios (GATE 3)
- Merchant M3: Regression test suite
- **Outcome**: Quality gates passed, all testing complete

### Day 4: Documentation & Finalization
**Duration**: ~9.5 hours
- Bard B1: Production deployment guide (GATE 4)
- Bard B2: Architecture internals
- Bard B3: Completion report
- Bard B4: Release notes
- **Outcome**: All documentation complete, ready for production

### Day 5: Final Verification & Go-Live
**Duration**: ~2-4 hours
- Final gate verification (all 5 gates confirm PASS)
- Mayor sign-off
- Phase 16 approval
- **Outcome**: Phase 16 go-ahead or issue resolution

---

## Production Readiness Checklist

**MANDATORY**: All items must be checked before Phase 16

### Code Quality
- [ ] Zero memory leaks (Valgrind P3)
- [ ] Zero undefined behavior (ThreadSanitizer P2)
- [ ] POSIX compliant (Paladin P4)
- [ ] No new CWEs introduced
- [ ] Security score A or A+

### Performance
- [ ] Startup time <3 seconds
- [ ] FPS sustained at 60
- [ ] Memory peak <500MB
- [ ] Regression <2% vs Phase 14

### Testing
- [ ] E2E scenarios all pass (Merchant M2)
- [ ] Regression suite all pass
- [ ] ThreadSanitizer clean
- [ ] Valgrind clean
- [ ] POSIX compliance verified

### Documentation
- [ ] Deployment guide (Bard B1)
- [ ] Architecture guide (Bard B2)
- [ ] Completion report (Bard B3)
- [ ] Release notes (Bard B4)
- [ ] All 8+ files complete

### Known Issues
- [ ] All issues documented
- [ ] Workarounds provided
- [ ] No CRITICAL unsolved
- [ ] Phase 16 roadmap clear

### Final Sign-Off
- [ ] Sage: Architecture approved
- [ ] Artisan: Build approved
- [ ] Paladin: Security approved ← CRITICAL
- [ ] Merchant: Performance approved
- [ ] Bard: Documentation approved
- [ ] Mayor: FINAL APPROVAL for Phase 16

---

## How to Use These Documents

### For Agents Receiving Tasks
1. Start with: `PHASE15_QUICK_REFERENCE.md` (overview of your role)
2. Read: Complete task description in `queue/prophet_phase15_mandate.yaml`
3. Reference: This index file as you progress
4. Report: Daily updates to `memory/communication.yaml`

### For Quality Assurance
1. Check: Quality gates checklist against actual test results
2. Verify: All 5 gates pass (ThreadSanitizer, Valgrind, E2E, Deployment, POSIX)
3. Validate: All deliverables exist and meet requirements
4. Sign-off: On behalf of your agent role

### For Project Manager (Mayor)
1. Overview: `PHASE15_MANDATE_SUMMARY.txt` (big picture)
2. Assign: Tasks from matrix to each agent
3. Monitor: Critical path (Sage S1 → Artisan A1 → Validation)
4. Escalate: Any blockers immediately (especially Paladin issues)
5. Approve: Only after ALL quality gates PASS

### For Deployment & Operations
1. Read: `PHASE15_DEPLOYMENT_GUIDE.md` (after Phase 15 complete)
2. Reference: `PHASE15_ARCHITECTURE.md` for internals
3. Check: `PHASE15_RELEASE_NOTES.md` for known issues
4. Monitor: Using baseline metrics from `PHASE15_PERFORMANCE_PROFILE.md`

---

## File Locations

### Main Mandate
- `/Users/kokage/national-operations/claudecode01/queue/prophet_phase15_mandate.yaml` (34 KB)

### Supporting Documents
- `/Users/kokage/national-operations/claudecode01/PHASE15_MANDATE_SUMMARY.txt` (16 KB)
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_QUICK_REFERENCE.md` (9.1 KB)
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_MANDATE_INDEX.md` (this file)

### Future Deliverables (to be created during Phase 15)
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_SHUTDOWN_DESIGN.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_SECURITY_REVIEW.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_DEPLOYMENT_GUIDE.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_ARCHITECTURE.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_COMPLETION_REPORT.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_RELEASE_NOTES.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_PERFORMANCE_PROFILE.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_TESTING_STRATEGY.md`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_LUA_CLEANUP_REFERENCE.c`
- `/Users/kokage/national-operations/claudecode01/memory/PHASE15_MEMORY_SAFETY_REPORT.md`

---

## Next Steps

### For Mayor (Immediate)
1. Acknowledge receipt of Phase 15 mandate
2. Distribute documents to all agents
3. Assign task owners
4. Schedule daily 15-minute standups
5. Monitor critical path: Sage S1 → Artisan A1 → Build A4 → Quality Gates

### For All Agents (Today)
1. Read: PHASE15_QUICK_REFERENCE.md
2. Understand: Your assigned tasks
3. Identify: Blockers or dependencies
4. Report: Any questions or concerns

### Timeline
- **Day 1**: Mandate distribution + task assignments
- **Days 2-5**: Parallel execution + daily standups
- **Day 6**: Final verification + Phase 16 go/no-go

---

**Document**: PHASE15_MANDATE_INDEX.md
**Created**: 2026-01-29 22:30 UTC
**Authority**: Prophet (預言者)
**Status**: REFERENCE GUIDE FOR PHASE 15 EXECUTION
