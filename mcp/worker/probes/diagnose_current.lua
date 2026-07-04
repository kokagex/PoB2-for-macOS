-- Baseline diagnostic for the AUTOMATED optimizer: dump the current build's
-- full structure + DPS so the search has a starting point. NO sample reference.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"

local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()
local b = calc.loadBuild(xml)
b.calcsTab:BuildOutput()
local t = calc.readBreakdown(b)
local info = calc.readInfo(b)
local used, asc, sec, sockets = b.spec:CountAllocNodes()

local w = io.stderr
w:write("=== BASELINE Chrono_RotA ===\n")
w:write(string.format("Minion CombinedDPS = %.0f\n", t.MinionCombinedDPS or -1))
w:write(string.format("Minion CritChance  = %.2f%%\n", t.MinionCritChance or -1))
w:write(string.format("Minion CritMulti   = %.2f\n", t.MinionCritMultiplier or -1))
w:write(string.format("Resists F/C/L/Ch   = %d/%d/%d/%d\n",
  t.FireResist or -99, t.ColdResist or -99, t.LightningResist or -99, t.ChaosResist or -99))
w:write(string.format("Passive points: used=%d asc=%d sec=%d sockets=%d  (char Lv %s, %s/%s)\n",
  used, asc, sec, sockets, tostring(info.character.level),
  tostring(info.character.class), tostring(info.character.ascendancy)))

w:write("\n--- SKILL GROUPS (gems) ---\n")
for _, g in ipairs(info.skills) do
  w:write(string.format("[%d] slot=%s%s%s\n", g.index, tostring(g.slot),
    g.isMain and " *MAIN*" or "", g.enabled and "" or " (disabled)"))
  for _, gem in ipairs(g.gems) do
    w:write(string.format("      %-32s Lv%s Q%s%s\n", tostring(gem.name),
      tostring(gem.level), tostring(gem.quality), gem.enabled and "" or " off"))
  end
end

w:write("\n--- ITEMS (resolved mods) ---\n")
for _, it in ipairs(info.items) do
  w:write(string.format("[%s] %s (%s, %s)\n", it.slot, tostring(it.name),
    tostring(it.base), tostring(it.rarity)))
  for _, m in ipairs(it.mods) do
    w:write(string.format("      %-8s %s\n", m.kind, m.text))
  end
end

w:write("\n--- PASSIVES ---\n")
w:write("keystones: " .. table.concat(info.passives.keystones, ", ") .. "\n")
w:write(string.format("notables (%d): %s\n", #info.passives.notables,
  table.concat(info.passives.notables, ", ")))
w:write("\n--- JEWEL SOCKETS ---\n")
for _, js in ipairs(info.passives.jewelSockets) do
  w:write(string.format("socket %s slot=%s jewel=%s base=%s radius=%s notableCount=%d allocInRadius=%d geomInRadius=%d\n",
    tostring(js.socket), tostring(js.slot), tostring(js.jewel), tostring(js.base),
    tostring(js.radius), js.notableCount, js.totalAllocInRadius, js.totalInRadius))
end
w:write("\n=== END BASELINE ===\n")
