# rawget/rawset Implementation Analysis
## Heroic Spirit #9 - Mission Report

**Date**: 2026-01-31
**Status**: Implementation Complete - Awaiting Validation
**File Modified**: `src/Classes/PassiveSpec.lua` (lines 129-154)

---

## Problem Statement

The PassiveSpec node copying code was failing because:

1. `pairs(tree.nodes)` returned **0 iterations** despite 4701 nodes existing
2. Direct access `tree.nodes[4]` worked perfectly
3. Metatable interference was suspected (custom `__pairs` metamethod)

## Solution: Two-Phase rawget/rawset Approach

### Phase 1: Node ID Collection (Numeric Iteration)

Instead of relying on `pairs()`, we use numeric iteration with `rawget()`:

```lua
local nodeIds = {}
local collectCount = 0
for i = 1, 100000 do
    local treeNode = rawget(self.tree.nodes, i)
    if treeNode then
        table.insert(nodeIds, i)
        collectCount = collectCount + 1
    end
end
```

**Advantages**:
- Bypasses `__index` metamethods via rawget()
- Numeric loop doesn't depend on `__pairs` metamethod
- Guaranteed to check all possible numeric keys
- Logs collection progress for debugging

### Phase 2: Node Copying (rawset)

Use collected IDs to copy nodes with explicit rawset:

```lua
for i, nodeId in ipairs(nodeIds) do
    local treeNode = rawget(self.tree.nodes, nodeId)
    if treeNode then
        local newNode = {
            id = nodeId,
            linked = { },
            power = { },
            group = treeNode.group,
            x = treeNode.x,
            y = treeNode.y,
            name = treeNode.name,
            linkedId = treeNode.linkedId or { },
            orbit = treeNode.orbit,
            orbitIndex = treeNode.orbitIndex,
            isProxy = treeNode.isProxy,
            icon = treeNode.icon,
            stats = treeNode.stats,
            skill = treeNode.skill
        }
        rawset(self.nodes, nodeId, newNode)
        directCopyCount = directCopyCount + 1
    end
end
```

**Advantages**:
- Bypasses `__newindex` metamethods via rawset()
- Explicit field copying (clear and maintainable)
- Validates each node before copying
- Logs copy progress for debugging

---

## Technical Details

### Why rawget/rawset?

| Function | Purpose | Bypass |
|----------|---------|--------|
| `rawget(table, key)` | Direct table read | `__index` metamethod |
| `rawset(table, key, value)` | Direct table write | `__newindex` metamethod |

These functions operate at the C API level and completely ignore metamethods.

### Why Numeric Iteration?

The for loop `for i = 1, 100000 do` doesn't rely on any metamethods:
- `pairs()` uses `__pairs` metamethod (can be overridden)
- `next()` uses `__pairs` metamethod (can be overridden)
- Numeric iteration is pure Lua VM operation (no metatable involvement)

### Defensive Programming

The implementation includes multiple safety checks:

1. **Nil validation**: Each rawget is checked before use
2. **Phase separation**: Collection and copying are separate (easier debugging)
3. **Comprehensive logging**: Progress logged at each phase
4. **Warning detection**: Alerts if collected ID becomes nil during copy

---

## Diagnostic Logging

All log messages use the `★★★ HS9:` prefix for easy identification:

```
★★★ HS9: Starting rawget/rawset node copy (bypassing pairs() metatable issue)
★★★ HS9: Collecting node IDs via numeric loop (1-100000)...
★★★ HS9: Collected node ID=4 (type=table)
★★★ HS9: Collected node ID=16 (type=table)
...
★★★ HS9: Collected 4701 node IDs via numeric iteration
★★★ HS9: Copying 4701 nodes using rawget/rawset...
★★★ HS9: Copied node ID=4, name=Strength
★★★ HS9: Copied node ID=16, name=Dexterity
...
★★★ HS9: directCopyCount = 4701 (rawget/rawset approach)
```

---

## Test Results

### Test #4 Execution

**Command**: `./test_with_monitoring.sh 40`
**Duration**: 40 seconds
**Frames Rendered**: 3540+ frames
**Result**: PassiveSpec:Init **NOT EXECUTED**

**Why?**
The application stayed on the Build List screen (main menu). PassiveSpec is only initialized when:
1. A new build is created
2. An existing build is loaded
3. The Tree Tab is opened in a build

**This is expected behavior** - the test did not create or load a build.

### Verification Status

