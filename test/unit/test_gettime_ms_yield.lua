-- busted: regression test for the GetTime() seconds-vs-ms unit fix.
-- Run: eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_gettime_ms_yield.lua
--
-- Symptom: passive tree shown (esp. "show node power" / heatMap) pegs CPU and the
-- node-power recalc freezes a whole frame on macOS.
--
-- Root cause: sg.GetTime() returns SECONDS on macOS (sg_core.cpp: tv_sec + tv_nsec/1e9),
-- but every upstream src/ consumer assumes MILLISECONDS (Windows PoB semantics). The fix
-- wraps the global at the GUI boundary: `_G.GetTime = function() return sg.GetTime()*1000 end`
-- (pob2_launch.lua). The load-bearing consequence this test pins down is CalcsTab
-- PowerBuilder's cooperative yield gate `GetTime() - start > 100`: in the seconds regime
-- "100" means 100 SECONDS, so a ~2s full-tree walk NEVER yields and runs in one frame
-- (freeze + CPU spike on every heatMap rebuild); in the ms regime it fires every 100ms.
--
-- NOTE: this models a COPY of CalcsTab's yield gate (src/Classes/CalcsTab.lua:632) and the
-- macOS clock regime. It does NOT exercise the real _G.GetTime wrap in pob2_launch.lua —
-- the live fix is that one-line boundary wrap. This test is a fast CI canary that documents
-- the unit-mismatch mechanism and proves the regime is what changes yielding behaviour.
-- It deliberately tests ONLY the yield-gate (the root-cause fix), not the additive adaptive
-- frame-pacing constants or the DOUBLE_CLICK_TIME ms flip shipped alongside it.

local NODE_COUNT    = 4000   -- realistic full-tree spec size
local MS_PER_NODE   = 0.5    -- simulated per-node calc cost (wall-clock)
local TOTAL_WALL_MS = NODE_COUNT * MS_PER_NODE   -- 2000 ms total

-- Deterministic fake monotonic clock. `unit_per_ms` selects the regime:
--   1.0    => GetTime() returns ms   (the wrap is in place: sg.GetTime()*1000)
--   0.001  => GetTime() returns sec  (no wrap: raw sg.GetTime() on macOS)
local function make_clock(unit_per_ms)
  local elapsed_ms = 0
  return function() return elapsed_ms * unit_per_ms end,
         function(dt_ms) elapsed_ms = elapsed_ms + dt_ms end
end

-- Run the PowerBuilder-style loop inside a coroutine, advancing the fake clock
-- by MS_PER_NODE each node, and count how many times it yields.
local function count_yields(GetTime, advance)
  local yields = 0
  local co = coroutine.create(function()
    local start = GetTime()
    for _ = 1, NODE_COUNT do
      advance(MS_PER_NODE)              -- simulate the per-node work cost
      -- verbatim gate from src/Classes/CalcsTab.lua:632
      if coroutine.running() and GetTime() - start > 100 then
        coroutine.yield()
        start = GetTime()
      end
    end
  end)
  while true do
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
    if coroutine.status(co) == "dead" then break end
    yields = yields + 1
  end
  return yields
end

describe("GetTime() ms-normalization yield gate", function()
  -- ~19: floor(2000/100) - 1, allowing one boundary slack node.
  local expected_ms_yields = math.floor(TOTAL_WALL_MS / 100) - 1

  it("never yields in the seconds regime (no wrap) -> whole calc in one frame (FREEZE)", function()
    local get, adv = make_clock(0.001)
    assert.are.equal(0, count_yields(get, adv))
  end)

  it("yields ~once per 100ms in the ms regime (boundary wrap) -> calc spread across frames", function()
    local get, adv = make_clock(1.0)
    assert.is_true(count_yields(get, adv) >= expected_ms_yields)
  end)
end)
