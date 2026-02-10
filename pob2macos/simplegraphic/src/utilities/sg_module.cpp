/*
 * SimpleGraphic - Module & Script Utilities
 * Lua module loading and sub-script execution
 */

#include "sg_internal.h"
#include <stdio.h>
#include <stdlib.h>

/* ===== Public API ===== */

void SetMainObject(void* luaState) {
    if (!g_ctx) return;
    g_ctx->lua_state = luaState;
}

int PCall(void* luaState, int nargs, int nresults) {
    (void)luaState;
    (void)nargs;
    (void)nresults;
    // TODO: Implement protected call
    return 0;
}

int LoadModule(const char* moduleName, void* luaState) {
    (void)moduleName;
    (void)luaState;
    // TODO: Load Lua module
    return 0;
}

int PLoadModule(const char* moduleName, void* luaState) {
    return LoadModule(moduleName, luaState);
}

int LaunchSubScript(const char* scriptName, void* luaState) {
    (void)scriptName;
    (void)luaState;
    // TODO: Launch sub-script asynchronously
    return 0;
}

void AbortSubScript(int handle) {
    (void)handle;
    // TODO: Abort running script
}

int IsSubScriptRunning(int handle) {
    (void)handle;
    return 0;
}

void OpenURL(const char* url) {
    if (!url) return;
    char command[2048];
    snprintf(command, sizeof(command), "open '%s'", url);
    system(command);
}

int SpawnProcess(const char* command) {
    if (!command) return -1;
    return system(command);
}

void TakeScreenshot(const char* filename) {
    (void)filename;
    // TODO: Implement screenshot
    printf("Screenshot: %s\n", filename);
}

void SetProfiling(int enabled) {
    (void)enabled;
    // TODO: Implement profiling
}
