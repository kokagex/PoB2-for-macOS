# Divine Mandate — Phase 14: Completing the Vision

## 天啓 (Revelation)

The spirits have spoken. Phase 13 brought forth two miracles:
- **LaunchSubScript**: Background Lua execution with pthread-based isolation, enabling OAuth flows and async operations
- **BC7 Software Decoder**: CPU-side texture decompression, liberating 18 textures from gray placeholder purgatory

The build stands at **0 errors, 98+ symbols exported, 49/51 API coverage (96%)**. The foundation is sound. The critical path is cleared.

But the vision is not yet complete.

Two truths emerge from the data:
1. **The remaining gaps are small but mighty** — Five minor APIs stand between us and 100%
2. **The project is now production-ready** — What we build now is optimization and polish, not survival

## The Five Sacred Gaps

| API | Status | Impact | Complexity |
|-----|--------|--------|-----------|
| **SetForeground** | Not implemented | UX: Brings window to front after OAuth | Trivial (1 macOS call) |
| **SetViewport** | Partially implemented | Clipping regions for UI layering | Minor (1 GL call) |
| **StripEscapes** | Partially implemented | Removes color codes from text | Minor (string processing) |
| **Timeout watchdog** | Designed, not implemented | Safety: Kills hung sub-scripts | Minor (watchdog thread) |
| **End-to-end PoB2 launch** | Untested | Real OAuth + texture rendering + downloads | Medium (integration test) |

## Phase 14 Vision: Polish & Certification

This is not a feature phase. This is a **completeness phase**.

**Theme**: *Perfection in the details*

Phase 14 will:
1. **Complete the Five Gaps** — Implement the remaining 5% of API surface
2. **Certify for production** — Real-world PoB2 testing with actual game data
3. **Optimize the critical path** — BC7 decode caching, batch rendering, frame rate analysis
4. **Harden security** — Timeout watchdog, input validation, error recovery
5. **Document the final vision** — Comprehensive guide for future maintainers

After Phase 14, the project is **feature-complete and production-ready**.

---

## Priority Tasks

### Priority 1: API Completion (Highest Value)

These complete the API surface to 100%:

#### 1.1 SetForeground Implementation (0.5 hours)
- **File**: `sg_stubs.c` → `NSApplication -activateIgnoringOtherApps:YES`
- **Rationale**: Used after OAuth succeeds; brings PoB2 window to front
- **Complexity**: Trivial — single macOS AppKit call
- **Success**: Window appears in foreground after auth flow
- **Why now**: Zero dependencies, unblocks UX improvements

#### 1.2 SetViewport Completion (1 hour)
- **File**: `sg_draw.c` — glViewport with scissor test
- **Rationale**: Used for UI clipping regions (ascendancy borders, skill tree viewport)
- **Complexity**: Minor — GL viewport + scissor setup
- **Success**: Clipping works, UI elements contained correctly
- **Why now**: Medium priority; improves rendering quality

#### 1.3 StripEscapes Hardening (0.5 hours)
- **File**: `sg_stubs.c` — Extend basic escape removal
- **Rationale**: PoB2 uses color codes `^X` and formatting. Must strip for console output
- **Complexity**: Minor — string parsing
- **Success**: All escape codes removed, plain text output
- **Why now**: Simple, improves debuggability

### Priority 2: Safety & Robustness (High Value)

#### 2.1 Timeout Watchdog Implementation (1.5 hours)
- **File**: `subscript_worker.c` — Add watchdog thread per sub-script
- **Rationale**: Prevents infinite-loop scripts from freezing UI (OAuth network timeouts, etc.)
- **Design**: One watchdog thread monitors execution time; kills target on timeout (configurable, default 30s)
- **Success**: Hung scripts abort gracefully, UI remains responsive
- **Why now**: Phase 13 designed this; implementation is straightforward

#### 2.2 Error Recovery & Resilience (1 hour)
- **File**: `sg_lua_binding.c` — Wrapper error handling
- **Rationale**: Invalid inputs to LaunchSubScript should fail gracefully, not crash
- **Success**: All error paths return nil/false with informative logging
- **Why now**: Robustness improvement, prevents subtle crashes

### Priority 3: Performance & Optimization (Medium Value)

#### 3.1 BC7 Decode Caching (1.5 hours)
- **File**: `image_loader.c` — Cache decoded BC7 blocks by hash
- **Rationale**: If same BC7 texture loaded twice, skip redundant decoding
- **Design**: LRU cache (16 entries) of decoded RGBA buffers
- **Success**: Repeat loads from cache, 5x faster than re-decode
- **Why now**: Improves load times for multi-pass rendering

#### 3.2 Batch Rendering Optimization (1 hour)
- **File**: `sg_draw.c` — Batch consecutive draws by texture/layer
- **Rationale**: Reduce GL state changes, improve frame rate
- **Success**: Fewer glBindTexture calls; measured FPS improvement
- **Why now**: Performance baseline established in Phase 13; now optimize

#### 3.3 Frame Rate Measurement (0.5 hours)
- **File**: `sg_core.c` — Track FPS in main loop
- **Rationale**: Measure actual rendering performance
- **Success**: FPS displayed in debug output; target 60 FPS
- **Why now**: Baseline for optimization work

### Priority 4: End-to-End Testing (Medium Value)

#### 4.1 Real PoB2 Launch Test (2 hours)
- **Scenario**: Full OAuth → Download passive tree data → Render skill tree with BC7 textures
- **Success criteria**:
  - OAuth completes successfully
  - Tree renders without errors
  - All BC7 textures visible (no gray)
  - Window remains responsive
  - Performance >30 FPS
