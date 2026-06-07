-- busted: regression tests for the support-gem-swap hang (2026-06-07).
-- Root cause: sg_utf8_decode (sg_text.cpp:23-55) returns 0xFFFD WITHOUT
-- advancing on any invalid UTF-8 byte, and all four C draw loops only break on
-- codepoint==0 -> one invalid byte spins a draw call forever (76s spindump).
-- Trigger: DrawStringCursorIndex returns a 0-based GLYPH index that callers
-- used as a byte position -> clicking a ja gem name cut a character in half ->
-- the invalid buffer hit DrawStringWidth -> hang.
-- Run: eval "$(luarocks --lua-version 5.1 path)"; busted test/unit/test_utf8_guard.lua

local M = require("pob2_testable")
local band = require("bit").band
local s_byte = string.byte

-- ===========================================================================
-- Independent model of the C decoder (transcribed from sg_text.cpp:23-55).
-- Deliberately NOT shared with the sanitiser under test: it uses the C code's
-- actual mask expressions (which also advance on overlong C0/C1 and F5-F7
-- leads), so a sanitiser bug cannot hide behind a shared helper.
-- ===========================================================================

-- C reads through a NUL-terminated char*; bytes past the Lua string end model
-- the terminator (Lua strings are NUL-terminated in memory).
local function cByte(s, i)
  return s_byte(s, i) or 0
end

-- Returns codepoint, bytesAdvanced. advance==0 with codepoint==0xFFFD is the
-- non-advancing bug path. Codepoint values for valid multi-byte sequences are
-- collapsed to 1 (only ==0 matters for loop termination; the only way C
-- composes 0 from a multi-byte sequence is overlong "\xC0\x80", which breaks
-- the loop -- it still terminates, so the collapse is safe for this oracle).
local function cDecode(s, i)
  local b0 = cByte(s, i)
  if b0 == 0 then return 0, 0 end
  if band(b0, 0x80) == 0 then return b0, 1 end
  if band(b0, 0xE0) == 0xC0 then
    if band(cByte(s, i + 1), 0xC0) ~= 0x80 then return 0xFFFD, 0 end
    return 1, 2
  end
  if band(b0, 0xF0) == 0xE0 then
    if band(cByte(s, i + 1), 0xC0) ~= 0x80 or band(cByte(s, i + 2), 0xC0) ~= 0x80 then
      return 0xFFFD, 0
    end
    return 1, 3
  end
  if band(b0, 0xF8) == 0xF0 then
    if band(cByte(s, i + 1), 0xC0) ~= 0x80 or band(cByte(s, i + 2), 0xC0) ~= 0x80
        or band(cByte(s, i + 3), 0xC0) ~= 0x80 then
      return 0xFFFD, 0
    end
    return 1, 4
  end
  return 0xFFFD, 0
end

-- sg_parse_escape_code (sg_text.cpp:59-109): '^' then digit -> skip 2;
-- '^' then 'x' with strlen(from 'x') >= 7 and sscanf("%06x") success -> skip 8.
-- sscanf "%06x" succeeds on optional whitespace + at least one hex digit.
local function cParseEscape(s, i)
  if cByte(s, i) ~= 94 then return false end
  local nb = cByte(s, i + 1)
  if nb >= 48 and nb <= 57 then return true, i + 2 end
  if nb == 120 then
    for k = i + 1, i + 7 do -- strlen(s) >= 7, counted from the 'x'
      if cByte(s, k) == 0 then return false end
    end
    local hex6 = s:sub(i + 2, i + 7)
    if hex6:match("^%s*%x") then return true, i + 8 end
  end
  return false
end

-- Models the C draw loop: while(*s) { if escape -> skip, continue; decode;
-- if cp==0 break; advance }. Returns false iff the loop spins forever.
local function cLoopTerminates(s)
  local i = 1
  while cByte(s, i) ~= 0 do
    local esc, nexti = cParseEscape(s, i)
    if esc then
      i = nexti
    else
      local cp, adv = cDecode(s, i)
      if cp == 0 then return true end
      if adv == 0 then return false end -- non-advancing 0xFFFD: infinite loop
      i = i + adv
    end
  end
  return true
end

