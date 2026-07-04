-- On the legal-geared build, dump the minion skill's gem setup (active + supports,
-- with level/quality) and the spec point usage, to see if there's free legal DPS
-- in gem levels/quality or unspent passive points before declaring 87% the ceiling.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()
local w = io.stderr

local b = calc.loadBuild(xml)
b.calcsTab:BuildOutput()
-- walk skills
local st = b.skillsTab
w:write("=== socket groups ===\n")
for gi, grp in ipairs(st.socketGroupList or {}) do
  w:write(string.format("[grp %d] label=%s slot=%s enabled=%s\n", gi, tostring(grp.label),
    tostring(grp.slot), tostring(grp.enabled)))
  for _, g in ipairs(grp.gemList or {}) do
    local gd = g.gemData
    local nm = gd and gd.name or g.nameSpec
    w:write(string.format("    - %-26s lvl=%s qual=%s enabled=%s%s\n", tostring(nm),
      tostring(g.level), tostring(g.quality), tostring(g.enabled),
      (gd and gd.tags and gd.tags.support) and " [support]" or ""))
  end
end
-- main skill + minion
local ms = b.calcsTab and b.calcsTab.mainEnv and b.calcsTab.mainEnv.player and b.calcsTab.mainEnv.player.mainSkill
w:write("\nmainSkill activeEffect gem: " .. tostring(ms and ms.activeEffect and ms.activeEffect.grantedEffect and ms.activeEffect.grantedEffect.name) .. "\n")
local used, asc, sec, sockets = b.spec:CountAllocNodes()
w:write(string.format("points: used=%s asc=%s sec=%s sockets=%s\n", tostring(used), tostring(asc), tostring(sec), tostring(sockets)))
local t = calc.readBreakdown(b)
w:write(string.format("baseline (orig gear) MinionCombinedDPS=%.0f\n", t.MinionCombinedDPS))
