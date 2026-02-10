# Backspace Duplication + Unexpected Save Dialog Fix - Plan V1

**Date**: 2026-02-10
**Task**: Fix (1) backspace causing text duplication/odd behavior, and (2) save dialog appearing without shortcut

---

## 1. Root Cause Analysis

### Symptoms
- Backspace sometimes causes text to increase or behave unexpectedly in text fields.
- Save dialog appears even when shortcut keys were not intentionally pressed.

### Likely Cause (ranked)
1. **Global shortcuts firing while an EditControl has focus**
   - Build/BuildList handle Ctrl+S/Ctrl+W at the mode level before text control input.
   - If modifier state is mis-read, Save dialog can appear while typing.
2. **CTRL modifier state is effectively stuck**
   - EditControl uses `IsKeyDown("CTRL")` for word-delete/backspace behavior.
   - If `IsKeyDown("CTRL")` is erroneously true, backspace acts like ctrl-backspace.
3. **Focus/selection inconsistencies**
   - If focus jumps or selection resets between frames, EditControl behavior may look like duplication.

---

## 2. Proposed Fix Options (choose ONE)

### Option A (Low risk): Suppress global shortcuts when EditControl has focus
- **Goal**: Stop Save dialog during typing.
- **Change**: In Build.lua and BuildList.lua, if `self.selControl` is a text input (has `OnChar`), skip Ctrl-based global shortcuts.
- **Pros**: Simple, minimal risk.
- **Cons**: Does not directly address CTRL-stuck inside EditControl.

### Option B (Medium risk): Make EditControl use event-based CTRL state
- **Goal**: Fix backspace behavior by ignoring a false CTRL state.
- **Change**: Track `self.ctrlDown` via KeyDown/KeyUp inside EditControl and use that instead of `IsKeyDown("CTRL")`.
- **Pros**: Targets backspace issue directly.
- **Cons**: Requires EditControl changes; may affect other modifier-based behaviors.

### Option C (Recommended): Combine A + B
- **Goal**: Fix both issues in one pass.
- **Change**: Apply Option A in Build/BuildList + Option B in EditControl.
- **Pros**: Addresses both problems.
- **Cons**: Slightly larger change set (still small scope).

---

## 3. Implementation Steps (for selected option)

1. Edit only **app bundle Lua** files.
2. Make one change set per chosen option.
3. No logs inside app bundle.
4. Verify with typing test in at least two fields (Build List search + Tree search).

---

## 4. Timeline
- Option A: 10–15 minutes
- Option B: 15–20 minutes
- Option C: 25–30 minutes

---

## 5. Risk Assessment

- **Low** for Option A
- **Medium** for Option B/C (modifier behavior changes)

**Rollback**: Revert modified Lua blocks in the app bundle.

---

## 6. Success Criteria

1. Backspace behaves normally (single delete; no duplication).
2. Save dialog does not appear while typing.
3. UI otherwise unchanged.
4. No logs created inside app bundle.

