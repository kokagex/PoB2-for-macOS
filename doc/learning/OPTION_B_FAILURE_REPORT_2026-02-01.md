# Option B Failure Report - Metal Fragment Shader Fix
**Date**: 2026-02-01 21:20
**Status**: ❌ **FAILED**
**Implemented**: Option B (Heuristic 完全削除)
**Result**: DrawImage() still broken - images not visible

---

## Executive Summary

Sage が推奨した Option B (Heuristic 完全削除) を実装したが、**DrawImage() は依然として動作せず**。

**Visual Verification Result**:
- ✅ DrawString() 動作 (テキスト表示OK)
- ❌ DrawImage() 動作せず (画像表示NG)
- ⚠️ 左上に「瞬間的に何かが表示」されるが判別不可能

**Sage の予測**: 99% 成功確率
**実際の結果**: 0% - 完全失敗

---

## 実装内容

### Applied Fix (Option B)

**File**: `pob2macos/dev/simplegraphic/src/backend/metal/metal_backend.mm`

**削除した Heuristic** (lines 119-124):
```glsl
if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
    float alpha = texColor.r;
    return float4(in.color.rgb, alpha * in.color.a);
}
```

**新しい実装**:
```glsl
// Direct RGBA rendering - works for both R8 and RGBA textures
return texColor * in.color;
```

---

## Visual Verification Evidence

### Test Setup
- **Duration**: 20 seconds
- **Window Size**: 1440x810
- **Background**: Blue
- **Text**: White/Yellow (visible)
- **Image**: Ring.png (1024x1024, RGBA) - 400x400 pixels at position (400, 300)

### Test Results

**Screenshot**: `/Users/kokage/Desktop/スクリーンショット 2026-02-01 21.18.13.png`

**What God Saw**:
- ✅ Blue background - clearly visible
- ✅ Text (red, white) - clearly visible in upper left
- ❌ Ring image - **NOT visible**
- ⚠️ Something "flickering" in upper left, but **indiscernible**

**God's Exact Words**:
> "左上に何かがチラチラうつっていますがリングではありません"
> "瞬間的に何かが表示されているのだけはわかりますがそれが何かは神の目では判別不可能です"

Translation: "Something is flickering in the upper left, but it's not a ring. Something is being displayed momentarily but it's impossible to see what it is."

---

## Technical Analysis

### Why Did Option B Fail?

**Sage's Assumption**:
> "R8Unorm textures are sampled as float4(R, 0, 0, 1), making the heuristic unnecessary."

**Reality Check**: This assumption may be incorrect for our Metal implementation.

### Possible Root Causes

#### Hypothesis 1: R8 Texture Sampling Issue
- Metal might NOT be sampling R8 as `float4(R, 0, 0, 1)`
- Our texture creation might be setting up R8 differently
- Need to verify actual texture format at runtime

#### Hypothesis 2: Vertex Color Multiplication Issue
- `texColor * in.color` might be zeroing out the image
- If `in.color` is incorrect (e.g., alpha = 0), image becomes invisible
- Need to check vertex color values

#### Hypothesis 3: Texture Binding Issue
- RGBA textures might not be binding correctly
- Texture array indexing might be wrong
- Need to verify texture array layer selection

#### Hypothesis 4: Alpha Blending Issue
- Blend mode might be incorrect
- Alpha premultiplication issue
- Need to check Metal blend state configuration

#### Hypothesis 5: Wrong Root Cause
- Original diagnosis was incorrect
- Problem is NOT in fragment shader at all
- Problem might be in:
  - Texture loading (C++ layer)
  - Texture array creation
  - Vertex data (texCoord.z for layer index)
  - Render pipeline state

---

## Debug Evidence from Logs

```
DEBUG: [Frame 0] metal_draw_image #0 - handle=0x6000039dc600,
  pos=(400.0,300.0),
  size_in=(400.0,400.0),
  size_draw=(400.0,400.0),
  tc_in=(0.000,0.000,1.000,1.000),
  tc_use=(0.000,0.000,1.000,1.000),
  color=(1.00,1.00,1.00,1.00),
  tex=IMAGE
```

**Analysis**:
- Position: (400, 300) - Should be visible in upper-left area ✅
- Size: 400x400 - Large enough to see ✅
- Texture coords: (0,0,1,1) - Full texture coverage ✅
- Color: (1,1,1,1) - White, full opacity ✅
- Texture type: IMAGE (not GLYPH) ✅

