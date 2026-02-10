/*
 * SimpleGraphic - Image Management
 * Image loading and handling
 */

#include "sg_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <zstd.h>

// stb_image - single-header image loading library
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

// DDS texture loader
#include "dds_loader.h"

/* ===== DDS Array Cache ===== */

struct DDSArrayCache {
    char* filename;
    uint8_t* decompressed_data;
    size_t decompressed_size;
    DDS_Texture dds_tex;
    struct DDSArrayCache* next;
};

static struct DDSArrayCache* g_dds_cache = NULL;

static struct DDSArrayCache* find_dds_cache(const char* filename) {
    for (struct DDSArrayCache* cache = g_dds_cache; cache; cache = cache->next) {
        if (strcmp(cache->filename, filename) == 0) {
            return cache;
        }
    }
    return NULL;
}

static struct DDSArrayCache* add_dds_cache(const char* filename, uint8_t* data, size_t size, const DDS_Texture* tex) {
    struct DDSArrayCache* cache = (struct DDSArrayCache*)calloc(1, sizeof(struct DDSArrayCache));
    if (!cache) return NULL;

    cache->filename = strdup(filename);
    cache->decompressed_data = data;
    cache->decompressed_size = size;
    cache->dds_tex = *tex;
    cache->next = g_dds_cache;
    g_dds_cache = cache;

    return cache;
}

/* ===== Image Management ===== */

struct ImageHandle_s* sg_image_create(void) {
    struct ImageHandle_s* img = (struct ImageHandle_s*)calloc(1, sizeof(struct ImageHandle_s));
    if (!img) return NULL;

    if (g_ctx) {
        img->id = g_ctx->next_image_id++;
        img->next = g_ctx->images;
        g_ctx->images = img;
    }

    return img;
}

void sg_image_destroy(struct ImageHandle_s* img) {
    if (!img) return;

    if (img->filename) {
        free(img->filename);
    }

    if (img->texture && g_ctx && g_ctx->renderer && g_ctx->renderer->destroy_texture) {
        g_ctx->renderer->destroy_texture(img->texture);
    }

    // Remove from list
    if (g_ctx) {
        struct ImageHandle_s** curr = &g_ctx->images;
        while (*curr) {
            if (*curr == img) {
                *curr = img->next;
                break;
            }
            curr = &(*curr)->next;
        }
    }

    free(img);
}

