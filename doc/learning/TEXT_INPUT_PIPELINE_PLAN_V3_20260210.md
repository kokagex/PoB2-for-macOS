# Text Input Pipeline Fix - Plan V3

**Date**: 2026-02-10
**Task**: Fix text input in search/build name fields (UI is otherwise OK)

---

## 1. Root Cause Analysis

### Symptoms
- UI is stable and rendering correctly.
- Text fields (search, build name, etc.) do not accept input.

### Known Context
- `pob2_launch.lua` loads `CharInput.dylib` and polls `GetCharInput()` in `poll_input_events()`.
- `Launch.lua` forwards `OnChar` to `Main:OnChar` and control host.
- App bundle logging is now redirected outside the bundle (no new logs in bundle).

### Hypotheses (ranked)
1. **CharInput callback is not receiving codepoints**
   - GLFW callback not firing or mismatched GLFW instance.
2. **`OnChar` pipeline is not reached**
   - `char_input_lib` nil, or codepoints filtered, or `Main:OnChar` not invoked.
3. **IME / non-ASCII input filtered**
   - Input method commits characters but filter rejects or encoding path fails.

---

## 2. Proposed Investigation / Fix Options

### Option A (Low risk): Verify CharInput at source
- Run `pob2macos/char_input/test_char.lua` against current runtime libraries.
- If no codepoints appear, fix CharInput or GLFW linkage.

### Option B (Medium risk): Switch to SimpleGraphic built-in `GetCharInput()`
- Rebuild SimpleGraphic from current source, deploy both `SimpleGraphic.dylib` and `libSimpleGraphic.dylib`.
- Update `pob2_launch.lua` to use `sg.GetCharInput()` directly (remove CharInput extension).

### Option C (Medium risk): Lua pipeline verification
- Add minimal, temporary `OnChar` instrumentation (visual or external log) to confirm whether events reach `Main:OnChar`.
- If `OnChar` fires but text fields still ignore input, inspect EditControl focus/handling.

---

## 3. Implementation Steps

1. **User confirmation** (required for next step selection)
   - Ask if ASCII input (A-Z) fails, or only Japanese IME input fails.
2. **Run Option A test** (user or assistant-run):
   - Execute `pob2macos/char_input/test_char.lua`.
   - If codepoints appear, proceed to Option C.
   - If no codepoints, proceed to Option B (or rebuild CharInput).
3. **Apply selected fix only** (per CLAUDE.md rule: 3 candidates → user selects).
4. **Verify** in two text fields (Build List search + Tree search).

---

## 4. Timeline
- Step 1: 5 minutes
- Step 2: 10 minutes
- Step 3: 15–30 minutes (depends on option)
- Step 4: 5 minutes

**Total**: 35–50 minutes

---

## 5. Risk Assessment

- **Low**: Option A (read-only test)
- **Medium**: Option B (binary rebuild and deploy)
- **Medium**: Option C (Lua edits; must avoid bundle logs)

**Mitigations**:
- Keep backups of dylib changes.
- Avoid writing logs inside app bundle.
- One change at a time with visual confirmation.

**Rollback**:
- Restore `SimpleGraphic.dylib` and `libSimpleGraphic.dylib` from backup.
- Revert Lua changes in `pob2_launch.lua` or relevant Lua files.

---

## 6. Success Criteria

1. ASCII input appears in text fields.
2. Backspace deletes characters.
3. No UI regressions.
4. No logs created inside app bundle.

