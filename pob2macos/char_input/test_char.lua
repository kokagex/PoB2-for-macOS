-- Test: CharInput extension behavior
local ffi = require("ffi")

-- Load SimpleGraphic
ffi.cdef[[
    void RenderInit(const char* flags);
    void ProcessEvents(void);
    int IsUserTerminated(void);
    void Shutdown(void);
    int IsKeyDown(const char* key);
    void* sg_get_context(void);
]]
local sg = ffi.load("runtime/SimpleGraphic.dylib")
sg.RenderInit("")

-- Load CharInput
ffi.cdef[[
    void CharInput_Init(void* glfw_window);
    int GetCharInput(void);
]]
local ci = ffi.load("runtime/CharInput.dylib")

-- Get window handle
local ctx = sg.sg_get_context()
local window = ffi.cast("void**", ctx)[0]
ci.CharInput_Init(window)

print("Type characters. Press ESC to quit.")
print("Each character will be printed with its codepoint.")
print("")

local frame = 0
while sg.IsUserTerminated() == 0 do
    sg.ProcessEvents()
    frame = frame + 1

    -- Check for ESC
    if sg.IsKeyDown("ESCAPE") == 1 then break end

    -- Read char input
    while true do
        local ch = ci.GetCharInput()
        if ch == 0 then break end
        print(string.format("Frame %d: codepoint=%d (0x%02X) char='%s'",
            frame, ch, ch, ch >= 32 and ch ~= 127 and string.char(ch) or "CTRL"))
    end

    -- Also check backspace key state
    if sg.IsKeyDown("BACKSPACE") == 1 then
        print(string.format("Frame %d: BACKSPACE key is DOWN", frame))
    end
end

sg.Shutdown()
print("Done.")
