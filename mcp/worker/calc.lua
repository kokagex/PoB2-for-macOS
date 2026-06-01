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

-- Loads a build from XML, fully resetting build-level state. The expensive Data
-- load stays warm across calls; only the build object is rebuilt.
function M.loadBuild(xml)
  loadBuildFromXML(xml, "mcp")
  return _G.build
end

-- Slice 1 patch surface: config input keys, enemyLevel, full passive-tree replace.
--   patch = { config = {k=v,...}, enemyLevel = N, treeURL = "https://..." }
function M.applyPatch(build, patch)
  if not patch then return end
  if patch.treeURL and patch.treeURL ~= "" then
    -- A tree URL imports a complete node set, so there is no pathing problem.
    build.treeTab:LoadURL(patch.treeURL)
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

-- Full request handler: load -> patch -> recalc -> topline.
function M.handle(req)
  assert(req and req.buildXml, "request requires buildXml")
  local build = M.loadBuild(req.buildXml)
  M.applyPatch(build, req.patch)
  build.calcsTab:BuildOutput()
  return M.readTopline(build)
end

return M
