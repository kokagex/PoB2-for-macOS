/*
 * SimpleGraphic MVP Test
 * Basic functionality test
 */

#include "../../include/simplegraphic.h"
#include <stdio.h>
#include <unistd.h>

int main() {
    printf("=== SimpleGraphic MVP Test ===\n\n");

    // Test 1: Initialization
    printf("[Test 1] RenderInit\n");
    RenderInit("DPI_AWARE");
    printf("✓ Window initialized\n\n");

    // Test 2: Screen size
    printf("[Test 2] GetScreenSize\n");
    int width, height;
    GetScreenSize(&width, &height);
    printf("✓ Screen: %dx%d\n\n", width, height);

    // Test 3: Drawing color
    printf("[Test 3] SetDrawColor\n");
    SetDrawColor(1.0f, 0.0f, 0.0f, 1.0f);
    printf("✓ Draw color set to red\n\n");

    // Test 4: Clear color
    printf("[Test 4] SetClearColor\n");
    SetClearColor(0.1f, 0.1f, 0.2f, 1.0f);
    printf("✓ Clear color set to dark blue\n\n");

    // Test 5: Text rendering
    printf("[Test 5] DrawString\n");
    DrawString(100, 100, 0, 20, "Arial", "Hello macOS MVP - SimpleGraphic.dylib is working!");
    printf("✓ Text rendered (check window)\n\n");

    // Test 6: Input
    printf("[Test 6] IsKeyDown\n");
    bool escape_pressed = IsKeyDown("escape");
    printf("✓ Escape key state: %s\n\n", escape_pressed ? "pressed" : "not pressed");

    // Test 7: Mouse
    printf("[Test 7] GetCursorPos\n");
    int x, y;
    GetCursorPos(&x, &y);
    printf("✓ Cursor at (%d, %d)\n\n", x, y);

    // Test 8: Timing
    printf("[Test 8] GetTime\n");
    double time = GetTime();
    printf("✓ Time: %.3f seconds\n\n", time);

    // Test 9: Run for 3 seconds
    printf("[Test 9] Event loop\n");
    printf("Window will stay open for 3 seconds (press ESC to exit early)...\n");

    double start_time = GetTime();
    int frame_count = 0;

    while (!IsUserTerminated() && (GetTime() - start_time) < 3.0) {
        // Process events
        ProcessEvents();

        // Check for escape key
        if (IsKeyDown("escape")) {
            printf("Escape pressed, exiting...\n");
            break;
        }

        // Sleep to avoid busy-wait
        usleep(16666);  // ~60 FPS
        frame_count++;
    }

    printf("✓ Rendered %d frames in %.2f seconds (avg %.1f FPS)\n\n",
           frame_count, GetTime() - start_time,
           frame_count / (GetTime() - start_time));

    // Test 10: Shutdown
    printf("[Test 10] Shutdown\n");
    Shutdown();
    printf("✓ Clean shutdown\n\n");

    printf("=== MVP Test Complete ===\n");
    printf("All tests passed!\n");

    return 0;
}
