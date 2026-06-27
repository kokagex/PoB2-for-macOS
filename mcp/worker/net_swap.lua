-- NET (within-budget) test: dealloc a low-value outside-radius node (frees 3 pts)
-- AND alloc Ice Storm (3pt, socket 61419 radius) in ONE patch. If used<=121 and
-- net DPS > 1,298,012 with res/EHP held, sample's tree is NOT point-optimal and
-- this is a genuine beyond-reference win. If net<=0, sample is point-optimal.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local f = assert(io.open(HOME .. "/Library/Application Support/Path of Building/Builds/sample.xml", "r"))
local SAMPLE_XML = f:read("*a"); f:close()
local BASE = 1298012

local b0 = calc.loadBuild(SAMPLE_XML); b0.calcsTab:BuildOutput()
local used0 = select(1, b0.spec:CountAllocNodes())
io.stderr:write(string.format("baseline used=%d minDPS=%d\n\n", used0, BASE))

local ICE_STORM = 23907
local swaps = {
  { dealloc = 11248, name = "Intelligence(11248)" },
  { dealloc = 50816, name = "Intelligence(50816)" },
  { dealloc = 40894, name = "Minion Life(40894)" },
  { dealloc = 45343, name = "Minion Area(45343)" },
  { dealloc = 53795, name = "Puppet Master chance(53795)" },
}
io.stderr:write("=== NET swap: dealloc X (free 3) + alloc Ice Storm (3pt in 61419 radius) ===\n")
for _, s in ipairs(swaps) do
  local b = calc.loadBuild(SAMPLE_XML)
  local ok, err = pcall(function()
    calc.applyPatch(b, { deallocNodes = { s.dealloc }, allocNodes = { ICE_STORM } })
    b.calcsTab:BuildOutput()
  end)
  if ok then
    local u = select(1, b.spec:CountAllocNodes())
    local t = calc.readBreakdown(b)
    io.stderr:write(string.format("  -%-26s used=%d  minDPS=%10.0f (net %+7.0f)  Cr%%=%.1f EHP=%.0f F/C/L=%d/%d/%d\n",
      s.name, u, t.MinionCombinedDPS, t.MinionCombinedDPS - BASE,
      t.MinionCritChance, t.TotalEHP, t.FireResist, t.ColdResist, t.LightningResist))
  else
    io.stderr:write(string.format("  -%-26s FAILED: %s\n", s.name, tostring(err):gsub("^.-calc%.lua:%d+: ", "")))
  end
end
io.stderr:write("\n=== done ===\n")
