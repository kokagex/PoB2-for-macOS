/*
 * SimpleGraphic - Text Rendering
 * FreeType-based text rendering with glyph atlas
 */

#include "sg_internal.h"
#include <ft2build.h>
#include FT_FREETYPE_H
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

/* ===== Constants ===== */

#define ATLAS_WIDTH 1024
#define ATLAS_HEIGHT 1024
#define HASH_TABLE_SIZE 256
#define MAX_GLYPHS_PER_ATLAS 512

/* ===== UTF-8 Decoder ===== */

static uint32_t sg_utf8_decode(const char** text) {
    const unsigned char* s = (const unsigned char*)*text;
    uint32_t codepoint = 0;
    int bytes = 0;

    if (s[0] == 0) {
        return 0;  // End of string
    } else if ((s[0] & 0x80) == 0) {
        // 1-byte sequence (ASCII)
        codepoint = s[0];
        bytes = 1;
    } else if ((s[0] & 0xE0) == 0xC0) {
        // 2-byte sequence
        if ((s[1] & 0xC0) != 0x80) return 0xFFFD;  // Invalid
        codepoint = ((s[0] & 0x1F) << 6) | (s[1] & 0x3F);
        bytes = 2;
    } else if ((s[0] & 0xF0) == 0xE0) {
        // 3-byte sequence (Japanese characters)
        if ((s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80) return 0xFFFD;
        codepoint = ((s[0] & 0x0F) << 12) | ((s[1] & 0x3F) << 6) | (s[2] & 0x3F);
        bytes = 3;
    } else if ((s[0] & 0xF8) == 0xF0) {
        // 4-byte sequence
        if ((s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80 || (s[3] & 0xC0) != 0x80) return 0xFFFD;
        codepoint = ((s[0] & 0x07) << 18) | ((s[1] & 0x3F) << 12) | ((s[2] & 0x3F) << 6) | (s[3] & 0x3F);
        bytes = 4;
    } else {
        return 0xFFFD;  // Invalid sequence
    }

    *text += bytes;
    return codepoint;
}

/* ===== Escape Code Parser ===== */

static bool sg_parse_escape_code(const char** text, float* color) {
    const char* s = *text;

    if (*s != '^') return false;

    s++;  // Skip '^'

    if (*s >= '0' && *s <= '9') {
        // Color index (^0 to ^9)
        int idx = *s - '0';

        // Predefined colors (Path of Building standard colors)
        static const float colors[10][3] = {
            {1.0f, 1.0f, 1.0f},  // ^0 White
            {1.0f, 0.0f, 0.0f},  // ^1 Red
            {0.0f, 1.0f, 0.0f},  // ^2 Green
            {0.0f, 0.0f, 1.0f},  // ^3 Blue
            {1.0f, 1.0f, 0.0f},  // ^4 Yellow
            {1.0f, 0.0f, 1.0f},  // ^5 Magenta
            {0.0f, 1.0f, 1.0f},  // ^6 Cyan
            {0.5f, 0.5f, 0.5f},  // ^7 Gray
            {1.0f, 0.5f, 0.0f},  // ^8 Orange
            {0.5f, 0.0f, 0.5f},  // ^9 Purple
        };

        color[0] = colors[idx][0];
        color[1] = colors[idx][1];
        color[2] = colors[idx][2];

        *text += 2;
        return true;

    } else if (*s == 'x' && strlen(s) >= 7) {
        // Hex color (^xRRGGBB)
        char hex[7];
        memcpy(hex, s + 1, 6);
        hex[6] = '\0';

        unsigned int rgb = 0;
        if (sscanf(hex, "%06x", &rgb) == 1) {
            color[0] = ((rgb >> 16) & 0xFF) / 255.0f;
            color[1] = ((rgb >> 8) & 0xFF) / 255.0f;
            color[2] = (rgb & 0xFF) / 255.0f;

            *text += 8;
            return true;
        }
    }

    return false;
}

/* ===== Glyph Atlas Management ===== */

static SGGlyphAtlas* sg_create_glyph_atlas(SGContext* ctx) {
    if (!ctx || !ctx->renderer) return NULL;

    SGGlyphAtlas* atlas = (SGGlyphAtlas*)calloc(1, sizeof(SGGlyphAtlas));
    if (!atlas) return NULL;

    atlas->width = ATLAS_WIDTH;
    atlas->height = ATLAS_HEIGHT;
    atlas->current_x = 0;
    atlas->current_y = 0;
    atlas->row_height = 0;
    atlas->glyph_count = 0;

    // Allocate zeroed buffer
    atlas->buffer = (unsigned char*)calloc(ATLAS_WIDTH * ATLAS_HEIGHT, 1);
    if (!atlas->buffer) {
        free(atlas);
        return NULL;
    }

    // Create Metal texture
    if (ctx->renderer->create_texture) {
        atlas->texture = ctx->renderer->create_texture(ATLAS_WIDTH, ATLAS_HEIGHT, atlas->buffer);
        if (!atlas->texture) {
            free(atlas->buffer);
            free(atlas);
            return NULL;
        }
    }

    // Create hash table
    atlas->hash_size = HASH_TABLE_SIZE;
    atlas->hash_table = (SGGlyphCacheEntry**)calloc(HASH_TABLE_SIZE, sizeof(SGGlyphCacheEntry*));
    if (!atlas->hash_table) {
        if (ctx->renderer->destroy_texture) {
            ctx->renderer->destroy_texture(atlas->texture);
        }
        free(atlas->buffer);
        free(atlas);
        return NULL;
    }

    return atlas;
}

static void sg_destroy_glyph_atlas(SGContext* ctx, SGGlyphAtlas* atlas) {
    if (!atlas) return;

    // Free all cache entries
    if (atlas->hash_table) {
        for (int i = 0; i < atlas->hash_size; i++) {
            SGGlyphCacheEntry* entry = atlas->hash_table[i];
            while (entry) {
                SGGlyphCacheEntry* next = entry->next;
                free(entry);
                entry = next;
            }
        }
        free(atlas->hash_table);
    }

    // Destroy texture
    if (ctx && ctx->renderer && ctx->renderer->destroy_texture && atlas->texture) {
        ctx->renderer->destroy_texture(atlas->texture);
    }

    free(atlas->buffer);
    free(atlas);
}

static uint32_t sg_hash_codepoint(uint32_t codepoint, int hash_size) {
    return codepoint % hash_size;
}

static SGGlyphCacheEntry* sg_find_glyph(SGGlyphAtlas* atlas, uint32_t codepoint) {
    if (!atlas || !atlas->hash_table) return NULL;

    uint32_t hash = sg_hash_codepoint(codepoint, atlas->hash_size);
    SGGlyphCacheEntry* entry = atlas->hash_table[hash];

    while (entry) {
        if (entry->codepoint == codepoint) {
            return entry;
        }
        entry = entry->next;
    }

    return NULL;
}

static SGGlyphCacheEntry* sg_rasterize_glyph(SGContext* ctx, FT_Face face, uint32_t codepoint, SGGlyphAtlas* atlas) {
    if (!ctx || !face || !atlas) return NULL;

    // Check if atlas is full
    if (atlas->glyph_count >= MAX_GLYPHS_PER_ATLAS) {
        fprintf(stderr, "Glyph atlas full, cannot rasterize more glyphs\n");
        return NULL;
    }

    // Load and render glyph
    if (FT_Load_Char(face, codepoint, FT_LOAD_RENDER)) {
        fprintf(stderr, "Failed to load glyph for codepoint U+%04X\n", codepoint);
        return NULL;
    }

    FT_GlyphSlot slot = face->glyph;
    FT_Bitmap* bitmap = &slot->bitmap;

    // Check if glyph fits in current row
    if (atlas->current_x + bitmap->width > atlas->width) {
        // Move to next row
        atlas->current_x = 0;
        atlas->current_y += atlas->row_height;
        atlas->row_height = 0;

        // Check if we have vertical space
        if (atlas->current_y + bitmap->rows > atlas->height) {
            fprintf(stderr, "Glyph atlas out of vertical space\n");
            return NULL;
        }
    }

    // Copy bitmap to atlas buffer
    for (unsigned int y = 0; y < bitmap->rows; y++) {
        for (unsigned int x = 0; x < bitmap->width; x++) {
            int atlas_x = atlas->current_x + x;
            int atlas_y = atlas->current_y + y;
            unsigned char pixel = bitmap->buffer[y * bitmap->width + x];
            atlas->buffer[atlas_y * atlas->width + atlas_x] = pixel;
        }
    }

    // Update texture
    if (ctx->renderer->update_texture && atlas->texture) {
        ctx->renderer->update_texture(atlas->texture, atlas->buffer);
    }

    // Create cache entry
    SGGlyphCacheEntry* entry = (SGGlyphCacheEntry*)calloc(1, sizeof(SGGlyphCacheEntry));
    if (!entry) return NULL;

    entry->codepoint = codepoint;
    entry->advance_x = slot->advance.x >> 6;
    entry->bitmap_left = slot->bitmap_left;
    entry->bitmap_top = slot->bitmap_top;
    entry->width = bitmap->width;
    entry->height = bitmap->rows;

    // Calculate UV coordinates
    entry->atlas_u0 = (float)atlas->current_x / atlas->width;
    entry->atlas_v0 = (float)atlas->current_y / atlas->height;
    entry->atlas_u1 = (float)(atlas->current_x + bitmap->width) / atlas->width;
    entry->atlas_v1 = (float)(atlas->current_y + bitmap->rows) / atlas->height;

    entry->last_used_frame = ctx->frame_number;

    // Add to hash table
    uint32_t hash = sg_hash_codepoint(codepoint, atlas->hash_size);
    entry->next = atlas->hash_table[hash];
    atlas->hash_table[hash] = entry;

    // Update packing state
    atlas->current_x += bitmap->width;
    if ((int)bitmap->rows > atlas->row_height) {
        atlas->row_height = bitmap->rows;
    }
    atlas->glyph_count++;

    return entry;
}

static SGGlyphCacheEntry* sg_get_glyph(SGContext* ctx, FT_Face face, uint32_t codepoint, SGGlyphAtlas* atlas) {
    // Try to find in cache
    SGGlyphCacheEntry* entry = sg_find_glyph(atlas, codepoint);
    if (entry) {
        entry->last_used_frame = ctx->frame_number;
        return entry;
    }

    // Rasterize new glyph
    return sg_rasterize_glyph(ctx, face, codepoint, atlas);
}

/* ===== Font Management ===== */

static const char* sg_get_font_path(const char* font_name) {
    // Map font names to system fonts - use static strings to avoid memory issues
    static const char* monaco_path = "/System/Library/Fonts/Monaco.ttf";
    static const char* menlo_path = "/System/Library/Fonts/Menlo.ttc";

    if (!font_name || font_name[0] == '\0' || strcmp(font_name, "VAR") == 0) {
        return monaco_path;
    }

    if (strcmp(font_name, "FIXED") == 0) {
        return menlo_path;
    }

    // For custom font names, validate it's a reasonable path
    // If empty or looks invalid, fall back to Monaco
    if (strlen(font_name) < 3) {
        fprintf(stderr, "Warning: Invalid font name '%s', using Monaco\n", font_name);
        return monaco_path;
    }

    // Try as-is
    return font_name;
}

static SGFontFace* sg_load_font(SGContext* ctx, const char* font_name, int size) {
    if (!ctx || !ctx->freetype_library) return NULL;

    FT_Library ft_lib = (FT_Library)ctx->freetype_library;

    // Check if font is already loaded
    SGFontFace* font = ctx->font_cache;
    while (font) {
        if (strcmp(font->name, font_name ? font_name : "VAR") == 0 && font->size == size) {
            return font;
        }
        font = font->next;
    }

    // Load new font
    const char* font_path = sg_get_font_path(font_name);

    // Validate font path before attempting to load
    if (!font_path || font_path[0] == '\0') {
        fprintf(stderr, "Error: Invalid font path (NULL or empty)\n");
        return NULL;
    }

    // Check if file exists before loading
    FILE* test_file = fopen(font_path, "r");
    if (!test_file) {
        fprintf(stderr, "Error: Font file not found: %s\n", font_path);
        return NULL;
    }
    fclose(test_file);

    FT_Face ft_face;
    if (FT_New_Face(ft_lib, font_path, 0, &ft_face)) {
        fprintf(stderr, "Error: FreeType failed to load font: %s\n", font_path);
        return NULL;
    }

    printf("Successfully loaded font: %s (size: %d)\n", font_path, size);

    if (FT_Set_Pixel_Sizes(ft_face, 0, size)) {
        fprintf(stderr, "Failed to set font size: %d\n", size);
        FT_Done_Face(ft_face);
        return NULL;
    }

    // Create font face structure
    SGFontFace* new_font = (SGFontFace*)calloc(1, sizeof(SGFontFace));
    if (!new_font) {
        FT_Done_Face(ft_face);
        return NULL;
    }

    new_font->ft_face = ft_face;
    new_font->size = size;
    strncpy(new_font->name, font_name ? font_name : "VAR", 63);
    new_font->name[63] = '\0';

    // Create glyph atlas
    new_font->atlas = sg_create_glyph_atlas(ctx);
    if (!new_font->atlas) {
        FT_Done_Face(ft_face);
        free(new_font);
        return NULL;
    }

    // Add to cache
    new_font->next = ctx->font_cache;
    ctx->font_cache = new_font;

    printf("Loaded font: %s at size %d\n", new_font->name, size);

    return new_font;
}

/* ===== Initialization ===== */

bool sg_text_init(SGContext* ctx) {
    if (!ctx) return false;

    FT_Library ft_lib;
    if (FT_Init_FreeType(&ft_lib)) {
        fprintf(stderr, "Failed to initialize FreeType\n");
        return false;
    }

    ctx->freetype_library = ft_lib;
    ctx->font_cache = NULL;
    ctx->frame_number = 0;

    printf("Text rendering initialized with FreeType\n");
    return true;
}

void sg_text_shutdown(SGContext* ctx) {
    if (!ctx) return;

    // Free all fonts and atlases
    SGFontFace* font = ctx->font_cache;
    while (font) {
        SGFontFace* next = font->next;

        if (font->atlas) {
            sg_destroy_glyph_atlas(ctx, font->atlas);
        }

        if (font->ft_face) {
            FT_Done_Face((FT_Face)font->ft_face);
        }

        free(font);
        font = next;
    }
    ctx->font_cache = NULL;

    // Shutdown FreeType
    if (ctx->freetype_library) {
        FT_Done_FreeType((FT_Library)ctx->freetype_library);
        ctx->freetype_library = NULL;
    }

    printf("Text rendering shutdown\n");
}

/* ===== Public API ===== */

void DrawString(int left, int top, int align, int height,
                const char* font, const char* text) {
    if (!g_ctx || !text) return;

    // CRITICAL FIX: Always use default font to avoid FFI string corruption issues
    // The font parameter from LuaJIT FFI may be corrupted, so we ignore it entirely
    static const char* default_font = "VAR";

    // Debug: Log first few DrawString calls
    static int call_count = 0;
    if (call_count < 3) {
        printf("DEBUG: DrawString #%d - pos(%d,%d) align=%d height=%d using_default_font='%s'\n",
               ++call_count, left, top, align, height, default_font);
        if (text) {
            // Print first 100 chars of text
            size_t len = strlen(text);
            if (len > 100) {
                char preview[101];
                strncpy(preview, text, 100);
                preview[100] = '\0';
                printf("       Text (first 100 chars): '%s'...\n", preview);
            } else {
                printf("       Full text: '%s'\n", text);
            }
        }
    }

    // Increment frame number
    g_ctx->frame_number++;

    // Load font using default font only (ignore font parameter)
    SGFontFace* font_face = sg_load_font(g_ctx, default_font, height);
    if (!font_face) {
        fprintf(stderr, "DrawString: Failed to load font\n");
        return;
    }

    FT_Face ft_face = (FT_Face)font_face->ft_face;

    // Parse text and render glyphs
    const char* s = text;
    float color[4] = {g_ctx->draw_color[0], g_ctx->draw_color[1], g_ctx->draw_color[2], g_ctx->draw_color[3]};

    // Calculate text width for alignment
    int text_width = 0;
    const char* temp = text;
    while (*temp) {
        if (*temp == '^') {
            float dummy[4];
            if (sg_parse_escape_code(&temp, dummy)) {
                continue;
            }
        }

        uint32_t codepoint = sg_utf8_decode(&temp);
        if (codepoint == 0) break;

        SGGlyphCacheEntry* glyph = sg_get_glyph(g_ctx, ft_face, codepoint, font_face->atlas);
        if (glyph) {
            text_width += glyph->advance_x;
        }
    }

    // Calculate starting X position based on alignment
    int x = left;
    if (align == 1) {
        // Center
        x = left - text_width / 2;
    } else if (align == 2) {
        // Right
        x = left - text_width;
    }

    int y = top;

    // Render each glyph
    while (*s) {
        // Check for escape codes
        if (*s == '^') {
            if (sg_parse_escape_code(&s, color)) {
                continue;
            }
        }

        uint32_t codepoint = sg_utf8_decode(&s);
        if (codepoint == 0) break;

        SGGlyphCacheEntry* glyph = sg_get_glyph(g_ctx, ft_face, codepoint, font_face->atlas);
        if (!glyph) continue;

        // Calculate glyph position
        int glyph_x = x + glyph->bitmap_left;
        int glyph_y = y - glyph->bitmap_top;

        // Render glyph (this will be handled by Metal renderer)
        if (g_ctx->renderer && g_ctx->renderer->draw_glyph && glyph->width > 0 && glyph->height > 0) {
            g_ctx->renderer->draw_glyph(font_face->atlas->texture, glyph_x, glyph_y,
                                       glyph->width, glyph->height,
                                       glyph->atlas_u0, glyph->atlas_v0,
                                       glyph->atlas_u1, glyph->atlas_v1,
                                       color[0], color[1], color[2], color[3]);
        }

        x += glyph->advance_x;
    }
}

int DrawStringWidth(int height, const char* font, const char* text) {
    if (!text || !g_ctx) return 0;

    // Load font
    SGFontFace* font_face = sg_load_font(g_ctx, font, height);
    if (!font_face) {
        // Fallback to simple approximation
        int char_width = height / 2;
        return (int)strlen(text) * char_width;
    }

    FT_Face ft_face = (FT_Face)font_face->ft_face;

    // Measure text width
    int width = 0;
    const char* s = text;

    while (*s) {
        // Skip escape codes
        if (*s == '^') {
            float dummy[4];
            if (sg_parse_escape_code(&s, dummy)) {
                continue;
            }
        }

        uint32_t codepoint = sg_utf8_decode(&s);
        if (codepoint == 0) break;

        SGGlyphCacheEntry* glyph = sg_get_glyph(g_ctx, ft_face, codepoint, font_face->atlas);
        if (glyph) {
            width += glyph->advance_x;
        }
    }

    return width;
}

int DrawStringCursorIndex(int height, const char* font, const char* text,
                          int cursorX, int cursorY) {
    (void)cursorY;

    if (!text || !g_ctx) return 0;

    // Load font
    SGFontFace* font_face = sg_load_font(g_ctx, font, height);
    if (!font_face) {
        // Fallback to simple approximation
        int char_width = height / 2;
        int index = cursorX / char_width;
        int text_len = (int)strlen(text);
        if (index < 0) index = 0;
        if (index > text_len) index = text_len;
        return index;
    }

    FT_Face ft_face = (FT_Face)font_face->ft_face;

    // Find cursor position
    int x = 0;
    int char_index = 0;
    const char* s = text;

    while (*s) {
        if (*s == '^') {
            float dummy[4];
            if (sg_parse_escape_code(&s, dummy)) {
                continue;
            }
        }

        uint32_t codepoint = sg_utf8_decode(&s);
        if (codepoint == 0) break;

        SGGlyphCacheEntry* glyph = sg_get_glyph(g_ctx, ft_face, codepoint, font_face->atlas);
        if (glyph) {
            if (cursorX < x + glyph->advance_x / 2) {
                return char_index;
            }
            x += glyph->advance_x;
        }

        char_index++;
    }

    return char_index;
}

const char* StripEscapes(const char* text) {
    if (!text) return NULL;

    // TODO: Implement proper escape stripping
    // For now, return original text
    return text;
}
