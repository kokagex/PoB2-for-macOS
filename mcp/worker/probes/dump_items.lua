-- Dump every equipped item (slot -> title + rarity + mod lines) on the ORIGINAL
-- build, so we can see which slots are uniques (keep) vs rares (craftable), and
-- specifically whether any slot beyond the dual sceptre already carries
-- "+Level of all Minion Skills". That mod is GLOBAL and stacks across slots
-- (sceptre max +4 each, helmet +2, amulet +3, focus) -- the last big legal lever.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local CUR = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local f = assert(io.open(CUR, "r")); local xml = f:read("*a"); f:close()
local w = io.stderr
local b = calc.loadBuild(xml)
local it = b.itemsTab
w:write("=== equipped items by slot ===\n")
local slotOrder = {}
for name in pairs(it.slots or {}) do slotOrder[#slotOrder + 1] = name end
table.sort(slotOrder)
for _, sname in ipairs(slotOrder) do
  local slot = it.slots[sname]
  local id = slot and slot.selItemId
  if id and id ~= 0 then
    local item = it.items[id]
    if item then
      w:write(string.format("\n[%s] %s  (rarity=%s, base=%s)\n", sname,
        tostring(item.title or item.name), tostring(item.rarity), tostring(item.baseName)))
      -- print explicit/implicit mod lines
      for _, line in ipairs(item.explicitModLines or {}) do
        w:write("    " .. tostring(line.line) .. "\n")
      end
      -- flag minion-level mods
      local raw = tostring(item.raw or "")
      if raw:lower():find("minion skill") then w:write("    >>> carries +Minion Skill level\n") end
    end
  end
end
