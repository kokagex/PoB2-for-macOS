-- Real zlib Deflate/Inflate for the headless worker via LuaJIT FFI -> libz.
-- HeadlessWrapper stubs Deflate/Inflate as no-ops (return ""), which breaks PoB
-- import-code round-trip. PoB's code format is base64(zlib_deflate(xml)), so we
-- bind libz's compress2/uncompress (both produce/consume zlib-wrapped streams)
-- to match what the PoB GUI's Inflate expects.
local ffi = require("ffi")

ffi.cdef[[
  unsigned long compressBound(unsigned long sourceLen);
  int compress2(uint8_t *dest, unsigned long *destLen,
                const uint8_t *source, unsigned long sourceLen, int level);
  int uncompress(uint8_t *dest, unsigned long *destLen,
                 const uint8_t *source, unsigned long sourceLen);
]]

-- libz is part of the system on macOS/Linux; load by soname, fall back to libc-bundled.
local z = ffi.load("z")

local M = {}

-- zlib-deflate a Lua string, returning the compressed bytes as a string.
function M.deflate(data, level)
  level = level or 9
  local srcLen = #data
  local bound = tonumber(z.compressBound(srcLen))
  local dest = ffi.new("uint8_t[?]", bound)
  local destLen = ffi.new("unsigned long[1]", bound)
  local rc = z.compress2(dest, destLen, data, srcLen, level)
  assert(rc == 0, "zlib compress2 failed: " .. tostring(rc))
  return ffi.string(dest, tonumber(destLen[0]))
end

-- zlib-inflate a Lua string. zlib's uncompress needs the output size up front,
-- which the PoB code format does not carry, so grow the buffer until it fits.
function M.inflate(data)
  local srcLen = #data
  local cap = math.max(1024, srcLen * 4)
  for _ = 1, 24 do
    local dest = ffi.new("uint8_t[?]", cap)
    local destLen = ffi.new("unsigned long[1]", cap)
    local rc = z.uncompress(dest, destLen, data, srcLen)
    if rc == 0 then
      return ffi.string(dest, tonumber(destLen[0]))
    elseif rc == -5 then -- Z_BUF_ERROR: output buffer too small, grow and retry
      cap = cap * 2
    else
      error("zlib uncompress failed: " .. tostring(rc))
    end
  end
  error("zlib uncompress: output exceeded growth cap")
end

return M
