# Phase 5: Tooltip 再有効化機能 - Implementation Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet
**ステータス**: Planning - Awaiting Approval

---

## 1. Current Observations

### ✅ What Works (Phase 4完了)
- アセンダンシークリック機能（Phase 3）
- 通常ノード割り当て/解除機能（Phase 4）
- MINIMAL モードでの基本的なツリー操作

### ❌ What's Disabled
- **Tooltip 機能**: Line 1256 で `if false` により完全に無効化
- コメント: "MINIMAL mode: Tooltip disabled to prevent crashes"
- コメント: "TODO: Re-enable after fixing all tooltip dependencies"

### 🔍 Known Code Locations
- **PassiveTreeView.lua line 1254-1268**: Tooltip 描画コード（無効化中）
- **PassiveTreeView.lua line 31**: `self.tooltip = new("Tooltip")` 初期化
- **AddNodeTooltip method**: Tooltip 内容生成メソッド

---

## 2. Proposed Solution

### Option A: 段階的 Tooltip 再有効化（RECOMMENDED）

**Strategy**:
1. Sage が Tooltip 関連コードと依存関係を分析
2. MINIMAL モード用の最小限の Tooltip を実装
3. 段階的にテスト（まずシンプルなノード、次に複雑なノード）
4. 必要に応じて nil ガードを追加

**Why This Approach**:
- Phase 3, 4 で確立した nil ガードパターンを適用
- 消去法デバッグを準備（クラッシュ時に使用）
- MINIMAL モードの制約を理解した実装

**Technical Details**:
```lua
-- Line 1256 を修正
-- Before: if false and node == hoverNode and ...
-- After: if _G.MINIMAL_PASSIVE_TEST and node == hoverNode and ...

-- AddNodeTooltip で MINIMAL mode 対応
function PassiveTreeViewClass:AddNodeTooltip(tooltip, node, build, incSmallPassiveSkillEffect)
    -- MINIMAL mode: Skip complex calculations
    if _G.MINIMAL_PASSIVE_TEST then
        -- Minimal tooltip: node name + basic info only
        tooltip:AddLine(20, node.dn or "Unknown Node")
        if node.sd and #node.sd > 0 then
            for _, line in ipairs(node.sd) do
                tooltip:AddLine(16, "^7" .. line)
            end
        end
        return
    end
    -- ... Full tooltip logic for non-MINIMAL mode
end
```

**Integration with Phase 3/4 Learnings**:
- Tooltip 内部で modList アクセスがあれば nil ガード追加
- build.treeTab や build.itemsTab へのアクセスを MINIMAL mode でスキップ
- 消去法でクラッシュ箇所を特定する準備

---

## 3. Implementation Steps

### Step 1: Code Analysis (Sage) - 15 minutes
**Deliverable**: Analysis document answering:
1. AddNodeTooltip メソッドはどこで何をしているか？
2. Tooltip クラスの依存関係は何か？
3. modList, build.treeTab, build.itemsTab へのアクセスはあるか？
4. MINIMAL mode で安全に実装できる最小限の Tooltip は何か？

**Dependencies**: None
**Risk**: Low - read-only analysis

---

### Step 2: MINIMAL Tooltip Implementation (Artisan) - 20 minutes
**Deliverable**: Modified PassiveTreeView.lua:
1. Line 1256: `if false` → `if _G.MINIMAL_PASSIVE_TEST` に変更
2. AddNodeTooltip: MINIMAL mode 分岐を追加
3. 必要に応じて nil ガードを追加

**Dependencies**: Step 1 completion
**Risk**: Medium - code modification

**Implementation Pattern (from Phase 3/4)**:
```lua
// Pattern 1: MINIMAL mode simple tooltip
if _G.MINIMAL_PASSIVE_TEST then
    tooltip:AddLine(20, node.dn or "Unknown")
    -- Skip complex calculations
    return
end

// Pattern 2: Full tooltip with guards
if build.calcsTab and build.calcsTab.mainOutput then
    -- Full tooltip logic
end
```

---

### Step 3: File Synchronization (Artisan) - 5 minutes
**Deliverable**: Files synced to app bundle
```bash
cp PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
diff PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua
```

**Dependencies**: Step 2 completion
**Risk**: Low - proven process from Phase 3, 4

---

### Step 4: Initial Testing (User) - 10 minutes
**Test Scenarios**:
1. ✅ ノードにホバー → Tooltip 表示
2. ✅ Tooltip にノード名が表示される
3. ✅ Tooltip に mod 情報が表示される
4. ✅ クラッシュしない

