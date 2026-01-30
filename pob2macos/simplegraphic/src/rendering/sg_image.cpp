/*
 * SimpleGraphic - Image Management
 * Image loading and handling
 */

#include "sg_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

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

    // TODO: Load image data using stb_image
    // For now, just mark as valid for testing
    img->valid = true;
    img->width = 256;
    img->height = 256;

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
