# Text Input Pipeline Fix - Plan V2

**Date**: 2026-02-10
**Task**: Enable text input in all edit fields (search boxes, build name, etc.)

---

## 1. Root Cause Analysis

### Symptoms
- All text input fields are non-functional (no characters appear).

### Most Likely Causes (ranked)
1. **GLFW char callback not registered** in SimpleGraphic (`glfwSetCharCallback` missing) → codepoints never reach engine.
2. **Lua polling missing**: `pob2_launch.lua` does not consume char input (no `GetCharInput()` loop).
3. **SimpleGraphic source mismatch**: current dylib has input APIs but source tree is incomplete; rebuild requires restoring sources.

### Evidence
- Downstream Lua pipeline already exists: `launch:OnChar()` → `Main:OnChar()` → `ControlHost` → `EditControl:OnChar()`.
- Existing plan (2026-02-10) identifies missing callback and polling.

---

## 2. Proposed Solution

### Strategy
Add a **char input queue** at the C++ layer, expose it via `GetCharInput()`, and **poll/forward** characters in `pob2_launch.lua`.

### Technical Approach
- **SimpleGraphic**
  - Register `glfwSetCharCallback` and enqueue codepoints in a ring buffer.
  - Provide `GetCharInput()` to pop one codepoint at a time (0 when empty).
  - (Optional parity) Implement `GetMouseWheelDelta()` if current dylib already expects it.

- **Lua (FFI)**
  - Add `GetCharInput()` to FFI cdef.
  - In `poll_input_events()` loop, drain codepoints and forward to `launch:OnChar()` after UTF-8 conversion.

---

## 3. Implementation Steps

### Step 0: Verify SimpleGraphic Sources
- Confirm current `simplegraphic/` source matches the dylib expectations.
- If missing, restore from known-good commit (`d4580cb`) before editing.

### Step 1: SimpleGraphic C++ Changes (Artisan)
Files:
- `simplegraphic/src/sg_internal.h`
- `simplegraphic/src/sg_input.cpp`
- `simplegraphic/include/simplegraphic.h`

Changes:
- Add `char_queue[64]`, `char_queue_head`, `char_queue_tail` to `SGContext`.
- Register `glfwSetCharCallback` and enqueue codepoints.
- Implement `GetCharInput()` (pop from queue; return 0 when empty).
- Ensure `sg_input_shutdown()` removes callbacks.
- Add public declarations for `GetCharInput()` (and `GetMouseWheelDelta()` if needed).

### Step 2: Build & Deploy (Merchant)
- Rebuild SimpleGraphic (Metal backend).
- Replace runtime dylib in app bundle:
  - `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib`

### Step 3: Lua FFI + Polling (Artisan)
Files:
- `pob2_launch.lua`

Changes:
- Add FFI declaration: `int GetCharInput(void);`
- In `poll_input_events()`, drain char queue and call `launch:OnChar()` with UTF-8 strings.

### Step 4: Verification (Paladin + User)
- Launch app, click any text field.
- Type ASCII characters → visible.
- Backspace works.
- Verify at least two fields: Build List search, tree search.

---

## 4. Timeline
- Step 0: 10 min
- Step 1: 30–45 min
- Step 2: 10–15 min
- Step 3: 15–20 min
- Step 4: 10–15 min

**Total**: ~75–105 minutes

---

## 5. Risk Assessment

### Risks
- Build failure due to missing dependencies or mismatched headers.
- Buffer overflow if char queue not bounded.
- UTF-8 conversion errors in Lua.

### Mitigations
- Use small ring buffer (64) and drop input when full.
- Only accept `GetCharInput()` until it returns 0.
- If build fails, revert to current dylib and isolate C++ changes.

### Rollback
- Restore previous `SimpleGraphic.dylib` from backup.
- Revert Lua change in `pob2_launch.lua`.

---

## 6. Success Criteria

1. Characters appear in text fields on keypress.
2. Backspace deletes characters.
3. No new crashes during input.
4. Works in at least two UI fields (Build List search + Tree search).

