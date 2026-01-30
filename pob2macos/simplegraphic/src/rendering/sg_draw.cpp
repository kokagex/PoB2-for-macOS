/*
 * SimpleGraphic - Drawing Primitives
 * Image drawing functions
 */

#include "sg_internal.h"
#include <stdio.h>

/* ===== Public API ===== */

void DrawImage(ImageHandle handle, float left, float top, float width, float height,
               float tcLeft, float tcTop, float tcRight, float tcBottom) {
    if (!g_ctx || !g_ctx->renderer) return;

    // Allow null handle for solid color rectangles
    if (g_ctx->renderer->draw_image) {
        g_ctx->renderer->draw_image((struct ImageHandle_s*)handle,
                                    left, top, width, height,
                                    tcLeft, tcTop, tcRight, tcBottom);
    }
}

void DrawImageQuad(ImageHandle handle,
                   float x1, float y1, float x2, float y2,
                   float x3, float y3, float x4, float y4,
                   float s1, float t1, float s2, float t2,
                   float s3, float t3, float s4, float t4) {
    if (!g_ctx || !g_ctx->renderer) return;

    // Allow null handle for solid color rectangles
    if (g_ctx->renderer->draw_quad) {
        g_ctx->renderer->draw_quad((struct ImageHandle_s*)handle,
                                   x1, y1, x2, y2, x3, y3, x4, y4,
                                   s1, t1, s2, t2, s3, t3, s4, t4);
    }
}
