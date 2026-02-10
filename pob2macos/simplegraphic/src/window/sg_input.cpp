/*
 * SimpleGraphic - Input Handling
 * Keyboard and mouse input
 */

#include "sg_internal.h"
#include <GLFW/glfw3.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

/* ===== GLFW Callbacks ===== */

static void glfw_key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    (void)scancode;
    (void)mods;

    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (!ctx || key < 0 || key >= 512) return;

    ctx->keys[key] = (action != GLFW_RELEASE);
}

static void glfw_cursor_pos_callback(GLFWwindow* window, double xpos, double ypos) {
    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (!ctx) return;

    ctx->mouse_x = xpos;
    ctx->mouse_y = ypos;
}

static void glfw_mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
    (void)mods;

    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (!ctx) return;

    // Map mouse buttons to pseudo-key indices (starting after keyboard keys)
    // GLFW_MOUSE_BUTTON_LEFT = 0, GLFW_MOUSE_BUTTON_RIGHT = 1, GLFW_MOUSE_BUTTON_MIDDLE = 2
    // We'll map them to indices 400, 401, 402 to avoid conflicts with keyboard keys
    if (button >= 0 && button < 8) {
        int key_index = 400 + button;
        if (key_index < 512) {
            ctx->keys[key_index] = (action != GLFW_RELEASE);
        }
    }
}

static void glfw_char_callback(GLFWwindow* window, unsigned int codepoint) {
    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (!ctx) return;
    int next_head = (ctx->char_queue_head + 1) % 64;
    if (next_head != ctx->char_queue_tail) {
        ctx->char_queue[ctx->char_queue_head] = codepoint;
        ctx->char_queue_head = next_head;
    }
}

static void glfw_scroll_callback(GLFWwindow* window, double xoffset, double yoffset) {
    (void)xoffset;
    SGContext* ctx = (SGContext*)glfwGetWindowUserPointer(window);
    if (!ctx) return;
    ctx->wheel_delta += yoffset;
}

/* ===== Key Name Mapping ===== */

int sg_map_key_name(const char* key_name) {
    if (!key_name) return -1;

    // Convert to lowercase for comparison
    char lower_name[64];
    size_t len = strlen(key_name);
    if (len >= sizeof(lower_name)) len = sizeof(lower_name) - 1;

    for (size_t i = 0; i < len; i++) {
        lower_name[i] = tolower(key_name[i]);
    }
    lower_name[len] = '\0';

    // Special keys
    if (strcmp(lower_name, "escape") == 0) return GLFW_KEY_ESCAPE;
    if (strcmp(lower_name, "space") == 0) return GLFW_KEY_SPACE;
    if (strcmp(lower_name, "return") == 0 || strcmp(lower_name, "enter") == 0) return GLFW_KEY_ENTER;
    if (strcmp(lower_name, "tab") == 0) return GLFW_KEY_TAB;
    if (strcmp(lower_name, "backspace") == 0) return GLFW_KEY_BACKSPACE;
    if (strcmp(lower_name, "delete") == 0) return GLFW_KEY_DELETE;

    // Arrow keys
    if (strcmp(lower_name, "left") == 0) return GLFW_KEY_LEFT;
    if (strcmp(lower_name, "right") == 0) return GLFW_KEY_RIGHT;
    if (strcmp(lower_name, "up") == 0) return GLFW_KEY_UP;
    if (strcmp(lower_name, "down") == 0) return GLFW_KEY_DOWN;

    // Modifier keys
    if (strcmp(lower_name, "lshift") == 0) return GLFW_KEY_LEFT_SHIFT;
    if (strcmp(lower_name, "rshift") == 0) return GLFW_KEY_RIGHT_SHIFT;
    if (strcmp(lower_name, "shift") == 0) return GLFW_KEY_LEFT_SHIFT;
    if (strcmp(lower_name, "lctrl") == 0 || strcmp(lower_name, "ctrl") == 0) return GLFW_KEY_LEFT_CONTROL;
    if (strcmp(lower_name, "rctrl") == 0) return GLFW_KEY_RIGHT_CONTROL;
    if (strcmp(lower_name, "lalt") == 0 || strcmp(lower_name, "alt") == 0) return GLFW_KEY_LEFT_ALT;
    if (strcmp(lower_name, "ralt") == 0) return GLFW_KEY_RIGHT_ALT;

    // Page navigation
    if (strcmp(lower_name, "pageup") == 0) return GLFW_KEY_PAGE_UP;
    if (strcmp(lower_name, "pagedown") == 0) return GLFW_KEY_PAGE_DOWN;
    if (strcmp(lower_name, "home") == 0) return GLFW_KEY_HOME;
    if (strcmp(lower_name, "end") == 0) return GLFW_KEY_END;
    if (strcmp(lower_name, "insert") == 0) return GLFW_KEY_INSERT;

    // Mouse buttons (mapped to indices 400+)
    if (strcmp(lower_name, "leftbutton") == 0) return 400;   // GLFW_MOUSE_BUTTON_LEFT
    if (strcmp(lower_name, "rightbutton") == 0) return 401;  // GLFW_MOUSE_BUTTON_RIGHT
    if (strcmp(lower_name, "middlebutton") == 0) return 402; // GLFW_MOUSE_BUTTON_MIDDLE

    // Function keys
    if (lower_name[0] == 'f' && lower_name[1] >= '1' && lower_name[1] <= '9') {
        if (lower_name[2] == '\0') {
            int num = lower_name[1] - '0';
            return GLFW_KEY_F1 + (num - 1);
        } else if (lower_name[1] == '1' && lower_name[2] >= '0' && lower_name[2] <= '2' && lower_name[3] == '\0') {
            int num = 10 + (lower_name[2] - '0');
            return GLFW_KEY_F1 + (num - 1);
        }
    }

    // Single character keys (a-z, 0-9)
    if (len == 1) {
        if (lower_name[0] >= 'a' && lower_name[0] <= 'z') {
            return GLFW_KEY_A + (lower_name[0] - 'a');
        }
        if (lower_name[0] >= '0' && lower_name[0] <= '9') {
            return GLFW_KEY_0 + (lower_name[0] - '0');
        }
    }

    fprintf(stderr, "Warning: Unknown key name: %s\n", key_name);
    return -1;
}

