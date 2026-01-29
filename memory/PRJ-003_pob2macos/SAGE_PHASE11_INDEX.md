# Phase 11 Complete Analysis Index
**Sage (賢者) Mission Report**
**Date:** 2026-01-29

---

## Mission Overview

**Objective:** Research DDS/BC7 texture support on macOS OpenGL and identify remaining API gaps blocking PoB2 full functionality.

**Deliverables:** 3 comprehensive analysis documents + 1 implementation specification

---

## Generated Documents

### 1. **sage_phase11_analysis.md** (723 lines, 21KB)
**Main analysis document - START HERE**

Contains:
- ✅ Executive summary of all three tasks
- ✅ **TASK 1:** OpenGL BC7/BPTC support analysis on macOS
  - Verdict: **NOT AVAILABLE** on macOS OpenGL 3.3
  - Recommendation: Software decode fallback (libsquish)
  - Two-tier implementation strategy
  - DDS format support status
  - Phase prioritization

- ✅ **TASK 2:** API gaps inventory
  - 7-10 medium-severity gaps identified
  - Test log error analysis
  - Priority matrix with severity levels
  - Impact assessment for each missing API

- ✅ **TASK 3:** LaunchSubScript analysis
  - Complete functional specification
  - Usage patterns in PoB2 (8 locations)
  - Requirement checklist
  - Safety/sandboxing considerations
  - **VERDICT: CANNOT BE STUBBED** - Blocks 30% of features

- ✅ Phase 11 execution plan (4-week schedule)
- ✅ Technical references and libraries

**Purpose:** Complete situation assessment for decision-making

---

### 2. **phase11_quick_ref.md** (86 lines, 3.6KB)
**Quick reference guide - USE DURING IMPLEMENTATION**

Contains:
- 🎯 Critical blockers at a glance
- 🎯 BC7 status summary
- 🎯 API gap priority matrix (color-coded)
- 🎯 File locations (C code, PoB2 source)
- 🎯 Implementation checklist

**Purpose:** Quick lookup during coding sessions

---

### 3. **launchsubscript_implementation.md** (673 lines, 19KB)
**Technical deep-dive implementation guide - REFERENCE DURING CODING**

Contains:
- 📋 Current state analysis (8 usage locations)
- 📋 Architecture design (Thread pool recommended)
- 📋 Complete C API specification with pseudocode
  - Data structures
  - Initialization
  - LaunchSubScript implementation
  - Worker thread main loop
  - Function registration
  - Callback registration
  - Main thread polling
  - Cleanup routines
- 📋 Integration points (Lua binding, main loop)
- 📋 Testing strategy (unit + integration tests)
- 📋 Performance characteristics
- 📋 Known issues and mitigations
- 📋 Success criteria (10-item checklist)

**Purpose:** Step-by-step implementation guide with code examples

---

## Critical Findings Summary

### Finding 1: BC7 Not Available on macOS
**Severity:** MEDIUM
**Status:** CONFIRMED
**Impact:** Asset rendering incomplete

- macOS OpenGL 3.3 Core Profile doesn't expose `GL_ARB_texture_compression_bptc`
- Apple's Metal layer doesn't map BC7 formats to OpenGL
- Hardware supports BC7 but OS-level restriction
- **Solution:** CPU decode via libsquish (Phase 12) or transcode to S3TC

### Finding 2: LaunchSubScript Missing
**Severity:** CRITICAL
**Status:** NOT IMPLEMENTED
**Impact:** Blocks 30% of PoB2 functionality

- All network requests fail (OAuth, updates, API calls)
- 8 different code paths require this feature
- Cannot be stubbed or deferred
- **Solution:** Implement thread pool + Lua state isolation (3-4 weeks)

### Finding 3: MakeDir Broken
**Severity:** HIGH
**Status:** PARTIALLY IMPLEMENTED
**Impact:** Save system doesn't work

- Fails when parent directories don't exist (errno 2)
- No recursive directory creation
- **Solution:** `mkdir -p` equivalent (1 day)

### Finding 4: Missing Zstandard Support
**Severity:** MEDIUM
**Status:** PARTIAL (zlib only)
**Impact:** Asset decompression fails

