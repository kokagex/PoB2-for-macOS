# App Bundle Log Generation Block - Plan V1

**Date**: 2026-02-10
**Task**: Prevent log file creation inside the app bundle

---

## 1. Root Cause Analysis

### Current Behavior
- The launcher script `PathOfBuilding.app/Contents/MacOS/PathOfBuilding` writes logs to:
  - `PathOfBuilding.app/Contents/Resources/debug/passive_tree_app.log`
- This creates/updates files **inside the app bundle**, which the user wants to prohibit.

### Evidence
- Script sets:
  - `LOG_DIR="$(dirname "$0")/../Resources/debug"`
  - `LOG="$LOG_DIR/passive_tree_app.log"`
  - `exec luajit ./pob2_launch.lua >> "$LOG" 2>&1`

---

## 2. Proposed Solution

### Strategy
Redirect logs to a **user-writable directory outside the bundle** (e.g., `~/Library/Logs/pob2macos`) while keeping logging available.

### Options
- **Option A (Recommended)**: Redirect logs to `~/Library/Logs/pob2macos` using an overrideable environment variable.
- Option B: Disable file logging entirely (`/dev/null`) and rely on terminal output only.

### Chosen Approach
**Option A** to preserve diagnostic logs without writing inside the bundle.

---

## 3. Implementation Steps

1. Update launcher script:
   - File: `PathOfBuilding.app/Contents/MacOS/PathOfBuilding`
   - Replace bundle path log dir with:
     - `LOG_DIR="${POB_LOG_DIR:-$HOME/Library/Logs/pob2macos}"`
     - `mkdir -p "$LOG_DIR"`
2. Keep log filename the same (`passive_tree_app.log`).
3. Verify no new files are created under `PathOfBuilding.app/Contents/Resources/debug` on launch.

---

## 4. Timeline
- Edit script: 5 minutes
- Verification: 5 minutes

Total: ~10 minutes

---

## 5. Risk Assessment

### Risks
- Minimal: log path change only.
- If `HOME` is not set, log dir may be invalid.

### Mitigations
- Use env override `POB_LOG_DIR` if needed.
- If `HOME` missing, fallback to `/tmp/pob2macos_logs` (optional adjustment if needed).

### Rollback
- Restore previous `LOG_DIR` line to bundle path.

---

## 6. Success Criteria

1. App launches normally.
2. No new log files are created under the app bundle.
3. Log file appears in `~/Library/Logs/pob2macos/passive_tree_app.log`.

