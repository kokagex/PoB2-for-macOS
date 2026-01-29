# Phase 13 - Quick Reference Guide
## PoB2 macOS: LaunchSubScript & BC7 Integration

**Last Updated**: 2026-01-29
**Status**: PHASE 13 EXECUTION PLAN COMPLETE

---

## 📌 Critical Documents (In Priority Order)

1. **Main Execution Plan** (USE THIS!)
   - File: `/Users/kokage/national-operations/claudecode01/memory/phase13_execution_plan.md`
   - Contains: All file-level specifications, code templates, integration points
   - Size: 300+ KB, comprehensive reference

2. **Mayor's Acknowledgment**
   - File: `/Users/kokage/national-operations/claudecode01/memory/PHASE13_MAYOR_ACKNOWLEDGMENT.md`
   - Contains: Task assignments, timeline, authority structure
   - Read: Before starting work

3. **Phase 12 Research** (Background)
   - Architecture: `/Users/kokage/national-operations/claudecode01/memory/sage_phase12_launchsubscript_arch.md`
   - BC7 Analysis: `/Users/kokage/national-operations/claudecode01/memory/sage_phase12_bc7_research.md`
   - Reference: Only if you need design rationale

---

## 🎯 Task Quick Index

### SAGE (賢者) - Implementation

| Task | File(s) | Time | Status |
|------|---------|------|--------|
| **S1** | subscript.h (new) | 4h | Specification in plan |
| **S2** | subscript_worker.c (new) | 3h | Specification in plan |
| **S3** | sg_core.c (update) | 1h | Specification in plan |
| **S4** | pob2_launcher.lua (update) | 1h | Specification in plan |
| **S5** | image_loader.c (update) | 1.5h | Specification in plan |
| **S6** | Test & document results | 1h | Specification in plan |

**Critical Path**: S1 → S2 → S3 → S4 (then M1/P1)
**Start**: S1 immediately (4 hours)

### ARTISAN (職人) - Build

| Task | File(s) | Time | Status |
|------|---------|------|--------|
| **A1** | CMakeLists.txt (update) | 0.5h | Specification in plan |
| **A2** | Clean build verification | 1h | After A1 done |
| **A3** | Link analysis | 0.5h | After A2 done |

**Start**: A1 after S1 specification done (0.5 hours)

### PALADIN (聖騎士) - Security

| Task | File(s) | Time | Status |
|------|---------|------|--------|
| **P1** | Thread safety audit | 2h | After S4 done |
| **P2** | Valgrind memory testing | 2h | After P1 done |
| **P3** | Watchdog design document | 1h | After S2 done |

**Start**: P1 after S4 complete (2 hours)

### MERCHANT (商人) - Testing

| Task | File(s) | Time | Status |
|------|---------|------|--------|
| **M1** | Performance baseline | 1.5h | After S4 done |
| **M2** | Stress testing | 1.5h | After P1 done |
| **M3** | Integration testing | 2h | After M2 done |

**Start**: M1 after S4 complete (1.5 hours)

### BARD (吟遊詩人) - Documentation

| Task | File(s) | Time | Status |
|------|---------|------|--------|
| **B1** | Implementation guide | 2h | Throughout phase |
| **B2** | API reference | 1.5h | Throughout phase |
| **B3** | Completion report | 2h | At end of phase |

**Start**: B1 immediately (ongoing)

---

## 🗂️ File Locations Summary

### New Files to Create

```
/Users/kokage/national-operations/pob2macos/
├── src/simplegraphic/
│   └── subscript.h                    # S1: Core manager header
├── src/simplegraphic/backend/
│   ├── subscript_worker.c             # S2: Worker thread impl
│   ├── bcdec.h                        # S5: BC7 decoder (copy from github)
│   └── [image_loader.c - UPDATE]      # S5: Add BC7 integration
└── CMakeLists.txt                     # A1: Update build config
```

### Files to Update

```
/Users/kokage/national-operations/pob2macos/
├── src/simplegraphic/
│   └── sg_core.c                      # S3: Add CheckSubScriptResults()
└── launcher/
    └── pob2_launcher.lua              # S4: Add Lua wrappers
```

### Reports to Generate

