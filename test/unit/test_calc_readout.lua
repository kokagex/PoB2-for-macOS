-- busted: tests calc.readTopline shape against a fake build (no engine needed).
-- Run: eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_calc_readout.lua
package.path = package.path .. ";./mcp/worker/?.lua"
local calc = require("calc")

describe("calc.readTopline", function()
  it("extracts the v1 output keys from mainOutput", function()
    local fakeBuild = {
      calcsTab = {
        mainOutput = {
          FullDPS = 1234.5, TotalDPS = 1000, CombinedDPS = 1100,
          AverageDamage = 50, BleedDPS = 0, IgniteDPS = 200, PoisonDPS = 0,
          CritChance = 75, Speed = 4.2,
        },
      },
    }
    local t = calc.readTopline(fakeBuild)
    assert.are.equal(1234.5, t.FullDPS)
    assert.are.equal(200, t.IgniteDPS)
    assert.are.equal(75, t.CritChance)
    assert.are.equal(4.2, t.Speed)
  end)

  it("returns 0 (not nil) for missing keys", function()
    local t = calc.readTopline({ calcsTab = { mainOutput = {} } })
    assert.are.equal(0, t.FullDPS)
    assert.are.equal(0, t.TotalDPS)
  end)
end)
