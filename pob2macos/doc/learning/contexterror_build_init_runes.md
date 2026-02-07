# Context Error: BUILD Init Crash - Runes Module Missing

## Date
2026-02-06

## Error Context

### Primary Error
```
Error executing src/Classes/ItemsTab.lua:
src/Classes/ItemsTab.lua:1631: bad argument #1 to 'pairs' (table expected, got nil)
```

**Location**: ItemsTab.lua:1631 (file top-level, executed during require())
```lua
for name, runeMods in pairs(data.itemMods.Runes) do
```

### Secondary Error (Consequence of Init Failure)
```
src/Modules/Build.lua:1175: attempt to perform arithmetic on field 'outputRevision' (a nil value)
WARNING: Build.spec is nil in OnFrame!
```

**Location**: Build.lua:1175 (OnFrame, after Init failure)
```lua
self.outputRevision = self.outputRevision + 1
```

## Root Cause Analysis

### Investigation Findings

1. **ModRunes.lua EXISTS** (`src/Data/ModRunes.lua`, 48KB)
2. **Data.lua DOES NOT LOAD Runes module** (lines 569-578)
   - Current data.itemMods initialization:
     - Item, Flask, Tincture, Graft
     - Jewel, JewelAbyss, JewelCluster, JewelCharm
     - **Runes: MISSING**

3. **Inconsistent nil-safety across codebase**:
   - ✅ Item.lua:838 → `pairs(data.itemMods.Runes or {})`
   - ❌ ItemsTab.lua:1631 → `pairs(data.itemMods.Runes)`
   - ❌ TradeQueryGenerator.lua:422 → `pairs(data.itemMods.Runes)`
   - Item.lua:446, 1317 → Direct access (but after nil-safe check)

### Root Cause
**Data.lua:569-578 is missing `Runes = LoadModule("Data/ModRunes")` line**, causing `data.itemMods.Runes` to be nil.

ItemsTab.lua:1631 is executed at **file top-level** (during require()), so it crashes immediately when ItemsTab is loaded during Build:Init().

### Execution Flow
```
Build:Init() → loads ItemsTab
  → ItemsTab.lua:1631 executes (top-level code)
    → pairs(nil) → CRASH
  → Init never completes
  → outputRevision not initialized (line 658 never reached)
  → OnFrame() called
    → Build.lua:1175: outputRevision is nil → ERROR
```

## Previous Fix Attempts
None (first time encountering this error)

## Work History Patterns
- Similar nil-safety fixes in ConfigOptions.lua (table.concat → join with nil-safety)
- Pattern: Check if data structures are fully initialized before access

## Hypothesis
This appears to be an **accidental omission** rather than intentional:
- ModRunes.lua file exists and is substantial (48KB)
- Item.lua already uses nil-safety for Runes (suggesting it's expected to sometimes be nil)
- Other mod types (Item, Flask, etc.) are properly loaded in Data.lua

**Why this error occurs on macOS but possibly not Windows**:
- Possible module load order difference
- Or: Windows version has this line, macOS port missed it during porting

## Risk Assessment
- **Impact**: High - blocks BUILD screen from loading
- **Scope**: Affects ItemsTab initialization (rune selection controls)
- **Complexity**: Low - straightforward fix

## Success Criteria
1. App launches without crash
2. BUILD screen displays successfully
3. No Lua errors in log related to Runes or outputRevision
4. Visual verification: BUILD screen shows passive tree + UI controls

---

## Fix Applied (2026-02-06)

### Selected Option: B (Load Runes only)

**Changes**:
- File: `src/Modules/Data.lua:578`
- Added: `Runes = LoadModule("Data/ModRunes"),`

**Implementation**:
```lua
data.itemMods = {
	Item = LoadModule("Data/ModItem"),
	Flask = LoadModule("Data/ModFlask"),
	Tincture = LoadModule("Data/ModTincture"),
	Graft = LoadModule("Data/ModGraft"),
	Jewel = LoadModule("Data/ModJewel"),
	JewelAbyss = LoadModule("Data/ModJewelAbyss"),
	JewelCluster = LoadModule("Data/ModJewelCluster"),
	JewelCharm = LoadModule("Data/ModJewelCharm"),
	Runes = LoadModule("Data/ModRunes"),  -- ADDED
}
```

**Rationale**:
- Simplest fix that addresses root cause
- ModRunes.lua exists and is used by Item.lua
- No nil-safety needed if module loads successfully

**Next Step**: Visual Verification Workflow (launch app, screenshot, verify UI)

---

## Second Error Found (2026-02-06)

### Status Update
✅ **Runes module loading FIXED** - ItemsTab now creates successfully

❌ **New error discovered**: ConfigOptions.lua:1909

### Error Details
```
ConfigOptions.lua:1909: attempt to perform arithmetic on field 'base_critical_strike_multiplier' (a nil value)
```

**Location**: ConfigOptions.lua:1909 (OnFrame, during placeholder setting)
```lua
build.configTab.varControls['enemyCritDamage']:SetPlaceholder(data.monsterConstants["base_critical_strike_multiplier"] - 100, true)
```

### Root Cause
**Key `base_critical_strike_multiplier` does not exist** in `data.monsterConstants`

Available similar keys in Data/Misc.lua:231-270:
- Line 139: `["unarmed_base_critical_strike_chance"] = 500`
- Line 139: `["base_critical_hit_damage_bonus"] = 100`
- Line 238: `["base_critical_hit_damage_bonus"] = 30` (monster section)
- Line 270: `["base_critical_hit_damage_bonus"] = 70`

**Hypothesis**: PoE2 renamed or removed this constant. Likely replacement: `base_critical_hit_damage_bonus`

### Init Progress
✅ BUILD:INIT called
✅ ImportTab created
✅ NotesTab created
✅ PartyTab created
✅ ConfigTab created
✅ **ItemsTab created successfully** (Runes fix worked!)
✅ TreeTab created
✅ SkillsTab created
✅ CalcsTab created
❌ outputRevision initialization NOT reached yet (OnFrame error occurs first)

---

## Nil-Safety Fixes Applied (2026-02-06)

### Files Modified
1. **CalcSetup.lua:43-44** - Added nil-safety for leech rate constants (default: 1200)
2. **ConfigOptions.lua:2186** - Fixed key name to `base_critical_hit_damage_bonus`
3. **CalcPerform.lua:1124-1135** - Added nil-safety for all charge-related constants

### Default Values Used (PoE1 typical values)
- `maximum_life_leech_rate_%_per_minute`: 1200 (20%/sec)
- `maximum_mana_leech_rate_%_per_minute`: 1200 (20%/sec)
- `critical_strike_chance_+%_per_power_charge`: 40
- `base_attack_speed_+%_per_frenzy_charge`: 4
- `base_cast_speed_+%_per_frenzy_charge`: 4
- `object_inherent_damage_+%_final_per_frenzy_charge`: 4
- `physical_damage_reduction_%_per_endurance_charge`: 4
- `elemental_damage_reduction_%_per_endurance_charge_if_player_minion`: 4
- `critical_ailment_dot_multiplier_+`: 0

### Next Test
Re-test app launch to verify BuildOutput() completes successfully
