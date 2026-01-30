/*
 * SimpleGraphic - Cross-platform 2D Graphics Library
 * macOS Implementation
 *
 * Public C API - 48 functions for Lua FFI binding
 */

#ifndef SIMPLEGRAPHIC_H
#define SIMPLEGRAPHIC_H

#ifdef __cplusplus
extern "C" {
#endif

/* ===== Initialization & System ===== */

/**
 * Initialize the rendering system
 * @param flags Initialization flags (e.g., "DPI_AWARE")
 */
void RenderInit(const char* flags);

/**
 * Run the main event loop
 * This should be called from the Lua main loop
 */
void ProcessEvents(void);

/**
 * Check if user requested termination (closed window)
 */
int IsUserTerminated(void);

/**
 * Shutdown the rendering system and cleanup resources
 */
void Shutdown(void);

/**
 * Get current time in seconds
 */
double GetTime(void);

/**
 * Exit the application
 */
void Exit(void);

/**
 * Restart the application
 */
void Restart(void);

/* ===== Window Management ===== */

/**
 * Set the window title
 */
void SetWindowTitle(const char* title);

/**
 * Get screen/framebuffer size
 */
void GetScreenSize(int* width, int* height);

/**
 * Get screen scale (DPI scale factor)
 */
double GetScreenScale(void);

/**
 * Get DPI scale override percentage
 */
int GetDPIScaleOverridePercent(void);

/**
 * Set DPI scale override percentage
 */
void SetDPIScaleOverridePercent(int percent);

/* ===== Drawing State ===== */

/**
 * Set clear color (background)
 */
void SetClearColor(float r, float g, float b, float a);

/**
 * Set current draw color
 */
void SetDrawColor(float r, float g, float b, float a);

/**
 * Get current draw color
 */
void GetDrawColor(float* r, float* g, float* b, float* a);

/**
 * Set draw layer and sublayer (for Z-ordering)
 */
void SetDrawLayer(int layer, int sublayer);

/**
 * Set viewport/clipping region
 */
void SetViewport(int x, int y, int width, int height);

/* ===== Image Handling ===== */

/**
 * Image handle (opaque pointer)
 */
typedef struct ImageHandle_s* ImageHandle;

/**
 * Create a new image handle
 */
ImageHandle NewImageHandle(void);

/**
 * Load image from file
 * @param async If true, load asynchronously
 */
int ImageHandle_Load(ImageHandle handle, const char* filename, int async);

/**
 * Unload image and free memory
 */
void ImageHandle_Unload(ImageHandle handle);

/**
 * Check if image is valid (loaded successfully)
 */
int ImageHandle_IsValid(ImageHandle handle);

/**
 * Get image dimensions
 */
void ImageHandle_ImageSize(ImageHandle handle, int* width, int* height);

/**
 * Set loading priority for async images
 */
void ImageHandle_SetLoadingPriority(ImageHandle handle, int priority);

/**
 * Get count of pending async image loads
 */
int GetAsyncCount(void);

/* ===== Image Drawing ===== */

/**
 * Draw image in rectangular region
 */
void DrawImage(ImageHandle handle, float left, float top, float width, float height,
               float tcLeft, float tcTop, float tcRight, float tcBottom);

/**
 * Draw image with arbitrary quadrilateral
 */
void DrawImageQuad(ImageHandle handle,
                   float x1, float y1, float x2, float y2,
                   float x3, float y3, float x4, float y4,
                   float s1, float t1, float s2, float t2,
                   float s3, float t3, float s4, float t4);

/* ===== Text Rendering ===== */

/**
 * Draw text string
 * @param align 0=left, 1=center, 2=right
 */
void DrawString(int left, int top, int align, int height,
                const char* font, const char* text);

/**
 * Calculate text width in pixels
 */
int DrawStringWidth(int height, const char* font, const char* text);

/**
 * Get cursor index from pixel position in text
 */
int DrawStringCursorIndex(int height, const char* font, const char* text,
                          int cursorX, int cursorY);

/**
 * Remove escape sequences from text (e.g., color codes)
 */
const char* StripEscapes(const char* text);

/* ===== Input ===== */

/**
 * Check if key is currently pressed
 * @param key Key name (e.g., "escape", "space", "a", "f1")
 */
int IsKeyDown(const char* key);

/**
 * Get mouse cursor position
 */
void GetCursorPos(int* x, int* y);

/**
 * Set mouse cursor position
 */
void SetCursorPos(int x, int y);

/**
 * Show or hide cursor
 */
void ShowCursor(int show);

/* ===== Clipboard ===== */

/**
 * Copy text to clipboard
 */
void Copy(const char* text);

/**
 * Get text from clipboard
 */
const char* Paste(void);

/**
 * Set clipboard content
 */
void SetClipboard(const char* text);

/* ===== System Integration ===== */

/**
 * Open URL in default browser
 */
void OpenURL(const char* url);

/**
 * Spawn external process
 */
int SpawnProcess(const char* command);

/**
 * Take screenshot and save to file
 */
void TakeScreenshot(const char* filename);

/* ===== File System ===== */

/**
 * Get script directory path
 */
const char* GetScriptPath(void);

/**
 * Get runtime directory path
 */
const char* GetRuntimePath(void);

/**
 * Get user data directory path
 */
const char* GetUserPath(void);

/**
 * Get current working directory
 */
const char* GetWorkDir(void);

/**
 * Set current working directory
 */
void SetWorkDir(const char* path);

/**
 * Create directory
 */
int MakeDir(const char* path);

/**
 * Remove directory
 */
int RemoveDir(const char* path);

/* ===== Console ===== */

/**
 * Print to console
 */
void ConPrintf(const char* format, ...);

/**
 * Print Lua table to console
 */
void ConPrintTable(void* luaState, int index);

/**
 * Execute console command
 */
void ConExecute(const char* command);

/**
 * Clear console
 */
void ConClear(void);

/* ===== Lua Integration ===== */

/**
 * Set main Lua object
 */
void SetMainObject(void* luaState);

/**
 * Protected Lua call
 */
int PCall(void* luaState, int nargs, int nresults);

/**
 * Load Lua module
 */
int LoadModule(const char* moduleName, void* luaState);

/**
 * Protected load module
 */
int PLoadModule(const char* moduleName, void* luaState);

/**
 * Launch sub-script asynchronously
 */
int LaunchSubScript(const char* scriptName, void* luaState);

/**
 * Abort running sub-script
 */
void AbortSubScript(int handle);

/**
 * Check if sub-script is running
 */
int IsSubScriptRunning(int handle);

/* ===== Compression ===== */

/**
 * Inflate (decompress) zlib data
 */
const char* Inflate(const char* data, int dataLen, int* outLen);

/**
 * Deflate (compress) data with zlib
 */
const char* Deflate(const char* data, int dataLen, int* outLen);

/* ===== Profiling ===== */

/**
 * Enable/disable profiling
 */
void SetProfiling(int enabled);

#ifdef __cplusplus
}
#endif

#endif /* SIMPLEGRAPHIC_H */
