-- Does a SECOND in-radius notable stack, or does it diminish as crit nears cap?
-- Single (1 notable) was +61,435. Test double + triple, all net-0 points (used<=121).
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local f = assert(io.open(HOME .. "/Library/Application Support/Path of Building/Builds/sample.xml", "r"))
local SAMPLE_XML = f:read("*a"); f:close()
local BASE = 1298012
local function run(label, dealloc, alloc)
  local b = calc.loadBuild(SAMPLE_XML)
  local ok, err = pcall(function()
    calc.applyPatch(b, { deallocNodes = dealloc, allocNodes = alloc }); b.calcsTab:BuildOutput()
  end)
  if ok then local u = select(1, b.spec:CountAllocNodes()); local t = calc.readBreakdown(b)
    io.stderr:write(string.format("  %-18s used=%d minDPS=%10.0f (net %+7.0f) Cr%%=%.1f Mult=%.2f EHP=%.0f F/C/L=%d/%d/%d\n",
      label, u, t.MinionCombinedDPS, t.MinionCombinedDPS - BASE, t.MinionCritChance, t.MinionCritMultiplier,
      t.TotalEHP, t.FireResist, t.ColdResist, t.LightningResist))
  else io.stderr:write(string.format("  %-18s FAILED: %s\n", label, tostring(err):gsub("^.-calc%.lua:%d+: ", ""))) end
end
io.stderr:write(string.format("baseline minDPS=%d\n=== stacking in-radius notables (socket 61419), net-0 pts ===\n", BASE))
-- dealloc low-value outside-radius nodes; alloc in-radius notables (each 3pt)
run("1 notable",  { 11248 },               { 23907 })                       -- Ice Storm
run("2 notables", { 11248, 45343 },        { 23907, 60878 })                -- + Lightning Storm
run("3 notables", { 11248, 45343, 53795 }, { 23907, 60878, 40985 })         -- + Empowering Remnants
io.stderr:write("\n=== done ===\n")
