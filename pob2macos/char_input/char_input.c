/*
 * CharInput - Minimal GLFW character input extension
 * Provides GetCharInput() for text field support
 * Loaded alongside SimpleGraphic.dylib
 */

#include <GLFW/glfw3.h>

#define QUEUE_SIZE 64

static unsigned int char_queue[QUEUE_SIZE];
static int queue_head = 0;
static int queue_tail = 0;

static void char_callback(GLFWwindow* window, unsigned int codepoint) {
    (void)window;
    int next = (queue_head + 1) % QUEUE_SIZE;
    if (next != queue_tail) {
        char_queue[queue_head] = codepoint;
        queue_head = next;
    }
}

void CharInput_Init(void* glfw_window) {
    if (!glfw_window) return;
    queue_head = 0;
    queue_tail = 0;
    glfwSetCharCallback((GLFWwindow*)glfw_window, char_callback);
}

int GetCharInput(void) {
    if (queue_head == queue_tail) return 0;
    unsigned int cp = char_queue[queue_tail];
    queue_tail = (queue_tail + 1) % QUEUE_SIZE;
    return (int)cp;
}
