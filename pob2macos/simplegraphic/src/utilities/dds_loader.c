/*
 * Simple DDS Texture Loader Implementation
 */

#include "dds_loader.h"
#include <string.h>
#include <stdio.h>

#define DDS_MAGIC 0x20534444  // "DDS "

bool dds_load_from_memory(const uint8_t* buffer, size_t size, DDS_Texture* tex) {
    if (!buffer || !tex || size < sizeof(DDS_Header)) {
        return false;
    }

    const DDS_Header* header = (const DDS_Header*)buffer;

    // Verify magic number
    if (header->magic != DDS_MAGIC) {
        fprintf(stderr, "DDS: Invalid magic number\n");
        return false;
    }

    // Verify header size
    if (header->size != 124) {
        fprintf(stderr, "DDS: Invalid header size: %u\n", header->size);
        return false;
    }

    tex->width = header->width;
    tex->height = header->height;
    tex->mipMapCount = (header->flags & 0x20000) ? header->mipMapCount : 1;
    tex->arraySize = 1;  // Default: single texture

    // Check if compressed
    if (header->ddspf.flags & DDPF_FOURCC) {
        tex->isCompressed = true;
        tex->format = header->ddspf.fourCC;

        // Handle DX10 header extension
        if (header->ddspf.fourCC == FOURCC_DX10) {
            if (size < sizeof(DDS_Header) + sizeof(DDS_Header_DXT10)) {
                fprintf(stderr, "DDS: DX10 header truncated\n");
                return false;
            }
            const DDS_Header_DXT10* dx10 = (const DDS_Header_DXT10*)(buffer + sizeof(DDS_Header));
            tex->format = dx10->dxgiFormat;
            tex->arraySize = dx10->arraySize;  // Read array size from DX10 header
        }

        // Calculate data offset and size
        size_t dataOffset = sizeof(DDS_Header);
        if (header->ddspf.fourCC == FOURCC_DX10) {
            dataOffset += sizeof(DDS_Header_DXT10);
        }

        tex->data = buffer + dataOffset;
        tex->dataSize = size - dataOffset;

        // Calculate size per layer for texture arrays
        int blockSize = dds_get_block_size(tex->format);
        if (blockSize > 0) {
            int blocksX = (tex->width + 3) / 4;
            int blocksY = (tex->height + 3) / 4;
            tex->layerDataSize = blocksX * blocksY * blockSize;
        } else {
            tex->layerDataSize = tex->dataSize;
        }

        printf("DDS: Loaded compressed texture %dx%d, format=0x%X, arraySize=%u, dataSize=%zu, layerSize=%zu\n",
               tex->width, tex->height, tex->format, tex->arraySize, tex->dataSize, tex->layerDataSize);
        return true;
    }

    fprintf(stderr, "DDS: Uncompressed textures not supported\n");
    return false;
}

int dds_get_block_size(uint32_t format) {
    switch (format) {
        case FOURCC_DXT1:
        case DXGI_FORMAT_BC1_UNORM:
            return 8;  // BC1: 8 bytes per 4x4 block
        case FOURCC_DXT5:
        case FOURCC_BC7:
        case DXGI_FORMAT_BC7_UNORM:
            return 16; // BC7/DXT5: 16 bytes per 4x4 block
        default:
            return 0;
    }
}

const uint8_t* dds_get_array_layer(const DDS_Texture* tex, uint32_t layerIndex) {
    if (!tex || !tex->data) {
        fprintf(stderr, "DDS: Invalid texture for layer extraction\n");
        return NULL;
    }

    if (layerIndex >= tex->arraySize) {
        fprintf(stderr, "DDS: Layer index %u out of range (arraySize=%u)\n",
                layerIndex, tex->arraySize);
        return NULL;
    }

    // For single texture, return original data
    if (tex->arraySize == 1) {
        return tex->data;
    }

    // Calculate offset for this layer
    size_t layerOffset = layerIndex * tex->layerDataSize;

    if (layerOffset + tex->layerDataSize > tex->dataSize) {
        fprintf(stderr, "DDS: Layer %u data exceeds file bounds (offset=%zu, layerSize=%zu, totalSize=%zu)\n",
                layerIndex, layerOffset, tex->layerDataSize, tex->dataSize);
        return NULL;
    }

    return tex->data + layerOffset;
}

