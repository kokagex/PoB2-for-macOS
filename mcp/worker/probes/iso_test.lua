-- ISOLATION test (advisor): the v1 greedy (1,017,105) came out BELOW the known-good
-- round-trip-verified legal_build (1,129,411). At least two variables moved at once:
-- Bidding II->III AND Muster level (legal_build keeps Muster@1; the strip/re-add
-- method returns Muster@20) AND main-group force-max. Toggle ONE at a time on FRESH
-- builds to find which flip drops DPS. Tests the "leveling gems is always free DPS"
-- assumption directly -- if Muster@20 < Muster@1, gem level is an optimization
-- variable, not a monotonic max, and the optimizer's action space must include it.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()
local w = io.stderr

local function sceptre(title)
  return table.concat({ title, "Rattling Sceptre",
    "Allies in your Presence deal 119% increased Damage",
    "Allies in your Presence deal 19 to 32 added Attack Physical Damage",
    "65% increased Spirit", "+4 to Level of all Minion Skills",
    "Allies in your Presence have 38% increased Critical Hit Chance",
    "Allies in your Presence have 39% increased Critical Damage Bonus" }, "\n")
end
local function jewel(title)
  return table.concat({ title, "Sapphire",
    "Minions deal 16% increased Damage", "Minions have 25% increased Critical Damage Bonus",
    "Minions have 20% increased Critical Hit Chance", "Minions have 4% increased Attack and Cast Speed" }, "\n")
end
local function gear(b)
  calc.applyPatch(b, { items = {
    { slot = "Weapon 1", raw = sceptre("A") }, { slot = "Weapon 2", raw = sceptre("B") },
    { slot = "Jewel 7960", raw = jewel("J1") }, { slot = "Jewel 21984", raw = jewel("J2") },
    { slot = "Jewel 61419", raw = jewel("J3") },
  } })
end
local function mg(b) return b.skillsTab.socketGroupList[b.mainSocketGroup] end
local function dps(b) b.calcsTab:BuildOutput(); return calc.readBreakdown(b).MinionCombinedDPS end
-- legal_build's swaps: Frost Nexus->Rakiata, Encroaching Ground->Commandment,
-- Bidding III->Bidding II, Hulking Minions->Concentrated Area (Muster kept @ orig lvl)
local function swaps(biddingTier)
  return { gems = {
    { name = "Frost Nexus", remove = true }, { name = "Rakiata's Flow" },
    { name = "Encroaching Ground", remove = true }, { name = "Commandment" },
    { name = "Bidding III", remove = true }, { name = "Bidding " .. biddingTier },
    { name = "Hulking Minions", remove = true }, { name = "Concentrated Area" },
  } }
end
local function setGemLevel(b, gemName, lvl, qual)
  local grp = mg(b)
  for _, g in ipairs(grp.gemList or {}) do
    local nm = (g.gemData and g.gemData.name) or g.nameSpec
    if nm == gemName then g.level = lvl; if qual then g.quality = qual end end
  end
  b.skillsTab:ProcessSocketGroup(grp); b.buildFlag = true
end
local function dumpLevels(b)
  local grp = mg(b); local s = {}
  for _, g in ipairs(grp.gemList or {}) do
    local nm = (g.gemData and g.gemData.name) or g.nameSpec
    s[#s + 1] = string.format("%s(L%s/Q%s)", nm, tostring(g.level), tostring(g.quality))
  end
  return table.concat(s, " ")
end

-- A: legal_build exact (Bidding II, Muster at original level, no main-max)
local A = calc.loadBuild(xml); gear(A); calc.applyPatch(A, swaps("II"))
w:write(string.format("A  legal_build exact (BiddingII, Muster orig)     %.0f\n", dps(A)))
w:write("   main-group: " .. dumpLevels(A) .. "\n")

-- B: A but Bidding III instead of II
local B = calc.loadBuild(xml); gear(B); calc.applyPatch(B, swaps("III"))
w:write(string.format("B  = A but Bidding III                            %.0f\n", dps(B)))

-- C: A but Muster leveled 1->20
local C = calc.loadBuild(xml); gear(C); calc.applyPatch(C, swaps("II")); setGemLevel(C, "Muster", 20, 20)
w:write(string.format("C  = A but Muster->L20/Q20                        %.0f\n", dps(C)))

-- D: A but ALL main-group gems maxed to 20/20 (the v2 final step)
local D = calc.loadBuild(xml); gear(D); calc.applyPatch(D, swaps("II"))
do local grp = mg(D); for _, g in ipairs(grp.gemList or {}) do g.level = 20; g.quality = 20 end
  D.skillsTab:ProcessSocketGroup(grp); D.buildFlag = true end
w:write(string.format("D  = A but ALL main-group gems L20/Q20            %.0f\n", dps(D)))

-- E: A but Muster removed (4 supports) -- Muster's marginal value at orig level
local E = calc.loadBuild(xml); gear(E); calc.applyPatch(E, swaps("II"))
calc.applyPatch(E, { gems = { { name = "Muster", remove = true } } })
w:write(string.format("E  = A but Muster removed (4 supports)            %.0f\n", dps(E)))

-- F: A but only the ACTIVE minion gem maxed to Q20 (supports+Muster untouched)
local Fb = calc.loadBuild(xml); gear(Fb); calc.applyPatch(Fb, swaps("II"))
do local grp = mg(Fb)
  for _, g in ipairs(grp.gemList or {}) do
    local nm = (g.gemData and g.gemData.name) or g.nameSpec
    local isSup = g.gemData and g.gemData.tags and g.gemData.tags.support
    if not isSup then g.level = 20; g.quality = 20 end
  end
  grp = mg(Fb); Fb.skillsTab:ProcessSocketGroup(grp); Fb.buildFlag = true end
w:write(string.format("F  = A but only ACTIVE gem maxed Q20              %.0f\n", dps(Fb)))
