# Text Input Visibility Fix (Color Table) - Plan V1

**Date**: 2026-02-10
**Task**: Ensure text input is visible by enforcing PoB standard color table in SimpleGraphic

---

## 1. Root Cause Analysis

### Symptoms
- UI is stable.
- Text input is processed (OnChar events fire, EditControl buffer updates), but user reports input not visible.

### Hypothesis (selected option)
- **Runtime SimpleGraphic uses an outdated color table** where `^7` is too dark on dark backgrounds, making input appear invisible.

### Evidence
- Lua debug shows `EditControl:OnChar` and buffer updates.
- This suggests display/visibility rather than input pipeline failure.

---

## 2. Proposed Solution

### Strategy
Rebuild SimpleGraphic with the **PoB standard color table** (ensuring `^7` = white) and deploy the updated dylib to the app bundle.

### Technical Details
- Verify `simplegraphic/src/rendering/sg_text.cpp` color table.
- Rebuild and replace:
  - `PathOfBuilding.app/Contents/Resources/runtime/SimpleGraphic.dylib`
  - `PathOfBuilding.app/Contents/Resources/runtime/libSimpleGraphic.dylib`

---

## 3. Implementation Steps

1. **Backup current runtime dylib** (outside app bundle):
   - Copy current `SimpleGraphic.dylib` to `/tmp/SimpleGraphic.dylib.backup_20260210`.
2. **Rebuild SimpleGraphic**:
   - `cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal`
   - `make -C build`
3. **Deploy dylib to app bundle**:
   - Copy `build/libSimpleGraphic.dylib` to runtime `SimpleGraphic.dylib` and `libSimpleGraphic.dylib`.
4. **User verification**:
   - Launch app and type into search fields.
   - Confirm text is visible.

---

## 4. Timeline
- Rebuild + deploy: 10–20 minutes
- Verification: 5 minutes

Total: ~25 minutes

---

## 5. Risk Assessment

- **Risk**: Low (color table constants only).
- **Mitigation**: External backup and quick rollback.

### Rollback
- Restore from `/tmp/SimpleGraphic.dylib.backup_20260210`.

---

## 6. Success Criteria

1. Search/build name input text is visible while typing.
2. No UI regressions.
3. No logs generated inside app bundle.

