-- Emit the constructed beyond-reference build (sample + 3 net-0-point in-radius
-- notable relocations -> +14.6% minion DPS at same points/EHP/capped res).
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local f = assert(io.open(HOME .. "/Library/Application Support/Path of Building/Builds/sample.xml", "r"))
local SAMPLE_XML = f:read("*a"); f:close()
local OUT = "/private/tmp/claude-501/-Users-kokage-national-operations/c8ddf0e2-3483-4c82-aa16-2b9dd36bc6bd/scratchpad/"
local b = calc.loadBuild(SAMPLE_XML)
calc.applyPatch(b, { deallocNodes = { 11248, 45343, 53795 }, allocNodes = { 23907, 60878, 40985 } })
b.calcsTab:BuildOutput()
local t = calc.readBreakdown(b)
io.stderr:write(string.format("beyond-reference: minDPS=%.0f Cr%%=%.1f Mult=%.2f EHP=%.0f F/C/L=%d/%d/%d used=%d\n",
  t.MinionCombinedDPS, t.MinionCritChance, t.MinionCritMultiplier, t.TotalEHP,
  t.FireResist, t.ColdResist, t.LightningResist, (select(1, b.spec:CountAllocNodes()))))
local ok, code = pcall(calc.exportCode, b)
if ok and code then
  local s = code.code or code
  local fo = io.open(OUT .. "beyond_reference_chrono_rota.code", "w"); fo:write(s); fo:close()
  io.stderr:write("export OK -> beyond_reference_chrono_rota.code (len=" .. #s .. ")\n")
else io.stderr:write("export FAILED: " .. tostring(code) .. "\n") end
