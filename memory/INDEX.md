# Memory Organization Index

**Updated:** 2026-01-30 20:20 JST
**Status:** Fully Organized

---

## Project Structure

```
memory/
├── INDEX.md (this file)
├── dashboard.md
├── projects.yaml
├── skills.yaml
├── PROJECT_QUICK_LINKS.md
├── MEMORY_ORGANIZATION_README.md
│
├── PRJ-001_village_tool/        # Village Tool Project (59+ files)
│   ├── PHASE15 documentation
│   ├── PHASE16 documentation
│   ├── PHASE17 documentation
│   ├── Agent reports (Artisan, Paladin, Merchant, Sage, Bard)
│   └── Architecture and deployment guides
│
├── PRJ-002_parts_extractor/     # Parts Extractor Project (13 files)
│   ├── Implementation documentation
│   └── Delivery reports
│
├── PRJ-003_pob2macos/           # Path of Building 2 macOS (84 files)
│   ├── v2.0.0 documentation
│   ├── Technical reports
│   └── Integration guides
│
└── analysis/                    # Cross-project analysis
```

---

## Projects

### PRJ-001: Village Tool
**Status:** Production Ready (Phase 17 Complete)
**Type:** Multi-agent system with C subscript workers
**Location:** /Users/kokage/national-operations/claudecode01/village_tool

**Key Files:**
- PHASE15_*: Initial implementation and testing
- PHASE16_*: Integration and security validation
- PHASE17_*: Final delivery and completion
- Agent reports: Artisan (A1), Paladin (P1-P3), Merchant (M1-M5), Sage (S1-S2)

**Documentation Count:** 59+ files

---

### PRJ-002: Parts Extractor
**Status:** Delivered
**Type:** Automotive parts inventory tool
**Location:** /Users/kokage/national-operations/claudecode01/parts_extractor

**Key Files:**
- PARTS_EXTRACTOR_DELIVERY.md
- IMPLEMENTATION_SUMMARY.md
- Budget and feature documentation

**Documentation Count:** 13 files

---

### PRJ-003: PoB2macOS
**Status:** Active Development (v2.0.0)
**Type:** Path of Building 2 port to macOS
**Location:** /Users/kokage/national-operations/claudecode01/pob2macos

**Current Phase:** OnFrame crash investigation
**Key Achievement:** Lua 5.4 integration, stack overflow resolved

**Key Files:**
- v2.0.0/SUCCESS_REPORT.md - Technical solution
- v2.0.0/FINAL_STATUS.md - Complete status
- v2.0.0/VERIFICATION_SUMMARY.md - Test results
- QUICK_START.md - Testing guide
- TEAM_SETTINGS.md - User requirements

**Documentation Count:** 84 files

---

## Quick Links

### Village Tool (PRJ-001)
- **Latest Status:** PHASE17_COMPLETION_REPORT.txt
- **Quick Start:** PHASE16_QUICK_START.md
- **Architecture:** PHASE15_ARCHITECTURE.md
- **Security:** PALADIN_PHASE15_SECURITY_VALIDATION.md

### Parts Extractor (PRJ-002)
- **Delivery:** PARTS_EXTRACTOR_DELIVERY.md
- **Summary:** IMPLEMENTATION_SUMMARY.md

### PoB2macOS (PRJ-003)
- **Latest Status:** v2.0.0/FINAL_STATUS.md
- **Quick Start:** QUICK_START.md
- **Tech Details:** v2.0.0/SUCCESS_REPORT.md
- **User Requirements:** TEAM_SETTINGS.md

---

## File Organization Rules

### By Phase
- PHASE15_* → PRJ-001_village_tool/
- PHASE16_* → PRJ-001_village_tool/
- PHASE17_* → PRJ-001_village_tool/

### By Agent
- ARTISAN_* → PRJ-001_village_tool/
- PALADIN_* → PRJ-001_village_tool/
- MERCHANT_* → PRJ-001_village_tool/
- SAGE_* → PRJ-001_village_tool/
- BARD_* → PRJ-001_village_tool/

### By Project
- PARTS_EXTRACTOR_* → PRJ-002_parts_extractor/
- PoB2macOS docs → PRJ-003_pob2macos/

---

## Statistics

| Project | Files | Status | Completion |
|---------|-------|--------|------------|
| PRJ-001 | 59+   | ✅ Complete | Phase 17 |
| PRJ-002 | 13    | ✅ Delivered | Final |
| PRJ-003 | 84    | 🔴 Active | v2.0.0 Dev |

**Total Documentation:** 156+ files
**Organization Status:** ✅ Complete
**Last Cleanup:** 2026-01-30

---

## Recent Updates

### 2026-01-30
- Organized all scattered PHASE files into PRJ-001
- Moved agent reports to PRJ-001
- Cleaned up root directory
- Updated PRJ-003 with latest PoB2macOS documentation
- Created this INDEX.md

### 2026-01-29
- Phase 17 completion for village_tool
- Final reports generated
- Cross-project analysis

### 2026-01-28
- Memory organization structure created
- PRJ-00x folders established
- Initial file categorization

---

## Maintenance

### Regular Tasks
- [ ] Update INDEX.md after major milestones
- [ ] Archive completed phase documentation
- [ ] Keep dashboard.md synchronized
- [ ] Update PROJECT_QUICK_LINKS.md

### Cleanup Policy
- Keep all PHASE documentation in respective PRJ folders
- Agent reports stay with PRJ-001
- Cross-project analysis in analysis/ folder
- Remove duplicate or obsolete files

---

**Maintained By:** Claude Code Assistant
**Purpose:** Centralized project documentation and memory management
**Location:** /Users/kokage/national-operations/claudecode01/memory/
