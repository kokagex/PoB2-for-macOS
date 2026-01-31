# Font Loading Issue Report

**Date**: 2026-01-31
**Project**: PRJ-003 pob2macos
**Issue**: Font loading causes Segmentation Fault (Exit 139)

---

## Problem Description

When attempting to render text using DrawString(), the application crashes with:
```
Failed to load font: me: 57
DrawString: Failed to load font
Exit code: 139 (Segmentation Fault)
```

## Evidence

### Error Manifestation
1. **test_minimal_render.lua**: Crashes when calling DrawString()
2. **test_passive_tree_fixed.lua**: Font path appears corrupted (`�����~fA�l.��%`)
3. **Consistent pattern**: font_path parameter is corrupted when passed to fprintf()

### Code Analysis

**File**: `simplegraphic/src/rendering/sg_text.cpp`

**Function**: `sg_get_font_path()` (Line 298-310)
```cpp
static const char* sg_get_font_path(const char* font_name) {
    if (!font_name || strcmp(font_name, "VAR") == 0) {
        return "/System/Library/Fonts/Monaco.ttf";
    }
    if (strcmp(font_name, "FIXED") == 0) {
        return "/System/Library/Fonts/Menlo.ttc";
    }
    return font_name;
}
```

**Function**: `sg_load_font()` (Line 327-333)
```cpp
const char* font_path = sg_get_font_path(font_name);
FT_Face ft_face;

if (FT_New_Face(ft_lib, font_path, 0, &ft_face)) {
    fprintf(stderr, "Failed to load font: %s\n", font_path);  // ← Corrupted here
    return NULL;
}
```

### System Verification
- Monaco.ttf: ✅ EXISTS at `/System/Library/Fonts/Monaco.ttf`
- Menlo.ttc: ✅ EXISTS at `/System/Library/Fonts/Menlo.ttc`
- FreeType library: ✅ Linked (version 26.4.20)

## Hypothesis

### Likely Causes (in order of probability)

1. **Memory Corruption in font_path**
   - `sg_get_font_path()` returns a pointer that becomes invalid
   - Possible stack corruption between function calls

2. **LuaJIT FFI String Handling Issue**
   - Lua string passed via FFI may be garbage collected
   - C code receives dangling pointer

3. **Build Configuration Problem**
   - Compiler optimization breaking pointer handling
   - ABI mismatch between FreeType and our code

## Investigation Steps Taken

1. ✅ Verified system fonts exist
2. ✅ Rebuilt SimpleGraphic.dylib (Release mode, Metal backend)
3. ✅ Tested basic rendering without text (still hangs)
4. ✅ Confirmed FreeType initialization succeeds

## Recommended Fixes

### FIX 1: Add Defensive Checks in sg_load_font()
```cpp
const char* font_path = sg_get_font_path(font_name);
if (!font_path || strlen(font_path) == 0) {
    fprintf(stderr, "Invalid font path\n");
    return NULL;
}

// Validate path exists before FreeType
FILE* test = fopen(font_path, "r");
if (!test) {
    fprintf(stderr, "Font file not found: %s\n", font_path);
    return NULL;
}
fclose(test);
```

### FIX 2: LuaJIT FFI String Safety
In Lua code, ensure strings are kept alive:
```lua
local fontName = "VAR"  -- Keep reference
local fontNamePtr = ffi.cast("const char*", fontName)
DrawString(..., fontNamePtr, ...)
```

### FIX 3: Simplify Font Path Handling
Return static string directly:
```cpp
static const char* sg_get_font_path(const char* font_name) {
    static const char* monaco = "/System/Library/Fonts/Monaco.ttf";
    static const char* menlo = "/System/Library/Fonts/Menlo.ttc";

    if (!font_name || strcmp(font_name, "VAR") == 0) {
        return monaco;
    }
    if (strcmp(font_name, "FIXED") == 0) {
        return menlo;
    }
    return font_name;
}
```

### FIX 4: Debug Build to Get Stack Trace
```bash
cd simplegraphic
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DSG_BACKEND=metal
make -C build
# Then run under lldb to get crash location
```

## Impact

**Critical**: Application cannot render any text, making UI completely unusable.

**Affected Areas**:
- All DrawString() calls
- PassiveTreeView node labels
- UI text rendering
- Debug console output

## Next Steps

1. **Immediate**: Add defensive checks (FIX 1)
2. **Test**: Rebuild and test with validation
3. **If still fails**: Try FIX 3 (static strings)
4. **If still fails**: Debug build + lldb stack trace
5. **Long-term**: Review LuaJIT FFI string handling patterns

---

**Status**: Under Investigation
**Priority**: P0 (Critical - Blocks all functionality)
**Assigned**: Debugging required before further passive tree work
