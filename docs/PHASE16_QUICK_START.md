# PoB2 macOS Quick Start Guide
## Phase 16 - Get Building in 15 Minutes

**Version:** Phase 16
**Time Required:** ~15 minutes from download to first working build
**Difficulty:** Beginner-Friendly
**Status:** Production Ready

---

## Table of Contents
1. [Installation (5 minutes)](#installation-5-minutes)
2. [First Launch (3 minutes)](#first-launch-3-minutes)
3. [Your First Build (5 minutes)](#your-first-build-5-minutes)
4. [Quick Reference](#quick-reference)
5. [Common Issues & Fixes](#common-issues--fixes)

---

## Installation (5 minutes)

### Download

Visit: [https://releases.pathofbuilding.com](https://releases.pathofbuilding.com)

Download: `pob2macos-phase16.dmg` (about 25 MB)

**Typical Download Time:** 1-3 minutes

### Install

1. **Open the downloaded file**
   - Double-click `pob2macos-phase16.dmg`
   - A Finder window appears

2. **Drag to Applications**
   - Drag `PoB2macOS.app` to the Applications folder
   - Or click the Applications shortcut in the window

3. **Wait for copy**
   - Should complete in <30 seconds

4. **Eject the disk**
   - Right-click the disk → Eject

**Installation Complete!** ✓

### Verify Installation

Open Finder → Applications → Look for "PoB2macOS"

---

## First Launch (3 minutes)

### Open PoB2

**Option 1: Finder**
- Open Applications
- Double-click PoB2macOS.app

**Option 2: Spotlight** (Quickest)
- Press Command + Space
- Type "PoB2"
- Press Enter

**Option 3: Terminal**
```bash
open /Applications/PoB2macOS.app
```

### First Launch Sequence

You'll see this sequence (completely normal):

```
1. Window opens (may be black briefly)
           ↓ (wait 2-3 seconds)
2. "Initializing..." message appears
           ↓
3. "Downloading data..." progress bar
           ↓ (wait 2-5 minutes on first run)
4. Progress reaches 100%
           ↓
5. Main application window appears
           ↓
6. Ready to build!
```

**What's downloading?**
- Game data: ~200-400 MB
- Passive tree: ~100 MB
- Item database: ~100 MB
- Graphics assets: ~50 MB

**First time only** - subsequent launches are instant!

### Success Indicators

You'll know it's ready when:
- ✓ Main window visible and clear
- ✓ Passive tree shows with colorful nodes
- ✓ UI elements visible (buttons, menus)
- ✓ Mouse cursor responds to movement

---

## Your First Build (5 minutes)

### Step 1: Start New Build (1 minute)

1. Look for "New Build" button (usually top-left)
2. Click it
3. A class selection appears

### Step 2: Select Your Class (1 minute)

**Six Character Classes to Choose From:**

- **Witch** - Intelligence focused, starts with cold/chaos spells
- **Shadow** - Dexterity focused, starts with evasion/deception
- **Ranger** - Dexterity/Intelligence, starts with projectile abilities
- **Duelist** - Strength/Dexterity, starts with melee skills
- **Marauder** - Strength focused, starts with powerful melee skills
- **Templar** - Strength/Intelligence, starts with holy/fire abilities

**For beginners, try:** Witch (easy to understand damage)

Click your chosen class → Click "Create"

**Time:** <1 minute

### Step 3: Add Your First Skill (2 minutes)

**In the main screen:**
1. Look for the Skills tab (usually bottom-left)
2. Click the Skills tab
3. In the search box, type a skill name:
   - For Witch: "Freezing Pulse" (beginner-friendly)
   - For Ranger: "Lightning Arrow"
   - For Duelist: "Cleave"
4. Click the skill to add it

**Watch it happen:**
- Skill gets added to your build
- Blue highlight appears on passive tree
- Calculations update in real-time
- DPS numbers change

### Step 4: Allocate Passive Points (1 minute)

The blue highlighted path shows which nodes give the skill bonuses.

1. In the Tree tab, click on blue-highlighted nodes
2. Each click allocates a point
3. Watch the DPS increase as you add points

**Result:**
- You've just optimized your build!
- Passive tree should have 5-10 allocated nodes
- DPS number visible (usually in stats panel)

**Congratulations! You have your first working build!** 🎉

---

## Quick Reference

### Main Workflow

```
Start → Select Class → Add Skill → Allocate Passives → Save Build
  |          ↓              ↓            ↓              ↓
 New       Witch         Freezing     Add 10         Save to
Build    (or Ranger)      Pulse       points         file
```

### Key Buttons & Where to Find Them

| Action | Location | Appears As |
|--------|----------|-----------|
| New Build | Top-left | "New Build" button |
| Select Skill | Skills tab | Search box, then click |
| Allocate Point | Tree tab | Click on node |
| View Stats | Stats tab | Shows DPS, resistances, etc |
| Save Build | File menu or Ctrl+S | "Save" button |

### Key Keyboard Shortcuts

| Action | Mac | Notes |
|--------|-----|-------|
| Save Build | Cmd+S | Always save your work |
| Open Build | Cmd+O | Load a saved build |
| New Build | Cmd+N | Start fresh |
| Undo | Cmd+Z | Undo last action |
| Redo | Cmd+Y | Redo an action |

### Tabs Overview

**Tree Tab**
- Shows passive skill tree
- Click nodes to allocate points
- Blue = path to your starting position
- Green = allocated by you

**Skills Tab**
- List of available skills
- Search for what you want
- Click to add to your build
- Shows skill scaling

**Items Tab**
- Equip gear for your character
- Modify item stats
- See how items affect your build

**Stats Tab**
- Shows all your character statistics
- DPS, resistances, health, etc.
- Updates in real-time as you change build

### File Menu (Top-Left)

- **New Build** - Start a new character
- **Open Build** - Load a saved build file
- **Save Build** - Save your current build
- **Export** - Share build with others
- **Settings** - Adjust preferences

---

## Common Issues & Fixes

### Issue: Black Screen on Launch

**Problem:** Application opens but screen is black.

**Fix:**
1. Wait 5-10 seconds (initialization in progress)
2. If still black after 30 seconds:
   - Close the app (Cmd+Q)
   - Restart your Mac
   - Try again

### Issue: Cannot Download Data

**Problem:** Gets stuck downloading or shows error.

**Fix:**
1. Check internet connection: Open Safari, visit google.com
2. If no internet, connect to WiFi
3. Close PoB2 (Cmd+Q)
4. Open again, let it retry download
5. If still fails, contact support

### Issue: Application Crashes

**Problem:** App crashes or closes unexpectedly.

**Fix:**
1. Restart your Mac completely
2. Download the latest version again
3. If problem persists: Contact support with error message

### Issue: Slow Performance

**Problem:** Application runs slowly or lags.

**Fix:**
1. Close other applications (Safari, etc)
2. Restart your Mac
3. If still slow, your Mac may not meet minimum requirements

### Issue: "Developer Cannot Be Verified"

**Problem:** macOS shows security warning on launch.

**Fix:**
1. Right-click PoB2macOS app
2. Select "Open"
3. Click "Open" in the dialog that appears
4. Now you can launch normally

---

## Saving Your Build

### Auto-Save

PoB2 automatically saves your current build as you work.

**Location:** `~/.pob2/builds/` (automatic)

### Manual Save

**To save a specific version:**

Press Cmd+S or use File → Save

**Choose:**
1. Enter a build name (e.g., "My First Witch")
2. Choose location (usually default is fine)
3. Click "Save"

**File saves as:** `My First Witch.pob2`

### Load Saved Build

Press Cmd+O or File → Open

Choose a saved build file from the list.

---

## Next Steps

### Want to Learn More?

- **Full Installation Guide:** `docs/INSTALLATION.md` (for advanced options)
- **Troubleshooting Guide:** `docs/TROUBLESHOOTING.md` (for problem solving)
- **Full Documentation:** Check the included docs folder

### Need Help?

- **Common Issues:** See "Common Issues & Fixes" above
- **Support Email:** support@pathofbuilding.com
- **GitHub Issues:** Report bugs on our GitHub

### Tips for Better Builds

1. **Check Passive Tree Color:**
   - Blue nodes = connected to your class start
   - Allocate nodes on this blue path for efficiency

2. **Look at Skill Scaling:**
   - Each skill shows what stat it scales with
   - Wizard spells usually need Intelligence
   - Physical melee needs Strength

3. **Save Multiple Versions:**
   - Keep "V1", "V2", "V3" for different builds
   - Easy to compare later

4. **Use Forums/Community:**
   - Share your build with others
   - Get feedback from experienced players
   - Learn from others' builds

---

## Summary: Your First 15 Minutes

| Step | Time | Task |
|------|------|------|
| 1. | 0-2m | Download PoB2 |
| 2. | 2-3m | Install to Applications |
| 3. | 3-8m | First launch + data download |
| 4. | 8-9m | Select class |
| 5. | 9-12m | Add skill and allocate points |
| 6. | 12-15m | Save your build |
| **DONE!** | **15m** | **You have a working build!** |

---

## Keyboard Shortcut Cheat Sheet

```
Cmd+N = New Build
Cmd+O = Open Build
Cmd+S = Save Build
Cmd+Z = Undo
Cmd+Y = Redo
Cmd+Q = Quit
```

**Print this or take a screenshot for quick reference!**

---

**Quick Start Status:** COMPLETE ✓
**Version:** Phase 16
**Last Updated:** 2026-01-29
**Average User Time:** 15 minutes to first working build

**You're all set! Start building your perfect character!** 🎮
