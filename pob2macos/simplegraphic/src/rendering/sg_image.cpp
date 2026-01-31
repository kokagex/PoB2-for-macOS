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

        // Use compressed format for BC1 and BC7
        bool use_compressed = (dds_tex.format == 0x47 || dds_tex.format == 0x62);  // BC1 or BC7

        if (use_compressed && g_ctx && g_ctx->renderer && g_ctx->renderer->create_compressed_texture) {
            // Use compressed texture directly (Metal supports BC1/BC7 natively)
            if (img->texture && g_ctx->renderer->destroy_texture) {
                g_ctx->renderer->destroy_texture(img->texture);
                img->texture = NULL;
            }

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
