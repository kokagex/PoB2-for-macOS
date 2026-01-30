# Metal Pipeline Debug Report - Task #3

**Date**: 2026-01-31
**Task**: Debug and verify Metal pipeline initialization
**Status**: Investigation Complete

---

## Executive Summary

The Metal rendering pipeline is initialized correctly. The problem is **NOT** in initialization, but in the **runtime vertex buffer handling** in `metal_draw_image()`.

**Root Cause**: Vertex buffer data race between CPU writes and GPU reads.

---

## Detailed Findings

### 1. Initialization Status: ✓ CORRECT

#### Shader Compilation
- **Status**: ✓ Successful
- **Vertex Shader**: `vertex_main()` (lines 96-102)
  - Takes vertex attributes: position (float2), texCoord (float2), color (float4)
  - Outputs: position in NDC space, texCoord, color
- **Fragment Shader**: `fragment_main()` (lines 104-119)
  - Samples texture at provided coordinates
  - Handles both R8Unorm (glyph atlas) and RGBA (images) formats
  - Multiplies by vertex color for final output

#### Metal Device Setup
- **Status**: ✓ Working
- Device: AMD Radeon Pro 5500M
- Command Queue: ✓ Created
- Vertex Buffer: ✓ Allocated (10000 vertices)
- Sampler State: ✓ Configured (Linear filtering, Clamp-to-edge)

#### Pipeline State
- **Status**: ✓ Configured
- Color Format: BGRA8Unorm (Line 237) - matches CAMetalLayer format
- Vertex Descriptor: ✓ Correct
  - Attribute 0 (Position): float2 at offset 0
  - Attribute 1 (TexCoord): float2 at offset 8
  - Attribute 2 (Color): float4 at offset 16
  - Stride: 24 bytes per vertex ✓
- Blending: ✓ Enabled with proper alpha blending

#### Dummy Texture
- **Status**: ✓ Initialized
- Format: RGBA8Unorm (Line 274)
- Size: 1x1 pixel
- Data: 0xFFFFFFFF (white with full alpha)
- Purpose: Solid color rendering when handle is null

### 2. Runtime Execution: ✓ STARTS, ✗ FAILS

#### begin_frame() Analysis
**Status**: ✓ Correct initialization

```cpp
metal->textVertexCount = 0;               // Reset batch counter
metal->currentAtlasTexture = nil;         // Clear texture cache
metal->currentDrawable = [metal->metalLayer nextDrawable];  // Get surface
metal->commandBuffer = [metal->commandQueue commandBuffer];  // Create buffer
MTLRenderCommandEncoder* encoder = ...    // Create encoder
```

**Issue**: The test red rectangle (lines 350-378) uses `beginFrameMetal()` to draw, which should work but **may be being overwritten** by subsequent DrawImage calls.

---

#### draw_glyph() Analysis (DrawString) - ✓ WORKS

**Strategy**: Batch rendering

```cpp
// Line 558: Use current batch count as starting index
NSUInteger idx = metal->textVertexCount;  // ← KEY: Uses counter!

// Lines 562-615: Write 6 vertices at offset idx
vertices[idx + 0].position = ...
vertices[idx + 1].position = ...
// ... (total 6 vertices)

// Line 617: Increment counter
metal->textVertexCount += 6;

// Rendering deferred until end_frame() or texture changes
```

**Why it works**:
1. Each call appends to the batch
2. No overwriting - uses `metal->textVertexCount` as offset
3. All glyphs from the same atlas batch together
4. Flushed only when:
   - Texture changes
   - Frame ends (`metal_end_frame()`)

**Critical Implementation Detail**:
- Memory access pattern is SEQUENTIAL
- CPU writes → GPU reads (much later in frame)
- No race condition because writes are serialized

---

#### draw_image() Analysis (DrawImage) - ✗ BROKEN

**Strategy**: Immediate rendering (but with critical flaw)

