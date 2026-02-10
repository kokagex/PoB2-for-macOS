# Notable Tooltip Text Fix - Plan V1

**Date**: 2026-02-10
**Task**: Fix missing tooltip text for notable passive nodes (multiple-choice/ascendancy)

---

## 1. Root Cause Analysis

### Observations
- User reports: notable passive tooltips show missing text for multiple nodes.
- Handoff note (2026-02-08) shows partial recovery by adding `node.statSets[1].stats` fallback in `PassiveTree.lua`, but “some notables still empty”.
- Tree data inspection shows several notable nodes with empty `stats` arrays and `isMultipleChoice = true`.
- Connected nodes for these multiple-choice notables contain the actual stat lines.

### Evidence
- Tree data (`TreeData/0_4/tree.json`) includes multiple-choice ascendancy nodes with empty `stats`.
- Example: “Path Seeker” has empty stats, but linked nodes like “Path of the Sorceress” and “Path of the Warrior” contain real stat lines.

### Hypotheses (ranked)
1. **H1 (Most likely)**: `node.sd` is empty for `isMultipleChoice` notables because the base node has no `stats` in tree data. Tooltip therefore renders only the header and no body text.
2. H2: A subset of nodes still use non-standard stat containers, and fallback logic is incomplete.
3. H3: Text is present but invisible due to rendering/color issues (less likely given other notables display correctly).

---

## 2. Proposed Solution

### Strategy
For multiple-choice nodes with empty `sd`, display stat lines from their connected option nodes (linked nodes). This presents the actual choices instead of an empty tooltip.

### Technical Approach
- **File**: `pob2macos/PathOfBuilding.app/Contents/Resources/src/Classes/PassiveTreeView.lua`
- **Location**: Inside `PassiveTreeViewClass:AddNodeTooltip(...)` before the standard `mNode.sd` loop.
- **Logic**:
  - If `mNode.sd` is empty and `node.isMultipleChoice` is true:
    - Add a small header line (e.g., “Available options:”)
    - Iterate `node.linked` and for each linked node with `sd` lines:
      - Add the linked node name
      - Add its stat lines using existing `addModInfoToTooltip` for consistency

This avoids modifying tree data and stays display-only.

---

## 3. Implementation Steps

1. **Confirm target nodes** (analysis already done): identify `isMultipleChoice` notables with empty stats and verify linked nodes have stats.
2. **Add tooltip fallback** in `PassiveTreeView.lua` for `isMultipleChoice` nodes with empty `sd`.
3. **Nil-safety**: guard against `node.linked` being nil or linked nodes lacking stats/mods.
4. **Visual verification**: hover the known multiple-choice notables and confirm option stats display.

---

## 4. Timeline

- Code change: 15 minutes
- Visual verification: 10 minutes (user-driven)
- Total: ~25 minutes

---

## 5. Risk Assessment

- **Risk**: Low. Display-only change in tooltip rendering.
- **Potential regression**: Incorrect or cluttered tooltip if linked nodes are not true options.
- **Mitigation**: Only activate when `node.isMultipleChoice` and `mNode.sd` is empty.
- **Rollback**: Remove the new fallback block (single section change).

---

## 6. Success Criteria

1. Multiple-choice notable tooltips show option stats instead of empty text.
2. Regular notables remain unchanged.
3. No crashes or new visual regressions.

---

## Notes / Constraints

- Lua edits require sub-agent per `.claude/CLAUDE.md`, but Task tool is unavailable in this environment. If needed, request explicit user approval to proceed with direct edit.
- No logs should be written inside the app bundle.
