/*
 * SimpleGraphic - State Management
 * Drawing state and window properties
 */

#include "sg_internal.h"
#include <string.h>
#include <stdio.h>

/* ===== Window Management ===== */

void SetWindowTitle(const char* title) {
    if (!g_ctx || !title) return;

    strncpy(g_ctx->window_title, title, sizeof(g_ctx->window_title) - 1);
    g_ctx->window_title[sizeof(g_ctx->window_title) - 1] = '\0';

    // Update actual window title (implemented in sg_window.cpp)
    if (g_ctx->window) {
        extern void sg_window_set_title(void* window, const char* title);
        sg_window_set_title(g_ctx->window, title);
    }
}

void GetScreenSize(int* width, int* height) {
    if (!g_ctx) {
        if (width) *width = SG_DEFAULT_WIDTH;
        if (height) *height = SG_DEFAULT_HEIGHT;
        return;
    }

    if (width) *width = g_ctx->width;
    if (height) *height = g_ctx->height;
}

double GetScreenScale(void) {
    return g_ctx ? g_ctx->dpi_scale : 1.0;
}

int GetDPIScaleOverridePercent(void) {
    // Not implemented yet
    return 100;
}

void SetDPIScaleOverridePercent(int percent) {
    // Not implemented yet
    (void)percent;
}

/* ===== Drawing State ===== */

void SetClearColor(float r, float g, float b, float a) {
    if (!g_ctx) return;

    g_ctx->clear_color[0] = r;
    g_ctx->clear_color[1] = g;
    g_ctx->clear_color[2] = b;
    g_ctx->clear_color[3] = a;

    if (g_ctx->renderer && g_ctx->renderer->set_clear_color) {
        g_ctx->renderer->set_clear_color(r, g, b, a);
    }
}

void SetDrawColor(float r, float g, float b, float a) {
    if (!g_ctx) return;

    g_ctx->draw_color[0] = r;
    g_ctx->draw_color[1] = g;
    g_ctx->draw_color[2] = b;
    g_ctx->draw_color[3] = a;

    if (g_ctx->renderer && g_ctx->renderer->set_draw_color) {
        g_ctx->renderer->set_draw_color(r, g, b, a);
    }
}

void GetDrawColor(float* r, float* g, float* b, float* a) {
    if (!g_ctx) {
        if (r) *r = 1.0f;
        if (g) *g = 1.0f;
        if (b) *b = 1.0f;
        if (a) *a = 1.0f;
        return;
    }

    if (r) *r = g_ctx->draw_color[0];
    if (g) *g = g_ctx->draw_color[1];
    if (b) *b = g_ctx->draw_color[2];
    if (a) *a = g_ctx->draw_color[3];
}

void SetDrawLayer(int layer, int sublayer) {
    if (!g_ctx) return;

    g_ctx->current_layer = layer;
    g_ctx->current_sublayer = sublayer;

    // Layer sorting not implemented in MVP
}

void SetViewport(int x, int y, int width, int height) {
    if (!g_ctx) return;

    g_ctx->viewport.x = x;
    g_ctx->viewport.y = y;
    g_ctx->viewport.width = width;
    g_ctx->viewport.height = height;

    if (g_ctx->renderer && g_ctx->renderer->set_viewport) {
        g_ctx->renderer->set_viewport(x, y, width, height);
    }
}
