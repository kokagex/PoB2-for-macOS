# PoE2 Import Script-Based Auth - Plan V1

**Date**: 2026-02-10
**Task**: Replace manual OAuth with script-based flow (auto auth) and remove current error

---

## 1. Root Cause Analysis

### Observations
- User wants script-based (automatic) OAuth instead of manual code paste.
- Current app shows error on Authorize due to `LaunchSubScript` signature mismatch.
- `LaunchSubScript` is stubbed in `simplegraphic` and returns 0; multi-arg calls error.
- LuaSocket core module is missing (`socket.core`), so `LaunchServer.lua` cannot run.

### Likely Causes
1. **LaunchSubScript mismatch**: FFI binding only accepts `(const char*, void*)`, while app calls it with multiple args.
2. **Missing socket.core**: OAuth local server script fails to require `socket`.
3. **Manual flow was introduced as workaround**, but user now wants automatic script-based flow.

---

## 2. Proposed Solutions (Choose ONE)

### Option A (Recommended): Script-based auth without LaunchSubScript
- **Approach**:
  - Rewrite `LaunchServer.lua` to use LuaJIT FFI + POSIX sockets (no `socket.core`).
  - Modify `PoEAPI:FetchAuthToken` to call `LaunchServer.lua` directly and exchange token via `lcurl.safe` synchronously.
  - Update `ImportTab` to call `FetchAuthToken` and remove manual code UI.
- **Pros**: Works without C changes; avoids LaunchSubScript stub.
- **Cons**: Auth call is blocking while waiting for browser redirect (short freeze).

### Option B: Implement full LaunchSubScript in C
- **Approach**: Implement threaded sub-script runner in `simplegraphic` and keep original OAuth flow.
- **Pros**: Non-blocking; matches upstream behavior.
- **Cons**: Larger C++ scope, higher risk/time.

### Option C: Keep manual flow
- **Approach**: Maintain paste-code UI.
- **Pros**: Already works.
- **Cons**: User explicitly requested script-based.

---

## 3. Implementation Steps (Option A)

1. **LaunchServer.lua**
   - Replace `require("socket")` with FFI-based local HTTP server.
   - Bind 127.0.0.1 port in 45000–45050, accept single request, parse `code` + `state`.
2. **PoEAPI.lua**
   - Rework `FetchAuthToken` to:
     - Call `LaunchServer.lua` directly.
     - Validate `state`.
     - POST to `/oauth/token` via `lcurl.safe`.
     - Save tokens + expiry.
3. **ImportTab.lua**
   - Remove manual AUTHCODE stage.
   - Button triggers `FetchAuthToken` and updates status.
4. **No app-bundle log writes**.
5. **Visual verification**: Authorize → browser → auto return → account list appears.

---

## 4. Timeline
- Code changes: 30–45 minutes
- Verification: 10 minutes

Total: ~1 hour

---

## 5. Risk Assessment
- **Risk**: Medium (FFI socket + blocking call).
- **Mitigations**:
  - Keep changes isolated to 3 files.
  - Clear error messages on timeout.
- **Rollback**: Revert modified Lua files.

---

## 6. Success Criteria
1. Authorize flow works without manual paste.
2. No `LaunchSubScript` signature error.
3. Auth returns to Import tab with account/character list.
4. No new logs created inside app bundle.

