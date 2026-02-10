/*
 * SimpleGraphic - Core Implementation
 * Initialization and lifecycle management
 */

#include "sg_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

/* Global context */
SGContext* g_ctx = NULL;

/* ===== Context Management ===== */

SGContext* sg_get_context(void) {
    return g_ctx;
}

bool sg_init_context(const char* flags) {
    if (g_ctx != NULL) {
        // Already initialized - this is okay, just return success
        return true;
    }

    g_ctx = (SGContext*)calloc(1, sizeof(SGContext));
    if (!g_ctx) {
        fprintf(stderr, "SimpleGraphic: Failed to allocate context\n");
        return false;
    }

    // Initialize defaults
    g_ctx->width = SG_DEFAULT_WIDTH;
    g_ctx->height = SG_DEFAULT_HEIGHT;
    g_ctx->dpi_scale = 1.0;
    g_ctx->user_terminated = false;
    strncpy(g_ctx->window_title, "SimpleGraphic", sizeof(g_ctx->window_title) - 1);

    // Default colors
    g_ctx->clear_color[0] = 0.0f;
    g_ctx->clear_color[1] = 0.0f;
    g_ctx->clear_color[2] = 0.0f;
    g_ctx->clear_color[3] = 1.0f;

    g_ctx->draw_color[0] = 1.0f;
    g_ctx->draw_color[1] = 1.0f;
    g_ctx->draw_color[2] = 1.0f;
    g_ctx->draw_color[3] = 1.0f;

    // Default viewport
    g_ctx->viewport.x = 0;
    g_ctx->viewport.y = 0;
    g_ctx->viewport.width = g_ctx->width;
    g_ctx->viewport.height = g_ctx->height;

    // Timing
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    g_ctx->start_time = ts.tv_sec + ts.tv_nsec / 1000000000.0;

    return true;
}

void sg_destroy_context(void) {
    if (!g_ctx) return;

    // Free clipboard if allocated
    if (g_ctx->clipboard_text) {
        free(g_ctx->clipboard_text);
    }

    // Free image list
    struct ImageHandle_s* img = g_ctx->images;
    while (img) {
        struct ImageHandle_s* next = img->next;
        if (img->filename) free(img->filename);
        free(img);
        img = next;
    }

    free(g_ctx);
    g_ctx = NULL;
}

/* ===== Public API Implementation ===== */

void RenderInit(const char* flags) {
    printf("SimpleGraphic: Initializing (flags: %s)\n", flags ? flags : "none");

    if (!sg_init_context(flags)) {
        fprintf(stderr, "SimpleGraphic: Failed to initialize context\n");
        exit(1);
    }

    // Initialize window
    if (!sg_window_init(g_ctx, flags)) {
        fprintf(stderr, "SimpleGraphic: Failed to initialize window\n");
        sg_destroy_context();
        exit(1);
    }

    // Initialize renderer
#ifdef SG_USE_METAL
    g_ctx->renderer = sg_create_metal_renderer();
    if (!g_ctx->renderer) {
        fprintf(stderr, "SimpleGraphic: Failed to create Metal renderer\n");
        sg_window_shutdown(g_ctx);
        sg_destroy_context();
        exit(1);
    }
#else
    g_ctx->renderer = sg_create_opengl_renderer();
    if (!g_ctx->renderer) {
        fprintf(stderr, "SimpleGraphic: Failed to create OpenGL renderer\n");
        sg_window_shutdown(g_ctx);
        sg_destroy_context();
        exit(1);
    }
#endif

    // Initialize renderer
    if (!g_ctx->renderer->init(g_ctx)) {
        fprintf(stderr, "SimpleGraphic: Renderer initialization failed\n");
        free(g_ctx->renderer);
        sg_window_shutdown(g_ctx);
        sg_destroy_context();
        exit(1);
    }

    // Initialize text rendering
    if (!sg_text_init(g_ctx)) {
        fprintf(stderr, "SimpleGraphic: Failed to initialize text rendering\n");
        // Non-fatal, continue
    }

    // Initialize input
    sg_input_init(g_ctx);

    printf("SimpleGraphic: Initialization complete\n");
}

void ProcessEvents(void) {
    if (!g_ctx || !g_ctx->window) return;

    static int frame_count = 0;
    bool log_this_frame = (frame_count % 60 == 0);  // Log every 60 frames

    // End the previous frame (present to screen)
    if (g_ctx->renderer && g_ctx->renderer->end_frame) {
        if (log_this_frame) printf("DEBUG: Calling end_frame (frame %d)\n", frame_count);
        g_ctx->renderer->end_frame(g_ctx);
    }

    // Poll window events
    sg_window_poll_events(g_ctx);

    // Begin a new frame
    if (g_ctx->renderer && g_ctx->renderer->begin_frame) {
        if (log_this_frame) printf("DEBUG: Calling begin_frame (frame %d)\n", frame_count);
        g_ctx->renderer->begin_frame(g_ctx);
    }

    frame_count++;
}

int IsUserTerminated(void) {
    if (!g_ctx) return 1;
    return g_ctx->user_terminated ? 1 : 0;
}

void Shutdown(void) {
    printf("SimpleGraphic: Shutting down\n");

    if (!g_ctx) return;

    // Shutdown text rendering
    sg_text_shutdown(g_ctx);

    // Shutdown input
    sg_input_shutdown(g_ctx);

    // Shutdown renderer
    if (g_ctx->renderer) {
        g_ctx->renderer->shutdown(g_ctx);
        free(g_ctx->renderer);
        g_ctx->renderer = NULL;
    }

    // Shutdown window
    sg_window_shutdown(g_ctx);

    // Destroy context
    sg_destroy_context();

    printf("SimpleGraphic: Shutdown complete\n");
}

double GetTime(void) {
    if (!g_ctx) return 0.0;

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    double current_time = ts.tv_sec + ts.tv_nsec / 1000000000.0;
    return current_time - g_ctx->start_time;
}

void Exit(void) {
    Shutdown();
    exit(0);
}

void Restart(void) {
    // Not implemented yet
    fprintf(stderr, "SimpleGraphic: Restart not implemented\n");
}