bool sg_image_load_from_file(struct ImageHandle_s* img, const char* filename) {
    if (!img || !filename) return false;

    printf("Loading image: %s\n", filename);

    // Check if this is a DDS.zst file
    size_t len = strlen(filename);
    bool is_dds_zst = (len > 8 && strcmp(filename + len - 8, ".dds.zst") == 0);

    if (is_dds_zst) {
        // Load compressed DDS file
        FILE* f = fopen(filename, "rb");
        if (!f) {
            fprintf(stderr, "Failed to open DDS.zst file: %s\n", filename);
            return false;
        }

        // Get file size
        fseek(f, 0, SEEK_END);
        size_t compressed_size = ftell(f);
        fseek(f, 0, SEEK_SET);

        // Read compressed data
        uint8_t* compressed_data = (uint8_t*)malloc(compressed_size);
        if (!compressed_data) {
            fclose(f);
            return false;
        }
        fread(compressed_data, 1, compressed_size, f);
        fclose(f);

        // Decompress with zstd
        size_t decompressed_size = ZSTD_getFrameContentSize(compressed_data, compressed_size);
        if (decompressed_size == ZSTD_CONTENTSIZE_ERROR || decompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
            fprintf(stderr, "Failed to get DDS decompressed size for %s\n", filename);
            free(compressed_data);
            return false;
        }

        uint8_t* decompressed_data = (uint8_t*)malloc(decompressed_size);
        if (!decompressed_data) {
            free(compressed_data);
            return false;
        }

        size_t result = ZSTD_decompress(decompressed_data, decompressed_size,
                                       compressed_data, compressed_size);
        free(compressed_data);

        if (ZSTD_isError(result)) {
            fprintf(stderr, "ZSTD decompression failed for %s: %s\n",
                    filename, ZSTD_getErrorName(result));
            free(decompressed_data);
            return false;
        }

        printf("Decompressed DDS: %zu -> %zu bytes\n", compressed_size, result);

        // Parse DDS
        DDS_Texture dds_tex;
        if (!dds_load_from_memory(decompressed_data, result, &dds_tex)) {
            fprintf(stderr, "Failed to parse DDS data for %s\n", filename);
            free(decompressed_data);
            return false;
        }

        // Get texture dimensions
        int width = dds_tex.width;
        int height = dds_tex.height;
        uint32_t arraySize = dds_tex.arraySize;

        // Use compressed format for BC1 and BC7
        bool use_compressed = (dds_tex.format == 0x47 || dds_tex.format == 0x62);  // BC1 or BC7

        if (use_compressed && g_ctx && g_ctx->renderer) {
            // Destroy old texture if exists
            if (img->texture && g_ctx->renderer->destroy_texture) {
                g_ctx->renderer->destroy_texture(img->texture);
                img->texture = NULL;
            }

            // Check if this is a texture array (arraySize > 1)
            if (arraySize > 1 && g_ctx->renderer->create_compressed_texture_array) {
                printf("DDS file has arraySize=%u, creating texture2d_array\n", arraySize);

                img->texture = g_ctx->renderer->create_compressed_texture_array(
                    width, height,
                    dds_tex.format,
                    (const void*)&dds_tex,
                    (const void*)decompressed_data
                );

                if (!img->texture) {
                    fprintf(stderr, "Failed to create compressed texture array for %s\n", filename);
                    free(decompressed_data);
                    return false;
                }

                printf("Created compressed Metal texture2d_array: %p (format 0x%X, %u layers)\n",
                       img->texture, dds_tex.format, arraySize);

                // Set array metadata
                img->isArray = true;
                img->arraySize = arraySize;
            } else if (g_ctx->renderer->create_compressed_texture) {
                // Regular 2D texture (arraySize == 0 or 1)
                img->texture = g_ctx->renderer->create_compressed_texture(width, height,
                                                                          dds_tex.format,
                                                                          dds_tex.data,
                                                                          dds_tex.dataSize);
                if (!img->texture) {
                    fprintf(stderr, "Failed to create compressed Metal texture for %s\n", filename);
                    free(decompressed_data);
                    return false;
                }

                printf("Created compressed Metal texture for DDS: %p (format 0x%X)\n", img->texture, dds_tex.format);

                // Set array metadata (not an array)
                img->isArray = false;
                img->arraySize = 1;
            } else {
                fprintf(stderr, "No compressed texture creation function available\n");
                free(decompressed_data);
                return false;
            }
        } else {
            // Decompress to RGBA (fallback for unsupported formats)
            uint8_t* pixel_data = (uint8_t*)malloc(width * height * 4);
            if (!pixel_data) {
                free(decompressed_data);
                return false;
            }

            if (!dds_decompress_to_rgba(&dds_tex, pixel_data)) {
                fprintf(stderr, "Failed to decompress DDS texture for %s (format 0x%X)\n",
                        filename, dds_tex.format);
                free(pixel_data);
                free(decompressed_data);
                return false;
            }

            printf("Decompressed DDS texture: %dx%d, format 0x%X\n", width, height, dds_tex.format);

            // Create regular RGBA texture
            if (g_ctx && g_ctx->renderer && g_ctx->renderer->create_texture) {
                if (img->texture && g_ctx->renderer->destroy_texture) {
                    g_ctx->renderer->destroy_texture(img->texture);
                    img->texture = NULL;
                }

                img->texture = g_ctx->renderer->create_texture(width, height, pixel_data);
                if (!img->texture) {
                    fprintf(stderr, "Failed to create Metal texture for %s\n", filename);
                    free(pixel_data);
                    free(decompressed_data);
                    return false;
                }

                printf("Created Metal texture for DDS: %p\n", img->texture);
            }

            free(pixel_data);
        }

        free(decompressed_data);

        img->valid = true;
        img->width = width;
        img->height = height;
        if (img->filename) free(img->filename);
        img->filename = strdup(filename);

        return true;
    }

    // Standard PNG/JPG loading with stb_image
    int width = 0, height = 0, channels = 0;
    unsigned char* pixel_data = stbi_load(filename, &width, &height, &channels, 4);

    if (!pixel_data) {
        fprintf(stderr, "stb_image: Failed to load image '%s': %s\n", filename, stbi_failure_reason());
        return false;
    }

    printf("Loaded image %s: %dx%d, %d channels (forced to RGBA)\n",
           filename, width, height, channels);

    // Create Metal texture
    if (g_ctx && g_ctx->renderer && g_ctx->renderer->create_texture) {
        if (img->texture && g_ctx->renderer->destroy_texture) {
            g_ctx->renderer->destroy_texture(img->texture);
            img->texture = NULL;
        }

        img->texture = g_ctx->renderer->create_texture(width, height, pixel_data);

        if (!img->texture) {
            fprintf(stderr, "Failed to create texture for image '%s'\n", filename);
            stbi_image_free(pixel_data);
            return false;
        }

        printf("Created Metal texture for %s: %p\n", filename, img->texture);
    } else {
        fprintf(stderr, "Warning: Renderer not available for texture creation\n");
    }

    stbi_image_free(pixel_data);

    img->valid = true;
    img->width = width;
    img->height = height;

    if (img->filename) free(img->filename);
    img->filename = strdup(filename);

    return true;
}

