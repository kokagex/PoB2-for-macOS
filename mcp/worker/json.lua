-- Thin wrapper over the bundled dkjson (../runtime/lua/dkjson.lua relative to src/).
local dk = require("dkjson")
local M = {}
function M.encode(t) return dk.encode(t, { indent = false }) end
function M.decode(s) return dk.decode(s) end
return M
