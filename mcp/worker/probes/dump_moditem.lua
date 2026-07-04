-- Pin down the real data.itemMods entry schema (2-level: category -> modName ->
-- entry) so crit-affix extraction reads the right field. Full-dump a few Item
-- and Jewel mod entries: array parts + named fields.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local w = io.stderr

local function dumpEntry(modName, entry)
  w:write("\n=== [" .. modName .. "] type=" .. type(entry) .. " ===\n")
  if type(entry) ~= "table" then return end
  for i, vv in ipairs(entry) do
    w:write("  [" .. i .. "] " .. type(vv) .. ": " .. tostring(vv):sub(1, 80) .. "\n")
    if type(vv) == "table" then
      for k2, v2 in pairs(vv) do
        if type(v2) ~= "table" and type(v2) ~= "function" then
          w:write("        ." .. tostring(k2) .. "=" .. tostring(v2):sub(1, 50) .. "\n")
        end
      end
    end
  end
  for k, vv in pairs(entry) do
    if type(k) ~= "number" then
      w:write("  ." .. tostring(k) .. "=" .. type(vv))
      if type(vv) == "string" or type(vv) == "number" or type(vv) == "boolean" then
        w:write(": " .. tostring(vv):sub(1, 60))
      elseif type(vv) == "table" then
        local arr = {}
        for i = 1, math.min(4, #vv) do arr[#arr + 1] = tostring(vv[i]):sub(1, 40) end
        w:write(": [" .. table.concat(arr, " | ") .. "]")
      end
      w:write("\n")
    end
  end
end

for _, cat in ipairs({ "Item", "Jewel" }) do
  local pool = data.itemMods[cat]
  w:write("\n########## data.itemMods." .. cat .. " (type=" .. type(pool) .. ") ##########\n")
  if type(pool) == "table" then
    local cnt = 0
    for modName, entry in pairs(pool) do
      cnt = cnt + 1
      if cnt <= 2 then dumpEntry(modName, entry) end
    end
    local total = 0; for _ in pairs(pool) do total = total + 1 end
    w:write("\ntotal " .. cat .. " mods = " .. total .. "\n")
  end
end
