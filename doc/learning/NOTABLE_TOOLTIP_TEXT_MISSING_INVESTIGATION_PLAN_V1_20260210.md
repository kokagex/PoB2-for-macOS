# Notable Tooltip Text Missing - Investigation Plan V1

**Date**: 2026-02-10
**Task**: Determine why notable passive tooltips show header-only text (body missing)

---

## 1. Root Cause Analysis

### Observations
- User screenshots show tooltip header (node name) visible, but body text absent.
- Missing text occurs on multiple notables (e.g., "Sitting Duck", "Disorientation").
- Prior plan noted multi-choice nodes with empty `stats`; linked nodes contain stats.
- Tooltip draw is active; background and header render (not a total tooltip failure).

### Previous Attempts / Context
- Notable tooltip fix plan V1 (2026-02-10) proposed fallback to linked node stats.
- Tooltip draw is enabled and pcall-protected (Phase I plan).
- Text visibility issues existed elsewhere (text input) due to color table mismatch.

### Hypotheses (ranked)
1. **H1 (Font alias mismatch)**: Header uses one font alias that exists; body uses another alias that is missing or not loaded on macOS (e.g., `VAR`/`FONTIN`). Result: header draws, body silently fails.
2. **H2 (Color table mismatch)**: Body lines are rendered with `^7` or other codes mapped to near-black/transparent, making text appear invisible against dark tooltip background.
3. **H3 (Data path mismatch)**: For some notables, `node.sd`/`node.mods` are empty due to tree data variants or missing stat sets; tooltip has no body lines to draw.
4. **H4 (Layout/clipping)**: Body lines are computed but clipped to zero height because of font metrics, width calc, or `tooltip:CheckWidth` mismatch.

---

## 2. Proposed Investigation

### Strategy
Correlate tooltip body rendering with font aliases, color codes, and node data in the app bundle and compare with original PoB2.

### Technical Approach
- Inspect tooltip rendering path in `PassiveTreeView.lua` and `Tooltip.lua`.
- Verify font aliases registered in runtime and compare to original.
- Validate node stat data for affected notables in `TreeData/0_4/tree.json`.
- Compare with local reference: `/Users/kokage/national-operations/pob2macos/dev/pob2-original`.

---

## 3. Implementation Steps

1. **Confirm node data**
   - Check `tree.json` entries for affected notables: `stats`, `statSets`, `isMultipleChoice`.
2. **Verify font aliases**
   - Identify font names used in tooltip body lines.
   - Confirm those aliases are registered and fonts exist in `runtime/fonts/`.
3. **Inspect Tooltip draw path**
   - Review `Tooltip.lua` for font selection, color code parsing, and line layout.
4. **Compare with original**
   - Diff relevant tooltip/font code between app bundle and `pob2-original`.
5. **Decide root cause**
   - Select the most likely hypothesis based on evidence.

---

## 4. Timeline

- Data + font inspection: 15 minutes
- Tooltip render path review: 15 minutes
- Reference comparison: 15 minutes
- Root cause determination: 5 minutes

**Total**: ~50 minutes

---

## 5. Risk Assessment

- **Risk**: Low (read-only analysis).
- **Potential impact**: None until changes are proposed.
- **Rollback**: Not applicable.

---

## 6. Success Criteria

1. Identify the most likely root cause with evidence (font, color, or data).
2. Provide a minimal, targeted fix proposal (no implementation yet).
3. Specify a visual verification step for the fix.
