-- CONSTRUCTION + faithful attribution. The additive ladder (current + sample
-- pieces) is CONFOUNDED: the Time-Lost jewel x tree-notable co-design only exists
-- when BOTH real items are present, so piecewise transplant destroys it and
-- reports the tree as ~0 (it contradicts test T inside the same data). Instead:
-- start from the REAL sample (validated 1,298,012) and revert ONE lever
-- sample->current; the DPS drop = that lever's true contribution. Only the
-- reverted slot touches parseItems, and reverted items carry baked roll values,
-- so every run is faithful. Finally export the validated top-tier build code.
-- Run: cwd=src/, CI=1, luarocks paths.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
local HOME = os.getenv("HOME")
local SAMPLE = HOME .. "/Library/Application Support/Path of Building/Builds/sample.xml"
local CUR    = HOME .. "/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml"
local function readXml(p) local f=assert(io.open(p,"r")) local s=f:read("*a") f:close() return s end

-- parseItems on a build XML -> name->raw (baked mod text; child-XML/ModRange
-- stripped, but reverted items only need their baked values, which survive).
local function trim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
local function unescape(s) return (s:gsub("&apos;","'"):gsub("&quot;",'"'):gsub("&gt;",">"):gsub("&lt;","<"):gsub("&amp;","&")) end
local function parseItems(xml)
  local items, cur, cap = {}, nil, false
  for line in xml:gmatch("[^\n]+") do
    local t = trim(line)
    if t:match("^<Item ") then cap, cur = true, {}
    elseif t:match("^</Item>") then
      if cur and #cur>0 then local nm for i,l in ipairs(cur) do if l:match("^Rarity:") then nm=cur[i+1] break end end
        if nm then items[unescape(nm)]=unescape(table.concat(cur,"\n")) end end
      cap,cur=false,nil
    elseif cap then if not t:match("^<") and t~="" then cur[#cur+1]=t end end
  end
  return items
end
local C = parseItems(readXml(CUR))
local function curRaw(k) for n,r in pairs(C) do if n:find(k,1,true) then return r end end end

local SAMPLE_XML = readXml(SAMPLE)
local CUR_NODES = readXml(CUR):match('<Spec [^>]-nodes="([^"]*)"')

local function measure(label, patch, xmlOverride)
  local b = calc.loadBuild(xmlOverride or SAMPLE_XML)
  local ok, err = pcall(function() if patch then calc.applyPatch(b, patch) end; b.calcsTab:BuildOutput() end)
  if not ok then io.stderr:write(string.format("%-50s FAILED: %s\n", label, tostring(err))); return end
  local t = calc.readBreakdown(b)
  io.stderr:write(string.format("%-50s minDPS=%10.0f Cr%%=%5.1f Mult=%.2f | EHP=%7.0f F/C/L=%d/%d/%d\n",
    label, t.MinionCombinedDPS or 0, t.MinionCritChance or 0, t.MinionCritMultiplier or 0,
    t.TotalEHP or 0, t.FireResist or 0, t.ColdResist or 0, t.LightningResist or 0))
  return t.MinionCombinedDPS or 0
end

io.stderr:write("=== SUBTRACTIVE ATTRIBUTION (revert one lever sample->current; drop = its real contribution) ===\n")
local base = measure("0 SAMPLE (top-tier, validated target)", nil)

-- Lever: rings (Behemoth Twirl + Kalandra's Touch -> current Evergrasping x2)
measure("- rings -> current Evergrasping x2", { items = {
  { slot="Ring 1", raw=curRaw("Evergrasping") }, { slot="Ring 2", raw=curRaw("Evergrasping") } } })

-- Lever: the two Time-Lost jewels -> current plain Sapphires (tree notables stay
-- allocated but nothing converts them -> isolates the jewel crit-conversion).
measure("- Time-Lost jewels -> current Sapphires", { items = {
  { slot="Jewel 21984", raw=curRaw("Vivid Stone") }, { slot="Jewel 61419", raw=curRaw("Armageddon Essence") } } })

-- Lever: From Nothing (Diamond) -> current Blight Shine
measure("- From Nothing -> current Blight Shine", { items = {
  { slot="Jewel 7960", raw=curRaw("Blight Shine") } } })

-- Lever: pure-DPS supports (remove sample's Rakiata's Flow + Tul's Stillness)
measure("- supports (remove Rakiata's Flow+Tul's)", { gems = {
  { name="Rakiata's Flow", group=1, remove=true }, { name="Tul's Stillness", group=1, remove=true } } })

-- Lever: amulet/helmet/weapon -> current
measure("- amulet/helm/weapon -> current", { items = {
  { slot="Amulet", raw=curRaw("Rift Clasp") }, { slot="Helmet", raw=curRaw("Rune Visage") },
  { slot="Weapon 1", raw=curRaw("Behemoth Breaker") } } })

-- Lever: tree -> current (test T; jewels stay real so the co-design is intact)
do
  local SAMPLE_CURTREE = SAMPLE_XML:gsub('(<Spec [^>]-nodes=")[^"]*(")', '%1' .. CUR_NODES .. '%2', 1)
  measure("- tree -> current (test T)", nil, SAMPLE_CURTREE)
end

io.stderr:write(string.format("\n  (each row's drop from %.0f = that lever's contribution to the top-tier build)\n", base or 0))

-- DELIVERABLE: export the validated top-tier build as an import code.
io.stderr:write("\n=== EXPORT: upgraded Chrono_RotA (= validated top-tier config) ===\n")
do
  local b = calc.loadBuild(SAMPLE_XML)
  b.calcsTab:BuildOutput()
  local ok, code = pcall(calc.exportCode, b)
  if ok and code then
    local out = "/private/tmp/claude-501/-Users-kokage-national-operations/c8ddf0e2-3483-4c82-aa16-2b9dd36bc6bd/scratchpad/upgraded_chrono_rota.code"
    local f = io.open(out, "w"); if f then f:write(code.code or code); f:close() end
    io.stderr:write("  export OK -> " .. out .. " (len=" .. #(code.code or code) .. ")\n")
  else
    io.stderr:write("  export FAILED: " .. tostring(code) .. "\n")
  end
end
io.stderr:write("\n=== done ===\n")
