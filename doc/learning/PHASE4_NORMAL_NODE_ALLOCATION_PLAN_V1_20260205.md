# Phase 4: 通常パッシブノード割り当て機能 - Implementation Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet
**ステータス**: Planning - Awaiting Approval

---

## 1. Current Observations

### ✅ What Works (Phase 3完了)
- アセンダンシー開始ノードクリック → クラス切り替え正常動作
- アセンダンシー通常ノードクリック → クラス切り替え正常動作
- modList nil ガードパターン確立（4箇所で適用済み）

### ❓ What Needs Investigation
- 通常パッシブノード（クラス/アセンダンシー以外）のクリック挙動
- 既存の AllocNode() メソッドの動作
- パス接続検証（孤立ノードの防止）の実装状況

### 🔍 Known Code Locations
- **PassiveTreeView.lua**: LEFT click handler (lines ~390-570)
- **PassiveSpec.lua**: AllocNode() method
- **PassiveTreeView.lua**: hoverNode.path check (line ~553)

---

## 2. Proposed Solution

### Option A: Minimal Investigation + Targeted Guards (RECOMMENDED)

**Strategy**:
1. Sage が既存コード（LEFT click handler, AllocNode）を分析
2. MINIMAL モードで必要なガードを特定
3. Artisan が modList nil ガード パターンを適用
4. 段階的テスト（1つのノードクリック → 複数ノードクリック）

**Why This Approach**:
- Phase 3 で確立した modList ガードパターンを再利用
- 消去法デバッグ手法を準備（クラッシュ時に適用）
- 既存コードを最大限活用（車輪の再発明を避ける）

**Technical Details**:
```lua
// Expected click flow for normal nodes:
if hoverNode.path and not shouldBlockGlobalNodeAllocation(hoverNode) then
    // Line ~553-565: Normal node allocation logic
    spec:AllocNode(hoverNode, ...)  // ← Needs investigation
    spec:AddUndoState()
    build.buildFlag = true
end
```

**Integration with Phase 3 Learnings**:
- AllocNode() 内で modList アクセスがあれば nil ガード追加
- BuildAllDependsAndPaths() 呼び出しは既にガード済み（Phase 3）
- 同じ消去法パターン: DEBUG ログ → クラッシュ特定 → ガード追加

---

## 3. Implementation Steps

### Step 1: Code Analysis (Sage) - 15 minutes
**Deliverable**: Analysis document answering:
1. Where is normal node LEFT click handled in PassiveTreeView.lua?
2. What does AllocNode() method do?
3. What are the modList access points in AllocNode()?
4. Are there path validation checks?

**Dependencies**: None
**Risk**: Low - read-only analysis

---

### Step 2: Guard Implementation (Artisan) - 20 minutes
**Deliverable**: Modified files with guards applied:
1. PassiveTreeView.lua: Add DEBUG logging around normal node click
2. PassiveSpec.lua: Add modList nil guards in AllocNode()
3. Verify no other modList accesses in click flow

**Dependencies**: Step 1 completion
**Risk**: Medium - code modification

**Implementation Pattern (from Phase 3)**:
```lua
// Pattern 1: modList access guard
if node.modList then
    node.modList:Sum(...)
end

// Pattern 2: node existence guard
if not node1 or not node2 then
    return
end

// Pattern 3: DEBUG logging for elimination
ConPrintf("DEBUG: About to call AllocNode")
spec:AllocNode(hoverNode, ...)
ConPrintf("DEBUG: AllocNode completed")
```

---

### Step 3: File Synchronization (Artisan) - 5 minutes
**Deliverable**: Files synced to app bundle
```bash
cp src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
cp src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
diff src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua
```

**Dependencies**: Step 2 completion
**Risk**: Low - proven process from Phase 3

---

### Step 4: Initial Testing (User) - 10 minutes
**Test Scenarios**:
1. ✅ Click normal passive node (non-allocated)
2. ✅ Click allocated normal node (deallocate)
3. ✅ Verify node visual state changes
4. ✅ Check for crashes

**Success Criteria**:
- No crashes on normal node click
- Nodes change visual state (allocated ↔ unallocated)
- DEBUG logs show AllocNode() completing

