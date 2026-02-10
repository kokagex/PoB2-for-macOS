# BuildList UI Fix Plan V2

**Date**: 2026-02-06 19:35
**Task**: Fix BuildList UI positioning and scaling issues
**Status**: Investigation → Implementation

---

## Root Cause Analysis

### Current Observations
- **User report**: "まったく変化してないけど成功してないでしょ" (No change at all, not successful)
- **Previous observation**: BuildList appearing in center of screen, too small
- **Implemented fixes**:
  - Windows-compatible screenScale division in Main.lua
  - Coordinate scaling in pob2_launch.lua Draw functions
  - Metal contentsScale設定
- **Result**: **NO VISIBLE CHANGE**

### Previous Attempts
1. ❌ **Attempt 1**: DPI scaling削除 → UI positions broken
2. ❌ **Attempt 2**: Windows版互換アプローチ (screenScale除算) → No visible change
3. ✅ **Files verified**: grep confirms code changes are in app bundle

### Critical Contradiction
- ✅ Files contain correct code (verified via grep)
- ✅ Log shows correct values (screenW=1792, scale=2)
- ❌ Visual result: NO CHANGE from previous state

### Root Cause Hypothesis Ranking

#### Hypothesis A: App Not Reloading Changed Files (70%)
**Evidence FOR**:
- macOS app cache may be preventing reload
- User sees ZERO change despite code modifications
- Common macOS behavior: app bundle caching

**Evidence AGAINST**:
- Logs show new debug messages (proves some code loaded)

**Root cause**: macOS NSBundle caching or dylib cache

**Fix**: Force clean reload
- Kill all PathOfBuilding processes
- Clear dylib cache: `sudo update_dyld_shared_cache`
- Delete app bundle, rebuild from source

#### Hypothesis B: Lua Module Caching (20%)
**Evidence FOR**:
- Lua LoadModule() may cache already-loaded modules
- Main.lua changes might not be reloading
- BuildList.lua changes might not be reloading

**Evidence AGAINST**:
- Lua doesn't typically cache across process restarts

**Root cause**: Lua module system not reloading files

**Fix**: Add module reload logic or restart process

#### Hypothesis C: Metal Layer Not Updating (10%)
**Evidence FOR**:
- contentsScale changes require layer rebuild
- Metal layer might not pick up new contentsScale

**Evidence AGAINST**:
- Metal layer is initialized at startup

**Root cause**: Layer property not updating

**Fix**: Rebuild SimpleGraphic.dylib and redeploy

---

## Proposed Solution

### Strategy: Diagnostic Approach + Clean Rebuild
1. **Add debug logging** to confirm which code is executing
2. **Force clean app state** to eliminate caching
3. **Verify each layer** of the coordinate transform chain

### Implementation Options

#### Option A: Diagnostic First (Recommended)
**Steps**:
1. Add unique debug logging to Main.lua and BuildList.lua with timestamp
2. Launch app, capture logs
3. Verify which version of code is executing
4. If old code → clean rebuild
5. If new code but wrong behavior → investigate transform chain

**Pros**: Identifies exact problem before making changes
**Cons**: Takes extra time for diagnosis

#### Option B: Force Clean Rebuild
**Steps**:
1. `pkill -9 PathOfBuilding`
2. `rm -rf PathOfBuilding.app`
3. Rebuild from source
4. Verify all files synced
5. Test

**Pros**: Guaranteed clean state
**Cons**: If not the issue, wasted rebuild time

#### Option C: Manual Coordinate Override
**Steps**:
1. Bypass screenScale entirely
2. Hardcode BuildList anchor to fixed pixel position (e.g., x=450)
3. Test if position changes
4. If yes → coordinate transform is broken
5. If no → rendering/display issue

**Pros**: Quick test of coordinate system
**Cons**: Not a real fix

---

## Implementation Steps (Option A: Diagnostic Approach)

### Step 1: Add Diagnostic Logging (5 min)
**Who**: Implementation agent
**Action**:
- Main.lua: Add `ConPrintf("MAIN.LUA VERSION: 2026-02-06-1935")`
- BuildList.lua: Add `print("BUILDLIST.LUA VERSION: 2026-02-06-1935")`
- BuildList.lua anchor.x: Keep existing debug log

**Deliverable**: Unique version strings in code

### Step 2: Launch and Capture Logs (5 min)
**Who**: Testing agent
**Action**:
- `open PathOfBuilding.app`
- Wait for UI to appear
- Capture logs: `tail -100 passive_tree_app.log`
- Search for version strings

**Deliverable**: Log output showing which code version is running

