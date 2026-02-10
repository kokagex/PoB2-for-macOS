# Deep Investigation Plan - DrawImage() Failure
**Date**: 2026-02-01 21:30
**Prophet**: Claude Sonnet 4.5
**Status**: Option B FAILED - Root cause re-investigation required
**Crisis**: DrawImage() still completely broken after shader fix

---

## Executive Summary

**Problem**: Option B (Heuristic削除) を実装したが、DrawImage() は依然として動作せず。

**Critical Finding**: 神が「瞬間的に何かが表示されているが判別不可能」と報告
- これは SOME rendering が発生していることを示唆
- しかし正しく表示されていない

**Conclusion**: Fragment shader heuristic が根本原因ではない可能性が高い

---

## Option B Failure Analysis

### What We Expected
- Heuristic削除により、RGBA images が正しく表示される
- R8 glyphs も引き続き動作する (Metal API spec による)

### What Actually Happened
- ❌ Images still NOT visible
- ✅ Text still works
- ⚠️ "Something flickering" in upper left corner

### Why Sage's Analysis Was Wrong

**Sage's Core Assumption**:
> "Metal API spec: R8Unorm は float4(R, 0, 0, 1) として sample される"

**Problem**: This assumption was NOT verified empirically in OUR implementation.

**Lesson**: Never trust theoretical analysis without testing.

---

## Systematic Debugging Plan

### Phase 1: Minimal Fragment Shader Tests (Sage)

**Purpose**: Isolate the problem using minimal test shaders

**Assigned**: Sage (Metal API specialist)

**Tests**:

#### Test 1: Pure Color Output
```glsl
fragment float4 fragment_main(...) {
    return float4(1.0, 0.0, 0.0, 1.0);  // Pure red
}
```
**Expected**: Entire screen red
**If FAILS**: Fragment shader not running at all

#### Test 2: Vertex Color Only
```glsl
fragment float4 fragment_main(VertexOut in [[stage_in]], ...) {
    return in.color;
}
```
**Expected**: Color from vertex (should be white 1,1,1,1)
**If FAILS**: Vertex data not reaching shader

#### Test 3: Texture Color Raw (No Vertex Multiplication)
```glsl
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d_array<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    float4 texColor = tex.sample(sam, in.texCoord.xy, uint(in.texCoord.z));
    return texColor;  // No multiplication with in.color
}
```
**Expected**: Image visible if texture sampling works
**If FAILS**: Texture not bound, or layer index wrong

#### Test 4: Texture Alpha Channel
```glsl
fragment float4 fragment_main(...) {
    float4 texColor = tex.sample(...);
    float alpha = texColor.a;
    return float4(alpha, alpha, alpha, 1.0);  // Visualize alpha as grayscale
}
```
**Expected**: Grayscale image showing alpha channel
**If FAILS**: Alpha channel is 0 (transparent)

#### Test 5: Texture Coordinates Visualization
```glsl
fragment float4 fragment_main(VertexOut in [[stage_in]], ...) {
    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
}
```
**Expected**: Gradient showing UV mapping
**If FAILS**: Texture coordinates are wrong

---

### Phase 2: C++ Layer Investigation (Artisan + Sage)

**Purpose**: Verify texture creation and binding

**Assigned**: Artisan (read C++ code), Sage (analyze)

**Investigation Areas**:

#### 2.1 Texture Creation Verification
**File**: `metal_backend.mm` lines 455-472

**Questions**:
1. Is RGBA texture actually created as MTLPixelFormatRGBA8Unorm?
2. Is texture successfully added to texture array?
3. Is layer index correctly tracked?
4. Are mipmaps generated correctly?

**Debug Points**:
```objc
NSLog(@"Texture created: format=%ld, width=%d, height=%d, layers=%ld",
      (long)texture.pixelFormat, width, height, (long)textureArray.arrayLength);
```

#### 2.2 Texture Binding Verification
**File**: `metal_backend.mm` render encoding section

**Questions**:
1. Is texture array bound to fragment shader slot 0?
2. Is sampler correctly configured?
3. Is texture array non-nil at render time?

**Debug Points**:
```objc
NSLog(@"Binding texture array: %@, layer count: %ld",
      textureArray, (long)textureArray.arrayLength);
```

#### 2.3 Vertex Data Verification
**File**: Vertex buffer creation

**Questions**:
1. Is texCoord.z (layer index) set correctly?
2. Is in.color set to (1,1,1,1) for images?
3. Are vertex positions correct?

---

### Phase 3: Render State Investigation (Sage)

**Purpose**: Check Metal render pipeline state

**Assigned**: Sage

**Investigation Areas**:

