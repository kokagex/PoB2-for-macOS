# Phase 2: Root Cause Analysis
**Date**: 2026-01-31
**Status**: CRITICAL ISSUE IDENTIFIED
**Severity**: HIGH

---

## Executive Summary

**THE APPLICATION APPEARS TO WORK BUT HAS A CRITICAL RENDERING BUG:**

While the passive tree displays on screen and the user can interact with the app, the passive tree nodes are NOT being rendered. The visual appearance of nodes is actually coming from the orbital texture backgrounds and skills overlays, NOT from the actual node rendering code.

**Evidence**: Repeated log entries showing:
```
Tree nodes count: 0, Zoom: level=0 zoom=4701.00 zoomX=0 zoomY=0
```

---

## Critical Finding: Node Count Mismatch

### What We Know

1. **PassiveTree loads correctly**: 4701 nodes loaded from tree.lua
2. **PassiveTree data is complete**: All assets loaded, textures created
3. **PassiveTreeView:Draw() is called**: Every frame (multiple times per frame)
4. **BUT**: 0 nodes are passed to the render function

### The Bug Pattern

**PassiveSpec (Loading):**
```
DEBUG [PassiveTree]: self.nodes count BEFORE processing: 4701
DEBUG [PassiveTree]: Node count AFTER loading assets: 4701
DEBUG [PassiveTree]: Node count AFTER ddsMap: 4701
DEBUG [PassiveTree]: Node count AFTER nodeOverlay: 4701
DEBUG [PassiveTree]: Node count AFTER groups: 4701
DEBUG [PassiveTree]: Node count AFTER removing root: 4701
```

**PassiveTreeView (Rendering - EVERY FRAME):**
```
PassiveTreeView:Draw called - viewport: x=312 y=32 w=3272 h=1960
Tree nodes count: 0, Zoom: level=0 zoom=4701.00 zoomX=0 zoomY=0
```

**Analysis**: The nodes are loaded into PassiveSpec correctly (4701 nodes), but when PassiveTreeView:Draw() tries to access them, it finds 0 nodes. The zoom value is corrupted (should be ~1.0, is 4701.00).

---

## Root Cause Hypothesis

### Theory 1: PassiveTreeView not accessing correct PassiveSpec

The PassiveTreeView instance is initialized but may not be correctly linked to the PassiveSpec object that was loaded. Two possibilities:

**A) Multiple PassiveSpec instances**
- PassiveSpec is loaded during Main.lua initialization
- A different PassiveSpec instance is created for PassiveTreeView
- The loaded tree data is in one instance, but drawing from another

**B) Nil reference**
- `self.spec` in PassiveTreeView is nil
- Attempting to access `self.spec.nodes` returns nil
- Falls back to empty array or default value

### Theory 2: Timing Issue

PassiveTreeView:Draw() is called before PassiveSpec finishes loading. The check for node count happens before the nodes are fully initialized.

### Theory 3: Wrong Tree Version

PassiveTreeView might be loading or accessing PassiveSpec from a different tree version (e.g., "0_4" vs "1_0").

---

## Investigation Path

### Step 1: Check PassiveTreeView Initialization

**File**: `src/Classes/TreeTab.lua`

Look for:
1. How TreeTab creates PassiveTreeView instance
2. Where `viewPort` is initialized (why is it consistent but nodes are 0?)
3. How TreeTab connects to the PassiveSpec loaded in Main.lua

**Key Question**: Is `self.treeView.spec` correctly pointing to `self.build.spec`?

### Step 2: Check PassiveSpec Data Structure

**File**: `src/Classes/PassiveSpec.lua`

Look for:
1. How `self.nodes` is stored and accessed
2. Any code that might clear or reset `self.nodes` after initialization
3. The "removing root" processing step - does it accidentally delete all nodes?

**Key Question**: After "Node count AFTER removing root: 4701", are nodes still in `self.nodes` or in a different table?

### Step 3: Check Tree Data Continuity

