# Data Loading Architecture Analysis

**Date**: 2026-02-05
**Analyst**: Prophet + Explore Agent
**Source**: `/Users/kokage/national-operations/pob2macos/dev/pob2-original/src/Modules/Data.lua`
**Purpose**: Stage 1 Step 1 - Understand Windows version data loading for macOS port

---

## Executive Summary

**Current Implementation**: Pure PoE1 (Path of Exile 1) data module
- Supports tree versions 2_6 through 3_27 (end of PoE1 cycle)
- No PoE2 systems present
- 51 data files loaded in specific sequence
- **CRITICAL**: This is PoE1 codebase, NOT PoE2

**Impact on macOS Port**: High - PoE1 vs PoE2 compatibility is major risk

---

## 1. Complete Load Order (51 Files)

### Foundation Layer (MUST Load First)
1. `Data/Global` - ColorCodes, ModFlags, KeywordFlags, SkillTypes
2. `Data/Misc` - Game constants, character stats, monster tables

### Modifier Definitions (Parallel Load Possible)
3-12. ModItem, ModFlask, ModTincture, ModGraft, ModJewel, ModJewelAbyss, ModJewelCluster, ModJewelCharm, ModMaster, ModVeiled

### Enchantments (Sequential)
13-19. EnchantmentHelmet, Boots, Gloves, Belt, Body, Weapon (template), Flask

### Game Systems (Sequential)
20-27. Essence, BeastCraft, ModNecropolis, Crucible, Pantheons, Costs, ModMap

### Jewel Systems
28-31. ClusterJewels, TimelessJewelData (2 files), TimelessJewel lookup helper

### Enemy Systems
32-33. Bosses, BossSkills

