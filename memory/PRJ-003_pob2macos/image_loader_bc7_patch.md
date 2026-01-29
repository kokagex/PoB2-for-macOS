# Image Loader C - BC7 Integration Patch

## File: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/image_loader.c`

## Change 1: Add bcdec.h include

**Location**: After line 54 (after `#include "stb_image.h"`)

**Add**:
```c
// BC7 decoder (header-only library)
#include "bcdec.h"
```

---

## Change 2: Add BC7 software decoder function

**Location**: After line 313 (after `create_sized_fallback` function definition)

**Add**:
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

---

## Change 3: Modify GPU upload failure handling

**Location**: Lines 482-485

**Replace**:
```c
    printf("[DDS] %s GPU upload failed, using fallback (%u x %u)\n", format_name, width, height);
    glDeleteTextures(1, &texture);
    return create_sized_fallback(width, height, out_width, out_height);
```

**With**:
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

## Summary of Changes

| Change | Type | Location | Lines |
|--------|------|----------|-------|
| Add bcdec.h include | Add | Line 55 | 2 |
| Add decode_bc7_software() | Add | After line 313 | 60 |
| Modify GPU failure path | Replace | Lines 482-485 | 30 |
| **Total** | | | **92 new/modified lines** |

---

## Implementation Notes

1. **Include Order**: bcdec.h added after stb_image.h since it's independent
2. **Function Placement**: decode_bc7_software() placed before load_dds_texture() for logical flow
3. **Error Handling**: All malloc/decode failures handled gracefully with fallback
4. **Memory Management**: Temporary buffers freed immediately after use
5. **Logging**: Uses existing [BC7] prefix for consistency with [DDS] logging

---

## Build Impact

- No CMakeLists.txt changes required
- No new dependencies
- No compiler flags needed
- Header-only library (zero linkage impact)
- Compiles to ~1.5 KB additional code