```cpp
// Line 711: ALWAYS start at index 0
NSUInteger idx = 0;  // ← CRITICAL BUG!

// Lines 716-769: Write 6 vertices at offset 0
vertices[idx + 0].position = ...  // Overwrites previous data!
vertices[idx + 1].position = ...
// ... (total 6 vertices)

// Lines 772-778: Draw IMMEDIATELY
[metal->renderEncoder setRenderPipelineState:metal->pipelineState];
[metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
[metal->renderEncoder setFragmentTexture:texture atIndex:0];
[metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];
```

**Why it's broken**:

1. **Data Race**:
   - CPU writes to vertices[0-5] in CPU-managed memory
   - Immediately issues GPU command to read vertices[0-5]
   - Metal doesn't wait for CPU→GPU sync
   - GPU may read stale/garbage data

2. **Vertex Buffer Corruption**:
   - If DrawString just called draw_glyph(), vertices[0-5] contain glyph data
   - DrawImage overwrites these with rectangle data
   - Both are rendered but glyphs get corrupted

3. **Memory Barrier Missing**:
   - `MTLResourceStorageModeShared` requires explicit sync
   - Missing: `[metal->textVertexBuffer didModifyRange:]`
   - Metal doesn't know CPU wrote new data

4. **Implicit Synchronization Failed**:
   - Line 774 sets the buffer, but Metal may cache the old pointer
   - GPU continues reading old data from previous frames

---

### 3. Test Rectangle Analysis (begin_frame)

Lines 350-378 attempt to draw a red fullscreen rectangle:

```cpp
testVerts[0].position = {-1.0f, 1.0f};   // NDC coordinates (correct)
testVerts[0].color = {1.0f, 0.0f, 0.0f, 1.0f};  // Red (correct)

[metal->renderEncoder setRenderPipelineState:metal->pipelineState];  // Set state
[metal->renderEncoder setFragmentTexture:metal->dummyWhiteTexture atIndex:0];  // Set dummy
[metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle ...];  // Draw
```

**Why this doesn't work either**:
1. Uses same vertex buffer as batching system
2. Overwrites vertices[0-5] with test data
3. But vertices are in **Shared storage** without explicit sync
4. Same memory barrier issue as DrawImage

---

### 4. Buffer Management Issue

**Current Implementation (Line 267)**:
```cpp
metal->textVertexBuffer = [metal->device newBufferWithLength:metal->textVertexBufferSize
                                                     options:MTLResourceStorageModeShared];
```

**Problem**: MTLResourceStorageModeShared
- CPU and GPU share memory (no copy)
- Requires explicit synchronization
- No automatic CPU→GPU cache flush
- Metal driver doesn't track CPU writes

**Expected Behavior**:
```
Frame 1: CPU writes to vertices[0-5] → GPU reads ✓
Frame 2: CPU writes to vertices[0-5] → GPU reads stale data ✗
```

---

## Memory Layout Analysis

### TextVertex Structure (Lines 20-24)
```cpp
struct TextVertex {
    float position[2];    // Offset 0, 8 bytes
    float texCoord[2];    // Offset 8, 8 bytes
    float color[4];       // Offset 16, 16 bytes
};                        // Total: 32 bytes (not 24!)
```

**CRITICAL ISSUE**: Alignment mismatch!
- Declared stride in vertex descriptor: 24 bytes (line 229)
- Actual struct size: 32 bytes
- Result: Metal reads wrong data for every subsequent vertex

**Example**:
```
Intended vertex 0: pos[0], pos[1], tex[0], tex[1], col[0-3]
Metal reads:      pos[0], pos[1], tex[0], tex[1], ???
Then vertex 1:    (reads from vertex 0's color!)
```

---

## Shader Output Verification

### Fragment Shader (Lines 104-119)
The shader attempts to output color, but let's verify:

```metal
fragment float4 fragment_main(...) {
    float4 texColor = tex.sample(sam, in.texCoord);

    if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
        float alpha = texColor.r;
        return float4(in.color.rgb, alpha * in.color.a);
    }

    return texColor * in.color;  // ← This should execute for dummy white
}
```