/* ===== Public API ===== */

ImageHandle NewImageHandle(void) {
    return (ImageHandle)sg_image_create();
}

int ImageHandle_Load(ImageHandle handle, const char* filename, int async) {
    if (!handle || !filename) return 0;

    struct ImageHandle_s* img = (struct ImageHandle_s*)handle;

    if (async) {
        img->async_loading = true;
        if (g_ctx) g_ctx->async_loading_count++;
        // TODO: Launch async loading
    }

    return sg_image_load_from_file(img, filename) ? 1 : 0;
}

int ImageHandle_LoadArrayLayer(ImageHandle handle, const char* filename, unsigned int layerIndex) {
    if (!handle || !filename) return 0;

    struct ImageHandle_s* img = (struct ImageHandle_s*)handle;

    printf("Loading DDS array layer: %s [%u]\n", filename, layerIndex);

    size_t len = strlen(filename);
    bool is_dds_zst = (len > 8 && strcmp(filename + len - 8, ".dds.zst") == 0);

    if (!is_dds_zst) {
        fprintf(stderr, "ImageHandle_LoadArrayLayer: File must be .dds.zst: %s\n", filename);
        return 0;
    }

    struct DDSArrayCache* cache = find_dds_cache(filename);
    uint8_t* decompressed_data = NULL;
    DDS_Texture dds_tex;

    if (cache) {
        printf("Using cached DDS data for %s\n", filename);
        decompressed_data = cache->decompressed_data;
        dds_tex = cache->dds_tex;
    } else {
        FILE* f = fopen(filename, "rb");
        if (!f) {
            fprintf(stderr, "Failed to open DDS.zst file: %s\n", filename);
            return 0;
        }

        fseek(f, 0, SEEK_END);
        size_t compressed_size = ftell(f);
        fseek(f, 0, SEEK_SET);

        uint8_t* compressed_data = (uint8_t*)malloc(compressed_size);
        if (!compressed_data) {
            fclose(f);
            return 0;
        }
        fread(compressed_data, 1, compressed_size, f);
        fclose(f);

        size_t decompressed_size = ZSTD_getFrameContentSize(compressed_data, compressed_size);
        if (decompressed_size == ZSTD_CONTENTSIZE_ERROR || decompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
            fprintf(stderr, "Failed to get DDS decompressed size for %s\n", filename);
            free(compressed_data);
            return 0;
        }

        decompressed_data = (uint8_t*)malloc(decompressed_size);
        if (!decompressed_data) {
            free(compressed_data);
            return 0;
        }

        size_t result = ZSTD_decompress(decompressed_data, decompressed_size, compressed_data, compressed_size);
        free(compressed_data);

        if (ZSTD_isError(result)) {
            fprintf(stderr, "ZSTD decompression failed for %s: %s\n", filename, ZSTD_getErrorName(result));
            free(decompressed_data);
            return 0;
        }

        printf("Decompressed DDS: %zu -> %zu bytes\n", compressed_size, result);

        if (!dds_load_from_memory(decompressed_data, result, &dds_tex)) {
            fprintf(stderr, "Failed to parse DDS data for %s\n", filename);
            free(decompressed_data);
            return 0;
        }

        add_dds_cache(filename, decompressed_data, result, &dds_tex);
    }

    if (layerIndex >= dds_tex.arraySize) {
        fprintf(stderr, "Layer index %u out of range for %s (arraySize=%u)\n", layerIndex, filename, dds_tex.arraySize);
        return 0;
    }

    const uint8_t* layer_data = dds_get_array_layer(&dds_tex, layerIndex);
    if (!layer_data) {
        fprintf(stderr, "Failed to extract layer %u from %s\n", layerIndex, filename);
        return 0;
    }

    printf("Extracted layer %u: size=%zu bytes\n", layerIndex, dds_tex.layerDataSize);

    int width = dds_tex.width;
    int height = dds_tex.height;
    bool use_compressed = (dds_tex.format == 0x47 || dds_tex.format == 0x62);

    if (use_compressed && g_ctx && g_ctx->renderer && g_ctx->renderer->create_compressed_texture) {
        if (img->texture && g_ctx->renderer->destroy_texture) {
            g_ctx->renderer->destroy_texture(img->texture);
            img->texture = NULL;
        }

        img->texture = g_ctx->renderer->create_compressed_texture(width, height, dds_tex.format, layer_data, dds_tex.layerDataSize);
        if (!img->texture) {
            fprintf(stderr, "Failed to create compressed Metal texture for layer %u of %s\n", layerIndex, filename);
            return 0;
        }

        printf("Created compressed Metal texture for layer %u: %p (format 0x%X)\n", layerIndex, img->texture, dds_tex.format);
    } else {
        fprintf(stderr, "Layer loading requires compressed texture support\n");
        return 0;
    }

    img->valid = true;
    img->width = width;
    img->height = height;
    if (img->filename) free(img->filename);

    char filename_with_layer[1024];
    snprintf(filename_with_layer, sizeof(filename_with_layer), "%s[%u]", filename, layerIndex);
    img->filename = strdup(filename_with_layer);

    return 1;
}

void ImageHandle_Unload(ImageHandle handle) {
    if (!handle) return;
    sg_image_destroy((struct ImageHandle_s*)handle);
}

int ImageHandle_IsValid(ImageHandle handle) {
    if (!handle) return 0;
    struct ImageHandle_s* img = (struct ImageHandle_s*)handle;
    return img->valid ? 1 : 0;
}

void ImageHandle_ImageSize(ImageHandle handle, int* width, int* height) {
    if (!handle) {
        if (width) *width = 0;
        if (height) *height = 0;
        return;
    }

    struct ImageHandle_s* img = (struct ImageHandle_s*)handle;
    if (width) *width = img->width;
    if (height) *height = img->height;
}

void ImageHandle_SetLoadingPriority(ImageHandle handle, int priority) {
    if (!handle) return;
    struct ImageHandle_s* img = (struct ImageHandle_s*)handle;
    img->loading_priority = priority;
}

int GetAsyncCount(void) {
    return g_ctx ? g_ctx->async_loading_count : 0;
}
