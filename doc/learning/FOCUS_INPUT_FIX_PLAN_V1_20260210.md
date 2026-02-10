# Focus Transfer Fix for Text Inputs - Plan V1

**Date**: 2026-02-10
**Task**: Ensure first click reliably focuses text inputs (search/build name) so OnChar input is visible

---

## 1. Root Cause Analysis

### Symptoms
- UI is stable.
- Text input events reach EditControl (OnChar fires, buffer updates), but user reports input appears non-functional.

### Hypothesis (selected option)
- **Mouse click focus is not transferring reliably** when another control is already selected. The current ControlHost click handling favors the existing `selControl`, so a click on a text field may not select it on the first click.

### Evidence
- ControlHost processes `KeyDown` for mouse buttons by sending the event to `selControl` first, then optionally to `mOverControl`.
- If `selControl` consumes the event and does not return the new control, focus may not move.

---

## 2. Proposed Solution

### Strategy
Prioritize **mouse click target** (`mOverControl`) for `KeyDown` mouse button events, regardless of current `selControl`. This makes focus transfer deterministic with a single click.

### Target File
- `PathOfBuilding.app/Contents/Resources/src/Classes/ControlHost.lua`

### Technical Change (conceptual)
- On `KeyDown` with `event.key:match("BUTTON")`, check mouse-over control **first**.
- If a control is under the cursor, pass the click to it and select it.
- Only if no control under cursor, fall back to current `selControl`.

---

## 3. Implementation Steps

1. Edit `ControlHost.lua` to handle mouse button focus first.
2. Do **not** add any logging inside the app bundle.
3. Launch app and verify that clicking the search box immediately enables typing.

---

## 4. Timeline
- Code change: 5–10 minutes
- Verification: 5 minutes

Total: ~15 minutes

---

## 5. Risk Assessment

- **Risk**: Low. Change only affects mouse button focus behavior.
- **Rollback**: Revert the small change in `ControlHost.lua`.

---

## 6. Success Criteria

1. Clicking a search field once gives focus (caret appears).
2. Typing shows characters immediately.
3. No regressions in other controls.
4. No log files created in the app bundle.

