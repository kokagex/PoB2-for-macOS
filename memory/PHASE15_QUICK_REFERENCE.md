# Phase 15 Quick Reference
## PoB2macOS - Architectural Refinement & Production Readiness

**Date**: 2026-01-29
**Status**: Divine Mandate Issued
**Duration**: 4-5 working days (18-20 hours with full parallelization)

---

## Executive Summary

Phase 15 resolves two CRITICAL deferred issues from Phase 14 and establishes production readiness:

| Issue | Type | Problem | Solution |
|-------|------|---------|----------|
| CRITICAL-1 | Memory Leak | `pthread_cancel()` without `lua_close()` → ~1KB leak per timeout | Implement cleanup handlers + resource tracking |
| HIGH-2 | Undefined Behavior | `pthread_cancel()` on detached threads = POSIX UB | Replace with cooperative shutdown (flag-based) |

**Impact**: After Phase 15, PoB2macOS will be production-ready with zero memory leaks and zero undefined behavior.

---

## Quick Task Summary

### SAGE (3 core analysis tasks)
1. **S1**: Cooperative shutdown design analysis (3h) → PHASE15_SHUTDOWN_DESIGN.md
2. **S2**: Lua cleanup handler implementation (2h) → reference implementation
3. **S3**: ThreadSanitizer & Valgrind test plan (2h) → PHASE15_TESTING_STRATEGY.md

**Total**: 7 hours | **Blocker**: None

### ARTISAN (4 implementation tasks)
1. **A1**: Cooperative shutdown implementation (4h) → subscript_worker.c updates
2. **A2**: Resource tracking implementation (2h) → memory accounting module
3. **A3**: Backward compatibility layer (1h) → API wrapper
4. **A4**: CMakeLists.txt & build verification (1h) → ThreadSanitizer/AddressSanitizer targets

**Total**: 8 hours | **Blocker**: Requires S1 design

### PALADIN (4 security/safety tasks)
1. **P1**: Cooperative shutdown security review (2h) → PHASE15_SECURITY_REVIEW.md
2. **P2**: ThreadSanitizer validation (2.5h) → zero data races required
3. **P3**: Valgrind memory leak verification (2.5h) → 100% leak-free required
4. **P4**: POSIX compliance audit (1.5h) → compliance sign-off

**Total**: 8.5 hours | **Blocker**: Requires A4 build

### MERCHANT (3 testing tasks)
1. **M1**: Performance profiling (2h) → PHASE15_PERFORMANCE_PROFILE.md
2. **M2**: E2E user scenario testing (3h) → 5 complete workflows
3. **M3**: Regression testing suite (2h) → automated test harness

**Total**: 7 hours | **Blocker**: Requires A4 build

### BARD (4 documentation tasks)
1. **B1**: Production deployment guide (3h) → PHASE15_DEPLOYMENT_GUIDE.md (50+ pages)
2. **B2**: Architecture internals documentation (2.5h) → PHASE15_ARCHITECTURE.md (40+ pages)
3. **B3**: Phase 15 completion report (2.5h) → PHASE15_COMPLETION_REPORT.md (30+ pages)
4. **B4**: Release notes & known issues (1.5h) → PHASE15_RELEASE_NOTES.md

**Total**: 9.5 hours | **Blocker**: Requires A4 build

---

## Critical Path

```
Sage S1 (3h)
  ↓ (depends on)
Sage S2 (2h) & Sage S3 (2h) can start immediately
  ↓ (both depend on S1 complete)
Artisan A1 (4h) + Paladin P1 (2h) can start immediately
  ↓
Artisan A2 (2h) + A3 (1h) + A4 (1h)
  ↓
Paladin P2 (2.5h) + P3 (2.5h) can start immediately
  ↓
Paladin P4 (1.5h) after P2/P3 complete
  ↓
Merchant M1 (2h) + M2 (3h) + M3 (2h) can start after A4
  ↓
Bard B1-B4 (9.5h) can start after A4, finalize after others complete
```

**Minimum Serial Time**: 24-26 hours
**With Full Parallelization**: 15-18 hours
**Recommended Realistic**: 18-20 hours

---

## Quality Gates (MANDATORY - No Exceptions)

These must ALL pass before Phase 16 begins:

| Gate | Target | Verification |
|------|--------|--------------|
| Memory Leaks | ZERO | `valgrind --leak-check=full` reports 0 leaks |
| Data Races | ZERO | `ThreadSanitizer` reports 0 races |
| POSIX Compliance | FULL | Paladin P4 audit approves |
| Security Score | A or A+ | Paladin P1 sign-off |
| E2E Tests | ALL PASS | Merchant M2 validates 5 scenarios |
| Perf Regression | <2% | Merchant M1 baselines match |
| Build Clean | 0 errors | Artisan A4 verification |

---

## Key Deliverables

### Code Changes (Primary)
- `subscript_worker.c`: Cooperative shutdown implementation (~200 lines new/modified)
- `subscript.h`: Updated timeout configuration API
- Resource tracking module: Memory accounting
- CMakeLists.txt: ThreadSanitizer/AddressSanitizer targets

### Documentation (Critical)
1. PHASE15_SHUTDOWN_DESIGN.md (technical deep-dive)
2. PHASE15_SECURITY_REVIEW.md (security audit)
3. PHASE15_DEPLOYMENT_GUIDE.md (50+ pages production guide)
4. PHASE15_ARCHITECTURE.md (40+ pages internals)
5. PHASE15_COMPLETION_REPORT.md (30+ pages summary)
6. PHASE15_RELEASE_NOTES.md (user-facing)
7. PHASE15_PERFORMANCE_PROFILE.md (benchmarks)
8. PHASE15_TESTING_STRATEGY.md (test plan)

