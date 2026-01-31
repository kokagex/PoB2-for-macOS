/*
 * Simple DDS Texture Loader
 * Supports BC1 (DXT1) and BC7 compressed formats
 */

#ifndef DDS_LOADER_H
#define DDS_LOADER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// DDS pixel format flags
#define DDPF_FOURCC 0x00000004

// DDS header flags
#define DDSD_CAPS        0x00000001
#define DDSD_HEIGHT      0x00000002
#define DDSD_WIDTH       0x00000004
#define DDSD_PIXELFORMAT 0x00001000

// DDS surface flags
#define DDSCAPS_TEXTURE 0x00001000

// DXT formats
#define FOURCC_DXT1 0x31545844  // "DXT1"
#define FOURCC_DXT5 0x35545844  // "DXT5"
#define FOURCC_BC7  0x37434220  // "BC7 " (note space)
#define FOURCC_DX10 0x30315844  // "DX10"

// DXGI formats from DX10 header
#define DXGI_FORMAT_BC1_UNORM 71
#define DXGI_FORMAT_BC7_UNORM 98

#pragma pack(push, 1)

typedef struct {
    uint32_t size;
    uint32_t flags;
    uint32_t fourCC;
    uint32_t rgbBitCount;
    uint32_t rBitMask;
    uint32_t gBitMask;
    uint32_t bBitMask;
    uint32_t aBitMask;
} DDS_PixelFormat;

typedef struct {
    uint32_t magic;           // Must be "DDS "
    uint32_t size;            // Must be 124
    uint32_t flags;
    uint32_t height;
    uint32_t width;
    uint32_t pitchOrLinearSize;
    uint32_t depth;
    uint32_t mipMapCount;
    uint32_t reserved1[11];
    DDS_PixelFormat ddspf;
    uint32_t caps;
    uint32_t caps2;
    uint32_t caps3;
    uint32_t caps4;
    uint32_t reserved2;
} DDS_Header;

typedef struct {
    uint32_t dxgiFormat;
    uint32_t resourceDimension;
    uint32_t miscFlag;
    uint32_t arraySize;
    uint32_t miscFlags2;
} DDS_Header_DXT10;

// DDS texture info
typedef struct {
    int width;
    int height;
    int mipMapCount;
    bool isCompressed;
    uint32_t format;           // FOURCC or DXGI format
    const uint8_t* data;       // Pointer to texture data
    size_t dataSize;
} DDS_Texture;

#pragma pack(pop)

#ifdef __cplusplus
extern "C" {
#endif

// Load DDS texture from memory
bool dds_load_from_memory(const uint8_t* buffer, size_t size, DDS_Texture* tex);

// Get bytes per block for compressed formats
int dds_get_block_size(uint32_t format);

// Decompress BC1/BC7 to RGBA8 (if needed)
bool dds_decompress_to_rgba(const DDS_Texture* tex, uint8_t* rgba_out);

#ifdef __cplusplus
}
#endif

#endif // DDS_LOADER_H
