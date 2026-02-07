# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mandatory Routine (MUST EXECUTE EVERY TIME)

**CRITICAL**: Before ANY task execution, MUST execute the `/routine` skill.

**Quick Reference**:
- **Skill Command**: `/routine`
- **Definition**: See `.claude/SKILL.md`
- **Purpose**: Load learning data, create plan, review, request approval
- **Context Savings**: ~80-90% reduction vs. manual execution

**Why This Routine Exists**:
- Past failure: 3 days of work with zero visual progress
- Key lesson: Never assume success without verification
- Quality: Plan → Review → Approve → Execute

<!--
MASKED: Original routine definition (2026-02-02)
Reason: Moved to /routine skill in .claude/SKILL.md for context reduction

Original 5-phase routine:

### Phase 1: 学習データ読み書き
1. Read learning data from `./doc/learning/` directory
2. Review critical lessons (CRITICAL_FAILURE_ANALYSIS.md, LESSONS_LEARNED.md)
3. Document current task context in `./doc/learning/`

### Phase 2: プロジェクト構造確認
1. Review project constraints and requirements
2. Confirm technical constraints (LuaJIT 5.1, Metal pipeline, etc.)
3. Identify task type and affected areas

### Phase 3: 計画書作成
1. Create detailed implementation plan in `./doc/learning/`
2. Include: root cause analysis, proposed fix, timeline, risk assessment
3. Define success criteria and deliverables

### Phase 4: レビュー実行
1. Create review document evaluating the plan
2. Check: learning integration, role clarity, technical accuracy, risks
3. Apply auto-approval criteria (6-point check)

### Phase 5: 神への認可申請
1. Present plan and review to God (user)
2. Await explicit approval before execution
3. Do NOT proceed without approval

To restore: Uncomment this section and remove the /routine skill reference above.
-->

---

## Error Handling and Fix Procedure (MANDATORY)

**CRITICAL**: When encountering errors during task execution, follow this protocol:

