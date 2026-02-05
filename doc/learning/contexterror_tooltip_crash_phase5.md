# Context Error: Tooltip Rendering Crash - Phase 5

**Date**: 2026-02-05
**Status**: INVESTIGATING - Multiple attempts, consistent crash during tooltip rendering
**Phase**: Phase 5 - Tooltip Re-enablement

---

## Symptom

**Observed Behavior**:
- ✅ Phase 3 (Ascendancy click) and Phase 4 (Normal node allocation) work correctly
- ❌ Application crashes when hovering over nodes to display tooltips
- ❌ Crash occurs even with ultra-minimal tooltip implementation

**Expected Behavior**:
- Hover over node → Tooltip appears with node name and basic info
- Application remains stable

---

## Work History - Fix Attempts

### Attempt 1: Re-enable Tooltip with MINIMAL Mode Branch
**Change**:
- Line 1255: `if false` → `if _G.MINIMAL_PASSIVE_TEST`
- Added MINIMAL mode implementation in AddNodeTooltip
- Used AddNodeName for proper formatting

**Result**: ❌ Text position misaligned
**Analysis**: Tooltip displayed but formatting was incorrect

---

### Attempt 2: Fix Text Position with AddNodeName
**Change**: Used `self:AddNodeName(tooltip, node, build)` for proper layout

**Result**: ❌ Crash
**Analysis**: AddNodeName accesses build.spec.nodes for Socket nodes, causing crash in MINIMAL mode

---

### Attempt 3: Inline AddNodeName Without build.spec Dependencies
**Change**:
- Created inline version of AddNodeName
- Set tooltip:SetRecipe(), tooltipHeader, added node name with proper fonts
- Removed build.spec dependencies

**Result**: ❌ Crash
**Analysis**: Still crashing, SetRecipe or tooltipHeader might be problematic

---

### Attempt 4: Add Elimination Logging
**Change**: Added file logging at multiple points to identify crash location

**Result**: ✅ Identified crash location
**Log Output**:
```
[TOOLTIP] 1-11. All AddNodeTooltip steps completed
[TOOLTIP] 12. AddNodeTooltip returned
[TOOLTIP] 13. Before Draw
```
(14. After Draw was NOT written)

**Analysis**: Crash occurs during `self.tooltip:Draw()` call, not in AddNodeTooltip

---

### Attempt 5: Ultra-Minimal Tooltip (No Formatting)
**Change**:
- Removed all formatting (SetRecipe, tooltipHeader, fonts, colors)
- Just basic tooltip:AddLine() calls

**Result**: ❌ Crash
**Analysis**: Issue is not with formatting, but with Draw method itself

---

### Attempt 6: Wrap Draw in pcall
**Change**: Wrapped tooltip:Draw() in pcall to catch error

**Result**: ❌ Crash (pcall did not prevent crash)
**Analysis**: Crash is at lower level (C/Metal layer), not catchable by Lua pcall

---

## Current State

### Verified Facts
1. ✅ AddNodeTooltip completes successfully (all 11 log steps written)
2. ✅ Tooltip content is created without errors
3. ❌ Crash occurs during tooltip:Draw() call
4. ❌ pcall cannot catch the crash (suggests native/C crash, not Lua error)
5. ✅ Phase 3, 4 functionality intact (no regression)

### Modified Files
1. **PassiveTreeView.lua**:
   - Line 1255: Tooltip rendering enabled for MINIMAL mode
   - Lines 1666-1678: Ultra-minimal AddNodeTooltip implementation
   - Lines 1262-1272: pcall wrapper around Draw

### Critical Observation
**The crash is in the native rendering layer (C++/Metal), not in Lua code.**

Possible causes:
1. Tooltip class requires initialization that doesn't happen in MINIMAL mode
2. Draw method requires specific setup or state that's missing
3. Font rendering system is not initialized in MINIMAL mode
4. Tooltip rendering depends on other systems (build.calcsTab, etc.) at render time

---

## Hypotheses

### Hypothesis A: Font System Not Initialized (HIGH)
**Theory**: Tooltip:Draw() tries to render text but font system is not initialized in MINIMAL mode
**Evidence**:
- Even with no font specification, crash still occurs
- Font rendering might happen at C layer during Draw
**Likelihood**: High
**Test**: Check if fonts need to be loaded/initialized before tooltip rendering

### Hypothesis B: Tooltip Object Not Fully Initialized (MEDIUM)
**Theory**: self.tooltip object exists but lacks required initialization for Draw
**Evidence**:
- Tooltip has never been used in MINIMAL mode before (always disabled with `if false`)
- Draw might require internal state set during full app initialization
**Likelihood**: Medium
**Test**: Check Tooltip class initialization requirements

### Hypothesis C: Viewport or DrawLayer Issue (LOW)
**Theory**: SetDrawLayer or viewPort parameter causes issues in MINIMAL mode
**Evidence**:
- SetDrawLayer(nil, 100) called before Draw
- viewPort parameter passed to Draw
**Likelihood**: Low
**Test**: Try drawing without SetDrawLayer or with different parameters

### Hypothesis D: Tooltip System Fundamentally Incompatible with MINIMAL Mode (HIGH)
**Theory**: Tooltip rendering requires full application infrastructure (build.calcsTab, etc.) at render time, not just during content creation
**Evidence**:
- Crash happens at native/C level (not catchable by pcall)
- No combination of simplifications prevents crash
- System has never worked in MINIMAL mode
**Likelihood**: High
**Test**: Consider alternative approach - disable tooltip entirely or show info differently

---

## Code Context

### Tooltip Rendering Flow (Current)
```
1. Line 1255: Hover detected on node
2. Line 1257: SetDrawLayer(nil, 100)
3. Line 1262: CheckForUpdate returns true
4. Line 1263: AddNodeTooltip creates content → SUCCESS
5. Line 1270: Set tooltip.center = true
6. Line 1262-1272: pcall(tooltip:Draw(...)) → CRASH (native layer)
```

### Why Phase 3, 4 Work But Tooltip Doesn't
- Phase 3, 4: Node allocation/rendering uses basic drawing primitives (DrawImage)
- Tooltip: Uses complex text rendering system with fonts, layouts, possibly requiring full app initialization

---

## Next Steps - Fix Candidates Needed

Following CLAUDE.md protocol:
1. Create 3 fix candidates (Diagnostic, Targeted, Robust)
2. Present to user with AskUserQuestion tool
3. Implement only selected option
4. Test and iterate

---

**Status**: ✅ RESOLVED - Tooltip Disabled, Phase 5 Aborted
**Resolution**: Option A - Complete tooltip disablement
**Next Step**: Phase 6 (or different feature)

---

## Resolution

**Selected Fix**: Option A - Tooltip を完全に無効化（推奨）

**Actions Taken**:
1. Reverted line 1255 to `if false` (tooltip disabled)
2. Removed MINIMAL mode implementation from AddNodeTooltip
3. Added failure documentation comments in code
4. Verified Phase 3, 4 functionality intact

**Result**: ✅ Application stable, Phase 3 & 4 working correctly

**Conclusion**:
Tooltip system is fundamentally incompatible with MINIMAL mode. Requires full application infrastructure (build.calcsTab, font rendering system, etc.) at native/C++ layer. MINIMAL mode testing cannot support tooltip rendering.

**Recommendation**:
- Keep tooltip disabled in MINIMAL mode
- Test tooltip functionality only in full application mode
- Consider alternative UI for node information display if needed in MINIMAL mode