- PoB2 uses `.dds.zst` (Zstandard compression)
- Current code only has zlib (Deflate)
- **Solution:** Add libzstd or dual-codec support (2 days)

### Finding 5: 7-10 Other API Gaps
**Severity:** LOW-MEDIUM
**Status:** INVENTORY COMPLETE
**Impact:** Progressive functionality degradation

- IsSubScriptRunning, AbortSubScript, LoadModule (real), GetSubScript, etc.
- Can defer most to Phase 12
- See priority matrix in documents

---

## Architecture Recommendations

### LaunchSubScript Implementation (MUST DO)

**Recommended Architecture: Thread Pool + Isolated Lua States**

```
Main Thread (Lua VM)
    ↓ LaunchSubScript(script, funcList, subList, args)
    ↓ returns scriptID immediately
    ↓
    ├→ Worker Thread 1 (Lua State) → executes script
    ├→ Worker Thread 2 (Lua State) → executes script
    ├→ Worker Thread 3 (Lua State) → executes script
    └→ Worker Thread 4 (Lua State) → executes script
         ↓ (on completion)
    ↓ OnSubFinished(id, results...)
    ↓ User callback
```

**Key Properties:**
- 4-thread pool handles typical load
- Each thread has isolated Lua VM
- Script can call exposed functions from main thread
- Script can invoke callbacks on main thread
- Thread-safe queue for work distribution
- Lock-free result processing

**Estimated Effort:** 3-4 weeks including testing

---

### BC7 Software Decode (CAN DEFER)

**Two-Tier Strategy:**

**Phase 11 (Immediate):**
1. Detect BC7 unavailability
2. Implement fallback to RGBA uncompressed (4x memory)
3. Document for Phase 12

**Phase 12 (Expansion):**
1. Integrate libsquish library (MIT licensed)
2. CPU decode BC7 → RGBA
3. Optimize mipmap handling

---

## Implementation Priorities

### Must Complete in Phase 11

1. **LaunchSubScript** (CRITICAL, 3-4 weeks)
   - Blocks all network operations
   - 30% of features depend on this
   - No viable stubbing option

2. **MakeDir Recursive** (HIGH, 1 day)
   - Currently broken
   - Save system non-functional
   - Quick fix needed

3. **Zstandard Support** (MEDIUM, 2 days)
   - Asset loading fails without it
   - PoB2 standardizes on .dds.zst format

### Should Complete in Phase 11

4. **IsSubScriptRunning/AbortSubScript** (MEDIUM, 2-3 days)
   - Update cancellation
   - Progress tracking

5. **DDS Parser Stub** (MEDIUM, 3-4 days)
   - Prepare for Phase 12 BC7 work
   - Currently not parsing DDS headers

### Can Defer to Phase 12

6. BC7 software decoder (libsquish integration)
7. GetSubScript implementation
8. SetWorkDir / RemoveDir
9. Other LOW priority APIs

---

## File References

### Core Implementation Files
```
/Users/kokage/national-operations/pob2macos/src/simplegraphic/
  ├── backend/opengl_backend.c       (OpenGL rendering, no BC7)
  ├── backend/glfw_window.c          (Window management)
  ├── sg_stubs.c                      (Path/utility functions)
  ├── sg_lua_binding.c               (Lua C API bindings)
  ├── sg_image.c                      (Image handle management)
  ├── sg_compress.c                   (zlib - needs Zstandard)
  └── sg_core.c                       (Main loop integration point)
```

### PoB2 Source Analysis
```
/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/
  ├── Launch.lua:310,344             (LaunchSubScript calls)
  ├── Classes/PoEAPI.lua:79           (OAuth via LaunchSubScript)
  ├── Classes/PoBArchivesProvider.lua:49  (Build recommendations)
  ├── Classes/TreeTab.lua:709         (Tree data processing)
  ├── Modules/BuildSiteTools.lua:40   (Build site integration)
  └── HeadlessWrapper.lua:118         (Stub definition)
```

---

## Success Criteria

### Phase 11 Gate-Passing Criteria

- [ ] LaunchSubScript implementation tested (unit + integration)
- [ ] MakeDir works recursively (can create nested paths)
- [ ] Zstandard decompression works for .dds.zst files
- [ ] DDS header parsing implemented
- [ ] BC7 fallback detection implemented
- [ ] Build downloads work end-to-end
- [ ] OAuth flow functional
- [ ] Update system operational
- [ ] No regressions in existing functionality
- [ ] Documentation updated

