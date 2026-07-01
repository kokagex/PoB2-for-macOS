-- Structural build summary for build_info. Split out of calc.lua (2026-07-02);
-- calc.lua re-exports readInfo so callers keep requiring "calc". Read-only --
-- gives chat the same picture the GUI tabs show, so advice starts from the
-- actual build. Assumes boot.lua has run (globals available).
local M = {}

function M.readInfo(build)
  local spec = build.spec

  local items = {}
  for slotName, slot in pairs(build.itemsTab.slots) do
    local id = slot.selItemId
    -- Tree jewel sockets ("Jewel <nodeId>") are included only while their
    -- node is allocated -- that matches what the calc actually uses.
    local active = not slot.nodeId or spec.allocNodes[slot.nodeId]
    if id and id ~= 0 and active then
      local item = build.itemsTab.items[id]
      if item then
        -- Resolved mod text per item: on a normal build load the modLine .line
        -- already carries the rolled value (e.g. "Minions have 54% increased
        -- Critical Hit Chance"), so advice can see WHAT each piece actually
        -- grants without re-parsing the XML (the ModRange-stripping re-parse is
        -- exactly what under-rolled jewels and hid the tree's role earlier). The
        -- stored ModRange scalar is uniformly 0.5 metadata on game-copied items,
        -- so it is not surfaced -- the resolved text is the reliable signal.
        local mods = {}
        for _, kind in ipairs({ "enchant", "implicit", "explicit", "rune" }) do
          for _, ml in ipairs(item[kind .. "ModLines"] or {}) do
            if ml.line and ml.line ~= "" then
              mods[#mods + 1] = { kind = kind, text = ml.line }
            end
          end
        end
        items[#items + 1] = {
          slot = slotName,
          name = item.name,
          base = item.baseName,
          rarity = item.rarity,
          mods = mods,
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

  local allocated, keystones, notables, sockets = 0, {}, {}, {}
  for _, node in pairs(spec.allocNodes) do
    local name = node.dn or node.name
    if node.type == "Keystone" then
      keystones[#keystones + 1] = name
    elseif node.type == "Notable" then
      notables[#notables + 1] = name
    elseif node.type == "Socket" then
      -- Allocated jewel sockets: these ids are valid patch.items slots
      -- ("Jewel <id>").
      sockets[#sockets + 1] = node.id
    end
    if node.type ~= "ClassStart" and node.type ~= "AscendClassStart" then
      allocated = allocated + 1
    end
  end
  table.sort(keystones)
  table.sort(notables)
  table.sort(sockets)

  -- Per-jewel-socket radius analysis. THE super-additive lever for radius jewels
  -- (Time-Lost Sapphire etc.): "Notable Passive Skills in Radius also grant ..."
  -- applies the jewel's mod to every ALLOCATED notable in its radius, so the
  -- count is the multiplier -- a Time-Lost over 20 allocated notables grants +20x
  -- its per-notable bonus, over 0 it is dead weight. spec.nodes[socketId]
  -- .nodesInRadius[item.jewelRadiusIndex] is GEOMETRIC (every node physically in
  -- range, precomputed at tree-load), so it MUST be filtered by spec.allocNodes:
  -- only allocated notables receive/grant the jewel's mod. Without that filter
  -- two different trees with the same socket geometry report the same count and
  -- the tree's role (the exact lever that was missed) stays invisible. Plain
  -- jewels have no radius (radiusIndex nil) and convert nothing.
  local jewelSockets = {}
  for slotName, slot in pairs(build.itemsTab.slots) do
    if slot.nodeId and spec.allocNodes[slot.nodeId] then
      local id = slot.selItemId
      local item = id and id ~= 0 and build.itemsTab.items[id]
      if item then
        local socketNode = spec.nodes[slot.nodeId]
        local rIdx = item.jewelRadiusIndex
        local inRadius = socketNode and socketNode.nodesInRadius and rIdx
          and socketNode.nodesInRadius[rIdx]
        local radiusName = item.jewelRadiusLabel
        if not radiusName and rIdx and data and data.jewelRadius
          and data.jewelRadius[rIdx] then
          radiusName = data.jewelRadius[rIdx].label
        end
        -- allocated-only: notableCount = allocated notables the jewel converts;
        -- totalAllocInRadius = allocated nodes in radius; totalInRadius = all
        -- geometric nodes in radius (the upper bound if every node were taken).
        local names, allocTotal, geomTotal = {}, 0, 0
        if inRadius then
          for nodeId, node in pairs(inRadius) do
            geomTotal = geomTotal + 1
            if spec.allocNodes[nodeId] then
              allocTotal = allocTotal + 1
              if node.type == "Notable" then
                names[#names + 1] = node.dn or node.name
              end
            end
          end
        end
        table.sort(names)
        jewelSockets[#jewelSockets + 1] = {
          socket = slot.nodeId,
          slot = slotName,
          jewel = item.name,
          base = item.baseName,
          radius = radiusName,            -- nil => non-radius jewel (converts nothing)
          notableCount = #names,          -- ALLOCATED notables -> the actual multiplier
          totalAllocInRadius = allocTotal,-- allocated nodes (notable + normal) in radius
          totalInRadius = geomTotal,      -- all nodes geometrically in radius (upper bound)
          notables = names,
        }
      end
    end
  end
  table.sort(jewelSockets, function(a, b) return a.socket < b.socket end)

  local config = {}
  for k, v in pairs(build.configTab.input) do
    config[k] = v
  end

  -- Selected spectres (upstream v0.22.0 spectre support): Build.lua keeps the
  -- chosen spectre ids in build.spectreList (Modules/Build.lua:1905-1947).
  -- Surfaced so advice on a spectre build can see WHICH spectres are in play;
  -- empty on non-spectre builds.
  local spectres = {}
  for _, id in ipairs(build.spectreList or {}) do
    spectres[#spectres + 1] = id
  end

  return {
    character = {
      level = build.characterLevel,
      class = spec.curClass and spec.curClass.name,
      ascendancy = spec.curAscendClass and spec.curAscendClass.name,
    },
    items = items,
    skills = groups,
    spectres = spectres,
    passives = {
      allocated = allocated,
      keystones = keystones,
      notables = notables,
      sockets = sockets,
      jewelSockets = jewelSockets,
    },
    config = config,
  }
end

return M