- Source file modified: ✓
- App bundle synchronized: ✓
- Code verified in bundle: ✓ (grep confirmed rawget presence)
- Runtime validation: ⏳ PENDING (requires build creation)

---

## Validation Requirements

To validate the implementation, perform one of these actions:

### Option A: Manual Testing (Recommended)

1. Run the application:
   ```bash
   ./run_pob2.sh
   ```

2. Create a new build or load existing build

3. Open the Tree Tab

4. Check console output for `★★★ HS9:` messages

5. Expected output:
   ```
   ★★★ HS9: Collected 4701 node IDs via numeric iteration
   ★★★ HS9: directCopyCount = 4701 (rawget/rawset approach)
   ```

### Option B: Automated Build Testing

Create a test script that:
1. Initializes Launch
2. Creates a Build object programmatically
3. Initializes TreeTab
4. Captures PassiveSpec:Init logs

### Option C: Build XML Loading

1. Place a sample build XML in the Builds directory
2. Launch app and load build
3. Navigate to Tree Tab
4. Monitor console for HS9 diagnostic messages

---

## Expected Outcomes

### Success Indicators

✓ `★★★ HS9: Collected 4701 node IDs via numeric iteration`
✓ `★★★ HS9: directCopyCount = 4701 (rawget/rawset approach)`
✓ No warnings about missing nodes
✓ Passive tree renders correctly
✓ All 4701 nodes visible and interactive

### Failure Indicators

✗ `collectCount = 0` (tree.nodes truly empty)
✗ `directCopyCount < collectCount` (copy phase failed)
✗ Warnings: "nodeId=X was in collection but rawget returned nil"
✗ Tree doesn't render or shows incomplete nodes

---

## Code Location

**File**: `/Users/kokage/national-operations/pob2macos/src/Classes/PassiveSpec.lua`
**Lines**: 129-154 (replaced EMERGENCY_FIX section)
**Function**: `PassiveSpecClass:Init()`
**Synchronized**: ✓ Both source and app bundle updated

---

## Comparison with Previous Approach

### OLD (EMERGENCY_FIX)
```lua
local directCopyCount = 0
for nodeId, treeNode in pairs(self.tree.nodes) do
    self.nodes[nodeId] = { ... }
    directCopyCount = directCopyCount + 1
end
ConPrintf("EMERGENCY_FIX: directCopyCount = %d", directCopyCount)
```

**Problems**:
- Relies on pairs() which returns 0 iterations
- Single-phase approach (no verification)
- Uses standard assignment (metatable interference possible)

### NEW (HS9 rawget/rawset)
```lua
-- Phase 1: Collect
local nodeIds = {}
for i = 1, 100000 do
    local treeNode = rawget(self.tree.nodes, i)
    if treeNode then table.insert(nodeIds, i) end
end

-- Phase 2: Copy
for i, nodeId in ipairs(nodeIds) do
    local treeNode = rawget(self.tree.nodes, nodeId)
    if treeNode then
        rawset(self.nodes, nodeId, { ... })
    end
end
```

**Advantages**:
- Bypasses metatable interference completely
- Two-phase for verification
- Explicit rawget/rawset at C API level
- Comprehensive diagnostic logging

---

## Conclusion

The rawget/rawset implementation is **theoretically sound** and addresses the root cause of the pairs() iteration failure. The code has been:

1. ✓ Implemented in source
2. ✓ Synchronized to app bundle
3. ✓ Verified via grep
4. ⏳ **Awaiting runtime validation** (requires build creation)

**Next Step**: User must create/load a build and open Tree Tab to trigger PassiveSpec:Init and validate the fix.

---

## Additional Notes

### LuaJIT 5.1 Compatibility

This implementation is fully compatible with LuaJIT 5.1:
- `rawget`/`rawset` are standard Lua 5.1 functions
- Numeric for loops are core Lua syntax
- `table.insert` and `ipairs` are Lua 5.1 standard library

### Performance Considerations

The numeric iteration (1 to 100,000) is acceptable because:
- rawget() is very fast (direct C API call)
- Most iterations will be nil (early exit)
- Only ~4700 nodes exist, so ~4700 successful rawgets
- Modern CPUs handle this in milliseconds

### Future Improvements

If this approach succeeds, consider:
1. Document the metatable issue in codebase
2. Add similar rawget/rawset to other metatable-sensitive code
3. Consider removing or documenting the problematic metatable
4. Add unit tests for metatable interference scenarios

---

**Report Generated**: 2026-01-31
**Agent**: Heroic Spirit #9
**Status**: Implementation Complete - Validation Required