-- Byte position where each glyph starts, derived from the C model (input must
-- be sanitised). starts[k] = insertion point before glyph k-1 (0-based k-1).
local function cGlyphStarts(s)
  local starts = {}
  local i = 1
  while i <= #s and cByte(s, i) ~= 0 do
    local esc, nexti = cParseEscape(s, i)
    if esc then
      i = nexti
    else
      starts[#starts + 1] = i
      local _, adv = cDecode(s, i)
      assert(adv > 0, "cGlyphStarts requires sanitised input")
      i = i + adv
    end
  end
  return starts
end

-- ===========================================================================

describe("C decode loop model (the hang oracle)", function()
  it("RED: a mid-cut ja string spins the C loop forever", function()
    -- "魔" (3 bytes) + lead byte of "法": exactly what the old glyph-as-byte
    -- caret produced from a ja gem name click
    local cut = ("魔法烈波"):sub(1, 4)
    assert.is_false(cLoopTerminates(cut))
  end)

  it("GREEN: the same string sanitised terminates", function()
    local cut = ("魔法烈波"):sub(1, 4)
    local fixed = M.sanitiseUTF8(cut)
    assert.is_true(cLoopTerminates(fixed))
    assert.are.equal(#cut, #fixed) -- byte count preserved
    assert.are.equal("魔?", fixed)
  end)

  it("RED: the original EditControl trigger chain produced invalid UTF-8", function()
    -- Old code: caret = raw glyph index (0-based) used as byte position.
    -- Clicking between glyph 0 and 1 of a ja name -> caret=2 -> sub(1,1)
    -- keeps only the first byte of a 3-byte character.
    local buf = "魔法烈波"
    local oldPrefix = buf:sub(1, 2 - 1)
    assert.is_false(cLoopTerminates(oldPrefix))
    -- New code: glyph index 1 -> byte insertion position 4 -> valid prefix
    local caret = M.cursorGlyphToBytePos(buf, 1)
    assert.are.equal(4, caret)
    assert.is_true(cLoopTerminates(buf:sub(1, caret - 1)))
  end)

  it("every truncation point of a ja string is repaired by the sanitiser", function()
    local s = "クロノマンサーの魔法烈波"
    local sawInvalid = 0
    for cut = 0, #s do
      local raw = s:sub(1, cut)
      if M.utf8FirstInvalid(raw) then
        sawInvalid = sawInvalid + 1
        assert.is_false(cLoopTerminates(raw), "cut=" .. cut .. " should spin")
      end
      local fixed = M.sanitiseUTF8(raw)
      assert.is_true(cLoopTerminates(fixed), "cut=" .. cut .. " not repaired")
      assert.are.equal(cut, #fixed, "cut=" .. cut .. " changed byte count")
    end
    assert.is_true(sawInvalid > 0) -- the RED path was actually exercised
  end)

  it("every single byte 0x00-0xFF terminates after sanitising", function()
    for b = 0, 255 do
      local raw = string.char(b)
      if b >= 128 then
        -- every solo high byte spins the C loop (lead without continuation,
        -- stray continuation, or invalid lead -- all non-advancing)
        assert.is_false(cLoopTerminates(raw), "byte " .. b .. " should spin")
        assert.are.equal("?", M.sanitiseUTF8(raw))
      else
        assert.is_true(cLoopTerminates(raw), "byte " .. b)
      end
      assert.is_true(cLoopTerminates(M.sanitiseUTF8(raw)), "byte " .. b)
    end
  end)

  it("fuzz: random byte strings always terminate after sanitising", function()
    math.randomseed(12345) -- deterministic
    for trial = 1, 300 do
      local len = math.random(0, 64)
      local bytes = {}
      for k = 1, len do
        bytes[k] = string.char(math.random(0, 255))
      end
      local raw = table.concat(bytes)
      local fixed = M.sanitiseUTF8(raw)
      assert.is_true(cLoopTerminates(fixed), "trial " .. trial)
      assert.are.equal(#raw, #fixed, "trial " .. trial .. " changed byte count")
      assert.is_nil(M.utf8FirstInvalid(fixed), "trial " .. trial .. " still invalid")
    end
  end)
end)

describe("sanitiseUTF8", function()
  it("returns valid ja text unchanged (identity, no rebuild)", function()
    local s = "魔法烈波のクロノマンサー Lv.20"
    assert.are.equal(s, M.sanitiseUTF8(s))
  end)

  it("returns pure ASCII unchanged (fast path)", function()
    local s = "Faster Attacks Support (Tier 1)"
    assert.are.equal(s, M.sanitiseUTF8(s))
  end)

  it("preserves escape codes", function()
    local s = "^7Some ^xFF00AAcolour ^8text"
    assert.are.equal(s, M.sanitiseUTF8(s))
  end)

  it("replaces each invalid byte one-for-one", function()
    assert.are.equal("abc?def", M.sanitiseUTF8("abc\255def"))
    -- truncated 3-byte sequence: lead+continuation both invalid in isolation
    assert.are.equal("??", M.sanitiseUTF8("\233\173"))
    -- multiple runs
    assert.are.equal("a?魔?b", M.sanitiseUTF8("a\128魔\200b"))
  end)

  it("preserves embedded NUL (C stops there; not a hang risk)", function()
    local s = "ab\0cd"
    assert.are.equal(s, M.sanitiseUTF8(s))
    assert.is_true(cLoopTerminates(s))
  end)

  it("repairs the __clampDrawText mid-character cut (wrapper composition)", function()
    local long = ("魔"):rep(1000) -- 3000 bytes
    local clamped = long:sub(1, 2000) -- what __clampDrawText does
    assert.is_not_nil(M.utf8FirstInvalid(clamped)) -- cut lands mid-character
    local fixed = M.sanitiseUTF8(clamped)
    assert.is_true(cLoopTerminates(fixed))
    assert.are.equal(2000, #fixed)
  end)
end)

describe("cursorGlyphToBytePos", function()
  it("ASCII: glyph index N maps to byte N+1", function()
    assert.are.equal(1, M.cursorGlyphToBytePos("abc", 0))
    assert.are.equal(2, M.cursorGlyphToBytePos("abc", 1))
    assert.are.equal(4, M.cursorGlyphToBytePos("abc", 3))
    assert.are.equal(4, M.cursorGlyphToBytePos("abc", 99)) -- clamped past end
  end)

  it("ja: maps to character boundaries", function()
    assert.are.equal(1, M.cursorGlyphToBytePos("魔法烈", 0))
    assert.are.equal(4, M.cursorGlyphToBytePos("魔法烈", 1))
    assert.are.equal(7, M.cursorGlyphToBytePos("魔法烈", 2))
    assert.are.equal(10, M.cursorGlyphToBytePos("魔法烈", 3))
    assert.are.equal(10, M.cursorGlyphToBytePos("魔法烈", 99))
  end)

  it("skips ^N colour codes before the glyph check (C loop order)", function()
    assert.are.equal(3, M.cursorGlyphToBytePos("^7魔法", 0)) -- caret after ^7
    assert.are.equal(6, M.cursorGlyphToBytePos("^7魔法", 1))
    assert.are.equal(9, M.cursorGlyphToBytePos("^7魔法", 2))
  end)

  it("skips ^xRRGGBB codes", function()
    assert.are.equal(9, M.cursorGlyphToBytePos("^xFF00AA魔", 0))
    assert.are.equal(12, M.cursorGlyphToBytePos("^xFF00AA魔", 1))
  end)

  it("empty string and negative index return 1", function()
    assert.are.equal(1, M.cursorGlyphToBytePos("", 0))
    assert.are.equal(1, M.cursorGlyphToBytePos("", 99))
    assert.are.equal(1, M.cursorGlyphToBytePos("abc", -1))
  end)

  it("stops at embedded NUL like C's while(*s)", function()
    assert.are.equal(3, M.cursorGlyphToBytePos("ab\0cd", 2))
    assert.are.equal(3, M.cursorGlyphToBytePos("ab\0cd", 5))
  end)

  -- escape fidelity: exact match with sg_parse_escape_code's accept set
  it("'^x' with fewer than 6 bytes after is NOT an escape (strlen from 'x' < 7)", function()
    -- "^x12345": C sees strlen("x12345")==6 < 7 -> '^' renders as a glyph
    assert.are.equal(1, M.cursorGlyphToBytePos("^x12345", 0))
    assert.are.equal(2, M.cursorGlyphToBytePos("^x12345", 1)) -- 'x' is glyph 1
  end)

  it("'^x' with non-hex payload is NOT an escape (sscanf fails)", function()
    assert.are.equal(1, M.cursorGlyphToBytePos("^xGGGGGG", 0))
  end)

  it("'^x' with leading whitespace + hex IS an escape (sscanf accepts)", function()
    -- hex6 = " 1234A": sscanf("%06x") skips whitespace, reads hex -> skip 8
    assert.are.equal(9, M.cursorGlyphToBytePos("^x 1234AZ", 0))
  end)

  it("'^' followed by a non-digit non-x letter is a normal glyph", function()
    assert.are.equal(1, M.cursorGlyphToBytePos("^z魔", 0))
    assert.are.equal(2, M.cursorGlyphToBytePos("^z魔", 1))
    assert.are.equal(3, M.cursorGlyphToBytePos("^z魔", 2)) -- before 魔
    assert.are.equal(6, M.cursorGlyphToBytePos("^z魔", 3)) -- past end
  end)

  it("agrees with the C-model walk for every glyph index", function()
    local battery = {
      "abc", "魔法烈", "^7魔法", "^xFF00AA魔x", "a^1b^2c",
      "^x 1234AZ", "^xGGGGGG", "mix魔x^7字", "ab^7", "śćźż", "🔥魔a",
    }
    for _, s in ipairs(battery) do
      assert.is_nil(M.utf8FirstInvalid(s), s) -- battery must be sanitised-form
      local starts = cGlyphStarts(s)
      for N = 0, #starts - 1 do
        assert.are.equal(starts[N + 1], M.cursorGlyphToBytePos(s, N),
                         string.format("%q glyph %d", s, N))
      end
      assert.are.equal(#s + 1, M.cursorGlyphToBytePos(s, #starts),
                       string.format("%q past-end", s))
    end
  end)

  it("EditControl invariant: result is a valid insertion point", function()
    local buffers = { "魔法烈波", "Faster Attacks", "^7魔法 Mix 123", "śćźż", "🔥魔a" }
    for _, buf in ipairs(buffers) do
      for N = 0, 20 do
        local p = M.cursorGlyphToBytePos(buf, N)
        assert.is_true(p >= 1 and p <= #buf + 1,
                       string.format("%q N=%d p=%d out of range", buf, N, p))
        local prefix = buf:sub(1, p - 1)
        assert.is_nil(M.utf8FirstInvalid(prefix),
                      string.format("%q N=%d prefix invalid", buf, N))
        assert.is_true(cLoopTerminates(prefix))
      end
    end
  end)
end)