#### 3.1 Blend Mode
```objc
// Check current blend mode
colorAttachment.blendingEnabled = ?
colorAttachment.sourceRGBBlendFactor = ?
colorAttachment.destinationRGBBlendFactor = ?
colorAttachment.sourceAlphaBlendFactor = ?
colorAttachment.destinationAlphaBlendFactor = ?
```

**Question**: Is alpha blending configured correctly?

#### 3.2 Render Pipeline State
```objc
// Check pipeline configuration
pipelineStateDescriptor.colorAttachments[0].pixelFormat = ?
pipelineStateDescriptor.depthAttachmentPixelFormat = ?
```

**Question**: Does pipeline state match framebuffer?

---

### Phase 4: Hypothesis Testing

Based on minimal tests, identify root cause from:

#### Hypothesis A: Texture Not Bound
**Symptom**: Test 3 shows black/nothing
**Root Cause**: Texture array not actually bound to shader
**Fix**: Fix texture binding code in C++

#### Hypothesis B: Wrong Layer Index
**Symptom**: Test 3 shows black, but Test 1-2 work
**Root Cause**: texCoord.z incorrect (accessing empty layer)
**Fix**: Fix layer index tracking in C++

#### Hypothesis C: Vertex Color is Zero
**Symptom**: Test 2 shows black, Test 3 shows image
**Root Cause**: in.color is (0,0,0,0), multiplying zeroes out image
**Fix**: Set vertex color to (1,1,1,1) for images

#### Hypothesis D: Alpha Channel is Zero
**Symptom**: Test 4 shows black
**Root Cause**: Image loading sets alpha to 0
**Fix**: Fix image loading to preserve alpha channel

#### Hypothesis E: Blend Mode Wrong
**Symptom**: Tests show image briefly (flickering)
**Root Cause**: Blend mode discarding image after first frame
**Fix**: Fix blend mode configuration

---

## Implementation Strategy

### Step 1: Run Minimal Tests (Sage)
- Implement Tests 1-5 sequentially
- Record which tests PASS and which FAIL
- Identify failure pattern

### Step 2: Identify Root Cause (Sage Analysis)
- Match failure pattern to hypotheses
- Determine TRUE root cause
- Propose targeted fix

### Step 3: Implement Fix (Artisan)
- Apply targeted fix based on root cause
- Rebuild and deploy

### Step 4: Visual Verification (Paladin)
- Run full visual test
- Get God's confirmation

---

## Success Criteria

**Investigation Success**:
- ✅ Minimal tests identify which component is broken
- ✅ Root cause clearly identified
- ✅ Hypothesis verified with evidence

**Fix Success**:
- ✅ God confirms: "I can see the image clearly"
- ✅ Both images AND text visible
- ✅ No flickering or corruption

---

## Timeline

| Phase | Duration | Agent | Deliverable |
|-------|----------|-------|-------------|
| 1. Minimal Tests | 10 min | Sage | Test results (which pass/fail) |
| 2. C++ Investigation | 10 min | Artisan+Sage | Debug log analysis |
| 3. Render State Check | 5 min | Sage | Blend mode/pipeline verification |
| 4. Root Cause ID | 5 min | Sage | TRUE root cause identified |
| 5. Targeted Fix | 5 min | Artisan | Fix implemented |
| 6. Visual Verification | 5 min | Paladin | God confirmation |
| **Total** | **40 min** | | **Complete** |

---

## Risk Assessment

**Risk Level**: MEDIUM
- Unknown root cause
- Multiple possible failure points
- Requires systematic debugging

**Mitigation**:
- Systematic testing eliminates guesswork
- Minimal tests isolate problem quickly
- Incremental approach reduces risk

**Success Probability**: 85%
- Systematic approach has high success rate
- Minimal tests will reveal root cause
- Once identified, fix is straightforward

---

## Learning from Failure

### What Went Wrong
1. **Insufficient Testing**: Trusted theoretical analysis without empirical verification
2. **Wrong Root Cause**: Fragment shader heuristic may not be the problem
3. **Over-Confidence**: 99% success probability was unjustified

### What We'll Do Better
1. **Empirical First**: Test assumptions before implementing fixes
2. **Systematic Debugging**: Use minimal tests to isolate problems
3. **Conservative Estimates**: Lower confidence until verified

---

## Next Steps

**Immediate**: Await God's approval for Deep Investigation Plan

**After Approval**:
1. Sage runs minimal fragment shader tests (Tests 1-5)
2. Sage analyzes results and identifies root cause
3. Artisan implements targeted fix
4. Paladin verifies with God's visual confirmation

---

**Plan Status**: READY FOR REVIEW
**Approval Required**: GOD
**Estimated Completion**: T+40 minutes from approval
**Success Probability**: 85% (conservative, evidence-based)
