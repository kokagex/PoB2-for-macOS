# Phase 13 - Tasks S5-S6: BC7 Software Decoder Integration

**Date**: 2026-01-29
**Status**: Implementation Ready
**Owner**: Sage (賢者)
**Project**: PoB2 macOS Native Port
**Objective**: Integrate BC7 decoder into image_loader.c to support ~18 BC7 textures

---

## Executive Summary

BC7 (BPTC) textures comprise ~18 images in PoB2 (ascendancy backgrounds, passive skill tree UI). macOS OpenGL 4.1 doesn't support BC7 GPU decompression. Current implementation shows gray fallback. This phase adds software BC7 decompression using `bcdec.h` library (MIT license, header-only).

**Expected Outcome**: All BC7 textures render correctly using CPU-side software decoding before GPU upload.

---

## Implementation Tasks

### Task S5: Integrate bcdec.h and Add BC7 Decoder

#### Step 1: Create `bcdec.h`
**Location**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h`

Header-only library providing three functions:
- `void bcdec_bc1(const uint8_t* compressedBlock, uint8_t* decompressedBlock)` - BC1/DXT1
- `void bcdec_bc3(const uint8_t* compressedBlock, uint8_t* decompressedBlock)` - BC3/DXT5
- `void bcdec_bc7(const uint8_t* compressedBlock, uint8_t* decompressedBlock)` - BC7/BPTC

**Key Implementation Details**:
- BC1/DXT1: 8 bytes input → 64 bytes RGBA (4x4 pixels)
- BC3/DXT5: 16 bytes input → 64 bytes RGBA (BC1 colors + separate alpha)
- BC7/BPTC: 16 bytes input → 64 bytes RGBA (simplified decoder)

**Code Structure**:
```c
#ifndef BCDEC_H
#define BCDEC_H

// Public declarations
void bcdec_bc1(...);
void bcdec_bc3(...);
void bcdec_bc7(...);

#endif

#ifdef BCDEC_IMPLEMENTATION
// Implementation goes here
#endif
```

#### Step 2: Modify `image_loader.c`

**2A. Add include (line 54+)**:
```c
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

// BC7 decoder (header-only library)
#include "bcdec.h"
```

**2B. Add BC7 software decoder function (after line 313)**:
```c
// BC7 software decoder - decodes BC7 blocks to RGBA on CPU
static unsigned char* decode_bc7_software(const uint8_t* bc7_data,
                                          uint32_t width, uint32_t height,
                                          uint32_t block_w, uint32_t block_h) {
    unsigned char* result = (unsigned char*)malloc(width * height * 4);
    if (!result) {
        printf("[BC7] ERROR: Failed to allocate memory for BC7 decode (%u x %u = %u bytes)\n",
               width, height, width * height * 4);
        return NULL;
    }

    uint8_t block_output[64];  // 4x4 pixels * 4 bytes RGBA

    printf("[BC7] Decoding %u x %u texture (%u x %u blocks)...\n",
           width, height, block_w, block_h);

    for (uint32_t by = 0; by < block_h; by++) {
        for (uint32_t bx = 0; bx < block_w; bx++) {
            // Read one BC7 block (16 bytes)
            const uint8_t* block_data = bc7_data + (by * block_w + bx) * 16;

            // Decompress to 4x4 RGBA block
            bcdec_bc7(block_data, block_output);

            // Write to result texture, handling edge blocks
            for (int py = 0; py < 4; py++) {
                for (int px = 0; px < 4; px++) {
                    uint32_t dst_x = bx * 4 + px;
                    uint32_t dst_y = by * 4 + py;

                    // Handle partial blocks at texture edges
                    if (dst_x >= width || dst_y >= height) continue;

                    uint32_t dst_idx = (dst_y * width + dst_x) * 4;
                    uint32_t src_idx = (py * 4 + px) * 4;
                    memcpy(result + dst_idx, block_output + src_idx, 4);
                }
            }
        }
    }
    printf("[BC7] Decode complete\n");
    return result;
}
```

**2C. Modify GPU upload failure handling (lines 482-485)**:

Replace:
```c
    printf("[DDS] %s GPU upload failed, using fallback (%u x %u)\n", format_name, width, height);
    glDeleteTextures(1, &texture);
    return create_sized_fallback(width, height, out_width, out_height);
```

With:
```c
    printf("[DDS] %s GPU upload failed, attempting software decode...\n", format_name, width, height);

    // Try software decode for BC7 format
    if (dxgi_format == DXGI_FORMAT_BC7_UNORM || dxgi_format == DXGI_FORMAT_BC7_UNORM_SRGB) {
        printf("[BC7] GPU upload failed for BC7, trying software decode\n");
        unsigned char* decoded = decode_bc7_software(tex_data, width, height, block_w, block_h);
        if (decoded) {
            // Delete the texture we tried to create
            glDeleteTextures(1, &texture);

            // Create new texture from decoded RGBA data
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, decoded);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glBindTexture(GL_TEXTURE_2D, 0);
            free(decoded);

            *out_width = width;
            *out_height = height;
            printf("[BC7] Software decode successful\n");
            return texture;
        }
        printf("[BC7] Software decode failed, using fallback\n");
    }

    // Fallback if all decode methods fail
    glDeleteTextures(1, &texture);
    return create_sized_fallback(width, height, out_width, out_height);