### Step 3: Analyze Results (5 min)
**Who**: Analysis agent
**Action**:
- If version strings NOT found → **Root cause = Caching** → Go to Step 4a
- If version strings found AND anchor.x debug shows wrong value → **Root cause = Coordinate transform** → Go to Step 4b
- If version strings found AND anchor.x correct → **Root cause = Rendering** → Go to Step 4c

**Deliverable**: Confirmed root cause

### Step 4a: Clean Rebuild (if caching) (10 min)
**Who**: Implementation agent
**Action**:
1. `pkill -9 PathOfBuilding`
2. Backup current app: `mv PathOfBuilding.app PathOfBuilding.app.bak`
3. Rebuild: (depends on build system - NEED TO CLARIFY)
4. Verify all files synced
5. Retest

**Deliverable**: Clean app bundle with verified code

### Step 4b: Fix Coordinate Transform (if transform broken) (15 min)
**Who**: Implementation agent
**Action**:
- Add logging at each transform stage:
  - GetScreenSize() output
  - screenScale value
  - anchor.x calculation
  - Draw function input coordinates
  - Draw function output (scaled) coordinates
- Identify where transform breaks
- Apply fix

**Deliverable**: Fixed coordinate transform chain

### Step 4c: Investigate Rendering (if rendering issue) (20 min)
**Who**: Analysis agent
**Action**:
- Check Metal layer configuration
- Verify contentsScale is applied
- Check drawable size vs window size
- Review NDC coordinate conversion in Metal backend

**Deliverable**: Rendering issue identified and fixed

### Step 5: Visual Verification (5 min)
**Who**: Testing agent
**Action**:
- Launch app
- Take screenshot
- Verify BuildList position and size
- User approval

**Deliverable**: Screenshot showing correct UI

---

## Timeline

| Step | Task | Duration | Cumulative |
|------|------|----------|------------|
| 1 | Add diagnostic logging | 5 min | 5 min |
| 2 | Launch and capture logs | 5 min | 10 min |
| 3 | Analyze results | 5 min | 15 min |
| 4a/b/c | Apply fix (depends on root cause) | 10-20 min | 25-35 min |
| 5 | Visual verification | 5 min | 30-40 min |

**Total Estimated Time**: 30-40 minutes
**Timebox Limit**: 60 minutes (hard stop)

---

## Risk Assessment

### Potential Failure Modes
1. **Caching persists after rebuild** → Mitigation: Clear all app caches, restart macOS
2. **Multiple issues layered** → Mitigation: Fix one at a time, retest each
3. **Fundamental Metal rendering bug** → Mitigation: Revert to simpler rendering approach

### Rollback Strategy
**If fix fails**:
1. Restore `PathOfBuilding.app.bak`
2. Document findings in `contexterror_buildlist_fix_failed.md`
3. Escalate to user for alternative approach decision

### Impact on Existing Functionality
- **Low risk**: Changes are diagnostic-only in Step 1-3
- **Medium risk**: Coordinate transform changes in Step 4b
- **Critical backup**: Keep `.bak` of working app bundle

---

## Success Criteria

### Visual Verification ✅
- BuildList appears on LEFT side of screen (not center)
- BuildList width approximately 1/2 of screen width (not tiny)
- All buttons visible and properly positioned
- Text readable and properly scaled
- User confirms "looks correct"

### Log-Level Checks ✅
- `main.screenW = 1792` (論理ピクセル)
- `main.screenScale = 2.0`
- `anchor.x = 896` (1792 / 2)
- No Lua errors
- DrawString coordinates in logical pixel space (e.g., 100-1700 range)

### Deliverables ✅
- Screenshot showing correct UI
- Log output confirming correct coordinate values
- Updated contexterror file with resolution
- MEMORY.md updated with lessons learned

---

## Role Assignments

- **Analysis Agent (Investigator)**: Analyze logs, identify root cause, guide fix selection
- **Implementation Agent (Coder)**: Add logging, apply fixes, rebuild if needed
- **Testing Agent (Verifier)**: Launch app, capture logs, take screenshots, verify results
- **Review Agent (Quality)**: Verify fix doesn't break existing functionality, check rollback readiness

---

## Notes

**Critical Success Factor**: Identify EXACT point where change is not taking effect (cache vs code vs rendering)

**If diagnostic shows old code is running**: This is app caching issue, clean rebuild required

**If diagnostic shows new code but wrong behavior**: This is logic/coordinate issue, deeper investigation needed

**Remember**: Visual verification is mandatory - logs can be correct while UI is broken
