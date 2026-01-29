# Phase 15 Divine Mandate - Complete Index & Navigation Guide

**Issued**: 2026-01-29T22:30:00Z  
**Authority**: Prophet (預言者)  
**Distributed By**: Mayor (村長)  
**Status**: ACKNOWLEDGED & ACTIVE

---

## Quick Navigation

### For Busy People (5-Minute Overview)
- **Start here**: `PHASE15_DISTRIBUTION_SUMMARY.txt` (executive summary)
- **Quick specs**: `memory/PHASE15_QUICK_REFERENCE.md` (1-page per agent)
- **Full mandate**: `queue/prophet_phase15_mandate.yaml` (original document)

### For Project Managers (30-Minute Planning)
1. `PHASE15_DISTRIBUTION_SUMMARY.txt` - Executive overview
2. `memory/PHASE15_COORDINATION_PLAN.md` - Full strategy
3. Individual task files: `queue/tasks/[agent]_phase15.yaml`

### For Village Agents (Detailed Work)
1. Your assigned task file (e.g., `queue/tasks/sage_phase15.yaml`)
2. `memory/PHASE15_QUICK_REFERENCE.md` - Background context
3. `memory/PHASE15_COORDINATION_PLAN.md` - Dependencies & integration
4. `queue/prophet_phase15_mandate.yaml` - Full technical details

### For Quality Gatekeepers (Paladin)
1. `queue/tasks/paladin_phase15.yaml` - Your 8.5-hour assignment
2. `memory/PHASE15_COORDINATION_PLAN.md` - Gate definitions (section: Quality Gates Checklist)
3. `queue/prophet_phase15_mandate.yaml` - Lines 345-461 (detailed P1-P4 specs)

### For Status Tracking (Mayor)
1. `memory/PHASE15_COORDINATION_PLAN.md` - Daily schedule & dependencies
2. `memory/communication.yaml` - Real-time status updates
3. `memory/dashboard.md` - Phase 15 progress section

---

## Document Map

### Central Authority Documents (Read First)

| Document | Purpose | Length | Read Time |
|----------|---------|--------|-----------|
| `queue/prophet_phase15_mandate.yaml` | Original mandate with full technical details | 1,077 lines | 30-45 min |
| `PHASE15_DISTRIBUTION_SUMMARY.txt` | Mayor's acknowledgment & task summary | ~300 lines | 10-15 min |
| `PHASE15_MAYOR_ACKNOWLEDGMENT.md` | Official receipt & authorization | ~400 lines | 15-20 min |
| `memory/PHASE15_QUICK_REFERENCE.md` | One-page reference per agent | 288 lines | 5-10 min |

### Planning & Coordination (Required Reading for Leads)

| Document | Purpose | For Whom | Read Time |
|----------|---------|----------|-----------|
| `memory/PHASE15_COORDINATION_PLAN.md` | Execution strategy, dependencies, timeline | Leads, Mayor | 20-30 min |
| `memory/dashboard.md` | Current project status (search "Phase 15") | Mayor, Leads | 5-10 min |

### Individual Task Assignments (Detailed Specifications)

| Document | Agent | Tasks | Hours | Read Time |
|----------|-------|-------|-------|-----------|
| `queue/tasks/sage_phase15.yaml` | Sage | S1/S2/S3 | 7 | 15-20 min |
| `queue/tasks/artisan_phase15.yaml` | Artisan | A1/A2/A3/A4 | 8 | 15-20 min |
| `queue/tasks/paladin_phase15.yaml` | Paladin | P1/P2/P3/P4 | 8.5 | 15-20 min |
| `queue/tasks/merchant_phase15.yaml` | Merchant | M1/M2/M3 | 7 | 15-20 min |
| `queue/tasks/bard_phase15.yaml` | Bard | B1/B2/B3/B4 | 9.5 | 15-20 min |

### Status Tracking (Real-Time Updates)