For dummy white texture (0xFFFFFFFF):
- texColor = (1.0, 1.0, 1.0, 1.0)
- Condition FALSE (G and B are not zero)
- Return: (1.0, 1.0, 1.0, 1.0) * in.color ✓ Correct

---

## Critical Bug Summary

### Issue #1: Memory Alignment
**Severity**: CRITICAL
**Location**: Line 20-24 (struct definition) + Line 229 (stride)
**Fix**: Change stride to 32 bytes OR add padding to struct

### Issue #2: Missing Memory Barrier
**Severity**: CRITICAL
**Location**: Lines 711-778 (metal_draw_image)
**Fix**: Add `didModifyRange:` call before GPU command issue

### Issue #3: Vertex Buffer Index
**Severity**: HIGH
**Location**: Line 711 (NSUInteger idx = 0)
**Fix**: Use `idx = metal->textVertexCount` for batching OR use dedicated buffer

### Issue #4: Texture Flush Logic
**Severity**: MEDIUM
**Location**: Lines 646-657
**Fix**: Simplify texture management

---

## Recommended Fixes (Priority Order)

### Fix #1: Correct Vertex Alignment (CRITICAL)
```cpp
// Before (wrong):
typedef struct TextVertex {
    float position[2];
    float texCoord[2];
    float color[4];
} TextVertex;  // Size: 32 bytes, but stride says 24

// After (correct):
typedef struct TextVertex {
    float position[2];   // 8 bytes
    float texCoord[2];   // 8 bytes
    float color[4];      // 16 bytes
} TextVertex __attribute__((aligned(32)));  // Explicit 32 bytes

// OR update stride in vertex descriptor:
vertexDesc.layouts[0].stride = 32;  // Was 24, now correct
```

### Fix #2: Add Memory Barrier (CRITICAL)
```cpp
// In metal_draw_image(), after writing vertices, before drawPrimitives:
[metal->textVertexBuffer didModifyRange:NSMakeRange(0, 6 * sizeof(TextVertex))];
```

### Fix #3: Unified Batching Strategy (HIGH)
```cpp
// Option A: Use batching like DrawString
NSUInteger idx = metal->textVertexCount;
// ... write vertices at offset idx ...
metal->textVertexCount += 6;
// Draw in end_frame() with all pending vertices

// Option B: Use dedicated image buffer
// Create separate buffer for immediate DrawImage calls
```

### Fix #4: Clean Texture Management (MEDIUM)
Remove complex logic, use simple texture switching

---

## Validation Checklist

After applying fixes, verify:

- [ ] Alignment: sizeof(TextVertex) == 32 bytes
- [ ] Stride: vertex descriptor stride = 32 bytes
- [ ] Barrier: `didModifyRange:` called before GPU access
- [ ] Drawing: Test red rectangle appears in begin_frame
- [ ] Image: DrawImage with null handle shows white rectangle
- [ ] Batching: Multiple DrawImage calls don't corrupt data
- [ ] Performance: No memory stalls from sync operations

---

## Test Case from Task #2

The minimal test (`test_drawimage_minimal.lua`) will verify:

1. **Stage 1**: Five white rectangles on black background
   - If visible: Fixes #1, #2 successful
   - If invisible: Additional issues remain

2. **Stage 2**: Colored grid (3x3)
   - Tests multiple DrawImage calls
   - Verifies no batching corruption

3. **Stage 3**: Textured image
   - Verifies handle-based texture binding
   - Tests actual image loading/rendering

---

## Next Steps

**Task #4** should implement fixes in this order:
1. Fix struct alignment/stride (10 minutes)
2. Add memory barrier (5 minutes)
3. Test with minimal red rectangle (5 minutes)
4. Extend to white rectangles via DrawImage (10 minutes)
5. Verify batching and texture handling (10 minutes)
6. Full integration test (10 minutes)

**Estimated total**: 50 minutes to fix