### Testing Checklist

```
Network Operations:
  ✓ Can download build from external URL
  ✓ Can authenticate with PoE account
  ✓ Can fetch game data from API
  ✓ OAuth redirect flow works

Asset Loading:
  ✓ Can decompress .dds.zst files
  ✓ Can parse DDS headers
  ✓ Can load tree textures
  ✓ Can load skill icons
  ✓ Fallback handles BC7 correctly

File System:
  ✓ Can create config directory
  ✓ Can save builds to user path
  ✓ Can create nested directories

Update System:
  ✓ Can check for updates
  ✓ Can cancel update check
  ✓ Progress reporting works
  ✓ Background mode works
```

---

## Document Usage Guide

**For Project Managers:**
1. Start with executive summary in sage_phase11_analysis.md
2. Review priority matrix (TASK 2)
3. Check implementation timeline (4 weeks)

**For Architects:**
1. Read full analysis: sage_phase11_analysis.md
2. Review LaunchSubScript requirements (TASK 3)
3. Study architecture section: launchsubscript_implementation.md
4. Assess thread pool design

**For Developers:**
1. Start with phase11_quick_ref.md
2. Read relevant sections of sage_phase11_analysis.md
3. Use launchsubscript_implementation.md during coding
4. Reference code examples in implementation guide

**For QA/Testing:**
1. Review success criteria in this document
2. Use testing checklist
3. Reference test strategy in launchsubscript_implementation.md

---

## Key Dependencies

### Libraries Required
- **libzstd** - Zstandard decompression
- **libsquish** - BC7 CPU decode (Phase 12)
- **pthreads** - Threading (POSIX, built-in macOS)
- **Existing:** zlib, LuaJIT, GLFW3

### External Resources
- OpenGL 4.6 Specification (Texture Compression chapter)
- macOS Technical Note TN2085 (OpenGL limitations)
- LuaJIT FFI documentation
- libzstd GitHub repository
- libsquish GitHub repository

---

## Known Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| LaunchSubScript threading bugs | MEDIUM | HIGH | Extensive unit testing, simple design |
| Thread deadlock | MEDIUM | HIGH | Separate Lua states, minimal locking |
| Script timeout | LOW | MEDIUM | Signal-based timeout or elapsed time check |
| Memory leak in script execution | MEDIUM | MEDIUM | Careful cleanup, test for leaks |
| Network error handling | MEDIUM | MEDIUM | Propagate curl errors to Lua layer |
| Zstandard library dependency | LOW | MEDIUM | Vendor library, build from source |

---

## Next Steps

1. **Immediate (Today):**
   - Share this index with team
   - Have architects review LaunchSubScript design
   - Allocate resources for 3-4 week sprint

2. **This Week:**
   - Set up thread pool code skeleton
   - Start MakeDir fix (quick win)
   - Begin Zstandard integration

3. **Week 2-3:**
   - Complete LaunchSubScript alpha version
   - Test with simple curl operations
   - Implement DDS parser

4. **Week 4:**
   - LaunchSubScript beta + OAuth integration
   - Full integration testing
   - Documentation updates

---

## Appendix: Document Cross-Reference

| Topic | Location |
|-------|----------|
| BC7 detailed analysis | sage_phase11_analysis.md - TASK 1 |
| API gaps complete list | sage_phase11_analysis.md - TASK 2, Summary Table |
| LaunchSubScript usage | sage_phase11_analysis.md - TASK 3, section 3.2 |
| Thread pool architecture | launchsubscript_implementation.md - Architecture Design |
| C API specification | launchsubscript_implementation.md - Implementation Specification |
| Testing strategy | launchsubscript_implementation.md - Testing Strategy |
| Performance analysis | launchsubscript_implementation.md - Performance Considerations |
| Quick implementation tasks | phase11_quick_ref.md - Checklist |

---

**Report Compiled by:** Sage (賢者)
**Classification:** Project Internal - Phase 11 Planning
**Status:** Complete and Ready for Implementation

For questions or clarifications, reference the specific section and line numbers provided throughout the documents.