// Simplified BC1 decompression (4x4 block)
static void decompress_bc1_block(const uint8_t* block, uint8_t* rgba) {
    uint16_t c0 = block[0] | (block[1] << 8);
    uint16_t c1 = block[2] | (block[3] << 8);
    uint32_t indices = block[4] | (block[5] << 8) | (block[6] << 16) | (block[7] << 24);

    // Convert RGB565 to RGB888
    uint8_t r0 = ((c0 >> 11) & 0x1F) * 255 / 31;
    uint8_t g0 = ((c0 >> 5) & 0x3F) * 255 / 63;
    uint8_t b0 = (c0 & 0x1F) * 255 / 31;

    uint8_t r1 = ((c1 >> 11) & 0x1F) * 255 / 31;
    uint8_t g1 = ((c1 >> 5) & 0x3F) * 255 / 63;
    uint8_t b1 = (c1 & 0x1F) * 255 / 31;

    // Color table
    uint8_t colors[4][4];
    colors[0][0] = r0; colors[0][1] = g0; colors[0][2] = b0; colors[0][3] = 255;
    colors[1][0] = r1; colors[1][1] = g1; colors[1][2] = b1; colors[1][3] = 255;

    if (c0 > c1) {
        colors[2][0] = (2*r0 + r1) / 3;
        colors[2][1] = (2*g0 + g1) / 3;
        colors[2][2] = (2*b0 + b1) / 3;
        colors[2][3] = 255;
        colors[3][0] = (r0 + 2*r1) / 3;
        colors[3][1] = (g0 + 2*g1) / 3;
        colors[3][2] = (b0 + 2*b1) / 3;
        colors[3][3] = 255;
    } else {
        colors[2][0] = (r0 + r1) / 2;
        colors[2][1] = (g0 + g1) / 2;
        colors[2][2] = (b0 + b1) / 2;
        colors[2][3] = 255;
        colors[3][0] = 0;
        colors[3][1] = 0;
        colors[3][2] = 0;
        colors[3][3] = 0; // Transparent
    }

    // Decode indices
    for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
            int idx = (indices >> ((y * 4 + x) * 2)) & 0x3;
            int offset = (y * 4 + x) * 4;
            rgba[offset + 0] = colors[idx][0];
            rgba[offset + 1] = colors[idx][1];
            rgba[offset + 2] = colors[idx][2];
            rgba[offset + 3] = colors[idx][3];
        }
    }
}

bool dds_decompress_to_rgba(const DDS_Texture* tex, uint8_t* rgba_out) {
    if (!tex || !rgba_out || !tex->isCompressed) {
        return false;
    }

    // Check if BC1 format (supports both FOURCC and DXGI)
    if (tex->format != FOURCC_DXT1 && tex->format != DXGI_FORMAT_BC1_UNORM) {
        fprintf(stderr, "DDS: Decompression not implemented for format 0x%X\n", tex->format);
        // For BC7 and other formats, we'll need to pass compressed data to Metal
        return false;
    }

    int blockSize = dds_get_block_size(tex->format);
    if (blockSize == 0) {
        return false;
    }

    int blocksX = (tex->width + 3) / 4;
    int blocksY = (tex->height + 3) / 4;

    const uint8_t* src = tex->data;
    uint8_t blockRGBA[64]; // 4x4 block in RGBA

    for (int by = 0; by < blocksY; by++) {
        for (int bx = 0; bx < blocksX; bx++) {
            decompress_bc1_block(src, blockRGBA);
            src += blockSize;

            // Copy block to output
            for (int y = 0; y < 4 && (by * 4 + y) < tex->height; y++) {
                for (int x = 0; x < 4 && (bx * 4 + x) < tex->width; x++) {
                    int srcIdx = (y * 4 + x) * 4;
                    int dstIdx = ((by * 4 + y) * tex->width + (bx * 4 + x)) * 4;
                    rgba_out[dstIdx + 0] = blockRGBA[srcIdx + 0];
                    rgba_out[dstIdx + 1] = blockRGBA[srcIdx + 1];
                    rgba_out[dstIdx + 2] = blockRGBA[srcIdx + 2];
                    rgba_out[dstIdx + 3] = blockRGBA[srcIdx + 3];
                }
            }
        }
    }

    return true;
}
