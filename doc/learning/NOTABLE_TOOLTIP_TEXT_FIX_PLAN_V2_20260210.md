# Notable Tooltip Text Fix - Plan V2

**Date**: 2026-02-10
**Task**: Fix missing body text in notable passive tooltips (header shows, body blank)

---

## 1. Root Cause Analysis

### Observations
- Tooltip header renders, body area is present but text is invisible/blank for multiple notables.
- Tree data contains `stats` for these nodes (example nodes in tree.json show non-empty stats arrays).
- AddNodeTooltip uses `mNode.sd` and `addModInfoToTooltip` to add lines.
- Prior Plan V1 (multiple-choice fallback) did not resolve the issue.

### Evidence
- `PassiveTree.lua` sets `node.sd = node.stats` and falls back to `statSets[1].stats`.
- `addModInfoToTooltip` always adds a line even when `node.mods` parsing fails.
- Tooltip background height suggests lines exist but are not visible.

### Hypotheses (ranked)
1. **H1 (Rendering/color path)**: Stat lines are added, but rendered with an invisible color (e.g., wrong color mapping for `^x` or `^7`).
2. **H2 (Data path mismatch)**: For affected notables, `mNode.sd` is empty at runtime (stats are not propagated), so lines are not added.
3. **H3 (Tooltip draw path)**: Tooltip uses different handling for first line (recipe/oils) and may skip subsequent lines due to data flags or `_handled` logic.

---

## 2. Proposed Solution / Investigation

### Strategy
Perform a minimal, on-screen verification to determine whether `mNode.sd` lines exist and whether rendering is the issue. Then apply the smallest fix that directly addresses the confirmed root cause.

### Approach Options (pick after evidence)
- **Option A (Rendering fix)**: Force stat lines to render with a known visible color (`colorCodes.NORMAL`) and strip any leading color codes that may be malformed.
- **Option B (Data fallback)**: If `mNode.sd` is empty, render from `node.stats` / `node.statSets` directly.
- **Option C (Tooltip flow)**: If the recipe/oil handling skips lines, bypass `_handled` logic for non-title lines or re-add lines after recipe block.

---

## 3. Implementation Steps

1. **Reference diff (read-only)**
   - Compare `Tooltip.lua` and `PassiveTreeView.lua` with `/Users/kokage/national-operations/pob2macos/dev/pob2-original` to identify known-good behavior.
2. **On-screen verification (minimal change, no file logs)**
   - Add a temporary debug line in AddNodeTooltip:
     - `tooltip:AddLine(12, "^xFFFFFF[DEBUG] sd="..tostring(#(mNode.sd or {})).." first="..tostring(mNode.sd and mNode.sd[1] or "nil"))`
   - This is visible-only and removed immediately after diagnosis.
3. **Choose fix (A/B/C)** based on the debug result:
   - If `sd > 0` but still invisible → Option A.
   - If `sd == 0` → Option B.
   - If debug line shows but other lines still missing → Option C.
4. **Implement fix** in `PassiveTreeView.lua` (and sync to app bundle if editing src/).
5. **Visual verification**
   - Hover known notables (e.g., Disorientation, Sitting Duck) and confirm body text is visible.
6. **Cleanup**
   - Remove debug line once root cause confirmed.

---

## 4. Timeline

- Reference diff: 10–15 minutes
- Debug verification + fix: 15–25 minutes
- Visual verification: 5–10 minutes

**Total**: ~30–50 minutes

---

## 5. Risk Assessment

- **Risk**: Low to Medium (tooltip display-only changes)
- **Mitigation**: Minimal changes, visual confirmation, easy rollback.
- **Rollback**: Revert the small change block in `PassiveTreeView.lua`.

---

## 6. Success Criteria

1. Tooltip body text appears for multiple notables that were previously blank.
2. Tooltip header and oils remain correct.
3. No regressions in other tooltips.

---

## Notes / Constraints

- Lua edits require sub-agent per `.claude/CLAUDE.md`; Task tool is unavailable, so direct edits require explicit user approval.
- No log files inside the app bundle.