- **Why now**: Validates all systems work together in production scenario

#### 4.2 Edge Case Testing (1 hour)
- **Scenarios**: Network timeout, large skill trees, rapid zoom/pan, memory pressure
- **Success**: All scenarios handled gracefully
- **Why now**: Certifies production readiness

### Priority 5: Documentation (Lower Value, Important)

#### 5.1 Phase 14 API Completion Report (1 hour)
- **Content**: What was implemented, why, performance impact
- **Audience**: Future maintainers
- **Success**: Complete guide to remaining 5%

#### 5.2 Performance Analysis Report (1 hour)
- **Content**: Frame rates, memory usage, optimization opportunities
- **Metrics**: Before/after for each optimization
- **Success**: Clear baseline and targets for future work

#### 5.3 Production Readiness Checklist (0.5 hours)
- **Covers**: Security, performance, reliability, error handling
- **Success**: All items checked ✓

---

## Success Criteria for Phase 14

### API Completeness
- [ ] SetForeground implemented (window appears in foreground)
- [ ] SetViewport functional (GL scissor test working)
- [ ] StripEscapes robust (all escape codes removed)
- [ ] **API coverage: 100% (51/51)**

### Safety & Robustness
- [ ] Timeout watchdog implemented and tested
- [ ] All error paths return graceful failures
- [ ] No crashes on invalid input
- [ ] Thread safety verified (ThreadSanitizer clean)

### Performance
- [ ] BC7 decode caching reduces repeat loads by 5x
- [ ] Batch rendering improves FPS by 20%+
- [ ] Frame rate >30 FPS (measured)
- [ ] Memory usage <50 MB peak (measured)

### End-to-End
- [ ] Real PoB2 launch succeeds with OAuth
- [ ] All BC7 textures render correctly
- [ ] No gray placeholders
- [ ] Edge cases handled gracefully

### Documentation
- [ ] Phase 14 completion report written
- [ ] Performance baseline documented
- [ ] Production readiness checklist verified

---

## Phase 14 Impact & Outcomes

### What This Enables

After Phase 14, the project is:
- **100% API-compatible** with Windows PoB2 SimpleGraphic
- **Production-ready** — Suitable for real PoB2 usage
- **Well-documented** — Future maintainers have clear guidance
- **Performance-optimized** — 5x faster BC7 loads, efficient batch rendering
- **Hardened** — Timeout watchdog, error recovery, edge case handling

### What's NOT in Phase 14

This phase does NOT include:
- Major feature additions (no new API functions)
- Complete rewrite of any component
- Lua JIT compilation (performance optimization deferred)
- Mobile/web ports (out of scope)

### Phase 14 → Phase 15 Bridge

After Phase 14, consider:
- **Lua JIT compilation** for sub-scripts (performance)
- **Thread pool** for concurrent sub-scripts (scalability)
- **Network timeout tuning** based on real-world data (reliability)
- **Additional game mode testing** (certification)

---

## Resource Allocation

**Estimated Effort: 12-15 hours**

### By Agent

| Agent | Hours | Tasks |
|-------|-------|-------|
| **Sage** | 4 | API completion (1.1, 1.2, 1.3), watchdog (2.1) |
| **Artisan** | 1 | Build verification |
| **Paladin** | 2 | Safety audit, watchdog review |
| **Merchant** | 3 | E2E testing (4.1, 4.2), optimization validation |
| **Bard** | 2 | Reports & documentation |

**Critical Path**: 1.1 (0.5h) → 4.1 (2h) → Documentation (2h) = 4.5 hours minimum

---

## Strategic Rationale

### Why These Priorities?

1. **API Completion First** — Five small tasks eliminate remaining gaps. Unblocks 100% compatibility claim.
2. **Safety Second** — Watchdog prevents production failures. One hung sub-script could destroy user experience.
3. **Performance Third** — Caching and batch rendering improve perceived quality. Users feel the speed.
4. **E2E Testing Fourth** — Real PoB2 data proves the system works in production. No surprises.
5. **Documentation Last** — Important but lowest urgency. Can be done in parallel.

### Why Phase 14 Matters

We are **96% complete**. The remaining 4% is the difference between:
- **"Almost works"** ← Phase 13 state
- **"Production-ready"** ← Phase 14 outcome

This phase transforms the project from MVP to **mature, hardened, documented system**.

---

## Divine Pronouncement

The village has built something extraordinary. LaunchSubScript and BC7 decoding were non-trivial achievements. The architectural foundation is solid.

Now comes the mastery: **Perfecting what has been built.**

Phase 14 is not about ambition. It is about **craftsmanship** — completing every detail, testing every edge case, documenting every decision.

When Phase 14 is complete, the project will be **feature-complete, production-ready, and maintainable**.

---

## Authority & Approval

This mandate is issued by the **Prophet (預言者)** on behalf of the village council, grounded in:
- Phase 13 delivery metrics (0 errors, 98+ symbols, 96% API coverage)
- Merchant verification reports (all integration checks PASS)
- Remaining API gap analysis (5 simple tasks)
- Production readiness assessment (98% ready, 2% remaining)

The Mayor (村長) will coordinate execution. All village agents stand ready.

---

**Mandate Date**: 2026-01-29
**Phase**: 14 (Completion & Certification)
**Status**: ISSUED
**Approval**: Mayor signature required

Let the final sprint begin. The finish line is visible.

✨ *May your APIs be complete, your tests be green, and your performance be swift.* ✨

---

**End of Divine Mandate — Phase 14**
