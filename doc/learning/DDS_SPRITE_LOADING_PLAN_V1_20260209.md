# DDS Sprite Loading Plan V1 (2026-02-09)

## Task
Add DDS sprite loading to PassiveTree.lua for PoE2 passive tree node icons.

## Root Cause
PoE2 tree uses DDS texture arrays (`.dds.zst` files) with `ddsCoords` mapping instead of PNG sprite sheets. Current code only loads PNG sprite sheets, leaving PoE2 nodes without icons.

## Implementation

### Single File Change: PassiveTree.lua

**Insert at line 329** (after existing sprite sheet loop `end`, before `bloodlineSpriteTypes`):

~40 lines of Lua code that:
1. Checks `self.ddsCoords` exists (from tree.lua data)
2. Iterates DDS files, maps filename patterns to sprite type keys:
   - `skills_*` → normalActive, notableActive, keystoneActive
   - `skills-disabled_*` → normalInactive, notableInactive, keystoneInactive
3. Calls `LoadArrayLayer(filePath, layerIndex)` for each sprite
4. Populates `self.spriteMap[iconName]` with correct type keys
5. Also loads `group-background_*` entries into `self.assets`

### Data Flow
- `ddsCoords` key: `"Art/2DArt/SkillIcons/passives/criticalstrikechance.dds"` → `node.icon` matches this
- DrawAsset calls `unpack(data)` → `[1]=0,[2]=0,[3]=1,[4]=1` = full texture

### No Changes Needed In:
- PassiveTreeView.lua (DrawAsset already handles full textures)
- pob2_launch.lua (LoadArrayLayer FFI already implemented)
- sg_image.cpp / dds_loader.c (already working)

## Risk & Rollback
- **Risk**: Low - additive code, no existing behavior modified
- **Rollback**: Delete the inserted block

## Success Criteria
1. App launches without errors
2. Node icons visible on passive tree
3. Node frames visible
4. Connection lines still display
5. Node allocation still works

## 6-Point Review
1. ✅ Root cause clear (no DDS loading code for PoE2 sprites)
2. ✅ Technically sound (uses existing FFI, matches data format)
3. ✅ Low risk (additive only)
4. ✅ Easy rollback (delete inserted block)
5. ✅ Visual verification plan (launch → check icons)
6. ✅ Timeline: ~15 min

**Score: 6/6**

## Applied Lessons
1. ConPrintf: use `%s` + `tostring()` for numeric output
2. Visual verification is the only real success metric
3. Single file change → test immediately
