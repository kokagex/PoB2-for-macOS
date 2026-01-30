/*
 * SimpleGraphic - Clipboard Utilities
 * Copy/paste operations
 */

#include "sg_internal.h"
#include <GLFW/glfw3.h>
#include <string.h>
#include <stdlib.h>

/* ===== Public API ===== */

void Copy(const char* text) {
    if (!g_ctx || !g_ctx->window || !text) return;
    glfwSetClipboardString((GLFWwindow*)g_ctx->window, text);
}

const char* Paste(void) {
    if (!g_ctx || !g_ctx->window) return "";
    const char* text = glfwGetClipboardString((GLFWwindow*)g_ctx->window);
    return text ? text : "";
}

void SetClipboard(const char* text) {
    Copy(text);
}