| File | Purpose | Updated By | Frequency |
|------|---------|------------|-----------|
| `memory/communication.yaml` | Daily standup, blockers, progress | All agents | Daily |
| `memory/dashboard.md` | Project status summary | Mayor | Daily |

### Historical/Reference (Backup Reading)

| Document | Purpose | Relates To |
|----------|---------|-----------|
| `memory/PHASE14_COMPLETION_REPORT.md` | Phase 14 results (baseline) | Performance profiling |
| `memory/paladin_phase14_security_report.md` | Phase 14 security (context) | Security improvements |

---

## Critical Path for Each Agent

### SAGE - Start Immediately (Blocker)
```
START → S1: Shutdown Design (3h) → APPROVAL GATE
            ├→ S2: Lua Cleanup Reference (2h)
            └→ S3: Test Plan (2h)
→ Deliver to Mayor for sign-off
→ UNBLOCKS: Artisan A1, Paladin P1
```
**Timeline**: Day 1 (7 hours total)  
**Task File**: `queue/tasks/sage_phase15.yaml`

### ARTISAN - Waits for Sage S1 Approval
```
BLOCKED BY: Sage S1 approval
            ↓
            A1: Cooperative Shutdown (4h) → BUILD
            A2: Resource Tracking (2h) → VERIFY
            A3: Backward Compatibility (1h) → TEST
            A4: Build Verification (1h) → SIGN-OFF
            ↓
UNBLOCKS: Paladin P2/P3, Merchant M1/M2/M3, Bard B1-B4
```
**Timeline**: Day 2 (8 hours total)  
**Task File**: `queue/tasks/artisan_phase15.yaml`  
**Dependencies**: Sage S1, S2

### PALADIN - Parallel Tracks
```
BLOCKED BY: Artisan A4 completion
            ↓
            P1: Security Review (2h) — runs during Artisan A1-A4
            ↓
            P2: ThreadSanitizer (2.5h) ┐
            P3: Valgrind (2.5h)        ├→ PARALLEL (5h total)
            ↓
            P4: POSIX Compliance (1.5h) — finalized after P2/P3
            ↓
            FINAL APPROVAL GATE (can BLOCK Phase 16)
```
**Timeline**: Days 2-4 (8.5 hours total, ~6h on Days 3-4)  
**Task File**: `queue/tasks/paladin_phase15.yaml`  
**Authority**: BLOCKER (can prevent Phase 16 if gates fail)

### MERCHANT - Parallel Tracks
```
BLOCKED BY: Artisan A4 completion
            ↓
            M1: Performance Profiling (2h) ┐
            M2: E2E Testing (3h)           ├→ PARALLEL (7h total)
            M3: Regression Suite (2h)      ┘
            ↓
            QA APPROVAL GATE
```
**Timeline**: Days 3-4 (7 hours total, mostly parallel)  
**Task File**: `queue/tasks/merchant_phase15.yaml`  
**E2E Scenarios**: 5 complete workflows (1.5 hours total runtime)

### BARD - Start After Artisan A4
```
CAN START: After Artisan A4 (independent of code)
           ↓
           B1: Deployment Guide (3h) ┐
           B2: Architecture (2.5h)    ├→ MOSTLY PARALLEL (9.5h)
           B4: Release Notes (1.5h)   ┘
           ↓ (integrate test results)
           B3: Completion Report (finalized, 2.5h)
           ↓
           DOCUMENTATION APPROVAL GATE (100+ pages)
```
**Timeline**: Days 2-4 (9.5 hours, concurrent with testing)  
**Task File**: `queue/tasks/bard_phase15.yaml`  
**Documentation**: 50+40+30+10 = 140+ pages minimum

---

## Quality Gates (Success Criteria)

### Gate 1: Design Correctness
- **Owner**: Sage (S1)
- **Location**: `queue/tasks/sage_phase15.yaml` (lines ~55-235)
- **Deliverable**: `PHASE15_SHUTDOWN_DESIGN.md`
- **Requirements**: 2000+ words, all cancellation points identified
- **Success**: Sage written approval