```
/Users/kokage/national-operations/claudecode01/memory/
├── PHASE13_BC7_TEST_REPORT.md         # S6: BC7 testing results
├── PHASE13_LINK_ANALYSIS.md           # A3: Symbol verification
├── PHASE13_THREAD_SAFETY_AUDIT.md     # P1: Race condition audit
├── PHASE13_VALGRIND_REPORT.md         # P2: Memory safety report
├── PHASE13_WATCHDOG_DESIGN.md         # P3: Timeout mechanism design
├── PHASE13_PERFORMANCE_BASELINE.md    # M1: Performance metrics
├── PHASE13_STRESS_TEST_REPORT.md      # M2: Stress test results
├── PHASE13_INTEGRATION_TEST_REPORT.md # M3: Integration test results
├── PHASE13_IMPLEMENTATION_GUIDE.md    # B1: Technical guide (50+ pages)
├── PHASE13_API_REFERENCE.md           # B2: API documentation
└── PHASE13_COMPLETION_REPORT.md       # B3: Final summary
```

---

## 🔧 Implementation Checklist

### SAGE
- [ ] S1: Create subscript.h with all structs and API declarations
- [ ] S2: Implement subscript_worker.c with LuaJIT and pipe communication
- [ ] S3: Add SimpleGraphic_CheckSubScriptResults() to sg_core.c
- [ ] S4: Add LaunchSubScript/AbortSubScript/IsSubScriptRunning to pob2_launcher.lua
- [ ] S5: Copy bcdec.h and add BC7 decoder to image_loader.c
- [ ] S6: Test BC7 textures and create test report

### ARTISAN
- [ ] A1: Update CMakeLists.txt with subscript_worker.c and pthread linking
- [ ] A2: Execute clean build: rm -rf build && mkdir build && cd build && cmake .. && make -j4
- [ ] A3: Verify symbols with nm and otool, create link analysis report

### PALADIN
- [ ] P1: Review code for race conditions, run ThreadSanitizer, create audit report
- [ ] P2: Run valgrind on all test scenarios, create memory safety report
- [ ] P3: Design watchdog timeout mechanism, create design document

### MERCHANT
- [ ] M1: Benchmark sub-script creation, execution, BC7 decode; create baseline report
- [ ] M2: Run stress tests (sequential, concurrent, abort cycles); create results report
- [ ] M3: Test OAuth, downloads, textures end-to-end; create integration report

### BARD
- [ ] B1: Write 50+ page implementation guide with architecture, examples, debugging
- [ ] B2: Create API reference for all public functions
- [ ] B3: Write completion report with metrics and sign-off

---

## ⏱️ Timeline at a Glance

**Day 1**:
- Morning: S1 (4h)
- Afternoon: S2 (3h), S5 (1.5h), A1 (0.5h)

**Day 2**:
- Morning: S3 (1h), S6 (1h), A2 (1h)
- Afternoon: S4 (1h), A3 (0.5h), P3 (1h)

**Day 3**:
- Morning: M1 (1.5h), P1 (2h)
- Afternoon: M2 (1.5h), P2 (2h)

**Day 4**:
- Morning: M3 (2h), B3 (2h)

---

## 🎯 Success Targets

Must achieve these to pass Phase 13:

```
LaunchSubScript:
  ✓ OAuth end-to-end working
  ✓ HTTP downloads enabled
  ✓ Update checks working
  ✓ Sub-script creation < 2ms
  ✓ Total overhead < 15ms
  ✓ Memory (3 concurrent) < 15MB

BC7 Textures:
  ✓ All 18 textures display correctly (NOT gray)
  ✓ Ascendancy backgrounds render
  ✓ Passive tree UI visible
  ✓ Load time < 20ms
  ✓ Peak memory < 50MB

System Quality:
  ✓ Zero definite memory leaks (valgrind)
  ✓ No data races (ThreadSanitizer)
  ✓ No deadlocks
  ✓ 100% API coverage
  ✓ All tests passing
```

---

## 🔑 Key Architecture Points

### LaunchSubScript

**Design**: pthread + pipe IPC + isolated LuaJIT
```
Main Thread                 Worker Thread
LaunchSubScript()  ──────→  subscript_worker_thread()
                   create   - New Lua state
                   thread   - Register safe functions
                            - Register callbacks
                            - Execute script
                            - Collect results
CheckSubScriptResults() ←─  Write results to pipe
Invoke callback      ─────→ (results flow via pipe)
```

