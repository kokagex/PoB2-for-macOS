/*
 * SimpleGraphic - Console Utilities
 * Console output and command execution
 */

#include "sg_internal.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

/* ===== Public API ===== */

void ConPrintf(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
}

void ConPrintTable(void* luaState, int index) {
    (void)luaState;
    (void)index;
    // TODO: Print Lua table
    printf("[Lua table]\n");
}

void ConExecute(const char* command) {
    if (!command) return;

    // Parse simple commands
    if (strncmp(command, "set ", 4) == 0) {
        printf("Console: %s\n", command);
        // TODO: Parse and execute vid_mode, vid_resizable etc.
    }
}

void ConClear(void) {
    printf("\033[2J\033[H");  // ANSI clear screen
}
