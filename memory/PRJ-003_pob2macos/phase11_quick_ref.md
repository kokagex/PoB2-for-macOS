# Phase 11 Quick Reference

## Critical Blockers

### 1. LaunchSubScript (BLOCKS 30% OF FEATURES)
- **Status:** Not implemented
- **Lines:** Launch.lua:310, 344; PoEAPI.lua:79; PoBArchivesProvider.lua:49
- **What it does:** Runs Lua scripts in background threads with network access
- **Requirement:** Thread pool + isolated Lua states
- **Impact:** Cannot download builds, authenticate, update, fetch game data

### 2. MakeDir (BREAKS SAVE SYSTEM)
- **Status:** Partial - fails when parent doesn't exist
- **Error:** errno 2 at `/Users/kokage/Library/Application Support/PathOfBuilding2/scripts/`
- **Fix:** Implement recursive directory creation (`mkdir -p` equivalent)
- **Lines:** sg_stubs.c (no real implementation exists)

### 3. Zstandard Decompression (ASSET LOADING)
- **Status:** Only zlib supported
- **Problem:** PoB2 assets are `.dds.zst` files, using Zstandard not zlib
- **Fix:** Add libzstd support to sg_compress.c
- **Impact:** Cannot decompress tree textures, skill icons

## BC7 Texture Support

### Status: NOT AVAILABLE on macOS
- OpenGL 3.3 Core doesn't expose `GL_ARB_texture_compression_bptc`
- Apple doesn't expose BC7 in OpenGL driver
- Hardware supports it, but locked at OS level

### Workaround Required:
1. **Detect unavailability:**
   ```c
   bool has_bc7 = check_extension(GL_ARB_texture_compression_bptc);
   ```

2. **Two-tier fallback:**
   - If available: Use GPU compression (GL_COMPRESSED_RGBA_BPTC_UNORM)
   - If not: Decode to RGBA in software or transcode to S3TC

3. **Phase 12:** Integrate libsquish for CPU BC7 decode

## API Gap Priority Matrix

```
CRITICAL  │ LaunchSubScript, MakeDir, Zstandard support
─────────┼──────────────────────────────────────────────
HIGH      │ IsSubScriptRunning, AbortSubScript, LoadModule(real)
─────────┼──────────────────────────────────────────────
MEDIUM    │ GetSubScript, DDS parser, GetAsyncCount
─────────┼──────────────────────────────────────────────
LOW       │ SetWorkDir, RemoveDir, SpawnProcess (works)
```

## File Locations

### Implementation Files:
- OpenGL backend: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/opengl_backend.c`
- Stubs: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_stubs.c`
- Image loading: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_image.c`
- Compression: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_compress.c`

### PoB2 Source References:
- Network/async: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Launch.lua:250-319`
- OAuth: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Classes/PoEAPI.lua:60-100`
- Archives: `/Users/kokage/Downloads/PathOfBuilding-PoE2-dev/src/Classes/PoBArchivesProvider.lua:48-88`

## Quick Implementation Checklist

- [ ] **Week 1:** LaunchSubScript thread pool + Lua state isolation
- [ ] **Week 2:** MakeDir recursive + Zstandard codec
- [ ] **Week 3:** IsSubScriptRunning/AbortSubScript + DDS parser
- [ ] **Week 4:** Testing + BC7 fallback preparation

## Testing Indicators

✓ Can download builds from external URL
✓ Can authenticate with PoE account
✓ Can load tree assets without errors
✓ Can check for updates
✓ Can save builds to config directory
✓ Can decompress `.dds.zst` files

---

For full analysis, see: `sage_phase11_analysis.md`
