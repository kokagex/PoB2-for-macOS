-- BLOCKING verification: the deliverable is the SERIALIZED .code, not the live
-- patched spec. Decode each .code back to XML, BuildOutput, and assert the DPS
-- matches what we claimed. Failure mode guarded: if exportCode serialized from
-- the original XML string instead of the modified spec.allocNodes, B would
-- silently carry sample's tree and import to 1,298,012, not 1,487,814.
package.path = "../mcp/worker/?.lua;" .. package.path
dofile("../mcp/worker/boot.lua")
local calc = require("calc")
-- `common` is a PoB global installed by boot.lua/HeadlessWrapper (not a module)
local common = _G.common
assert(common and common.base64, "common.base64 unavailable")
local OUT = "/private/tmp/claude-501/-Users-kokage-national-operations/c8ddf0e2-3483-4c82-aa16-2b9dd36bc6bd/scratchpad/"

local function decode(code)
  -- reverse base64url -> base64, then Inflate -> XML (inverse of exportCode)
  local b64 = code:gsub("-", "+"):gsub("_", "/")
  return Inflate(common.base64.decode(b64))
end

local function measure_from_code(path)
  local f = assert(io.open(path, "r")); local code = f:read("*a"); f:close()
  code = code:gsub("%s+$", "")
  local xml = decode(code)
  local b = calc.loadBuild(xml)
  b.calcsTab:BuildOutput()
  local t = calc.readBreakdown(b)
  return t, (select(1, b.spec:CountAllocNodes()))
end

local cases = {
  { name = "A upgraded (==sample)",        path = OUT .. "upgraded_chrono_rota.code",         expect = 1298012 },
  { name = "B beyond-reference (+14.6%)",  path = OUT .. "beyond_reference_chrono_rota.code", expect = 1487814 },
}
io.stderr:write("=== round-trip: decode .code -> XML -> BuildOutput ===\n")
local allok = true
for _, c in ipairs(cases) do
  local ok, t, used = pcall(measure_from_code, c.path)
  if not ok then
    io.stderr:write(string.format("  %-30s DECODE/BUILD FAILED: %s\n", c.name, tostring(t)))
    allok = false
  else
    local got = t.MinionCombinedDPS
    local diff = got - c.expect
    local pass = math.abs(diff) < 1500   -- allow tiny float drift only
    if not pass then allok = false end
    io.stderr:write(string.format("  %-30s used=%d minDPS=%10.0f expect=%d (%+.0f) %s  Cr%%=%.1f F/C/L=%d/%d/%d\n",
      c.name, used, got, c.expect, diff, pass and "PASS" or "*** FAIL ***",
      t.MinionCritChance, t.FireResist, t.ColdResist, t.LightningResist))
  end
end
io.stderr:write(allok and "\n=== ALL PASS — artifacts reproduce claimed DPS ===\n"
                     or  "\n=== FAIL — artifact diverges from claim ===\n")
