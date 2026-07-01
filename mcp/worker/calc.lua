-- Engine glue for the headless calc worker: load a build, apply a patch, read
-- the v1 top-line output keys. Assumes boot.lua has run (globals available).
--
-- Split (2026-07-02): patch application lives in patch.lua, the build_info
-- summary in info.lua. This module keeps the output readers + request
-- dispatch, and re-exports applyPatch/resolveSkillGroup/readInfo so every
-- existing caller (server.lua and the probe scripts) keeps requiring "calc".
local patch = require("patch")
local info = require("info")

local M = {}

-- Facade: the public API predates the split; keep it stable.
M.applyPatch = patch.applyPatch
M.resolveSkillGroup = patch.resolveSkillGroup
M.readInfo = info.readInfo

local TOPLINE_KEYS = {
  "FullDPS", "TotalDPS", "CombinedDPS", "AverageDamage",
  "BleedDPS", "IgniteDPS", "PoisonDPS", "CritChance", "Speed",
}

-- Minion/summon builds put ~0 in the player keys above and the real DPS in the
-- minion sub-table (build.calcsTab.mainOutput.Minion), the same object PoB saves
-- as <MinionStat> (Modules/Build.lua:1997: mainOutput.Minion[stat]). Surface it
-- under a "Minion" prefix so a single calc serves both player and minion builds.
local MINION_TOPLINE_KEYS = {
  "CombinedDPS", "TotalDPS", "AverageDamage", "Speed",
  "CritChance", "CritMultiplier",
}

-- Append minion keys (prefixed) + an EffectiveDPS that combines player and
-- minion CombinedDPS exactly as PoB does (Classes/CalcsTab.lua:700-701), so the
-- headline DPS is non-zero for both build types. Missing keys default to 0
-- (never nil), and on a pure-player build (out.Minion nil) every Minion* key is
-- 0 and EffectiveDPS == CombinedDPS, leaving player builds unchanged.
local function appendMinion(t, out)
  local m = out.Minion
  for _, k in ipairs(MINION_TOPLINE_KEYS) do
    t["Minion" .. k] = (m and m[k]) or 0
  end
  t.EffectiveDPS = (out.CombinedDPS or 0) + (m and m.CombinedDPS or 0)
end

-- Pull the v1 output keys; missing keys default to 0 (never nil).
function M.readTopline(build)
  local out = (build.calcsTab and build.calcsTab.mainOutput) or {}
  local t = {}
  for _, k in ipairs(TOPLINE_KEYS) do
    t[k] = out[k] or 0
  end
  appendMinion(t, out)
  return t
end

-- Richer key set for calc_breakdown: DPS, crit, speed/hit, and per-damage-type
-- hit averages, so chat can explain "why this number" and find levers. All keys
-- verified present on a real mainOutput; absent ones default to 0.
local BREAKDOWN_KEYS = {
  -- Offence
  "FullDPS", "TotalDPS", "CombinedDPS", "AverageDamage", "AverageHit",
  "CritChance", "CritMultiplier", "CritEffect", "Speed", "AccuracyHitChance",
  "PhysicalHitAverage", "FireHitAverage", "ColdHitAverage",
  "LightningHitAverage", "ChaosHitAverage",
  "BleedDPS", "IgniteDPS", "PoisonDPS",
  "ManaCost", "LifeCost",
  -- Defence (the PoB engine computes the full mainOutput; these were previously
  -- not surfaced, which made the worker look offence-only. Key names verified
  -- against a real mainOutput dump. Absent keys default to 0.)
  "Life", "LifeUnreserved", "Mana", "EnergyShield", "Ward",
  "TotalEHP", "EHPSurvivalTime",
  "Armour", "Evasion", "PhysicalDamageReduction", "MeleeEvadeChance",
  "FireResist", "ColdResist", "LightningResist", "ChaosResist",
  "PhysicalMaximumHitTaken", "FireMaximumHitTaken", "ColdMaximumHitTaken",
  "LightningMaximumHitTaken", "ChaosMaximumHitTaken",
  "BlockChance", "SpellBlockChance", "BlockChanceMax", "SpellSuppressionChance",
}

-- Minion breakdown: the levers behind a minion build's DPS (crit, speed, hit,
-- per-element hit averages, DoT) plus minion survivability. All verified present
-- on a real mainOutput.Minion dump; absent keys default to 0. Emitted under a
-- "Minion" prefix alongside the player keys so one breakdown explains both.
local MINION_BREAKDOWN_KEYS = {
  "CombinedDPS", "TotalDPS", "AverageDamage", "AverageHit", "Speed",
  "CritChance", "CritMultiplier", "CritEffect", "HitChance", "AccuracyHitChance",
  "PhysicalHitAverage", "FireHitAverage", "ColdHitAverage",
  "LightningHitAverage", "ChaosHitAverage",
  "WithBleedDPS", "WithIgniteDPS", "WithPoisonDPS", "TotalDotDPS",
  "Life", "EnergyShield",
}

function M.readBreakdown(build)
  local out = (build.calcsTab and build.calcsTab.mainOutput) or {}
  local t = {}
  for _, k in ipairs(BREAKDOWN_KEYS) do
    t[k] = out[k] or 0
  end
  local m = out.Minion
  for _, k in ipairs(MINION_BREAKDOWN_KEYS) do
    t["Minion" .. k] = (m and m[k]) or 0
  end
  t.EffectiveDPS = (out.CombinedDPS or 0) + (m and m.CombinedDPS or 0)
  return t
end

-- Loads a build from XML, fully resetting build-level state. The expensive Data
-- load stays warm across calls; only the build object is rebuilt.
function M.loadBuild(xml)
  loadBuildFromXML(xml, "mcp")
  return _G.build
end

-- Serialise the (possibly patched) build to a PoB import code, so the user can
-- paste it into the PoB GUI. Format: base64url(zlib_deflate(SaveDB("code"))),
-- matching ImportTab.lua:130 / Build.lua:2447. Requires real Deflate (boot.lua).
function M.exportCode(build)
  local xml = build:SaveDB("code")
  local b64 = common.base64.encode(Deflate(xml))
  return (b64:gsub("+", "-"):gsub("/", "_"))
end

-- Full request handler. req.op selects the operation (default "calc"):
--   "calc"   -> load -> patch -> recalc -> topline output table
--   "export" -> load -> patch -> { code = <PoB import code> }
--   "info"   -> load -> patch -> structural build summary (no recalc)
function M.handle(req)
  assert(req and req.buildXml, "request requires buildXml")
  local build = M.loadBuild(req.buildXml)
  M.applyPatch(build, req.patch)
  if req.op == "export" then
    return { code = M.exportCode(build) }
  end
  if req.op == "info" then
    return M.readInfo(build)
  end
  build.calcsTab:BuildOutput()
  if req.op == "breakdown" then
    return M.readBreakdown(build)
  end
  return M.readTopline(build)
end

return M
