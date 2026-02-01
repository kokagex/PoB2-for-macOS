# Documentation Directory

This directory contains cross-project documentation, learning data, and agent definitions.

## Structure

```
doc/
├── README.md           # This file
├── agents/             # Agent system definitions (shared across projects)
│   ├── 00_overview.md          # Multi-agent system hierarchy
│   ├── 01_prophet.md           # Prophet agent (Strategic planning)
│   ├── 02_mayor.md             # Mayor agent (Task coordination)
│   ├── 03_paladin.md           # Paladin agent (Quality assurance)
│   ├── 04_merchant.md          # Merchant agent (External research)
│   ├── 05_sage.md              # Sage agent (Technical validation)
│   ├── 06_bard.md              # Bard agent (Documentation)
│   └── 07_artisan.md           # Artisan agent (Implementation)
└── learning/           # Learning data and historical context
    ├── CRITICAL_FAILURE_ANALYSIS.md  # Past failure lessons
    ├── LESSONS_LEARNED.md            # Accumulated knowledge
    ├── METAL_SHADER_DEBUG_REPORT.md  # Current investigation
    ├── METAL_SHADER_FIX_PLAN_2026-02-01.md  # Implementation plan
    └── PLAN_REVIEW_2026-02-01.md     # Plan review
```

## Purpose

### `agents/`
Contains the multi-agent system definitions shared across all projects.

**Agent Hierarchy**:
- **Standard Tier**: Prophet, Mayor, Paladin, Merchant, Sage, Bard, Artisan

### `learning/`
Contains learning data, failure analyses, and implementation plans. This serves as institutional memory across projects.

## Mandatory Routine

Before any task execution, the Prophet agent MUST:
1. Read learning data from `../doc/learning/`
2. Read all agent definitions from `../doc/agents/`
3. Create implementation plan in `../doc/learning/`
   - **Planning is the Mayor's responsibility**
   - Break down tasks into minimal units for incremental processing
   - Write detailed specifications and finalize design
   - **Implementation begins ONLY after God's agreement**
4. Perform review
5. Seek God's approval
   - **ONLY the Prophet can communicate with God**
   - **The Prophet MUST relay God's will to the Mayor**
   - **The Prophet MUST NOT perform any practical work**
   - Reports from villagers (specialist agents) are received by the Mayor
   - The Mayor reports to the Prophet
   - The Prophet reports to God ONLY when approved by the Prophet
6. Execute plan in parallel (multiple agents work simultaneously). If only one assignee, another agent MUST assist

## Location

**Root**: `/Users/kokage/national-operations/doc/`

This directory is at the root level (`national-operations/`) to be accessible by all projects:
- `pob2macos/`
- `memory/`
- Other future projects

---

**Note**: Use relative paths from any project directory: `../doc/learning/`, `../doc/agents/`
