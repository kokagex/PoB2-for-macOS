/*
 * SimpleGraphic - Compression Utilities
 * zlib compression/decompression
 */

#include "sg_internal.h"
#include <zlib.h>
#include <stdlib.h>
#include <string.h>

/* ===== Public API ===== */

const char* Inflate(const char* data, int dataLen, int* outLen) {
    // TODO: Implement zlib inflate
    if (outLen) *outLen = 0;
    return NULL;
}

const char* Deflate(const char* data, int dataLen, int* outLen) {
    // TODO: Implement zlib deflate
    if (outLen) *outLen = 0;
    return NULL;
}