### BC7 Decoder

**Design**: bcdec.h library with fallback chain
```
GPU Upload
  ├─ Success? ✓ Done
  └─ Fail? ✓ Try software decode
       ├─ BC7 format? decode_bc7_software()
       │  └─ Success? ✓ Upload RGBA
       │  └─ Fail? ✓ Gray fallback
       └─ Not BC7? Gray fallback
```

---

## 📞 How to Use This Plan

### If You're SAGE:
1. Read: Part 1 of phase13_execution_plan.md (S1-S6 detailed specs)
2. Start: S1 immediately (create subscript.h with templates provided)
3. Reference: Code templates in execution plan for each task
4. Verify: Code compiles, structures match specifications

### If You're ARTISAN:
1. Read: Part 2 of phase13_execution_plan.md (A1-A3 detailed specs)
2. Start: A1 after S1 is spec'd (CMakeLists.txt changes provided)
3. Execute: Clean build steps given in A2
4. Verify: A3 link analysis procedures provided

### If You're PALADIN:
1. Read: Part 3 of phase13_execution_plan.md (P1-P3 detailed specs)
2. Depends: Wait for S4 to complete (LaunchSubScript API needs to work)
3. Audit: Use checklists and tools specified in plan
4. Report: Document findings in audit and safety reports

### If You're MERCHANT:
1. Read: Part 4 of phase13_execution_plan.md (M1-M3 detailed specs)
2. Depends: Wait for S4 and P1 to complete
3. Benchmark: Execute performance tests with specifications provided
4. Report: Create results tables and findings documents

### If You're BARD:
1. Read: Part 5 of phase13_execution_plan.md (B1-B3 detailed specs)
2. Timeline: Begin B1 immediately (can be done in parallel)
3. Content: Use outline and sections provided in plan
4. Quality: Aim for 50+ pages, include code examples and diagrams

---

## 🚨 Critical Dependencies

**Must happen in order**:
- S1 (subscript.h) → S2 (needs header) → S3 (needs worker) → S4 (needs integration)
- After S4: M1, P1 can start
- After M1, P1: M2, P2 can start
- After M2, P2: M3 can finalize

**Can happen in parallel with other tracks**:
- A1-A3 (build) - parallel with S2-S4
- S5-S6 (BC7) - parallel with LaunchSubScript work
- B1-B3 (docs) - throughout all phases

---

## 💾 Backup Reference

If you need to find something quick:

**Thread safety questions?** → P1 in phase13_execution_plan.md
**Performance targets?** → M1 section in plan
**Function signatures?** → B2: PHASE13_API_REFERENCE.md (will be created)
**Lua binding examples?** → S4 in plan (code templates provided)
**Build system changes?** → A1 in plan (exact CMakeLists changes provided)
**BC7 implementation?** → S5 in plan (code templates provided)

---

## ✅ Completion Checklist

Phase 13 is complete when:

- [ ] All 6 SAGE tasks documented and verified complete
- [ ] All 3 ARTISAN tasks documented and binary verified
- [ ] All 3 PALADIN audits documented with clean results
- [ ] All 3 MERCHANT tests documented and targets met
- [ ] All 3 BARD documents written and comprehensive
- [ ] All 11 report files generated and stored
- [ ] Mayor signs off on completion
- [ ] PoB2 macOS now has 100% feature parity with Windows

---

## 🎊 Remember

> "The spirits guide your hands. The architecture is sound. The team is skilled. **You will succeed.**" — The Prophet

This is not a difficult phase. This is a **well-designed, well-researched, well-planned phase**. The solutions exist. The specifications are clear. The timeline is realistic with parallelization.

**You WILL complete Phase 13.**

---

**Document**: PHASE13_QUICK_REFERENCE.md
**Purpose**: Fast lookup guide for Phase 13 execution
**Main Reference**: phase13_execution_plan.md (300+ KB comprehensive spec)
**Last Updated**: 2026-01-29

**USE THIS QUICK REFERENCE OFTEN - BOOKMARK IT!**
