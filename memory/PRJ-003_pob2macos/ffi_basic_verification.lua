#!/usr/bin/env luajit
-- ============================================================================
-- FFI SimpleGraphic Basic Verification Test
-- ============================================================================
--
-- Purpose: Test FFI loading with minimal definitions first
-- Created: 2026-01-29
--
-- ============================================================================

local ffi = require("ffi")

print("[FFI_BASIC] Starting FFI verification test")
print("")

-- Phase 1: Load library first
local build_dir = "/Users/kokage/national-operations/pob2macos/build"
local lib_paths = {
    build_dir .. "/libsimplegraphic.1.2.0.dylib",
    build_dir .. "/libsimplegraphic.dylib",
}
local lib_path = nil

for _, path in ipairs(lib_paths) do
    local f = io.open(path)
    if f then
        f:close()
        lib_path = path
        break
    end
end

if not lib_path then
    print("[FFI_BASIC] ERROR: Library not found at any candidate path")
    os.exit(1)
end

print("[FFI_BASIC] Attempting to load: " .. lib_path)

local ok, sg_lib = pcall(function()
    return ffi.load(lib_path)
end)

if not ok then
    print("[FFI_BASIC] ERROR: Failed to load library")
    print("[FFI_BASIC] Error: " .. tostring(sg_lib))
    os.exit(1)
end

if not sg_lib then
    print("[FFI_BASIC] ERROR: Library loaded but returned nil")
    os.exit(1)
end

print("[FFI_BASIC] SUCCESS: Library loaded")
print("")

-- Phase 2: Try simple FFI definitions one at a time
print("[FFI_BASIC] Testing FFI definitions...")
print("")

local tests_passed = 0
local tests_failed = 0

local function test_definition(name, cdef_str)
    print("[FFI_BASIC] Testing: " .. name)
    local ok, err = pcall(function()
        ffi.cdef(cdef_str)
    end)
    if ok then
        print("[FFI_BASIC]   ✓ Definition accepted: " .. name)
        tests_passed = tests_passed + 1
    else
        print("[FFI_BASIC]   ✗ Definition failed: " .. name)
        print("[FFI_BASIC]     Error: " .. tostring(err))
        tests_failed = tests_failed + 1
    end
end

-- Test definitions
test_definition("void SimpleGraphic_RenderInit(const char *mode)", "void SimpleGraphic_RenderInit(const char *mode);")
test_definition("void SimpleGraphic_Shutdown()", "void SimpleGraphic_Shutdown(void);")
test_definition("void SimpleGraphic_SetWindowTitle(const char *title)", "void SimpleGraphic_SetWindowTitle(const char *title);")

local w_ptr = ffi.new("int[1]")
local h_ptr = ffi.new("int[1]")
test_definition("void SimpleGraphic_GetScreenSize(int *w, int *h)", "void SimpleGraphic_GetScreenSize(int *w, int *h);")

test_definition("double SimpleGraphic_GetTime()", "double SimpleGraphic_GetTime(void);")
test_definition("float SimpleGraphic_GetScreenScale()", "float SimpleGraphic_GetScreenScale(void);")

test_definition("bool SimpleGraphic_IsUserTerminated()", "bool SimpleGraphic_IsUserTerminated(void);")
test_definition("bool SimpleGraphic_IsKeyDown(const char *key)", "bool SimpleGraphic_IsKeyDown(const char *key);")

test_definition("void SimpleGraphic_SetDrawColor(...)", "void SimpleGraphic_SetDrawColor(float r, float g, float b, float a);")
test_definition("void SimpleGraphic_DrawImage(...)", "void SimpleGraphic_DrawImage(void *img, int l, int t, int w, int h, float tl, float tt, float tr, float tb);")

print("")
print("[FFI_BASIC] Results: " .. tests_passed .. " passed, " .. tests_failed .. " failed")
print("")

-- Phase 3: Try function calls
print("[FFI_BASIC] Testing actual function calls...")
print("")

local call_tests = 0
local call_failures = 0

local function test_call(name, func_call)
    print("[FFI_BASIC] Calling: " .. name)
    local ok, result, err = pcall(func_call)
    if ok then
        print("[FFI_BASIC]   ✓ Call succeeded: " .. name)
        call_tests = call_tests + 1
    else
        print("[FFI_BASIC]   ✗ Call failed: " .. name)
        print("[FFI_BASIC]     Error: " .. tostring(result))
        call_failures = call_failures + 1
    end
end

test_call("SimpleGraphic_RenderInit", function() sg_lib.SimpleGraphic_RenderInit("DPI_AWARE") end)
test_call("SimpleGraphic_Shutdown", function() sg_lib.SimpleGraphic_Shutdown() end)
test_call("SimpleGraphic_SetWindowTitle", function() sg_lib.SimpleGraphic_SetWindowTitle("Test") end)
test_call("SimpleGraphic_GetTime", function() return sg_lib.SimpleGraphic_GetTime() end)
test_call("SimpleGraphic_GetScreenScale", function() return sg_lib.SimpleGraphic_GetScreenScale() end)
test_call("SimpleGraphic_IsUserTerminated", function() return sg_lib.SimpleGraphic_IsUserTerminated() end)
test_call("SimpleGraphic_IsKeyDown", function() return sg_lib.SimpleGraphic_IsKeyDown("A") end)
test_call("SimpleGraphic_SetDrawColor", function() sg_lib.SimpleGraphic_SetDrawColor(1.0, 1.0, 1.0, 1.0) end)

print("")
print("[FFI_BASIC] Call Results: " .. call_tests .. " succeeded, " .. call_failures .. " failed")
print("")

if call_failures == 0 then
    print("[FFI_BASIC] ✓ FFI INTEGRATION SUCCESSFUL")
    os.exit(0)
else
    print("[FFI_BASIC] ✗ Some tests failed")
    os.exit(1)
end