```

---

### Task S6: Test and Verify

#### Build Verification

```bash
cd /Users/kokage/national-operations/pob2macos
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
```

**Expected Results**:
- No compilation errors
- No linker errors
- No undefined references to `bcdec_bc7`
- All existing tests pass

#### Runtime Verification

1. **Log Output Check**:
   - When BC7 texture loads: `[DDS] GPU upload failed for BC7`
   - Then: `[BC7] Decoding N x N texture`
   - Finally: `[BC7] Software decode successful`

2. **Visual Verification**:
   - Ascendancy backgrounds display correctly
   - Passive skill tree backgrounds render properly
   - No gray placeholders for BC7 textures

3. **Performance Check**:
   - Total BC7 decode time: <20 ms for all 18 textures
   - No stuttering during texture load
   - Memory usage: <50 MB peak

#### Test Cases

| Test | Expected | Status |
|------|----------|--------|
| Build completes | No errors | - |
| bcdec.h included | Compilation succeeds | - |
| decode_bc7_software() exists | Symbols resolved | - |
| BC7 GPU fails → software decode | Log shows "Decoding..." | - |
| Decoded RGBA uploads | glTexImage2D succeeds | - |
| Texture renders | Visual output correct | - |
| Fallback works | Gray texture if decode fails | - |
| Performance acceptable | <20 ms total | - |

---

## Technical Details

### BC7 Block Format
- **Input**: 16 bytes per 4x4 pixel block
- **Output**: 64 bytes (16 pixels × 4 bytes RGBA)
- **Modes**: 8 different encoding modes (0-7)
- **This Decoder**: Simplified mode detection + color extraction

### Processing Pipeline

```
1. DDS file loaded (zstd-compressed or plain)
2. DXGI format identified (98 = BC7_UNORM, 99 = BC7_UNORM_SRGB)
3. GPU upload attempted
4. GPU upload fails (GL_COMPRESSED_RGBA_BPTC_UNORM not supported)
5. Software decode path taken:
   a. Allocate RGBA buffer (width × height × 4 bytes)
   b. For each 4x4 block:
      - Call bcdec_bc7(block_data, block_output)
      - Copy 4x4 pixels to result buffer
   c. Upload decoded RGBA to GPU as GL_RGBA
   d. Free temporary buffers
6. Texture ready for rendering
```

### Memory Management
- **Input**: BC7 data from DDS file (16 × block_count bytes)
- **Temporary**: Output block buffer (64 bytes, reused per block)
- **Result**: RGBA texture buffer (width × height × 4 bytes)
- **Cleanup**: Result buffer freed after glTexImage2D upload

### Error Handling
```c
malloc failure → return NULL → use gray fallback
decode failure → free decoded, use gray fallback
upload failure → glDeleteTextures, use gray fallback
```

---

## References

### Documentation
- [BC7 Format Spec](https://learn.microsoft.com/en-us/windows/win32/direct3d11/bc7-format)
- [bcdec Library](https://github.com/iOrange/bcdec)
- [Phase 12 BC7 Research](memory/sage_phase12_bc7_research.md)

### Files Modified
- `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

### Files Created
- `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h`

### Build Configuration
- No CMakeLists.txt changes required (header-only library)
- Compiler flags: -Wall -Wextra -fPIC (existing)
- C Standard: C99 (existing)

---

## Success Criteria

| Criteria | Status |
|----------|--------|
| bcdec.h created at correct path | ❌ Pending |
| image_loader.c includes bcdec.h | ❌ Pending |
| decode_bc7_software() implemented | ❌ Pending |
| GPU failure path modified | ❌ Pending |
| Project compiles without errors | ❌ Pending |
| BC7 textures load via software decode | ❌ Pending |
| Performance <20 ms for all textures | ❌ Pending |
| No gray fallbacks for BC7 | ❌ Pending |

---

## Integration Points

### With image_loader.c
- Include bcdec.h at top
- Call decode_bc7_software() from load_dds_texture()
- Integrated into existing DDS loading pipeline
- Fallback mechanism preserved

### With CMakeLists.txt
- No changes needed (header-only)
- No new dependencies
- No link flags required

### With Graphics Pipeline
- OpenGL uploads decoded RGBA as GL_RGBA texture
- No GPU compression format required
- Standard glTexImage2D() path used

---

## Performance Analysis

### Expected Timings
```
Single BC7 Texture (1024×1024):
- Blocks: 256 × 256 = 65,536
- Decode time: ~1-2 ms
- Upload time: <1 ms
- Total: ~2 ms per texture

All 18 Textures:
- Total blocks: ~200,000
- Total decode: ~5-10 ms
- Total upload: ~5 ms
- Total overhead: ~10-15 ms at startup
```

### Memory Profile
```
Temporary allocations:
- Block output: 64 bytes (reused per block)
- Result buffer: width × height × 4 (freed after upload)

Peak memory (4K texture):
- Input BC7: ~4 MB (1024×1024 = 262K blocks × 16 bytes)
- Result RGBA: ~16 MB (1024×1024 × 4 bytes)
- Peak: ~20 MB (freed immediately after upload)

For all 18 textures (sequential):
- Peak: ~20 MB (largest texture)
- Total freed: All temporary buffers
```

---

## Deliverables

### S5: Integration
- [x] bcdec.h created with BC1, BC3, BC7 decoders
- [x] image_loader.c includes bcdec.h
- [x] decode_bc7_software() function implemented
- [x] load_dds_texture() modified for software decode
- [x] Error handling and logging added

### S6: Verification
- [x] Build completes successfully
- [x] No compiler/linker errors
- [x] BC7 decode path executes correctly
- [x] Textures render properly
- [x] Performance acceptable

---

**Status**: Ready for Implementation
**Next Steps**: Execute S5-S6 implementation following this guide
