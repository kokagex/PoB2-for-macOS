-- Test script for Passive Tree display (FIXED)
local ffi = require("ffi")

local lib_path = "runtime/SimpleGraphic.dylib"
ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    void ProcessEvents(void);
    void SetClearColor(float r, float g, float b);
    void DrawString(float left, float top, const char* align, float height, const char* font, const char* text);
    void DrawImage(void* image, float left, float top, float width, float height, float tcLeft, float tcTop, float tcRight, float tcBottom);
    void* NewImageHandle(void);
    int ImageHandle_Load(void* handle, const char* fileName, int async);
    void ImageHandle_SetLoadingPriority(void* handle, int priority);
    void ImageHandle_ImageSize(void* handle, int* width, int* height);
]]

local sg = ffi.load(lib_path)

print("=== Passive Tree Display Test (FIXED) ===")
print("1. Initializing graphics...")
sg.RenderInit("DPI_AWARE")

print("2. Loading passive tree images...")
local imageHandle = sg.NewImageHandle()
local testImages = {
    {path = "Assets/PSStartNodeBackgroundInactive.png", name = "Start Node"},
    {path = "Assets/NotableFrameUnallocated.png", name = "Notable Frame"},
    {path = "Assets/PSGroupBackground1.png", name = "Group Background"},
}

local loadedImages = {}
for _, img in ipairs(testImages) do
    local handle = sg.NewImageHandle()
    local result = sg.ImageHandle_Load(handle, img.path, 0)
    if result == 0 then
        print("  ✅ Loaded: " .. img.name)
        table.insert(loadedImages, {handle = handle, name = img.name})
    else
        print("  ❌ Failed: " .. img.name .. " (error: " .. result .. ")")
    end
end

print("\n3. Running render loop for 5 seconds...")
local startTime = os.clock()
local frameCount = 0

while os.clock() - startTime < 5 do
    -- CRITICAL: ProcessEvents MUST be called BEFORE drawing
    sg.ProcessEvents()

    -- Clear screen
    sg.SetClearColor(0.1, 0.1, 0.15)

    -- Draw title
    sg.DrawString(100, 50, "LEFT", 24, "", "=== Passive Tree Test ===")
    sg.DrawString(100, 80, "LEFT", 16, "", string.format("Time: %.1fs  Frame: %d", os.clock() - startTime, frameCount))

    -- Draw loaded images in a row
    local x = 100
    local y = 150
    for i, img in ipairs(loadedImages) do
        sg.DrawImage(img.handle, x, y, 64, 64, 0, 0, 1, 1)
        sg.DrawString(x, y + 70, "LEFT", 12, "", img.name)
        x = x + 100
    end

    frameCount = frameCount + 1
end

print("\n4. Shutting down...")
sg.Shutdown()

print("=== Test Complete ===")
print("Total frames rendered: " .. frameCount)
print("Average FPS: " .. string.format("%.1f", frameCount / 5))
