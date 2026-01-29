# Memory Directory Organization

**Date**: 2026-01-29
**Status**: Complete

## Overview

The memory directory has been reorganized to group documentation by project for better discoverability and project management.

## Structure

```
memory/
├── PRJ-001_village_tool/          (30 files)
├── PRJ-002_parts_extractor/       (11 files)
├── PRJ-003_pob2macos/             (79 files)
├── analysis/                       (shared utilities)
├── dashboard.md                    (cross-project status)
├── DIVINE_FINAL_REPORT_20260128.md (framework overview)
├── projects.yaml                   (project configuration)
├── skills.yaml                     (agent skills)
└── MEMORY_ORGANIZATION_README.md   (this file)
```

## Project Breakdown

### PRJ-001: village_tool
**Phases**: 1-3
**Focus**: Foundation, architecture, early testing
**Key Files**:
- `PHASE1_DELIVERABLES.md` - Phase 1 requirements
- `PHASE2_COMPLETION_REPORT.md` - Phase 2 completion
- `PHASE3_MVP_DELIVERABLES.md` - MVP definition
- Phase 1-3 reports from Merchant, Paladin, Sage
- Test results and early validation

**Total**: 30 files

### PRJ-002: parts_extractor
**Phases**: 4-5
**Focus**: FFT processing, PNG extraction, performance optimization
**Key Files**:
- `PHASE4_* ` & `PHASE5_*` - Phase documentation
- `merchant_phase4_perf.md` - Performance baseline
- `merchant_phase5_build.md` - Build system updates
- `paladin_phase4_security.md`, `paladin_phase5_security_fixes.md` - Security audits
- `bard_phase4_docs.md` - Documentation

**Total**: 11 files

### PRJ-003: pob2macos
**Phases**: 6-14
**Focus**: Lua engine port, FFI binding, rendering, sub-script execution, watchdog
**Key Subphases**:
- **Phases 6-8**: Core Lua integration, callbacks, synchronization
- **Phases 9-10**: Performance tuning, integration testing (documentation minimal)
- **Phases 11-12**: API gap analysis, BC7 decoder research
- **Phase 13**: LaunchSubScript, BC7 integration
- **Phase 14**: SetForeground, Timeout Watchdog, FPS Counter

**Key Files**:
- `PHASE13_IMPLEMENTATION_GUIDE.md` - Phase 13 comprehensive guide
- `PHASE14_COMPLETION_REPORT.md` - Phase 14 completion
- Phase 6-14 reports from all agents (Merchant, Paladin, Sage)
- Technical analyses (BC7, LaunchSubScript architecture)
- FFI verification and test results

**Total**: 79 files (majority of documented work)

## Shared/Root-Level Files

**4 files** that remain at root level:

1. **dashboard.md** - Real-time status dashboard tracking all projects
2. **DIVINE_FINAL_REPORT_20260128.md** - Framework architectural overview
3. **projects.yaml** - Project configuration metadata
4. **skills.yaml** - Agent skill definitions

**analysis/** - Shared analysis utilities directory

## Usage

When looking for documentation:

- **Village Tool (PRJ-001)**: Navigate to `PRJ-001_village_tool/`
- **Parts Extractor (PRJ-002)**: Navigate to `PRJ-002_parts_extractor/`
- **PoB2 macOS (PRJ-003)**: Navigate to `PRJ-003_pob2macos/`
- **Cross-project status**: See `dashboard.md`
- **Framework info**: See `DIVINE_FINAL_REPORT_20260128.md`

## Document Types by Frequency

### Completion Reports
Each phase typically generates:
- `PHASE##_COMPLETION_SUMMARY/REPORT.md` or `.txt`
- Agent completion reports: Merchant, Paladin, Sage, Bard

### Analysis & Architecture
- `sage_phase##_*.md` - Research and analysis
- `*_analysis.md` - Technical deep dives
- `*_implementation_guide.md` - Implementation specifications

### Security & Performance
- `paladin_phase##_security_report.md` - Security audits
- `merchant_phase##_*.md` - Performance and integration testing
- `*_performance*.md` - Benchmark results

## Total Statistics

- **Total files organized**: 120 files
- **Total projects**: 3 active projects + framework
- **Documentation breadth**: Phases 1-14 (14 phases documented)
- **Agent contributions**: Artisan, Bard, Guardian, Paladin, Sage, Prophet, Merchant, Tester

## Notes

This organization groups related deliverables while preserving the chronological phase structure within each project folder. The cross-project dashboard and framework documents remain at root for easy visibility into overall project status.
