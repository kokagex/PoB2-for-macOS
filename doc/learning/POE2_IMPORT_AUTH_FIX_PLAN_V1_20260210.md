# PoE2 Import OAuth Error Fix - Plan V1

**Date**: 2026-02-10
**Task**: Fix OAuth authorization error in Import/Export (PoE2) and restore working authentication flow

---

## 1. Root Cause Analysis

### Observations
- Clicking **Authorize with Path of Exile** triggers an on-screen error and blocks further use.
- Error text (from log):
  - `In 'OnFrame': src/Classes/PoEAPI.lua:79: bad argument #2 to 'LaunchSubScript' (cannot convert 'string' to 'void *')`
- The app’s FFI binding defines `LaunchSubScript(const char* scriptName, void* luaState)`.
- PoEAPI’s legacy OAuth flow calls `LaunchSubScript(serverText, "", ...)`, which passes a string where a `void*` is expected.

### Likely Cause (ranked)
1. **Legacy OAuth flow still invoked** and calls `LaunchSubScript` with an invalid signature (string instead of pointer).
2. **Manual OAuth flow not active** in the running build or is bypassed (old ImportTab code path still used).
3. **App is running a different code copy** than the edited bundle (stale app binary or different working directory).

---

## 2. Proposed Solutions (Choose ONE)

### Option A (Recommended): Manual OAuth flow + disable legacy `LaunchSubScript`
- **Approach**:
  - Ensure ImportTab uses manual OAuth flow (open browser, paste redirect URL/code).
  - Modify `PoEAPI:FetchAuthToken` to *not* call `LaunchSubScript` and instead return a clear error or redirect to manual flow.
- **Pros**: Small change, avoids FFI mismatch, no socket dependency.
- **Cons**: Requires manual paste step.

### Option B: Wrap `LaunchSubScript` safely
- **Approach**: Create a Lua wrapper to convert legacy call to `sg.LaunchSubScript(scriptName, luaState)` and pass `nil`/`ffi.NULL` for the pointer.
- **Pros**: Keeps auto auth pattern.
- **Cons**: Risky; other code paths use multi-arg signature, not compatible with current FFI binding.

### Option C: Restore server-based OAuth with LuaSocket
- **Approach**: Bundle LuaSocket or equivalent and re-enable local callback server.
- **Pros**: Fully automatic OAuth.
- **Cons**: High effort, packaging complexity.

---

## 3. Implementation Steps (for Option A)

1. **ImportTab.lua** (app bundle):
   - Ensure `Authorize` button calls `self.api:BeginAuth()` and switches to manual code entry mode.
   - Provide input UI for paste + a button to complete auth via `self.api:CompleteAuth()`.
2. **PoEAPI.lua** (app bundle):
   - Modify `FetchAuthToken` to avoid `LaunchSubScript` entirely.
   - Return a clear error (e.g., "Manual auth required") if called.
3. **No logging inside app bundle**.
4. **Visual verification**: Press Authorize → browser opens → paste code/URL → authentication succeeds without error overlay.

**Note**: Lua modifications must be delegated to sub-agent per `.claude/AGENT.md`. Current environment lacks Task tool; approval needed to proceed with direct edits if sub-agent is unavailable.

---

## 4. Timeline
- Code changes: 15–25 minutes
- Verification: 5–10 minutes

Total: ~30 minutes

---

## 5. Risk Assessment
- **Risk**: Low. Changes localized to Import OAuth flow.
- **Rollback**: Revert changes to `PoEAPI.lua` and `ImportTab.lua` in app bundle.

---

## 6. Success Criteria
1. Clicking **Authorize with Path of Exile** does **not** trigger the `LaunchSubScript` error.
2. Browser opens to PoE auth page.
3. Pasting redirect URL/code completes auth and switches to account selection.
4. No new logs created inside app bundle.