**Conclusion**: Draw command parameters are correct, but image is still not visible.

---

## What We Know

### Working ✅
1. DrawString() renders text correctly
2. Metal shader compiles without errors
3. Texture loads successfully (1024x1024)
4. Metal draw commands execute
5. Metal presents drawables

### Not Working ❌
1. DrawImage() does not show visible images
2. Only "flickering" visible, not actual image
3. Image content is indiscernible

### Unknown ❓
1. What is the "flickering" in upper left?
2. Is ANY image data reaching the fragment shader?
3. Is the texture actually bound to the shader?
4. What is the actual fragment shader output?

---

## Next Steps Required

### Immediate: Deep Debugging

Need to add extensive debug logging to fragment shader:

```glsl
fragment float4 fragment_main(...) {
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));

    // DEBUG: Output texture color directly (ignore vertex color)
    return texColor;

    // If this shows image: problem is in vertex color multiplication
    // If this still shows nothing: problem is in texture sampling
}
```

### Investigation Areas

1. **Texture Array Verification**:
   - Is texture actually in array at correct layer?
   - Is layer index (texCoord.z) correct?
   - Can we sample texture at all?

2. **Vertex Color Inspection**:
   - What is actual `in.color` value?
   - Is it (1,1,1,1) as expected?
   - Could it be (0,0,0,0) causing invisibility?

3. **Fragment Shader Output**:
   - What is actual `float4` output from shader?
   - Is it (0,0,0,0) [transparent]?
   - Is it correct RGBA values?

4. **Texture Format Verification**:
   - What is actual MTLPixelFormat of loaded texture?
   - Is it RGBA8Unorm as expected?
   - How does Metal sample this format?

---

## Lessons Learned

### Critical Error: Over-Confidence

**Sage's Verdict**: 99% success probability, 95% confidence
**Reality**: 0% success - complete failure

**Lesson**: Never trust theoretical analysis without empirical verification.

### Critical Error: Insufficient Testing

**What We Did**: Applied fix, tested once
**What We Should Have Done**:
1. Test original theory (R8 sampling as float4(R,0,0,1))
2. Verify texture format at runtime
3. Test intermediate states (shader output directly)

### Critical Error: Wrong Root Cause?

**Original Diagnosis**: Fragment shader heuristic is the problem
**Possible Reality**: Problem might be elsewhere entirely

**Lesson**: Root cause analysis was possibly incorrect. Need deeper investigation.

---

## Risk Assessment

**Current State**:
- DrawString() works ✅
- DrawImage() broken ❌
- No progress from original failure state

**Rollback Impact**:
- Rollback to original heuristic: No improvement (images were already broken)
- Keep Option B: No regression (already broken)

**Recommendation**: **DO NOT ROLLBACK**
- Option B is theoretically cleaner
- Problem is deeper than fragment shader heuristic
- Need to investigate actual root cause

---

## Required Action

### Phase 1: Root Cause Re-Investigation

**Assign**: Explorer (Heroic Agent) - Root cause investigation specialist

**Task**: Deep dive into Metal rendering pipeline to find TRUE root cause:
1. Verify texture array creation
2. Verify texture binding to shader
3. Verify fragment shader is receiving texture data
4. Verify vertex color values
5. Verify alpha blending configuration

### Phase 2: Incremental Debugging

Create minimal test shaders that output:
1. Pure red: `return float4(1,0,0,1);` - Verify shader runs
2. Texture color raw: `return texColor;` - Verify texture sampling
3. Vertex color only: `return in.color;` - Verify vertex data
4. Alpha channel: `return float4(texColor.a);` - Verify alpha

### Phase 3: Expert Consultation

Need Metal API expert (MetalSpecialist if available, or external research) to verify:
- How does Metal actually sample R8Unorm textures?
- What is correct way to handle texture arrays with mixed formats?
- What could cause "flickering" but invisible images?

---

## Status

**Failure Confirmed**: ✅
**Root Cause Identified**: ❌ (original diagnosis likely incorrect)
**Next Action**: Deep investigation required
**Escalation**: Prophet must create new investigation plan

---

**Report Status**: COMPLETE
**Severity**: CRITICAL
**Impact**: DrawImage() completely non-functional
**User Impact**: Cannot display passive tree or any images