**Success Criteria**:
- ノードホバー時に Tooltip が表示される
- Tooltip にノード名と基本情報が含まれる
- アプリがクラッシュしない

**If Crash Occurs**: Apply Phase 3/4 elimination method
1. ファイルログで最後の実行箇所を確認
2. 詳細ログを追加してクラッシュ箇所を特定
3. nil ガードを追加または該当コードをスキップ

**Dependencies**: Step 3 completion
**Risk**: Medium - may reveal crashes

---

### Step 5: Code Quality Review (Paladin) - 10 minutes
**Deliverable**: Quality checklist
- ✅ All modList accesses guarded?
- ✅ All build.* accesses guarded?
- ✅ MINIMAL mode path clearly separated?
- ✅ LuaJIT 5.1 compatibility?

**Dependencies**: Step 4 completion (successful test)
**Risk**: Low - review only

---

## 4. Timeline

| Step | Duration | Cumulative |
|------|----------|------------|
| 1. Code Analysis | 15 min | 15 min |
| 2. MINIMAL Tooltip Implementation | 20 min | 35 min |
| 3. File Sync | 5 min | 40 min |
| 4. Testing | 10 min | 50 min |
| 5. Quality Review | 10 min | 60 min |

**Total Estimated Time**: 60 minutes (1 hour)
**Timebox Limit**: 90 minutes (if crashes require elimination method)

---

## 5. Risk Assessment

### Risk 1: AddNodeTooltip crashes with modList nil (MEDIUM)
**Likelihood**: Medium (same pattern as Phase 3, 4)
**Impact**: High (blocks feature)
**Mitigation**: Apply modList nil guard pattern from Phase 3
**Rollback**: Revert to `if false`, keep Tooltip disabled

### Risk 2: Tooltip requires build.calcsTab (MEDIUM)
**Likelihood**: Medium (Tooltip may need calculations)
**Impact**: Medium (cannot show full tooltip info)
**Mitigation**: MINIMAL mode shows minimal info only
**Rollback**: Skip calculation-dependent parts

### Risk 3: Tooltip rendering crashes (LOW)
**Likelihood**: Low (Tooltip class likely stable)
**Impact**: Medium (visual glitch or crash)
**Mitigation**: Wrap Tooltip:Draw in pcall for testing
**Rollback**: Revert Tooltip re-enablement

### Risk 4: File sync failure (LOW)
**Likelihood**: Very Low (proven process)
**Impact**: Low (changes not applied)
**Mitigation**: diff verification after copy
**Rollback**: Re-copy files, verify with diff

---

## 6. Success Criteria

### Visual Verification
- ✅ **Hover over unallocated node** → Tooltip appears with node name
- ✅ **Tooltip shows mod descriptions** → Basic mod info visible
- ✅ **Hover over allocated node** → Tooltip appears
- ✅ **Application remains stable** → No crashes during hover

### Log Verification (if DEBUG enabled)
- ✅ "Tooltip rendering" appears (if logged)
- ✅ No ERROR lines in log
- ✅ No nil access errors

### Code Quality
- ✅ All modList accesses have nil guards
- ✅ All build.* accesses have nil guards or MINIMAL mode skip
- ✅ LuaJIT 5.1 compatible code only
- ✅ No breaking changes to full app mode

---

## 7. Deliverable Checklist

- [ ] Sage analysis document created
- [ ] Artisan implementation completed
- [ ] Files synced to app bundle (diff verified)
- [ ] User testing successful (4/4 scenarios passed)
- [ ] Paladin quality review completed
- [ ] DEBUG logging removed or reduced (if added)
- [ ] LESSONS_LEARNED.md updated with Phase 5 results
- [ ] Phase 5 marked as complete

---

## 8. Rollback Strategy

**If Phase 5 fails completely**:
1. Revert PassiveTreeView.lua line 1256 to `if false`
2. Revert any AddNodeTooltip changes
3. Sync reverted files to app bundle
4. Verify Phase 3, 4 functionality still works
5. Document failure in contexterror file
6. Re-plan with new approach

**Rollback Commands**:
```bash
git checkout PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua
cp PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
```

---

## 9. Next Phase Preview

**After Phase 5 Success**:
- Phase 6: Search functionality (find nodes by name/mod)
- Phase 7: Zoom/pan improvements
- Phase 8: DEBUG log cleanup

---

**Plan Status**: ✅ Complete - Ready for Review
