-- Test script for Passive Tree display diagnosis
local ffi = require("ffi")

-- Load SimpleGraphic library
local lib_path = "runtime/SimpleGraphic.dylib"
ffi.cdef[[
    void RenderInit(const char* flags);
    void Shutdown(void);
    int ProcessEvents(void);
    void SetClearColor(float r, float g, float b);
    void DrawString(float left, float top, const char* align, float height, const char* font, const char* text);
    void DrawImage(void* image, float left, float top, float width, float height, float tcLeft, float tcTop, float tcRight, float tcBottom);
    void* NewImageHandle(void);
    int ImageHandle_Load(void* handle, const char* fileName, int async);
    void ImageHandle_SetLoadingPriority(void* handle, int priority);
    void RenderPresent(void);
]]

local sg = ffi.load(lib_path)

print("=== Passive Tree Display Test ===")
print("1. Initializing graphics...")
sg.RenderInit("DPI_AWARE")

print("2. Setting clear color...")
sg.SetClearColor(0.1, 0.1, 0.15)

print("3. Testing text rendering...")
sg.DrawString(100, 100, "LEFT", 16, "", "Passive Tree Test")

print("4. Testing image loading...")
local imageHandle = sg.NewImageHandle()
if imageHandle ~= nil then
    print("  - ImageHandle created")

    -- Try loading a passive tree asset
    local testImages = {
        "Assets/PSStartNodeBackgroundInactive.png",
        "Assets/NotableFrameUnallocated.png",
        "Assets/PSGroupBackground1.png",
    }

    for _, imagePath in ipairs(testImages) do
        local result = sg.ImageHandle_Load(imageHandle, imagePath, 0)
        if result == 0 then
            print("  ✅ Loaded: " .. imagePath)
            -- Try to draw it
            sg.DrawImage(imageHandle, 200, 200, 64, 64, 0, 0, 1, 1)
        else
            print("  ❌ Failed to load: " .. imagePath .. " (error: " .. result .. ")")
        end
    end
else
    print("  ❌ Failed to create ImageHandle")
end

print("5. Presenting frame...")
sg.RenderPresent()

print("6. Running event loop for 5 seconds...")
local startTime = os.clock()
while os.clock() - startTime < 5 do
    if sg.ProcessEvents() == 0 then
        print("  Window closed")
        break
    end
    sg.SetClearColor(0.1, 0.1, 0.15)
    sg.DrawString(100, 100, "LEFT", 16, "", "Passive Tree Test - " .. math.floor(os.clock() - startTime) .. "s")
    sg.RenderPresent()
end

print("7. Shutting down...")
sg.Shutdown()

print("\n=== Test Complete ===")
