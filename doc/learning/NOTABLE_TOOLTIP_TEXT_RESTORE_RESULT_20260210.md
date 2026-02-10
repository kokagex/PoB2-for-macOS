# Notable Tooltip Text Restore - Result

**Date**: 2026-02-10  
**Issue**: Notable passive tooltip showed header only; body text was missing for some nodes (e.g., `Disorientation`, `Sitting Duck`).

## 1. Symptom
- Tooltip header rendered correctly.
- Tooltip body area appeared, but stat text did not show.
- Initial body-line fallback patch (`node.mods[i]` missing case) showed no visible change.

## 2. Investigation Process (What Actually Worked)
1. **Validated data assumptions against tree.json**
- Confirmed target notables had non-empty `stats` and were not `isMultipleChoice`.
- This reduced priority of "data missing in tree source" hypothesis.

2. **Added temporary visual debug line in AddNodeTooltip**
- Injected `[DBG] sd=... mods=...` line into tooltip body generation.
- User screenshot showed no debug line, proving the failure happened before body text draw completion.

3. **Checked runtime log instead of only UI**
- Log showed repeated error:
  - `ERROR: Tooltip failed: ./pob2_launch.lua:421: bad argument #1 to 'DrawImage' (cannot convert 'table' to 'void *')`
- This identified the real break point: tooltip draw pipeline aborted in `DrawImage` wrapper.

4. **Fixed DrawImage wrapper type handling**
- Runtime passed image arguments in multiple table shapes (`{ _handle = ... }`, `{ handle = ... }`).
- Wrapper only handled one shape and leaked Lua table values to FFI `void*`.
- Added robust unwrapping and final safety guard.

5. **Retested with user screenshot**
- Tooltip body text rendered correctly.
- Temporary debug line removed after confirmation.

## 3. Root Cause
- **Primary root cause**: `pob2_launch.lua` `DrawImage` wrapper forwarded Lua `table` handles into FFI call.
- Result: tooltip draw raised exception mid-render, so body text never completed.
- Secondary hardening: `AddNodeTooltip` depended on `node.mods[i]` presence; added fallback for missing mods so raw `sd` lines still display.

## 4. Implemented Fixes

### A) FFI image handle hardening
- File: `pob2macos/PathOfBuilding.app/Contents/Resources/pob2_launch.lua`
- Change summary:
  - Accept both wrapper styles:
    - `{ _handle = cdata }`
    - `{ handle = { _handle = cdata } }` or `{ handle = cdata }`
  - Final guard: if handle is still `table`, force `nil` (never pass table into FFI `void*`).

### B) Tooltip body fallback when mods are absent
- Files:
  - `pob2macos/PathOfBuilding.app/Contents/Resources/src/Classes/PassiveTreeView.lua`
  - `src/Classes/PassiveTreeView.lua`
- Change summary:
  - Replaced direct `node.mods[i]` access with nil-safe `nodeMod`.
  - If `nodeMod` is missing but `line` exists, still render `colorCodes.MAGIC .. line`.

## 5. Verification
- User visual confirmation screenshot: body text now visible on notable tooltip.
- `luajit` load checks passed for edited files.

## 6. Reusable Lessons
1. **When tooltip header renders but body does not, check runtime log immediately**.
2. **If temporary body debug line is not visible, suspect draw pipeline failure before text loop completion**.
3. **FFI wrappers must normalize all known object shapes and never pass Lua tables to C pointer params**.
4. **Keep tooltip body rendering resilient to missing parsed-mod metadata (`node.mods`)**.
5. **After diagnosis, remove temporary debug UI lines before finalizing**.

## 7. Quick Triage Template (for next similar issue)
1. Reproduce with a known node (`Disorientation` etc.).
2. Add temporary tooltip debug line in body section.
3. If debug not shown, inspect `~/Library/Logs/pob2macos/passive_tree_app.log`.
4. Search for `Tooltip failed` or FFI type conversion errors.
5. Fix wrapper/type path first, then content/data fallback.