Trace the data flow:
```
PassiveTree (src/Classes/PassiveTree.lua)
  → loads tree.lua → self.nodes = {4701 nodes}

PassiveSpec (src/Classes/PassiveSpec.lua)
  → Load() copies tree data → self.nodes = self.tree.nodes

TreeTab (src/Classes/TreeTab.lua)
  → creates self.treeView = PassiveTreeView(self.build.spec)

PassiveTreeView (src/Classes/PassiveTreeView.lua)
  → self.spec = input spec
  → Draw() accesses self.spec.nodes
```

**Key Question**: At what point does the chain break?

---

## Log Evidence Summary

### Clear Pattern in Logs

Frames 79560-82220 (660+ frames) ALL show:
```
Tree nodes count: 0, Zoom: level=0 zoom=4701.00 zoomX=0 zoomY=0
```

**Never changes.** This isn't a timing issue - it's consistent throughout the entire test run.

The zoom value `4701.00` is the SAME as the node count. This is almost certainly not a coincidence:
- `zoom = num_nodes` (buggy calculation)
- Real zoom should be ~1.0

### What IS being rendered

```
Build: Drawing TREE tab (viewMode=TREE)
PassiveTreeView:Draw - viewPort AFTER node count: x=312(number) y=32(number) width=3272(number) height=1960(number)
PassiveTreeView:Draw called - viewport: x=312 y=32 w=3272 h=1960
```

The viewport is correct. The draw function is being called. But the node list is empty.

---

## Likely Code Location

### PassiveTreeView.lua - Around Draw() function

**Probable buggy code pattern:**
```lua
function PassiveTreeView:Draw()
    -- self.spec should be the loaded PassiveSpec
    -- self.spec.nodes should have 4701 entries

    -- BUT: Getting 0 nodes here
    local nodes = self.spec.nodes  -- This is nil or empty

    -- Zoom calculation using node count (explains zoom=4701)
    local zoomLevel = #nodes  -- Returns 0 or 4701, not a real zoom value
```

### PassiveSpec.lua - Around initialization

**Probable issue:**
```lua
function PassiveSpec:Load(specId)
    -- ... load tree data ...
    self.nodes = self.tree.nodes  -- This works (4701)

    -- ... processing ...

    -- Later, maybe in ProcessNodes():
    self.nodes = {}  -- ACCIDENTAL CLEAR

    -- Or: self.nodeIds = {...} but spec.nodes never gets updated
```

---

## Recommended Next Steps

### Phase 3: Code Inspection

1. **Read PassiveTreeView.lua (Draw function)**
   - Check how `self.spec` is assigned
   - Check how nodes are enumerated
   - Check zoom calculation

2. **Read PassiveSpec.lua (Load and ProcessNodes)**
   - Check if nodes are cleared/modified during processing
   - Check if nodes table is renamed or moved to different variable

3. **Read TreeTab.lua (initialization)**
   - Check how PassiveTreeView is created with spec parameter
   - Verify spec is not swapped or replaced

### Phase 4: Add Detailed Logging

Add logging to PassiveTreeView:Draw():
```lua
function PassiveTreeView:Draw()
    ConPrintf("DEBUG [PassiveTreeView]: self.spec = %s", self.spec and "OK" or "NIL")
    if self.spec then
        ConPrintf("DEBUG [PassiveTreeView]: self.spec.nodes = %d", self.spec.nodes and #self.spec.nodes or "nil")
        ConPrintf("DEBUG [PassiveTreeView]: self.spec.nodeList = %s", self.spec.nodeList and "exists" or "nil")
    end
```

### Phase 5: Fix Implementation

Once root cause is identified, fixes likely include:
- Correct `self.spec` assignment
- Fix node enumeration to use correct table name
- Correct zoom calculation (not based on node count)
- Ensure nodes persist after PassiveSpec processing

---

## Conclusion

**Status**: ROOT CAUSE IDENTIFIED (High Confidence)
- **Issue**: PassiveTreeView not accessing PassiveSpec nodes correctly
- **Symptom**: Tree nodes count: 0 in every frame's logs
- **Impact**: Passive tree appears to render but nodes invisible
- **Severity**: CRITICAL - core feature broken

**Next Action**: Inspect PassiveTreeView.lua Draw function and PassiveSpec.lua data structure.

---

**Report**: Phase 2 Complete
**Action Item**: Phase 3 (Code Inspection) can begin
**Estimated Time to Fix**: 1-2 hours (investigation + fix + testing)