/* ===== Initialization ===== */

void sg_input_init(SGContext* ctx) {
    if (!ctx || !ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)ctx->window;

    // Set callbacks
    glfwSetKeyCallback(window, glfw_key_callback);
    glfwSetCursorPosCallback(window, glfw_cursor_pos_callback);
    glfwSetMouseButtonCallback(window, glfw_mouse_button_callback);
    glfwSetCharCallback(window, glfw_char_callback);
    glfwSetScrollCallback(window, glfw_scroll_callback);

    // Initialize state
    memset(ctx->keys, 0, sizeof(ctx->keys));
    ctx->mouse_x = 0.0;
    ctx->mouse_y = 0.0;
    ctx->char_queue_head = 0;
    ctx->char_queue_tail = 0;
    ctx->wheel_delta = 0.0;

    printf("Input system initialized\n");
}

void sg_input_shutdown(SGContext* ctx) {
    if (!ctx || !ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)ctx->window;
    glfwSetKeyCallback(window, NULL);
    glfwSetCursorPosCallback(window, NULL);
    glfwSetMouseButtonCallback(window, NULL);
    glfwSetCharCallback(window, NULL);
    glfwSetScrollCallback(window, NULL);
}

/* ===== Public API ===== */

void sg_input_update(SGContext* ctx) {
    if (!ctx || !ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)ctx->window;

    // Clear mouse button and modifier states when window not focused
    if (!glfwGetWindowAttrib(window, GLFW_FOCUSED)) {
        // Clear mouse buttons (400-407)
        for (int i = 400; i < 408; i++) {
            ctx->keys[i] = false;
        }
        // Clear modifier keys
        ctx->keys[GLFW_KEY_LEFT_SHIFT] = false;
        ctx->keys[GLFW_KEY_RIGHT_SHIFT] = false;
        ctx->keys[GLFW_KEY_LEFT_CONTROL] = false;
        ctx->keys[GLFW_KEY_RIGHT_CONTROL] = false;
        ctx->keys[GLFW_KEY_LEFT_ALT] = false;
        ctx->keys[GLFW_KEY_RIGHT_ALT] = false;
        // Clear scroll
        ctx->wheel_delta = 0.0;
    }
}

int IsKeyDown(const char* key) {
    if (!g_ctx) return 0;

    int glfw_key = sg_map_key_name(key);
    if (glfw_key < 0 || glfw_key >= 512) return 0;

    return g_ctx->keys[glfw_key] ? 1 : 0;
}

void GetCursorPos(int* x, int* y) {
    if (!g_ctx) {
        if (x) *x = 0;
        if (y) *y = 0;
        return;
    }

    if (x) *x = (int)g_ctx->mouse_x;
    if (y) *y = (int)g_ctx->mouse_y;
}

void SetCursorPos(int x, int y) {
    if (!g_ctx || !g_ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)g_ctx->window;
    glfwSetCursorPos(window, (double)x, (double)y);
}

void ShowCursor(int show) {
    if (!g_ctx || !g_ctx->window) return;

    GLFWwindow* window = (GLFWwindow*)g_ctx->window;
    glfwSetInputMode(window, GLFW_CURSOR, show ? GLFW_CURSOR_NORMAL : GLFW_CURSOR_HIDDEN);
}

int GetCharInput(void) {
    if (!g_ctx) return 0;
    if (g_ctx->char_queue_head == g_ctx->char_queue_tail) return 0;
    unsigned int cp = g_ctx->char_queue[g_ctx->char_queue_tail];
    g_ctx->char_queue_tail = (g_ctx->char_queue_tail + 1) % 64;
    return (int)cp;
}

int GetMouseWheelDelta(void) {
    if (!g_ctx) return 0;
    int delta = (int)g_ctx->wheel_delta;
    g_ctx->wheel_delta -= delta;
    return delta;
}