**If Crash Occurs**: Apply Phase 3 elimination method
1. Check last DEBUG log line
2. Add more granular logs in crash section
3. Identify exact crash line
4. Add nil guard or skip problematic code

**Dependencies**: Step 3 completion
**Risk**: Medium - may reveal new crashes

---

### Step 5: Code Quality Review (Paladin) - 10 minutes
**Deliverable**: Quality checklist
- ✅ All modList accesses guarded?
- ✅ Edge cases considered (nil paths, invalid nodes)?
- ✅ LuaJIT 5.1 compatibility?
- ✅ No breaking changes to full app?

**Dependencies**: Step 4 completion (successful test)
**Risk**: Low - review only

---

## 4. Timeline

| Step | Duration | Cumulative |
|------|----------|------------|
| 1. Code Analysis | 15 min | 15 min |
| 2. Guard Implementation | 20 min | 35 min |
| 3. File Sync | 5 min | 40 min |
| 4. Testing | 10 min | 50 min |
| 5. Quality Review | 10 min | 60 min |

**Total Estimated Time**: 60 minutes (1 hour)
**Timebox Limit**: 90 minutes (if crashes require elimination method)

---

## 5. Risk Assessment

### Risk 1: AllocNode() crashes with modList nil (MEDIUM)
**Likelihood**: Medium (same pattern as Phase 3)
**Impact**: High (blocks feature)
**Mitigation**: Apply modList nil guard pattern from Phase 3
**Rollback**: Remove guards, revert to Phase 3 state

### Risk 2: Path validation fails in MINIMAL mode (MEDIUM)
**Likelihood**: Medium (path calculation may need full infrastructure)
**Impact**: Medium (孤立ノード防止が効かない)
**Mitigation**: Skip path validation in MINIMAL mode, or add guards
**Rollback**: Disable path validation for MINIMAL mode

### Risk 3: New crash locations discovered (LOW)
**Likelihood**: Low (Phase 3 fixed most modList issues)
**Impact**: Medium (requires elimination debugging)
**Mitigation**: Apply Phase 3 elimination method (proven effective)
**Rollback**: Document crash, apply next iteration of guards

### Risk 4: File sync failure (LOW)
**Likelihood**: Very Low (proven process)
**Impact**: Low (修正が反映されない)
**Mitigation**: diff verification after copy
**Rollback**: Re-copy files, verify with diff

---

## 6. Success Criteria

### Visual Verification
- ✅ **Click unallocated normal node** → Node becomes highlighted/allocated
- ✅ **Click allocated normal node** → Node becomes unhighlighted/unallocated
- ✅ **Click multiple connected nodes** → Path visually highlighted
- ✅ **Application remains stable** → No crashes after multiple clicks

### Log Verification
- ✅ "DEBUG: About to call AllocNode" appears
- ✅ "DEBUG: AllocNode completed" appears
- ✅ No ERROR lines in log
- ✅ No nil access errors

### Code Quality
- ✅ All modList accesses have nil guards
- ✅ LuaJIT 5.1 compatible code only
- ✅ No breaking changes to full app mode

---

## 7. Deliverable Checklist

- [ ] Sage analysis document created
- [ ] Artisan implementation completed
- [ ] Files synced to app bundle (diff verified)
- [ ] User testing successful (4/4 scenarios passed)
- [ ] Paladin quality review completed
- [ ] DEBUG logging removed or reduced
- [ ] LESSONS_LEARNED.md updated with Phase 4 results
- [ ] Phase 4 marked as complete

---

## 8. Rollback Strategy

**If Phase 4 fails completely**:
1. Revert all PassiveTreeView.lua changes
2. Revert all PassiveSpec.lua changes
3. Sync reverted files to app bundle
4. Verify Phase 3 functionality still works (アセンダンシークリック)
5. Document failure in contexterror file
6. Re-plan with new approach

**Rollback Commands**:
```bash
git checkout src/Classes/PassiveTreeView.lua
git checkout src/Classes/PassiveSpec.lua
cp src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
cp src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
```

---

## 9. Next Phase Preview

**After Phase 4 Success**:
- Phase 5: Tooltip re-enablement (currently disabled at line 1207)
- Phase 6: Search functionality
- Phase 7: Zoom/pan improvements

---

**Plan Status**: ✅ Complete - Ready for Review
