-- Build-independent game-data queries against the booted PoB engine: gems,
-- uniques, item bases, passive-tree nodes. Assumes boot.lua has run (data/main
-- globals available). List ops return { total, returned, results } so a capped
-- list is never mistaken for the full set; detail lookups by exact name are a
-- hard error when nothing matches (silent empties hide typos).
local M = {}

local DEFAULT_LIMIT = 20

local function contains(s, sub)
  return s ~= nil and s:lower():find(sub:lower(), 1, true) ~= nil
end

-- Sort + cap a result list, reporting the uncapped total.
local function capped(list, limit, sortKey)
  table.sort(list, function(a, b) return tostring(a[sortKey]) < tostring(b[sortKey]) end)
  limit = tonumber(limit) or DEFAULT_LIMIT
  local out = {}
  for i = 1, math.min(#list, limit) do out[i] = list[i] end
  return { total = #list, returned = #out, results = out }
end

-- ---------------------------------------------------------------------------
-- data_gems: list { search?, gemType? ("skill"|"support"), limit? }
--            detail { name } -> requirements, description, per-level summary
-- ---------------------------------------------------------------------------

local function gemDetail(gem)
  local ge = gem.grantedEffect or {}
  local levels = {}
  for lvl, info in pairs(ge.levels or {}) do
    if type(lvl) == "number" then
      levels[#levels + 1] = {
        level = lvl,
        levelRequirement = info.levelRequirement,
        cost = info.cost,
      }
    end
  end
  table.sort(levels, function(a, b) return a.level < b.level end)
  local granted = {}
  for _, eff in ipairs(gem.grantedEffectList or {}) do
    granted[#granted + 1] = eff.name
  end
  return {
    name = gem.name,
    type = ge.support and "support" or "skill",
    tags = gem.tagString,
    description = ge.description,
    reqStr = gem.reqStr, reqDex = gem.reqDex, reqInt = gem.reqInt,
    naturalMaxLevel = gem.naturalMaxLevel,
    grantedEffects = granted,
    levels = levels,
  }
end

function M.gems(args)
  if args.name then
    local want = args.name:lower()
    for _, gem in pairs(data.gems) do
      if gem.name and gem.name:lower() == want then
        return gemDetail(gem)
      end
    end
    error(string.format("gem %q not found; use search for a substring match", args.name))
  end
  local seen, list = {}, {}
  for _, gem in pairs(data.gems) do
    local typeStr = (gem.grantedEffect and gem.grantedEffect.support) and "support" or "skill"
    if gem.name and not seen[gem.name]
        and (not args.search or contains(gem.name, args.search) or contains(gem.tagString, args.search))
        and (not args.gemType or args.gemType == typeStr) then
      seen[gem.name] = true
      list[#list + 1] = { name = gem.name, type = typeStr, tags = gem.tagString }
    end
  end
  return capped(list, args.limit, "name")
end

-- ---------------------------------------------------------------------------
-- data_uniques: list { search? (name/base), textSearch? (anywhere in item text),
--                      type? ("body", "ring", ...), limit? }
--               detail { name } -> parsed mods + raw text (raw feeds patch.items)
-- ---------------------------------------------------------------------------

local function modLineTexts(modLines)
  local out = {}
  for _, modLine in ipairs(modLines or {}) do
    out[#out + 1] = modLine.line
  end
  return out
end

local function uniqueDetail(utype, raw)
  local item = new("Item", raw)
  return {
    name = item.title or item.name,
    base = item.baseName,
    type = utype,
    league = item.league,
    implicits = modLineTexts(item.implicitModLines),
    mods = modLineTexts(item.explicitModLines),
    -- Raw PoB item text: pass straight to patch.items[{slot, raw}] to equip it.
    raw = raw,
  }
end

function M.uniques(args)
  if args.name then
    local want = args.name:lower()
    for utype, arr in pairs(data.uniques) do
      for _, raw in ipairs(arr) do
        local itemName = raw:match("^%s*([^\r\n]+)")
        if itemName and itemName:lower() == want then
          return uniqueDetail(utype, raw)
        end
      end
    end
    error(string.format("unique %q not found; use search for a substring match", args.name))
  end
  local list, types = {}, {}
  for utype, arr in pairs(data.uniques) do
    types[#types + 1] = utype
    if not args.type or args.type == utype then
      for _, raw in ipairs(arr) do
        local name, base = raw:match("^%s*([^\r\n]+)[\r\n]+([^\r\n]+)")
        if name
            and (not args.search or contains(name, args.search) or contains(base, args.search))
            and (not args.textSearch or contains(raw, args.textSearch)) then
          list[#list + 1] = { name = name, base = base, type = utype }
        end
      end
    end
  end
  table.sort(types)
  local out = capped(list, args.limit, "name")
  out.types = types
  return out
end

-- ---------------------------------------------------------------------------
-- data_passives: { search? (name or stat text), type? ("Notable"|"Keystone"|
--                  "Normal"|"Socket"), ascendancy?, limit? }
-- Always includes stats per node, so no separate detail mode is needed.
-- ---------------------------------------------------------------------------

-- Node types that are pure tree furniture, never advice-relevant.
local SKIP_NODE_TYPES = { OnlyImage = true, ClassStart = true, AscendClassStart = true }

function M.passives(args)
  local tree = main:LoadTree(latestTreeVersion)
  local list = {}
  for id, node in pairs(tree.nodes) do
    local ntype = node.type
    local name = node.dn or node.name
    if not SKIP_NODE_TYPES[ntype] and name
        and (not args.type or args.type == ntype)
        and (not args.ascendancy or (node.ascendancyName and contains(node.ascendancyName, args.ascendancy))) then
      local stats = node.sd or node.stats or {}
      local hit = not args.search or contains(name, args.search)
      if not hit and args.search then
        for _, line in ipairs(stats) do
          if contains(line, args.search) then hit = true break end
        end
      end
      if hit then
        list[#list + 1] = {
          id = node.id or id,
          name = name,
          type = ntype,
          ascendancy = node.ascendancyName,
          stats = stats,
        }
      end
    end
  end
  return capped(list, args.limit, "name")
end

-- ---------------------------------------------------------------------------
-- data_itembases: { search?, type? ("Body Armour", ...), subType?, limit? }
-- ---------------------------------------------------------------------------

function M.itembases(args)
  local list, types, seenType = {}, {}, {}
  for name, base in pairs(data.itemBases) do
    if not seenType[base.type] then
      seenType[base.type] = true
      types[#types + 1] = base.type
    end
    if (not args.search or contains(name, args.search))
        and (not args.type or args.type == base.type)
        and (not args.subType or args.subType == base.subType) then
      list[#list + 1] = {
        name = name,
        type = base.type,
        subType = base.subType,
        reqLevel = base.req and base.req.level,
        armour = base.armour,
        weapon = base.weapon,
      }
    end
  end
  table.sort(types)
  local out = capped(list, args.limit, "name")
  out.types = types
  return out
end

-- ---------------------------------------------------------------------------

local OPS = {
  data_gems = M.gems,
  data_uniques = M.uniques,
  data_passives = M.passives,
  data_itembases = M.itembases,
}

function M.knows(op)
  return OPS[op] ~= nil
end

function M.handle(req)
  return OPS[req.op](req.args or {})
end

return M