### Skill System (CRITICAL SEQUENCE)
34. SkillStatMap (template)
35-41. Skills/* (act_str, act_dex, act_int, other, glove, minion, spectre, sup_*)
42. **Gems** (MUST load AFTER Skills)

### Minion System
43-44. Minions, Spectres

### Item System (Parallel Load Possible)
45-46. Bases/* (18 item types: axe, bow, claw, dagger, etc.)
47-48. Rares, Uniques/*
49. FlavourText

---

## 2. Critical Data Tables Created

### Core Tables
```lua
data.powerStatList          -- Sortable stat columns
data.misc                   -- Game constants
data.keystones              -- Keystone passives (50+)
data.ailmentTypeList        -- All ailments
data.weaponTypeInfo         -- Weapon classification
```

### Modifier System
```lua
data.itemMods = {
    Item, Flask, Tincture, Graft,
    Jewel, JewelAbyss, JewelCluster, JewelCharm
}
data.masterMods             -- Master crafting
data.enchantments = {
    ["Helmet"], ["Boots"], ["Gloves"], ["Belt"],
    ["Body Armour"], ["Weapon"], ["UtilityFlask"]
}
data.essences, data.veiledMods, data.beastCraft
data.necropolisMods, data.crucible
```

### Skill & Gem System
```lua
data.skills = {             -- ALL active/support skills
    [skillId] = {
        id, name, modSource,
        baseMods, qualityMods, levelMods,
        skillTypes, statMap, grantedEffect
    }
}
data.gems = {               -- Gem instances (items)
    [gemId] = {
        id, name, baseTypeName,
        grantedEffectId,    -- LINKS to data.skills
        grantedEffect,      -- Cached reference
        levels, tags, reqStr/Dex/Int
    }
}
data.gemForSkill            -- Reverse: skill → gem
data.gemForBaseName         -- Search: "name" → gemId
```

### Item System
```lua
data.itemBases = {          -- Item base templates
    [baseName] = {
        name, type, subType,
        req = {level, str, dex, int},
        armour, evasion, energy_shield,
        physical_damage, fire_damage, etc.
    }
}
data.uniques = {            -- Unique items by type
    ["axe"], ["body"], ["helmet"], ...
}
data.rares                  -- Rare item templates
data.flavourText            -- Flavor text lookup
```

### Minion System
```lua
data.minions = {
    [minionName] = {
        name, modList, skillList, limit
    }
}
data.spectres               -- Merged into minions
```

### Jewel System
```lua
data.jewelRadius            -- Current radius definitions
data.jewelRadii = {
    ["3_15"], ["3_16"]      -- PoE1 versions
}
data.setJewelRadiiGlobally()  -- Set by tree version
data.clusterJewels          -- Cluster jewel defs
data.timelessJewelTypes     -- Timeless jewel IDs
```

### Boss System
```lua
data.bosses = {
    [name] = { isUber, armourMult, evasionMult }
}
data.bossStats              -- Pre-computed averages
data.bossSkills             -- Boss skill definitions
```

---

## 3. Critical Dependencies

### MUST Follow Load Order

**Foundation First**:
```
Data/Global → Data/Misc → Everything Else
```

**Skill System Sequence (CRITICAL)**:
```
SkillStatMap → Data/Skills/* → Data/Gems
                                    ↓
                                Minions/Spectres
```
**Reason**: Gems reference `grantedEffectId` from Skills. Loading Gems before Skills causes nil errors.

**Enchantment Weapon Template**:
```
EnchantmentWeapon → [Split by weapon type]
```
**Reason**: Weapon enchantments serve as template, copied to all weapon base types.

### Parallel Load Groups (No Dependencies)

**ModItem Variants**: Item, Flask, Tincture, Graft, Jewel, etc. (can load concurrently)

**ItemBase Types**: axe, bow, claw, dagger, etc. (can load concurrently)

**Skill Types**: act_str, act_dex, act_int, minion, etc. (can load concurrently)

---

## 4. PoE1 vs PoE2 Compatibility Issues

### 🚨 CRITICAL FINDING: This is 100% PoE1 Implementation

**Version Evidence**:
```lua
-- From GameVersions.lua
legacyTargetVersion = "2_6"           -- Pre-3.0.0
liveTargetVersion = "3_0"             -- Default
latestTreeVersion = "3_27"            -- End of PoE1 cycle
treeVersionList = {
    "2_6", "3_6", "3_7", ... "3_27"  -- PoE1 only
}
```

**PoE1-Specific Systems Detected**:

1. **Jewel Radii** (lines 500-518):
   - Pre-3.16: `["3_15"]` (smaller ranges)
   - Post-3.16: `["3_16"]` (expanded with "Very Large", "Massive")
   - **Missing**: PoE2 `["0_1"]` radius definitions

2. **Curse System** (lines 255-282):
   - PoE1 curses: Temporal Chains, Enfeeble, Vulnerability
   - Warlord's Mark, Assassin's Mark (removed in PoE2)
   - **Missing**: PoE2 curse rework

3. **Boss Scaling** (lines 849-878):
   - "Guardian / Pinnacle Boss" (PoE1 end-game)
   - "Uber Pinnacle Boss" (highest PoE1 difficulty)
   - **Missing**: PoE2 Archnemesis mod system

4. **Enchantment Sources** (lines 549-560):
   - Labyrinth (Normal/Cruel/Merciless/Eternal) - PoE1 only
   - Harvest, Heist - PoE1 mechanics
   - **Missing**: PoE2 enchantment systems

5. **Item Types** (lines 27-50):
   - Includes "tincture", "graft" (PoE2 additions in PoE1 data)
   - Classic PoE1 types: axe, bow, claw, dagger, sword, wand
   - **Missing**: PoE2-exclusive weapon types

6. **Attributes** (lines 111-140):
   - Strength, Dexterity, Intelligence
   - Life, Mana, Energy Shield
   - **Missing**: "Spirit" or PoE2-specific attributes

### ⚠️ Implications for macOS Port

**Immediate Impact**:
- TreeTab works because passive tree structure is similar PoE1/PoE2
- BUT: Data files are PoE1-specific

**Stage 1 Mitigation**:
- Load data files AS-IS (PoE1 data)
- Accept that calculations may be incorrect for PoE2
- Document as "PoE1 data loaded" limitation

**Future Stages**:
- Stage 2: May need PoE2-specific data files
- Stage 3: ModCache may require PoE2 mod definitions
- Stage 4: Boss/skill data will need PoE2 updates

---

## 5. Stage 1 Implementation Strategy

### Minimal Data Loading (Stage 1 Scope)

**Files to Load (Safe Subset)**:
1. ✅ `Data/Global` - Universal (ColorCodes, ModFlags)
2. ✅ `Data/Misc` - Already partially loaded (line 100 in Launch.lua)
3. ✅ `Data/Gems` - Needed for skill system
4. ✅ `Data/Bases/axe` through `Data/Bases/belt` - Item base definitions
5. ✅ `Data/Uniques/axe` through `Data/Uniques/belt` - Unique item database

**Tables to Initialize (Empty)**:
```lua
data.itemMods = {}
data.masterMods = {}
data.enchantments = {}
data.essences = {}
data.veiledMods = {}
data.beastCraft = {}
data.necropolisMods = {}
data.crucible = {}
data.pantheons = {}
data.costs = {}
data.mapMods = {}
data.clusterJewels = {}
data.timelessJewelTypes = {}
data.bosses = {}
data.bossSkills = {}
data.minions = {}
data.spectres = {}
```

**Files to SKIP (Stage 1)**:
- ModItem, ModFlask, etc. (not needed yet)
- Enchantments (not used in TreeTab)
- Essence, BeastCraft, etc. (crafting systems)
- Skills/* (Stage 2 - calculation pipeline)
- Minions/Spectres (Stage 3 - skill system)

### Load Order for Stage 1

```
1. Data/Global
2. Data/Misc (already loaded at line 100)
3. Data/Gems
4. Data/Bases/* (18 files, parallel)
5. Data/Uniques/* (19 files, parallel)
```

**Estimated File Count**: 1 + 0 + 1 + 18 + 19 = **39 files to load**

**Estimated Data Size**: ~500KB of Lua tables

---

## 6. Risk Assessment for Stage 1

### Risk 1: PoE1 Data Incompatibility (HIGH)

**Issue**: All data files are PoE1-specific
**Impact**: Calculations may be incorrect for PoE2 builds

**Mitigation**:
- Accept PoE1 data for Stage 1
- Document limitation clearly
- Plan PoE2 data migration for Stage 2-3

**Acceptable**: Stage 1 only loads data, doesn't use it for calculations yet

---

### Risk 2: File Loading Errors (MEDIUM)

**Issue**: 39 files to load, any error breaks initialization
**Impact**: App may crash or fail to start

**Mitigation**:
- Use pcall() wrapper for each LoadModule
- Log which file failed
- Continue with partial data if non-critical file fails

**Implementation**:
```lua
local ok, result = pcall(LoadModule, "Data/Gems", data)
if not ok then
    ConPrintf("ERROR loading Data/Gems: %s", tostring(result))
    data.gems = {}  -- Empty fallback
end
```

---

### Risk 3: Breaking TreeTab (LOW)

**Issue**: Adding data tables may interfere with Phase 3, 4, A
**Impact**: Lose working functionality

**Mitigation**:
- Data loading is additive (no removal)
- TreeTab doesn't use data.gems yet
- Test TreeTab after loading

**Acceptable**: Low risk, well-mitigated

---

## 7. Deliverable: Step 1 Complete

**Analysis Complete**: ✅

**Key Findings**:
1. ✅ Load order identified: 51 files, specific dependencies
2. ✅ Data tables documented: 20+ major structures
3. ✅ PoE1 vs PoE2 incompatibility identified (CRITICAL)
4. ✅ Stage 1 strategy defined: Load 39 files, initialize empty tables
5. ✅ Risks assessed: PoE1 data (HIGH), file errors (MEDIUM), breaking TreeTab (LOW)

**Recommendation**: Proceed to Step 2 (Load Minimal Data Files)

**Caveat**: Accept PoE1 data for Stage 1, plan PoE2 migration for later stages

---

**Status**: ✅ COMPLETE
**Next Step**: Stage 1 Step 2 - Load Minimal Data Files