### 1. Context Error Documentation
When bash errors, crashes, or repeated failures occur:
1. **Create `contexterror_<task>_<phase>.md`** in `./doc/learning/` directory
2. **Document**:
   - Full error context (logs, error messages, stack traces)
   - Previous fix attempts and their results
   - Current hypothesis about root cause
   - Work history analysis (what worked, what didn't)

**Example**: `contexterror_ascendancy_crash_phase3.md`

### 2. Fix Prediction Process (BEFORE IMPLEMENTATION)
Before implementing any fix:
1. **Analyze work history**: Review all previous fix attempts from contexterror files
2. **Identify patterns**: What types of fixes succeeded? What failed?
3. **Predict 3 fix candidates**:
   - Option A: Diagnostic approach (add logging, narrow down issue)
   - Option B: Targeted fix (address suspected root cause)
   - Option C: Robust/fallback approach (ensure stability)

### 3. User Consultation (REQUIRED)
**NEVER implement fixes without user approval**:
1. Use `AskUserQuestion` tool to present 3 fix candidates
2. Provide clear descriptions of each option's pros/cons
3. Wait for user selection
4. Implement ONLY the selected option

### 4. Iterative Fix Protocol
**Fix thoroughly until stable operation**:
1. Implement selected fix
2. Test immediately
3. Document results in contexterror file
4. If crash continues:
   - Update contexterror file with new findings
   - Predict 3 NEW fix candidates based on updated context
   - Present to user for selection
5. **Repeat until stable operation achieved**

**Elimination Method (消去法)**:
When multiple potential crash locations exist, use systematic elimination:
1. Add DEBUG logging at boundaries between suspected sections
2. Test to identify which section crashes
3. Add more granular logging within that section
4. Repeat until exact crash line identified
5. Apply targeted fix to confirmed crash location

**Example**:
```
Section A → Section B → Section C
Add log: "A complete", "B complete", "C complete"
Test shows: "A complete" logged, "B complete" NOT logged
→ Crash is in Section B
Add log: "B step 1", "B step 2", "B step 3"
Test shows: "B step 2" logged, "B step 3" NOT logged
→ Crash is between step 2 and step 3
```

**Visual Verification Workflow (表示確認ワークフロー)**:
When testing visual/display issues, follow this automated workflow:
1. **Launch from command line** (requires user approval): `./PathOfBuilding.app/Contents/MacOS/PathOfBuilding &`
2. **User takes screenshot**: User captures screen state and says "撮った"
3. **Auto-terminate app**: `pkill -f PathOfBuilding` (no confirmation needed)
4. **Auto-check screenshot**: Read latest `~/Desktop/スクリーンショット*.png`
5. **Analyze visually**: Verify UI rendering, layout, text visibility
6. **Auto-delete screenshot**: `rm ~/Desktop/スクリーンショット*.png` (no confirmation needed)

**Commands** (automated after step 1 approval):
```bash
# 1. Launch app (ASK USER FIRST, then run)
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding &

# 2-6. Run automatically when user says "撮った"
pkill -f PathOfBuilding
ls -lt ~/Desktop/スクリーンショット*.png | head -1
# Read tool to view image
rm ~/Desktop/スクリーンショット*.png
```

**User Approval Points**:
- ✅ App launch (step 1): Always ask before launching
- ❌ Screenshot deletion (step 6): No confirmation needed, auto-delete after viewing

**Why Visual Verification**:
- Logs don't show UI rendering issues (coordinate misalignment, scaling problems)
- Screenshot provides objective visual evidence of display state
- Automated workflow ensures consistent verification process
- Prevents "3 days with zero visual progress" failure pattern

### 5. Success Documentation
When fix succeeds:
1. Document final solution in `LESSONS_LEARNED.md`
2. Update relevant analysis files with "RESOLVED" status
3. Note key insights for future similar issues

**Example Flow**:
```
Error occurs → Create contexterror.md → Analyze history →
Predict 3 fixes → Ask user → Implement selected fix →
Test → Still fails? → Update contexterror.md → Predict 3 NEW fixes →
Ask user → Repeat until stable
```

**Why This Protocol Exists**:
- Prevents wasted effort on wrong approaches
- Learns from previous failures
- Ensures user stays in control of fix direction
- Documents debugging journey for future reference

---

## Working Philosophy

**Explicit Reasoning**: Claude should actively use thinking blocks to verbalize internal reasoning processes. Articulating thoughts step-by-step enhances problem-solving capabilities and leads to more accurate, well-reasoned solutions. This practice of "thinking out loud" improves analytical abilities and helps identify potential issues before they occur.

## Project Overview

**pob2macos** is a native macOS port of Path of Building 2, a build planning tool for Path of Exile 2. This is a hybrid Lua + C++/Objective-C application with a custom graphics backend.

**Architecture**: Lua application layer (292 MB) + SimpleGraphic C++ library (Metal backend) + macOS app bundle

**Key Technologies**:
- **Graphics**: Metal API (primary), OpenGL (fallback)
- **Scripting**: LuaJIT 5.1 with FFI (NOT Lua 5.4)
- **Window Management**: GLFW3
- **Text Rendering**: FreeType2
- **Build System**: CMake 3.16+

---

## Build Commands

### Building SimpleGraphic Library

```bash
cd simplegraphic
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
```

Output: `simplegraphic/build/libSimpleGraphic.dylib`

**Backend Options**:
- `-DSG_BACKEND=metal` (default, recommended)
- `-DSG_BACKEND=opengl` (fallback)

**Build Types**:
- `-DCMAKE_BUILD_TYPE=Release` (default)
- `-DCMAKE_BUILD_TYPE=Debug`

### Deploying to App Bundle

After building SimpleGraphic, copy to runtime and app bundle:

```bash
# Copy to runtime directory
cp simplegraphic/build/libSimpleGraphic.dylib runtime/SimpleGraphic.dylib

# Copy runtime to app bundle
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

**CRITICAL**: Always sync changes to BOTH locations:
1. Source code: `src/` → `PathOfBuilding.app/Contents/Resources/pob2macos/src/`
2. Runtime: `runtime/` → `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`
3. Launch script: `pob2_launch.lua` → `PathOfBuilding.app/Contents/Resources/pob2macos/`

### Running the Application

```bash
# From repository root
./run_pob2.sh

# Or launch app bundle directly
open PathOfBuilding.app

# Or run from terminal (shows logs)
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding
```

---

## Testing

### Test Framework

**Busted** for Lua unit tests (configuration in `.busted`):
```bash
busted spec/
```

### Integration Tests

Manual test scripts in repository root (all use LuaJIT):

```bash
# Basic rendering test (5 seconds)
luajit test_5sec.lua

# Image loading verification
luajit test_image_loading.lua

# Text rendering test
luajit test_text_rendering.lua

# Passive tree display test
luajit test_passive_tree_fixed.lua

# Full application launch test
luajit test_pob_launch.lua
```

### Regression Testing

```bash
./tests/regression_test.sh
```

**IMPORTANT**: Due to macOS security restrictions, some test scripts may fail with "permission denied" when run via luajit. In such cases, test by launching the app bundle directly.

---

## Code Architecture

### Execution Flow

```
run_pob2.sh (Bash)
  ↓
pob2_launch.lua (FFI loader)
  ↓ loads SimpleGraphic.dylib via FFI
  ↓ initializes global functions (_G.RenderInit, _G.DrawImage, etc.)
  ↓
src/Launch.lua (PoB launcher)
  ↓ initializes renderer
  ↓ loads Main module
  ↓
src/Modules/Main.lua (PoB core)
  ↓ loads data, calculations, UI
  ↓ manages build list and build screens
  ↓
Main game loop (ProcessEvents → Draw → ProcessEvents)
```

### SimpleGraphic C++ Library Structure

**Source**: `simplegraphic/src/`
```
core/           - Initialization, state management
window/         - Window creation, input handling (GLFW)
rendering/      - Draw commands, images, text (FreeType)
backend/metal/  - Metal rendering implementation (1015 lines)
utilities/      - Filesystem, compression, clipboard, console
lua/            - Lua FFI bindings (placeholder)
```

**Public API**: `simplegraphic/include/simplegraphic.h` (48 exported functions)

**Critical Functions**:
- `RenderInit()` - Initialize graphics (call FIRST)
- `ProcessEvents()` - Poll events AND manage frame lifecycle (begin_frame/end_frame)
- `DrawImage()`, `DrawString()` - Rendering commands
- `NewImageHandle()`, `ImageHandle_Load()` - Image management
- `Shutdown()` - Cleanup (call on exit)

### Metal Backend Render Pipeline

**CRITICAL SEQUENCE** (must be followed strictly):

```
1. RenderInit()           - Initialize Metal
2. ProcessEvents()        - begin_frame() → create renderEncoder
3. SetClearColor()        - Set background
4. DrawString/DrawImage() - Queue draw commands
5. ProcessEvents()        - end_frame() → flush batches, present, begin new frame
6. Loop to step 3
```

**NEVER** call `DrawImage()` or `DrawString()` before the first `ProcessEvents()` - this causes NULL renderEncoder errors.

Correct pattern in `pob2_launch.lua` lines 414-434:
```lua
while IsUserTerminated() == 0 do
    ProcessEvents()          -- MUST be called FIRST
    if launch.OnFrame then
        launch:OnFrame()     -- Draw commands happen here
    end
    ...
end
```

### Lua FFI Bridge

**File**: `pob2_launch.lua`
- Declares 48 SimpleGraphic C functions via FFI
- Wraps ImageHandle as Lua class
- Exports globals (_G.RenderInit, _G.DrawImage, etc.)
- Converts Lua types to C types (strings → char*, numbers → floats)

### Path of Building Lua Code

**Entry Point**: `src/Launch.lua`
- Updates on first start
- Detects dev mode
- Initializes renderer
- Loads `Main` module
- Provides frame callbacks and key handling

**Main Module**: `src/Modules/Main.lua`
- Loads game version, data, calculation modules
- Manages two modes: build list and build screen
- Loads mod caches, passive trees, items

**Key Modules**:
- `Build.lua` - Build screen controls, save/load, tabs
- `Calcs.lua` - Damage calculations, stat computation
- `CalcSetup.lua` - Mod databases, skill tree, jewels
- `Data.lua` - Game data (items, skills, mods)
- `ModParser.lua` - Parses mods to generate ModCache

**Key Classes**:
- `PassiveTree.lua` / `PassiveTreeView.lua` - Skill tree rendering
- `PassiveSpec.lua` - Passive tree data and pathing
- `TreeTab.lua` - Tree tab UI
- `Item.lua` - Item representation
- `ModDB.lua` / `ModList.lua` - Modifier databases

See `docs/rundown.md` for detailed module descriptions.

---

## Critical Coding Patterns

### LuaJIT 5.1 Compatibility

**IMPORTANT**: This project uses LuaJIT 5.1, NOT Lua 5.4. When checking Lua best practices:
- Reference: https://www.lua.org/manual/5.1/
- Avoid Lua 5.2+ features (bitwise operators, goto, _ENV)
- Use LuaJIT FFI for C interop
- Prefer `table.insert()` over `table.move()`

### Nil-Safety Pattern

Due to 13 critical nil-safety fixes in PRJ-003, always validate before accessing:

**Arrays/Tables**:
```lua
-- BAD
local value = node.nodesInRadius[3][nodeId]

-- GOOD
if node.nodesInRadius and node.nodesInRadius[3] then
    local value = node.nodesInRadius[3][nodeId]
end
```

**Deep Chains**:
```lua
-- BAD
local item = self.build.itemsTab.items[itemId]

-- GOOD
local itemsTab = self.build and self.build.itemsTab
local item = itemsTab and itemsTab.items[itemId]
```

**Optional Fields**:
```lua
-- Always initialize missing critical fields
if not node.pathDist then
    node.pathDist = 1000  -- Default value
    ConPrintf("WARNING: Node %s had no pathDist, initialized to 1000", tostring(node.id))
end
```

### ProcessEvents() Calling

Always call `ProcessEvents()` BEFORE any `Draw*()` commands in each frame:

```lua
-- CORRECT
ProcessEvents()
DrawString(100, 100, "LEFT", 16, "", "Hello")
DrawImage(imageHandle, 0, 0, 64, 64, 0, 0, 1, 1)

-- INCORRECT (causes NULL renderEncoder)
DrawString(100, 100, "LEFT", 16, "", "Hello")
ProcessEvents()  -- Too late!
```

---

## File Synchronization

**CRITICAL**: The app bundle is NOT automatically synchronized with source code.

After modifying files in:
- `src/**/*.lua` → Copy to `PathOfBuilding.app/Contents/Resources/pob2macos/src/`
- `pob2_launch.lua` → Copy to `PathOfBuilding.app/Contents/Resources/pob2macos/`
- `runtime/SimpleGraphic.dylib` → Copy to `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`

**Sync Command**:
```bash
# Sync Lua file to app bundle (example)
cp src/Classes/PassiveSpec.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# Sync entire src directory
cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/
```

---

## Debugging

### Console Output

Lua debugging:
```lua
ConPrintf("DEBUG: value = %s", tostring(value))
print("Debug message")  -- Stdout
```

C++ debugging (Metal backend):
```objc
NSLog(@"DEBUG: renderEncoder = %@", renderEncoder);
printf("Debug message\n");  // Stdout
```

### Capture Application Logs

```bash
# Run from terminal to see all logs
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_debug.log

# Check system logs
tail -f ~/Library/Logs/PathOfBuilding.log
```

### Common Issues

**"permission denied" when running luajit tests**:
- Cause: macOS security restrictions
- Fix: Launch app bundle directly instead

**"renderEncoder is NULL" warning**:
- Cause: DrawImage/DrawString called before ProcessEvents()
- Fix: Ensure ProcessEvents() is first in game loop

**Passive tree not displaying**:
- Check: Asset files in `Assets/` exist
- Check: TreeTab.lua OnFrame() has draw calls
- Check: ProcessEvents() called before draw commands
- See: `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/PASSIVE_TREE_DIAGNOSTIC.md`

**Fixes not taking effect**:
- Check: Files copied to app bundle (not just source)
- Verify: `PathOfBuilding.app/Contents/Resources/pob2macos/src/` has changes

---

## Documentation

**Repository Docs**:
- `docs/rundown.md` - Codebase overview, module descriptions
- `docs/addingSkills.md` - Adding new skills
- `docs/addingMods.md` - Adding modifications
- `docs/calcOffence.md` - Offense calculation
- `docs/modSyntax.md` - Modifier syntax

**PRJ-003 Documentation** (in `/Users/kokage/national-operations/memory/PRJ-003_pob2macos/`):
- `LUA_QUALITY_CHECK_REPORT.md` - Lua code quality assessment
- `CRITICAL_FIXES_REPORT.md` - Critical nil-safety fixes
- `PASSIVE_TREE_DIAGNOSTIC.md` - Passive tree display troubleshooting
- `INSTALLATION_GUIDE.md` - Setup instructions

**Key Context**:
- 13 critical nil-safety fixes applied to 5 files (Main.lua, PassiveSpec.lua, PassiveTreeView.lua, Launch.lua, TreeTab.lua)
- Metal backend render pipeline requires strict ProcessEvents() ordering
- App bundle deployment is manual (no auto-sync)

---

## Development Workflow

1. **Modify C++ code** in `simplegraphic/src/`
2. **Rebuild library**: `cd simplegraphic && make -C build`
3. **Copy to runtime**: `cp simplegraphic/build/libSimpleGraphic.dylib runtime/`
4. **Deploy to app**: `cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/`
5. **Test**: `./run_pob2.sh` or `open PathOfBuilding.app`

For Lua changes:
1. **Modify Lua code** in `src/`
2. **Sync to app bundle**: `cp src/path/to/file.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/path/to/`
3. **Test**: `./run_pob2.sh`

Always verify changes took effect by checking the app bundle files directly.