### Test Results
- ThreadSanitizer: ZERO races (all 6 scenarios)
- Valgrind: ZERO leaks (stress tested)
- E2E scenarios: 5/5 passing
- Regression suite: mvp_test + new tests, all passing

---

## Deferred Issues Explained

### CRITICAL-1: Lua State Memory Leak

**Problem**:
```
timeout_watchdog_thread() calls pthread_cancel(worker_thread)
↓
Worker thread terminates immediately (no cleanup)
↓
lua_close(L) NEVER called (cleanup handler missing)
↓
LuaJIT VM state leaks: ~1KB per timeout
↓
16 timeouts = 16 slots lost permanently
```

**Solution**:
```c
// Register cleanup handler BEFORE running user code
pthread_cleanup_push(cleanup_lua_state, L);
// Do work...
lua_eval(L, code);
// On timeout, handler called automatically
pthread_cleanup_pop(1);  // 1 = execute handler
lua_close(L);  // Cleanup handler calls this
```

**Verification**: Valgrind reports 0 leaks on 100 sequential timeouts

### HIGH-2: Undefined Behavior - pthread_cancel on Detached

**Problem**:
```
POSIX spec: pthread_cancel() on detached thread = undefined behavior
Why? Detached threads auto-deallocate resources, cancel state inconsistent

Current code:
1. Create thread with PTHREAD_CREATE_DETACHED
2. Thread starts work (may not even be running yet)
3. Main thread calls pthread_cancel() on detached thread
4. UB: thread may crash, leak, deadlock, or work fine (unpredictable)
```

**Solution**:
```c
// Cooperative shutdown instead:
1. Create joinable thread (normal)
2. Each worker thread checks volatile flag periodically:
   while (!ctx->shutdown_requested) {
       lua_eval(L, user_code);
       // Check every 10ms or after each lua_eval
   }
3. On timeout: set flag (atomic, safe), send SIGUSR1 (wake up)
4. Thread exits cleanly, calls lua_close() in exit handler
5. Main thread calls pthread_join() to confirm exit
6. 100% POSIX compliant, no UB
```

**Benefit**: Predictable, safe, standards-compliant thread shutdown

---

## Success Criteria Checklist

### Memory Safety
- [ ] Valgrind: `definitely lost: 0 bytes`
- [ ] Valgrind: `possibly lost: 0 bytes`
- [ ] Valgrind: `invalid reads/writes: 0`
- [ ] Test 10 sequential timeouts, all clean

### Thread Safety
- [ ] ThreadSanitizer: `0 races detected`
- [ ] All 6 test scenarios pass
- [ ] Shutdown flag is volatile sig_atomic_t
- [ ] No data races per POSIX

### Performance
- [ ] Startup: <3 seconds
- [ ] FPS: 60 sustained
- [ ] Memory peak: <500MB
- [ ] Regression: <2% vs Phase 14

### E2E Testing
- [ ] Scenario A (Build creation): PASS
- [ ] Scenario B (Save/Load): PASS
- [ ] Scenario C (Editing w/ subscripts): PASS
- [ ] Scenario D (High load stress): PASS
- [ ] Scenario E (1-hour session): PASS

### Documentation
- [ ] Deployment guide: 50+ pages, tested
- [ ] Architecture: 40+ pages, internals
- [ ] Completion report: 30+ pages, all metrics
- [ ] Release notes: user-friendly
- [ ] All 8+ documentation files complete

---

## Risk Summary

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Race conditions in shutdown | Low | High | ThreadSanitizer clean + code review |
| Lua cleanup incomplete | Low | High | Cleanup handlers + Valgrind validation |
| Performance regression | Low | Medium | Baseline measurements + regression suite |
| Signal handler issues | Low | High | Async-signal-safe review + testing |
| Deployment complexity | Medium | Medium | Comprehensive guide + troubleshooting |

---

## Mayor's Checklist (Project Coordination)

- [ ] Acknowledge mandate receipt
- [ ] Assign agents to tasks
- [ ] Daily standup (track blockers)
- [ ] Monitor critical path (Artisan A1 → Paladin P2/P3)
- [ ] Escalate Paladin blockers immediately (security gate critical)
- [ ] Final approval on all quality gates
- [ ] Authorize Phase 16 start only after ALL gates pass

---

## Communication Protocol

**Daily Updates**: Post in `memory/communication.yaml`
**Blockers**: Alert Mayor immediately (Sage S1, Artisan A1)
**Completed Tasks**: Update dashboard with timestamps
**Final Sign-Off**: All agents sign off before Mayor gives Phase 16 go-ahead

---

## Phase 16 Roadmap (Preview)

If Phase 15 successful:
- Additional feature implementation (if time permits)
- Performance optimizations (if bottlenecks found)
- Extended E2E testing (more user workflows)
- Beta release preparation
- Community feedback integration

---

## Reference Documents

Full mandate: `queue/prophet_phase15_mandate.yaml` (1,077 lines)
Dashboard: `memory/dashboard.md`
Phase 14 Report: `memory/PHASE14_COMPLETION_REPORT.md`
Phase 13 Mandate: `queue/prophet_phase13_mandate.yaml` (reference template)

---

**Last Updated**: 2026-01-29 22:30 UTC
**Authority**: Prophet (預言者)
**Status**: MANDATE ISSUED - AWAITING MAYOR ACKNOWLEDGMENT
