-- busted: regression test for the ddsMap / spriteMap nil-handle crash.
-- Run: eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_ddsmap_nil_handle.lua
--
-- Symptom: "src/Classes/PassiveTreeView.lua:664: attempt to index field 'handle'
-- (a nil value)" in OnFrame, on 0_4 (and older) trees whose .dds.zst texture arrays
-- the macOS port cannot load.
--
-- Root cause: PassiveTree:LoadAssets()'s ddsMap failed-load else branch stored
-- handle = nil, violating the asset invariant that every record carries a non-nil
-- image handle (the success branch and every spriteMap entry store handle =
-- data.handle). GetAssetByName returns the ddsMap entry first, so consumers that
-- call handle:ImageSize() (PassiveTreeView 664/1368, Tooltip 47) deref nil and crash.
--
-- Fix: store handle = data.handle -- the valid, empty handle LoadImage always creates
-- via NewImageHandle() (non-nil) for any non-nil imgName (ddsCoords keys, from pairs(),
-- are structurally never nil, so LoadImage's `if not imgName then return` early-out
-- cannot fire on this path and data.handle = NewImageHandle() always runs).
--
-- This test models BOTH the populate (fix vs no-fix) and the consume (verbatim
-- PassiveTreeView line 663-666) under BOTH possible ImageSize contracts:
--   * zero-contract : ImageSize() returns 0,0   -- the PROVEN real contract
--       (sg_image.cpp:487 reads img->width, calloc-zeroed, only set on valid==true;
--        FFI imageHandleMT:ImageSize returns w[0],h[0] which are always numbers ->
--        never nil. pob2_launch.lua:638).
--   * nil-contract  : ImageSize() returns nil,nil -- COUNTERFACTUAL, included to prove
--       the fix's sufficiency DEPENDS on the zero-contract.
--
-- NOTE: this models a COPY of the populate/consume logic and can drift from
-- PassiveTree.lua. The load-bearing recurrence guard is the in-code load-time
-- invariant in PassiveTree:LoadAssets() (errors with the asset name if any
-- ddsMap/spriteMap record has a nil handle). This test is a fast CI canary that
-- documents the crash mechanism and the 0,0-contract dependency.

-- A handle whose Load() failed. ImageSize() returns whatever the contract dictates.
local function make_handle(contract)
  return setmetatable({ _failed = true }, { __index = {
    ImageSize = function(_)
      if contract == "zero" then return 0, 0 end
      return nil, nil   -- counterfactual nil-contract
    end,
  } })
end

-- LoadImage ALWAYS assigns data.handle = NewImageHandle() (a non-nil wrapper),
-- then ImageSize fills width/height. A failed disk/archive load leaves width = 0.
local function fake_LoadImage(contract)
  local data = {}
  data.handle = make_handle(contract)   -- non-nil even on failure (PassiveTree.lua:778)
  data.width, data.height = 0, 0         -- failed load -> 0,0
  return data
end

-- Populate one ddsMap entry exactly as the else (failed-load) branch does.
local function populate_else_branch(with_fix, contract)
  local data = fake_LoadImage(contract)
  return {
    found = false,
    handle = with_fix and data.handle or nil,   -- fix: data.handle (non-nil); defect: nil
    width = 0,
    height = 0,
    [1] = 0,
  }
end

-- Consume verbatim per PassiveTreeView.lua:663-666 (the crash site).
-- Returns true if a draw would happen, false if cleanly skipped.
local function consume_background(bg)
  if bg.width == 0 then
    bg.width, bg.height = bg.handle:ImageSize()   -- line 664 (crashes if handle nil)
  end
  if bg.width > 0 then                             -- line 666 VERBATIM (no nil guard)
    return true   -- would DrawImage
  end
  return false    -- cleanly skipped
end

describe("ddsMap nil-handle crash", function()
  describe("without the fix (handle = nil)", function()
    it("crashes the consumer under the real zero-contract", function()
      local bg = populate_else_branch(false, "zero")
      assert.has_error(function() consume_background(bg) end)
    end)

    it("crashes the consumer under the nil-contract too", function()
      local bg = populate_else_branch(false, "nil")
      assert.has_error(function() consume_background(bg) end)
    end)
  end)

  describe("with the fix (handle = data.handle)", function()
    it("does not crash under the proven zero-contract", function()
      local bg = populate_else_branch(true, "zero")
      assert.has_no_error(function() consume_background(bg) end)
    end)

    it("cleanly skips the draw (width stays 0) under the zero-contract", function()
      local bg = populate_else_branch(true, "zero")
      assert.is_false(consume_background(bg))
    end)

    it("STILL crashes under the counterfactual nil-contract "
      .."(proves the zero-contract is load-bearing)", function()
      local bg = populate_else_branch(true, "nil")
      assert.has_error(function() consume_background(bg) end)
    end)
  end)
end)
