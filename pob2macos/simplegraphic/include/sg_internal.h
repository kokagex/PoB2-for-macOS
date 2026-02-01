/*
 * SimpleGraphic - Internal Header
 * Private interfaces and data structures
 */

#ifndef SG_INTERNAL_H
#define SG_INTERNAL_H

#include "simplegraphic.h"
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ===== Configuration ===== */

#define SG_DEFAULT_WIDTH 1920
#define SG_DEFAULT_HEIGHT 1080
#define SG_MAX_IMAGES 4096
#define SG_MAX_FONTS 64
#define SG_MAX_LAYERS 16

/* ===== Forward Declarations ===== */

struct SGContext;
struct SGRenderer;
struct ImageHandle_s;

/* ===== Image Handle Structure ===== */

struct ImageHandle_s {
    uint32_t id;
    int width;
    int height;
    bool valid;
    bool async_loading;
    int loading_priority;
    void* texture;          // Backend-specific texture data
    char* filename;
    bool isArray;           // True if texture is a texture2d_array
    uint32_t arraySize;     // Number of layers in array (1 for non-arrays)
    struct ImageHandle_s* next;
};

/* ===== Text Rendering Structures ===== */

typedef struct SGGlyphCacheEntry {
    uint32_t codepoint;
    int advance_x;          // Horizontal advance in pixels
    int bitmap_left;        // Left bearing
    int bitmap_top;         // Top bearing
    int width;              // Bitmap width
    int height;             // Bitmap height
    float atlas_u0, atlas_v0;  // UV coordinates in atlas
    float atlas_u1, atlas_v1;
    uint64_t last_used_frame;  // For LRU eviction
    struct SGGlyphCacheEntry* next;  // Hash table chaining
} SGGlyphCacheEntry;

typedef struct SGGlyphAtlas {
    void* texture;          // MTLTexture or GL texture
    int width;              // Atlas texture width (1024)
    int height;             // Atlas texture height (1024)
    unsigned char* buffer;  // CPU-side buffer for updates
    int current_x;          // Current packing position X
    int current_y;          // Current packing position Y
    int row_height;         // Current row height
    SGGlyphCacheEntry** hash_table;  // Hash table of glyphs
    int hash_size;          // Size of hash table
    int glyph_count;        // Number of glyphs in atlas
} SGGlyphAtlas;

typedef struct SGFontFace {
    void* ft_face;          // FT_Face
    int size;               // Font size in pixels
    SGGlyphAtlas* atlas;    // Glyph atlas for this font/size
    char name[64];          // Font name
    struct SGFontFace* next;
} SGFontFace;

/* ===== Renderer Interface ===== */

typedef struct SGRenderer {
    // Initialization
    bool (*init)(struct SGContext* ctx);
    void (*shutdown)(struct SGContext* ctx);

    // Frame management
    void (*begin_frame)(struct SGContext* ctx);
    void (*end_frame)(struct SGContext* ctx);
    void (*present)(struct SGContext* ctx);

    // State
    void (*set_clear_color)(float r, float g, float b, float a);
    void (*set_draw_color)(float r, float g, float b, float a);
    void (*set_viewport)(int x, int y, int width, int height);

    // Drawing
    void (*draw_image)(struct ImageHandle_s* img,
                       float left, float top, float width, float height,
                       float tcLeft, float tcTop, float tcRight, float tcBottom);
    void (*draw_quad)(struct ImageHandle_s* img,
                      float x1, float y1, float x2, float y2,
                      float x3, float y3, float x4, float y4,
                      float s1, float t1, float s2, float t2,
                      float s3, float t3, float s4, float t4);
    void (*draw_glyph)(void* texture, int x, int y, int width, int height,
                       float u0, float v0, float u1, float v1,
                       float r, float g, float b, float a);

    // Image management
    void* (*create_texture)(int width, int height, const void* data);
    void* (*create_compressed_texture)(int width, int height, uint32_t format, const void* data, size_t dataSize);
    void* (*create_compressed_texture_array)(int width, int height, uint32_t format, const void* dds_tex, const void* decompressed_data);
    void (*destroy_texture)(void* texture);
    void (*update_texture)(void* texture, const void* data);

    // Backend-specific data
    void* backend_data;
} SGRenderer;

/* ===== Context Structure ===== */

typedef struct SGContext {
    // Window state
    void* window;           // GLFWwindow*
    int width;
    int height;
    double dpi_scale;
    bool user_terminated;
    char window_title[256];

    // Renderer
    SGRenderer* renderer;

    // Drawing state
    float clear_color[4];
    float draw_color[4];
    int current_layer;
    int current_sublayer;
    struct {
        int x, y, width, height;
    } viewport;

    // Images
    struct ImageHandle_s* images;
    uint32_t next_image_id;
    int async_loading_count;

    // Text rendering
    void* freetype_library;  // FT_Library
    SGFontFace* font_cache;  // Linked list of loaded fonts
    uint64_t frame_number;   // For LRU cache eviction

    // Input state
    bool keys[512];
    double mouse_x;
    double mouse_y;

    // Timing
    double start_time;

    // Console
    char console_buffer[16384];
    int console_length;

    // Lua integration
    void* lua_state;
    void* main_object;

    // Clipboard
    char* clipboard_text;
} SGContext;

/* ===== Global Context ===== */

extern SGContext* g_ctx;

/* ===== Internal Functions ===== */

// Core
SGContext* sg_get_context(void);
bool sg_init_context(const char* flags);
void sg_destroy_context(void);

// Renderer backends
SGRenderer* sg_create_metal_renderer(void);
SGRenderer* sg_create_opengl_renderer(void);

// Window management
bool sg_window_init(SGContext* ctx, const char* flags);
void sg_window_shutdown(SGContext* ctx);
void sg_window_poll_events(SGContext* ctx);

// Input
void sg_input_init(SGContext* ctx);
void sg_input_shutdown(SGContext* ctx);
int sg_map_key_name(const char* key_name);

// Text rendering
bool sg_text_init(SGContext* ctx);
void sg_text_shutdown(SGContext* ctx);
void* sg_text_load_font(const char* font_name, int size);
void sg_text_draw_string(int x, int y, int align, int height,
                          const char* font, const char* text);
int sg_text_measure_width(int height, const char* font, const char* text);

// Image loading
struct ImageHandle_s* sg_image_create(void);
void sg_image_destroy(struct ImageHandle_s* img);
bool sg_image_load_from_file(struct ImageHandle_s* img, const char* filename);
unsigned char* sg_load_image_data(const char* filename, int* width, int* height, int* channels);

// Utilities
void sg_clipboard_set(const char* text);
const char* sg_clipboard_get(void);

// Path helpers
const char* sg_get_script_path(void);
const char* sg_get_runtime_path(void);
const char* sg_get_user_path(void);

#ifdef __cplusplus
}
#endif

#endif /* SG_INTERNAL_H */
