/*
 * SimpleGraphic - Window Management
 * GLFW-based window creation and event handling
 */

#include "sg_internal.h"
#include <GLFW/glfw3.h>
#include <stdio.h>
#include <string.h>

/* ===== GLFW Callbacks ===== */

static void glfw_error_callback(int error, const char* description) {
    fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

static void glfw_window_close_callback(GLFWwindow* window) {
    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (ctx) {
        ctx->user_terminated = true;
    }
}

static void glfw_framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (ctx) {
        ctx->width = width;
        ctx->height = height;
        printf("Framebuffer resized: %dx%d\n", width, height);
    }
}

/* ===== Initialization ===== */

bool sg_window_init(SGContext* ctx, const char* flags) {
    if (!ctx) return false;

    // Set error callback
    glfwSetErrorCallback(glfw_error_callback);

    // Initialize GLFW
    if (!glfwInit()) {
        fprintf(stderr, "Failed to initialize GLFW\n");
        return false;
    }

    printf("GLFW version: %s\n", glfwGetVersionString());

    // Window hints
#ifdef SG_USE_METAL
    // For Metal, no OpenGL context
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
#else
    // For OpenGL 3.3 Core
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    // DPI awareness
    if (flags && strstr(flags, "DPI_AWARE")) {
        glfwWindowHint(GLFW_COCOA_RETINA_FRAMEBUFFER, GLFW_TRUE);
    }

    // Resizable window
    glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

    // Create window
    GLFWwindow* window = glfwCreateWindow(
        ctx->width,
        ctx->height,
        ctx->window_title,
        NULL,
        NULL
    );

    if (!window) {
        fprintf(stderr, "Failed to create GLFW window\n");
        glfwTerminate();
        return false;
    }

    ctx->window = window;

    // Set window user pointer
    glfwSetWindowUserPointer(window, ctx);

    // Set callbacks
    glfwSetWindowCloseCallback(window, glfw_window_close_callback);
    glfwSetFramebufferSizeCallback(window, glfw_framebuffer_size_callback);

    // Get actual framebuffer size (for Retina displays)
    int fb_width, fb_height;
    glfwGetFramebufferSize(window, &fb_width, &fb_height);
    ctx->width = fb_width;
    ctx->height = fb_height;

    // Calculate DPI scale
    int window_width, window_height;
    glfwGetWindowSize(window, &window_width, &window_height);
    if (window_width > 0) {
        ctx->dpi_scale = (double)fb_width / (double)window_width;
    }

    printf("Window created: %dx%d (framebuffer: %dx%d, DPI scale: %.2f)\n",
           window_width, window_height, fb_width, fb_height, ctx->dpi_scale);

#ifndef SG_USE_METAL
    // Make context current for OpenGL
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);  // Enable vsync
#endif

    return true;
}

void sg_window_shutdown(SGContext* ctx) {
    if (!ctx || !ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)ctx->window;
    glfwDestroyWindow(window);
    ctx->window = NULL;

    glfwTerminate();
}

void sg_window_poll_events(SGContext* ctx) {
    if (!ctx || !ctx->window) return;

    glfwPollEvents();

    // Update input state (clear stuck keys when unfocused)
    sg_input_update(ctx);

    // Check if window should close
    GLFWwindow* window = (GLFWwindow*)ctx->window;
    if (glfwWindowShouldClose(window)) {
        ctx->user_terminated = true;
    }
}

void sg_window_set_title(void* window, const char* title) {
    if (!window || !title) return;
    glfwSetWindowTitle((GLFWwindow*)window, title);
}

/* ===== Native Window Handle ===== */

#ifdef SG_USE_METAL
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3native.h>

void* sg_window_get_native_handle(SGContext* ctx) {
    if (!ctx || !ctx->window) return NULL;
    return glfwGetCocoaWindow((GLFWwindow*)ctx->window);
}
#endif