### Gate 2: Build System
- **Owner**: Artisan (A4)
- **Location**: `queue/tasks/artisan_phase15.yaml` (lines ~175-210)
- **Verification**: 3 successful builds (normal, ThreadSanitizer, AddressSanitizer)
- **Success**: Artisan written approval

### Gate 3: Thread Safety
- **Owner**: Paladin (P2)
- **Location**: `queue/tasks/paladin_phase15.yaml` (lines ~118-187)
- **Deliverable**: `PHASE15_THREAD_SAFETY_REPORT.md`
- **Requirement**: ThreadSanitizer ZERO races on all 6 scenarios
- **Success**: Paladin written approval

### Gate 4: Memory Safety
- **Owner**: Paladin (P3)
- **Location**: `queue/tasks/paladin_phase15.yaml` (lines ~189-267)
- **Deliverable**: `PHASE15_MEMORY_SAFETY_REPORT.md`
- **Requirements**: Valgrind 0 leaks, 0 invalid reads/writes
- **Success**: Paladin written approval

### Gate 5: POSIX Compliance
- **Owner**: Paladin (P4)
- **Location**: `queue/tasks/paladin_phase15.yaml` (lines ~269-310)
- **Deliverable**: `PHASE15_POSIX_COMPLIANCE_AUDIT.md`
- **Requirement**: No undefined behavior per POSIX.1-2017
- **Success**: Paladin written approval

### Gate 6: E2E Testing
- **Owner**: Merchant (M2)
- **Location**: `queue/tasks/merchant_phase15.yaml` (lines ~104-233)
- **Deliverable**: E2E test results + evidence
- **Requirements**: 5 scenarios all passing
- **Success**: Merchant written approval

### Gate 7: Documentation
- **Owner**: Bard (B1-B4)
- **Location**: `queue/tasks/bard_phase15.yaml`
- **Deliverables**: 4 major documents (140+ pages)
- **Requirements**: Production-ready documentation
- **Success**: Bard written approval

**Authorization**: ALL 7 gates must pass for Phase 16 approval

---

## Timeline Overview

| Day | Owner | Focus | Hours | Status |
|-----|-------|-------|-------|--------|
| 1 | Sage | Foundation (S1/S2/S3 research) | 7 | Design gate |
| 2 | Artisan | Implementation (A1-A4 coding) | 8 | Build gate |
| 3-4 | Paladin/Merchant/Bard | Validation (P/M), Documentation (B) | 12-13 | Final gates |
| **Total** | | | **18-20** | |

**Schedule**: 4-5 working days with full parallelization

**Critical Path**: Sage S1 (3h) → Artisan A1-A4 (8h) → Paladin P4 (1.5h) = 12.5 hours serial

---

## Key Definitions

### CRITICAL-1: Lua State Memory Leak
- **Problem**: `pthread_cancel()` without `lua_close()` → ~1KB leak per timeout
- **Impact**: 16 timeouts exhaust all slots
- **Resolution**: Cooperative shutdown + cleanup handlers
- **Proof**: Valgrind reports 0 leaks (Gate 4)

### HIGH-2: Undefined Behavior
- **Problem**: POSIX violation - `pthread_cancel()` on detached threads
- **Impact**: Crashes, resource leaks, inconsistent state
- **Resolution**: Flag-based cooperative shutdown (joinable threads)
- **Proof**: ThreadSanitizer clean (Gate 3), POSIX audit (Gate 5)

### Cooperative Shutdown
- **Mechanism**: Volatile flag + graceful exit instead of force cancel
- **Benefit**: POSIX compliant, deterministic, resource-safe
- **Implementation**: Sage S1 design → Artisan A1 code

### Deployment Readiness
- **Definition**: Production-grade software with comprehensive docs
- **Requirements**: Zero critical issues, <2% perf regression, all gates pass
- **Proof**: Phase 15 completion report (Bard B3)

---

