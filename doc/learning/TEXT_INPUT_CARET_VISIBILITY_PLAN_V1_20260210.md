# Text Input Caret Visibility - Plan V1

**Date**: 2026-02-10
**Task**: Make caret blink more visible to indicate focus during text input

---

## 1. Root Cause Analysis

### Symptoms
- Text inputs accept typing, but caret blink is hard to see.
- Focus state is therefore unclear to the user.

### Likely Causes
1. Caret is drawn at **1 px width** only.
2. Blink duty is **50% (500ms on / 500ms off)**, reducing perceived visibility.
3. Caret color equals text color, which can be low contrast in some areas.

---

## 2. Proposed Solution

### Strategy (single-file, low risk)
- Increase caret width to improve visibility.
- Increase ON time (duty cycle) while keeping 1s period for familiar blink.
- Keep color aligned to existing text color to avoid theme regression.

### Target File
- `PathOfBuilding.app/Contents/Resources/src/Classes/EditControl.lua`

### Technical Changes
- Define caret rendering parameters in `Draw()`:
  - `caretWidth = max(2, floor(textHeight * 0.08))`
  - `blinkOnMs = 700` (70% on, 30% off)
- Apply these to all three caret draw paths (multiline, selection, single-line).

---

## 3. Implementation Steps

1. Edit `EditControl.lua` caret drawing sections.
2. Avoid adding any new log files inside app bundle.
3. Restart app and visually confirm caret visibility in at least two fields.

---

## 4. Timeline
- Code change: 10–15 minutes
- Visual verification: 5 minutes

Total: ~20 minutes

---

## 5. Risk Assessment
- **Risk**: Low (purely visual change in edit control).
- **Rollback**: Revert caret width/duty cycle values.

---

## 6. Success Criteria
1. Caret is visibly blinking in focused text fields.
2. Focus is obvious at a glance.
3. No regressions in text rendering or selection highlight.
4. No new logs created inside app bundle.

