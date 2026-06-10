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

-- Resolve a node reference (numeric id, or exact node name case-insensitive)
-- to a node in the build's spec. Names are not unique on the tree (small nodes
-- like "Cast Speed" repeat), so name matches are first narrowed to nodes in
-- the state the operation wants (wantAlloc: dealloc targets allocated nodes,
-- alloc targets unallocated ones); a still-ambiguous name is a hard error
-- listing the candidate ids -- the caller retries with an id. Unknown refs are
-- hard errors too, mirroring skillName: a silently ignored node is a
-- plausible-looking wrong answer.
local function resolveNode(spec, ref, wantAlloc)
  if type(ref) == "number" then
    local node = spec.nodes[ref]
    if not node then
      error(string.format("passive node id %d not found in tree", ref))
    end
    return node
  end
  local want = tostring(ref):lower()
  local matches = {}
  for _, node in pairs(spec.nodes) do
    local name = node.dn or node.name
    if name and name:lower() == want then
      matches[#matches + 1] = node
    end
  end
  if #matches > 1 then
    local narrowed = {}
    for _, node in ipairs(matches) do
      if (not node.alloc) == (not wantAlloc) then
        narrowed[#narrowed + 1] = node
      end
    end
    if #narrowed > 0 then matches = narrowed end
  end
  if #matches == 0 then
    error(string.format(
      "passive node %q not found (exact name or numeric id; data_passives lists candidates)",
      tostring(ref)))
  end
  if #matches > 1 then
    local ids = {}
    for _, node in ipairs(matches) do ids[#ids + 1] = tostring(node.id) end
    error(string.format("passive node name %q is ambiguous; use an id: %s",
      tostring(ref), table.concat(ids, ", ")))
  end
  return matches[1]
end

-- Equip items given as raw PoB item text (e.g. data_uniques detail `raw`).
-- Each entry needs an explicit slot; fit is validated before equipping so a
-- mismatched slot errors instead of silently calculating the old item.
local function applyItems(build, items)
  local itemsTab = build.itemsTab
  for _, entry in ipairs(items) do
    assert(type(entry) == "table" and entry.raw and entry.slot,
      "patch.items entries require { slot, raw }")
    local slot = itemsTab.slots[entry.slot]
    if not slot then
      local names = {}
      for name, s in pairs(itemsTab.slots) do
        if not s.nodeId then names[#names + 1] = name end
      end
      table.sort(names)
      error(string.format("slot %q not found; slots: %s",
        tostring(entry.slot), table.concat(names, ", ")))
    end
    local item = new("Item", entry.raw)
    if not item.base then
      error(string.format("could not parse item text: unknown base %q (item %q)",
        tostring(item.baseName), tostring(item.name)))
    end
    if not itemsTab:IsItemValidForSlot(item, entry.slot) then
      error(string.format("item %q (%s) does not fit slot %q",
        tostring(item.name), tostring(item.baseName), entry.slot))
    end
    itemsTab:AddItem(item, true)
    slot:SetSelItemId(item.id)
  end
end

-- Deallocate then allocate passive nodes by ref. AllocNode pays the travel
-- path to the node (matching a real respec). It returns silently when no path
-- exists, so allocation is verified afterwards -- a no-op alloc must error,
-- not produce an unchanged "comparison".
local function applyNodes(build, deallocRefs, allocRefs)
  local spec = build.spec
  for _, ref in ipairs(deallocRefs or {}) do
    local node = resolveNode(spec, ref, true)
    if not node.alloc then
      error(string.format("deallocNodes: node %q (%d) is not allocated",
        tostring(node.dn or node.name), node.id))
    end
    spec:DeallocNode(node)
  end
  for _, ref in ipairs(allocRefs or {}) do
    local node = resolveNode(spec, ref, false)
    if node.alloc then
      error(string.format("allocNodes: node %q (%d) is already allocated",
        tostring(node.dn or node.name), node.id))
    end
    spec:AllocNode(node)
    if not spec.allocNodes[node.id] then
      error(string.format(
        "allocNodes: no path to node %q (%d) from the current tree",
        tostring(node.dn or node.name), node.id))
    end
  end
end

-- Patch surface: config input keys, enemyLevel, full passive-tree replace,
-- incremental node alloc/dealloc, item equip from raw text, main-skill select
-- by gem name.
--   patch = { config = {k=v,...}, enemyLevel = N, treeURL = "https://...",
--             allocNodes = { "Heavy Buffer", 12345 }, deallocNodes = {...},
--             items = { { slot = "Body Armour", raw = "..." } },
--             skillName = "Eye of Winter" }
function M.applyPatch(build, patch)
  if not patch then return end
  if patch.treeURL and patch.treeURL ~= "" then
    -- A tree URL imports a complete node set, so there is no pathing problem.
    build.treeTab:LoadURL(patch.treeURL)
  end
  if patch.deallocNodes or patch.allocNodes then
    -- After treeURL, so incremental edits apply to the replaced tree.
    applyNodes(build, patch.deallocNodes, patch.allocNodes)
  end
  if patch.items then
    applyItems(build, patch.items)
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

-- Structural summary of a loaded build: who it is, what it wears, what it
-- casts, which passives it took, what config is set. Read-only -- gives chat
-- the same picture the GUI tabs show, so advice starts from the actual build.
function M.readInfo(build)
  local spec = build.spec

  local items = {}
  for slotName, slot in pairs(build.itemsTab.slots) do
    local id = slot.selItemId
    if id and id ~= 0 and not slot.nodeId then
      local item = build.itemsTab.items[id]
      if item then
        items[#items + 1] = {
          slot = slotName,
          name = item.name,
          base = item.baseName,
          rarity = item.rarity,
        }
      end
    end
  end
  table.sort(items, function(a, b) return a.slot < b.slot end)

  local groups = {}
  for index, group in ipairs(build.skillsTab.socketGroupList) do
    local gems = {}
    for _, gem in ipairs(group.gemList or {}) do
      gems[#gems + 1] = {
        name = gem.nameSpec,
        level = gem.level,
        quality = gem.quality,
        enabled = gem.enabled,
      }
    end
    groups[#groups + 1] = {
      index = index,
      slot = group.slot,
      enabled = group.enabled,
      isMain = index == build.mainSocketGroup,
      gems = gems,
    }
  end

  local allocated, keystones, notables = 0, {}, {}
  for _, node in pairs(spec.allocNodes) do
    local name = node.dn or node.name
    if node.type == "Keystone" then
      keystones[#keystones + 1] = name
    elseif node.type == "Notable" then
      notables[#notables + 1] = name
    end
    if node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
      allocated = allocated + 1
    end
  end
  table.sort(keystones)
  table.sort(notables)

  local config = {}
  for k, v in pairs(build.configTab.input) do
    config[k] = v
  end

  return {
    character = {
      level = build.characterLevel,
      class = spec.curClass and spec.curClass.name,
      ascendancy = spec.curAscendClass and spec.curAscendClass.name,
    },
    items = items,
    skills = groups,
    passives = {
      allocated = allocated,
      keystones = keystones,
      notables = notables,
    },
    config = config,
  }
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
