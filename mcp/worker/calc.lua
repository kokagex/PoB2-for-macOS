-- Engine glue for the headless calc worker: load a build, apply a patch, read
-- the v1 top-line output keys. Assumes boot.lua has run (globals available).
local M = {}

local TOPLINE_KEYS = {
  "FullDPS", "TotalDPS", "CombinedDPS", "AverageDamage",
  "BleedDPS", "IgniteDPS", "PoisonDPS", "CritChance", "Speed",
}

-- Pull the v1 output keys; missing keys default to 0 (never nil).
function M.readTopline(build)
  local out = (build.calcsTab and build.calcsTab.mainOutput) or {}
  local t = {}
  for _, k in ipairs(TOPLINE_KEYS) do
    t[k] = out[k] or 0
  end
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

function M.readBreakdown(build)
  local out = (build.calcsTab and build.calcsTab.mainOutput) or {}
  local t = {}
  for _, k in ipairs(BREAKDOWN_KEYS) do
    t[k] = out[k] or 0
  end
  return t
end

-- Loads a build from XML, fully resetting build-level state. The expensive Data
-- load stays warm across calls; only the build object is rebuilt.
function M.loadBuild(xml)
  loadBuildFromXML(xml, "mcp")
  return _G.build
end

-- Resolve a gem name to its socket-group index. mainOutput is computed for the
-- group build.mainSocketGroup points at (CalcSetup.lua:1606, mode "MAIN"), so
-- selecting a skill by name means moving that pointer. Matching is
-- case-insensitive on gem nameSpec; the FIRST matching group wins, and the
-- group's main active skill stays whatever the build saved (a name that only
-- appears as a support still selects its group). Unknown names are a hard
-- error -- silently keeping the XML's group is exactly the bug this fixes.
function M.resolveSkillGroup(build, skillName)
  local want = skillName:lower()
  local seen, names = {}, {}
  for index, group in ipairs(build.skillsTab.socketGroupList) do
    for _, gem in ipairs(group.gemList or {}) do
      local name = gem.nameSpec
      if name and name ~= "" then
        if name:lower() == want then
          return index
        end
        if not seen[name] then
          seen[name] = true
          names[#names + 1] = name
        end
      end
    end
  end
  error(string.format("skillName %q not found in build; gems present: %s",
    skillName, table.concat(names, ", ")))
end

-- Slice 1 patch surface: config input keys, enemyLevel, full passive-tree
-- replace, main-skill select by gem name.
--   patch = { config = {k=v,...}, enemyLevel = N, treeURL = "https://...",
--             skillName = "Eye of Winter" }
function M.applyPatch(build, patch)
  if not patch then return end
  if patch.treeURL and patch.treeURL ~= "" then
    -- A tree URL imports a complete node set, so there is no pathing problem.
    build.treeTab:LoadURL(patch.treeURL)
  end
  if patch.skillName and patch.skillName ~= "" then
    build.mainSocketGroup = M.resolveSkillGroup(build, patch.skillName)
  end
  -- configTab.input is aliased to the active config set's input (ConfigTab.lua:1090),
  -- so writing here targets the right table. But the compiled config modList is only
  -- rebuilt by BuildModList() -- buildFlag/BuildOutput alone leaves it stale, which
  -- silently no-ops the config. So always rebuild after touching config.
  local configTouched = false
  if patch.config then
    for k, v in pairs(patch.config) do
      build.configTab.input[k] = v
    end
    configTouched = true
  end
  if patch.enemyLevel then
    -- UpdateLevel() (called by BuildModList) reads input.enemyLevel (ConfigTab.lua:917).
    build.configTab.input.enemyLevel = patch.enemyLevel
    configTouched = true
  end
  if configTouched then
    build.configTab:BuildModList()
  end
  build.buildFlag = true
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
function M.handle(req)
  assert(req and req.buildXml, "request requires buildXml")
  local build = M.loadBuild(req.buildXml)
  M.applyPatch(build, req.patch)
  if req.op == "export" then
    return { code = M.exportCode(build) }
  end
  build.calcsTab:BuildOutput()
  if req.op == "breakdown" then
    return M.readBreakdown(build)
  end
  return M.readTopline(build)
end

return M
