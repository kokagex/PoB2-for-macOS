# Active ORBIT: Token-Efficient Protocol Redesign

Date: 2026-02-17
Status: Approved

## Problem

LOGOS-ORBIT consumes excessive tokens with minimal value:
- `/routine` 5-phase: 8,500-15,000 tokens/task (ceremonial, not actionable)
- Subagent delegation: 3,500-9,000 tokens/subtask (bloated prompts)
- CLAUDE.md ORBIT section: 500 tokens/turn (verbose)

Total: 40,000+ tokens for a typical 3-subtask operation.

## Solution: 3 Improvements

### 1. Active ORBIT (replaces /routine)

Single entry point: `record_action`. Three modes auto-activate:

**Guardian** (on edit actions):
- Auto-detects affected interfaces from file content
- Matches against historical failure rules (Nomos store)
- Returns concrete warnings with file:line references
- MCP change: `audit_contract` gets `auto_detect: true` mode
- Integration: `record_action` response includes `guardianAlert`

**Navigator** (on search >5 or entropy >0.9):
- Builds file dependency graph from action history
- Identifies unvisited nodes in the graph
- Suggests concrete files/lines to explore
- Detects unverified edits (edit:verify ratio)
- MCP change: `check_drift` returns contextual routes with targets

**Chronicler** (on outcome reporting):
- `outcome: "failed"` → auto record_failure + generate_rule
- `outcome: "success"` → auto tattoo_spec for pattern
- User correction detected → auto evolve_criterion
- MCP change: `record_action` accepts optional `outcome` field

### 2. Micro-Agent Protocol (subagent token control)

Max 5000 tokens per subagent task.

**Prompt template** (150-300 tokens max):
```
TASK: [one-line description]
FILE: [absolute path]
LINE: [line number]
CHANGE:
  old: [exact old_string]
  new: [exact new_string]
CONSTRAINT: LuaJIT 5.1 | no nil fallback | %s+tostring()
```

**Model selection**:
- haiku: simple replacements (max_turns: 3)
- sonnet: logic changes (max_turns: 5)
- opus: never for subagents (main agent handles design)

**Rules**:
- 1 subagent = 1 file, 1 change
- No full file content in prompt (Edit old_string suffices)
- Context: 3 lines before/after (not 10)

### 3. CLAUDE.md Compression

Replace ORBIT section (18 lines → 8 lines):
```markdown
### 0. LOGOS-ORBIT: Active Protocol
record_action is the sole entry point. 3 modes auto-activate:
- **Guardian** (edit): past failure matching + interface check
- **Navigator** (search >5): unexplored file suggestions
- **Chronicler** (outcome): auto-learn success/failure patterns
No direct MCP calls needed. /routine is abolished.
```

Replace subagent section:
```markdown
### 2. Lua Subagents: 5000 Token Cap
Delegate .lua edits via Task tool. TASK/FILE/LINE/CHANGE/CONSTRAINT format.
Model: haiku (replacements) / sonnet (logic). 1 file per agent.
```

## Token Impact

| Scenario | Before | After | Reduction |
|----------|--------|-------|-----------|
| Simple bugfix | 15,000 | 800 | 95% |
| Normal task (3 subtasks) | 40,000 | 2,500 | 94% |
| Large change (10 subtasks) | 100,000+ | 6,000 | 94%+ |
| Per-turn base cost | 500 | 150 | 70% |

## Files to Change

| File | Change |
|------|--------|
| logos-chronos/src/record.ts | outcome field, Guardian/Navigator auto-invoke |
| logos-chronos/src/drift.ts | contextualRoutes generation |
| logos-integrity/src/audit.ts | auto_detect mode |
| logos-nomos/src/failure.ts | auto record_failure via record_action |
| .claude/CLAUDE.md | ORBIT section rewrite |
| skills/routine/SKILL.md | Abolish 5-phase, replace with Tier + Active ORBIT |

## Risk Assessment

- Low: CLAUDE.md / SKILL.md changes (text only, reversible)
- Medium: MCP server changes (need testing, but backward compatible)
- Mitigation: All MCP changes are additive (new fields), no breaking changes