## Quick Links by Role

### For Sage
1. Task: `queue/tasks/sage_phase15.yaml`
2. Quick ref: `memory/PHASE15_QUICK_REFERENCE.md` (lines 25-32)
3. Technical details: `queue/prophet_phase15_mandate.yaml` (lines 149-235)
4. Coordination: `memory/PHASE15_COORDINATION_PLAN.md` (section: Sage)

### For Artisan
1. Task: `queue/tasks/artisan_phase15.yaml`
2. Dependencies: Sage S1/S2 output files
3. Coordination: `memory/PHASE15_COORDINATION_PLAN.md` (section: Artisan)
4. Timeline: Day 2 of schedule

### For Paladin
1. Task: `queue/tasks/paladin_phase15.yaml`
2. Gates: `memory/PHASE15_COORDINATION_PLAN.md` (section: Quality Gates)
3. Test scenarios: Sage S3 deliverable (`PHASE15_TESTING_STRATEGY.md`)
4. Authority: BLOCKER for Phase 16

### For Merchant
1. Task: `queue/tasks/merchant_phase15.yaml`
2. E2E scenarios: `queue/prophet_phase15_mandate.yaml` (lines 509-558)
3. Performance baseline: `memory/PHASE14_COMPLETION_REPORT.md`
4. Regression suite: `queue/tasks/merchant_phase15.yaml` (lines 234-273)

### For Bard
1. Task: `queue/tasks/bard_phase15.yaml`
2. Content specs: Each task section (B1-B4) has detailed requirements
3. Integration: Results from P2-P4, M1-M3 into B3 completion report
4. Pages minimum: 50+40+30+10 = 140 pages

### For Mayor
1. Acknowledgment: `PHASE15_MAYOR_ACKNOWLEDGMENT.md`
2. Summary: `PHASE15_DISTRIBUTION_SUMMARY.txt`
3. Coordination: `memory/PHASE15_COORDINATION_PLAN.md`
4. Status: `memory/dashboard.md` (Phase 15 section)
5. Daily updates: `memory/communication.yaml`

---

## How to Read This Index

**If you have 5 minutes**: Read `PHASE15_DISTRIBUTION_SUMMARY.txt`

**If you have 15 minutes**: Read this file + your task file

**If you have 30 minutes**: This file + full coordination plan

**If you have 1 hour**: All of above + original mandate

**If you're Paladin**: Also read quality gate definitions (section above)

---

## File Locations (Absolute Paths)

```
/Users/kokage/national-operations/claudecode01/

├── PHASE15_INDEX.md (this file)
├── PHASE15_DISTRIBUTION_SUMMARY.txt
├── PHASE15_MAYOR_ACKNOWLEDGMENT.md
│
├── queue/
│   ├── prophet_phase15_mandate.yaml (original mandate)
│   └── tasks/
│       ├── sage_phase15.yaml
│       ├── artisan_phase15.yaml
│       ├── paladin_phase15.yaml
│       ├── merchant_phase15.yaml
│       └── bard_phase15.yaml
│
└── memory/
    ├── PHASE15_QUICK_REFERENCE.md
    ├── PHASE15_COORDINATION_PLAN.md
    ├── dashboard.md (updated with Phase 15)
    └── communication.yaml (status updates)
```

---

## Authority & Approval Chain

```
Prophet (Issues Mandate)
    ↓
Mayor (Distributes & Coordinates)
    ├→ Sage (Design Authority)
    ├→ Artisan (Build Authority)
    ├→ Paladin (Security Authority - BLOCKER)
    ├→ Merchant (QA Authority)
    └→ Bard (Documentation Authority)
        ↓
    All approvals → Mayor Final Authorization → Phase 16 Start
```

---

**Last Updated**: 2026-01-29T22:30:00Z  
**Status**: ACTIVE  
**Next**: Agents begin assigned tasks  

---

For questions or clarifications, refer to the specific task file or contact Mayor via `memory/communication.yaml`.
