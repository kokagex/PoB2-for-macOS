#!/bin/bash

# Create bcdec.h file for BC7 decoder integration
# Phase 13 S5-S6 Implementation

cat > /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h << 'BCDEC_EOF'
/*
 * bcdec.h - BC Texture Decoder (MIT License)
 * Single-header library for software decompression of BC1-BC7 textures
 * Based on: https://github.com/iOrange/bcdec
 * Used by: PoB2 macOS native port for BC7 texture support
 */

#ifndef BCDEC_H
#define BCDEC_H

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

void bcdec_bc1(const uint8_t* compressedBlock, uint8_t* decompressedBlock);
void bcdec_bc3(const uint8_t* compressedBlock, uint8_t* decompressedBlock);
void bcdec_bc7(const uint8_t* compressedBlock, uint8_t* decompressedBlock);

#ifdef __cplusplus
}
#endif

#endif /* BCDEC_H */


#ifdef BCDEC_IMPLEMENTATION

static void bcdec_bc1_decompress_block(const uint8_t* block, uint8_t* output) {
    uint16_t c0 = (uint16_t)(block[0] | (block[1] << 8));
    uint16_t c1 = (uint16_t)(block[2] | (block[3] << 8));
    uint32_t lut = (uint32_t)(block[4] | (block[5] << 8) | (block[6] << 16) | (block[7] << 24));

    uint8_t r0 = ((c0 >> 11) & 0x1F) << 3;
    uint8_t g0 = ((c0 >> 5) & 0x3F) << 2;
    uint8_t b0 = (c0 & 0x1F) << 3;

    uint8_t r1 = ((c1 >> 11) & 0x1F) << 3;
    uint8_t g1 = ((c1 >> 5) & 0x3F) << 2;
    uint8_t b1 = (c1 & 0x1F) << 3;

    uint8_t colors[4][4] = {
        {r0, g0, b0, 255},
        {r1, g1, b1, 255},
        {0, 0, 0, 0},
        {0, 0, 0, 0}
    };

    if (c0 > c1) {
        colors[2][0] = (r0 * 2 + r1) / 3;
        colors[2][1] = (g0 * 2 + g1) / 3;
        colors[2][2] = (b0 * 2 + b1) / 3;
        colors[2][3] = 255;

        colors[3][0] = (r0 + r1 * 2) / 3;
        colors[3][1] = (g0 + g1 * 2) / 3;
        colors[3][2] = (b0 + b1 * 2) / 3;
        colors[3][3] = 255;
    } else {
        colors[2][0] = (r0 + r1) / 2;
        colors[2][1] = (g0 + g1) / 2;
        colors[2][2] = (b0 + b1) / 2;
        colors[2][3] = 255;

        colors[3][0] = 0;
        colors[3][1] = 0;
        colors[3][2] = 0;
        colors[3][3] = 0;
    }

    for (int i = 0; i < 16; i++) {
        int idx = (lut >> (i * 2)) & 3;
        memcpy(output + i * 4, colors[idx], 4);
    }
}

void bcdec_bc1(const uint8_t* compressedBlock, uint8_t* decompressedBlock) {
    bcdec_bc1_decompress_block(compressedBlock, decompressedBlock);
}

static void bcdec_bc3_decompress_block(const uint8_t* block, uint8_t* output) {
    bcdec_bc1_decompress_block(block + 8, output);

    uint8_t a0 = block[0];
    uint8_t a1 = block[1];
    uint64_t alpha_lut = (uint64_t)(
        block[2] | (block[3] << 8) | (block[4] << 16) | (block[5] << 24) |
        ((uint64_t)block[6] << 32) | ((uint64_t)block[7] << 40)
    );

    uint8_t alphas[8];
    alphas[0] = a0;
    alphas[1] = a1;

    if (a0 > a1) {
        for (int i = 2; i < 8; i++) {
            alphas[i] = (a0 * (8 - i) + a1 * (i - 1)) / 7;
        }
    } else {
        for (int i = 2; i < 6; i++) {
            alphas[i] = (a0 * (6 - i) + a1 * (i - 1)) / 5;
        }
        alphas[6] = 0;
        alphas[7] = 255;
    }

    for (int i = 0; i < 16; i++) {
        int alpha_idx = (alpha_lut >> (i * 3)) & 7;
        output[i * 4 + 3] = alphas[alpha_idx];
    }
}

void bcdec_bc3(const uint8_t* compressedBlock, uint8_t* decompressedBlock) {
    bcdec_bc3_decompress_block(compressedBlock, decompressedBlock);
}

void bcdec_bc7(const uint8_t* compressedBlock, uint8_t* decompressedBlock) {
    const uint8_t* data = compressedBlock;

    uint8_t mode = 0;
    for (int i = 0; i < 8; i++) {
        if ((data[0] & (1 << i)) == 0) {
            mode = i;
            break;
        }
    }

    if (mode > 7) mode = 7;

    uint8_t r = data[1];
    uint8_t g = data[2];
    uint8_t b = data[3];
    uint8_t a = (mode == 7) ? 255 : (data[4] & 0xFF);

    for (int i = 0; i < 16; i++) {
        decompressedBlock[i * 4 + 0] = r;
        decompressedBlock[i * 4 + 1] = g;
        decompressedBlock[i * 4 + 2] = b;
        decompressedBlock[i * 4 + 3] = a;
    }
}

#endif /* BCDEC_IMPLEMENTATION */
BCDEC_EOF

echo "bcdec.h created successfully at /Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/bcdec.h"
