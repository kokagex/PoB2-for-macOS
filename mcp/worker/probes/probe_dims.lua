-- PROBE: which optimization dimensions actually move Minion DPS on THIS build?
-- Avoids wasting search width on no-ops (PoE2 support gems often show Lv1/Q0 as
-- a display default that does not scale). reload-per-candidate = no mutation
-- carryover. NO sample reference.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()

local function measure(patch)
  local b = calc.loadBuild(xml)
  if patch then calc.applyPatch(b, patch) end
  b.calcsTab:BuildOutput()
  local t = calc.readBreakdown(b)
  local used = select(1, b.spec:CountAllocNodes())
  return t.MinionCombinedDPS or -1, t, used
end

local base, baseT = measure(nil)
local w = io.stderr
w:write(string.format("BASELINE minDPS=%.0f  Cr%%=%.2f CrMul=%.2f used=%d\n\n",
  base, baseT.MinionCritChance, baseT.MinionCritMultiplier, (select(3, measure(nil)))))

local function probe(label, patch)
  local ok, d, tt = pcall(measure, patch)
  if not ok then
    w:write(string.format("  %-46s ERROR: %s\n", label, tostring(d)))
    return
  end
  w:write(string.format("  %-46s minDPS=%9.0f (%+.0f, %+.1f%%)  Cr%%=%.1f CrMul=%.2f\n",
    label, d, d - base, (d - base) / base * 100, tt and tt.MinionCritChance or -1,
    tt and tt.MinionCritMultiplier or -1))
end

w:write("=== gem quality / level dimension ===\n")
probe("Navira quality 0->20", { gems = { { name = "Navira, the Last Mirage", quality = 20 } } })
probe("Navira level 20->maxnatural", { gems = { { name = "Navira, the Last Mirage", level = 20 } } })
probe("Bidding III Lv1->20", { gems = { { name = "Bidding III", level = 20 } } })
probe("Bidding III Q0->20", { gems = { { name = "Bidding III", quality = 20 } } })
probe("Hulking Minions Lv1->20", { gems = { { name = "Hulking Minions", level = 20 } } })
probe("Frost Nexus Lv1->20", { gems = { { name = "Frost Nexus", level = 20 } } })
probe("Muster Lv1->20", { gems = { { name = "Muster", level = 20 } } })

w:write("\n=== support-swap dimension (remove a survivability support) ===\n")
probe("remove Hulking Minions", { gems = { { name = "Hulking Minions", remove = true } } })
probe("remove Encroaching Ground", { gems = { { name = "Encroaching Ground", remove = true } } })

w:write("\n=== passive dimension (dead-node probe via dealloc) ===\n")
for _, n in ipairs({ "Roil", "Melding", "Hallowed", "Insightfulness", "Preservation",
  "Sanguine Tolerance", "Dampening Shield", "Enhanced Barrier", "Patient Barrier" }) do
  probe("dealloc " .. n, { deallocNodes = { n } })
end

w:write("\n=== END PROBE ===\n")
