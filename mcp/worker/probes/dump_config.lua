-- Dump configTab.input (the saved combat config) on the legal-geared build, so we
-- can see which build-sustained buffs are toggled OFF. PoB defaults are bare
-- (enemy full life, no curse/shock/charges); a build that sat at 151,802 with
-- lvl-1 supports almost certainly never had combat config set. Enable ONLY what
-- the build's own mechanics generate (Blasphemy+Despair curse, Pain Offering,
-- Sigil of Power, shock support, charges it sustains) -- per advisor BLOCK.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()
local w = io.stderr
local b = calc.loadBuild(xml)
local inp = b.configTab.input or {}
-- sorted dump of all set config keys
local keys = {}
for k in pairs(inp) do keys[#keys + 1] = k end
table.sort(keys)
w:write("=== configTab.input (currently set keys) ===\n")
for _, k in ipairs(keys) do
  w:write(string.format("  %-40s = %s\n", k, tostring(inp[k])))
end
w:write("total set keys=" .. #keys .. "\n")
-- list config options the build exposes that mention buffs/curse/shock/charge/offering
w:write("\n=== available config var names mentioning combat buffs ===\n")
local seen = {}
for _, var in ipairs(b.configTab.varList or {}) do
  local nm = var.var or ""
  local lbl = var.label or ""
  local hay = (nm .. " " .. lbl):lower()
  if hay:find("curse") or hay:find("shock") or hay:find("charge") or hay:find("offering")
    or hay:find("sigil") or hay:find("wither") or hay:find("expos") or hay:find("frenzy")
    or hay:find("pain") or hay:find("enemy") or hay:find("covered") or hay:find("despair") then
    if not seen[nm] then seen[nm] = true
      w:write(string.format("  var=%-34s label=%s\n", nm, lbl:sub(1, 46)))
    end
  end
end
