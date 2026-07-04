-- Enumerate candidate SUPPORT gems from data.gems (sample-free, engine-derived).
-- We don't yet know the field that flags "support", so dump structure + collect
-- names via several candidate markers, so the swap search has a real candidate set.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local w = io.stderr

-- 1) learn the shape: print keys of one gem entry
local sampleKey
for k, g in pairs(data.gems) do sampleKey = k; break end
local g0 = data.gems[sampleKey]
w:write("sample gem key = " .. tostring(sampleKey) .. "\n")
w:write("sample gem name = " .. tostring(g0 and g0.name) .. "\n")
w:write("top-level keys: ")
for k, v in pairs(g0 or {}) do w:write(k .. "(" .. type(v) .. ") ") end
w:write("\n")
if g0 and g0.grantedEffect then
  w:write("grantedEffect keys: ")
  for k, v in pairs(g0.grantedEffect) do w:write(k .. "(" .. type(v) .. ") ") end
  w:write("\n")
end
if g0 and g0.tags then
  w:write("tags: ")
  for k, v in pairs(g0.tags) do w:write(k .. "=" .. tostring(v) .. " ") end
  w:write("\n")
end

-- 2) collect support gem names via grantedEffect.support / tags.support
local supports = {}
for _, g in pairs(data.gems) do
  if g.name then
    local isSup = (g.grantedEffect and g.grantedEffect.support)
      or (g.tags and g.tags.support)
      or (g.gemTypeList and (function()
            for _, t in ipairs(g.gemTypeList) do if t == "Support" then return true end end
          end)())
    if isSup then supports[#supports + 1] = g.name end
  end
end
table.sort(supports)
w:write(string.format("\n=== %d support gems ===\n", #supports))
for i, n in ipairs(supports) do
  w:write(string.format("%-30s%s", n, (i % 3 == 0) and "\n" or ""))
end
w:write("\n")
