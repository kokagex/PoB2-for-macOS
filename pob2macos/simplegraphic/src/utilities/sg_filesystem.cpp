/*
 * SimpleGraphic - Filesystem Utilities
 * Path and directory operations
 */

#include "sg_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <libgen.h>
#include <mach-o/dyld.h>

static char script_path[1024] = "";
static char runtime_path[1024] = "";
static char user_path[1024] = "";

/* ===== Path Helpers ===== */

const char* sg_get_script_path(void) {
    if (script_path[0] == '\0') {
        // Get executable path
        uint32_t size = sizeof(script_path);
        _NSGetExecutablePath(script_path, &size);

        // Get directory
        char* dir = dirname(script_path);
        strncpy(script_path, dir, sizeof(script_path) - 1);
    }
    return script_path;
}

const char* sg_get_runtime_path(void) {
    if (runtime_path[0] == '\0') {
        snprintf(runtime_path, sizeof(runtime_path), "%s", sg_get_script_path());
    }
    return runtime_path;
}

const char* sg_get_user_path(void) {
    if (user_path[0] == '\0') {
        const char* home = getenv("HOME");
        if (home) {
            snprintf(user_path, sizeof(user_path), "%s/Library/Application Support/PathOfBuilding", home);
        }
    }
    return user_path;
}

/* ===== Public API ===== */

const char* GetScriptPath(void) {
    return sg_get_script_path();
}

const char* GetRuntimePath(void) {
    return sg_get_runtime_path();
}

const char* GetUserPath(void) {
    return sg_get_user_path();
}

const char* GetWorkDir(void) {
    static char cwd[1024];
    return getcwd(cwd, sizeof(cwd));
}

void SetWorkDir(const char* path) {
    if (path) chdir(path);
}

int MakeDir(const char* path) {
    if (!path) return 0;
    return mkdir(path, 0755) == 0 ? 1 : 0;
}

int RemoveDir(const char* path) {
    if (!path) return 0;
    return rmdir(path) == 0 ? 1 : 0;
}
