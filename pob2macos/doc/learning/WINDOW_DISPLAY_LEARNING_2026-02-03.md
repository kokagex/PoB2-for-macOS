# Window Display Learning Log (2026-02-03)

Purpose: step-by-step window display verification. Each step changes exactly one thing to avoid repeating the same mistake.

## Step 0 - Baseline knowledge (from script inspection)
- `dev/visual_test.lua` and `dev/visual_test_20sec.lua` call `RenderInit("window:...")` and then draw in a loop.
- If the console output does not reach `Screen size: ...`, `RenderInit` is likely blocking or failing before window creation.

## Step 1 - Dylib load only (no RenderInit)
- Command: `luajit -e '... ffi.load("./runtime/SimpleGraphic.dylib") ...'`
- Result: `OK: dylib loaded`
- Conclusion: The library itself loads; failure is likely during `RenderInit` or later.

## Step 2 - RenderInit smoke test (CLI)
- Command: `luajit -e '... RenderInit("window:SmokeTest") ...'` (stdout unbuffered, 6s timeout)
- Result: Printed `before RenderInit`, then `SimpleGraphic: Initializing`, then hung until timeout. No `after RenderInit` printed.
- Errors observed: `Connection Invalid error for service com.apple.hiservices-xpcservice`.
- Conclusion: `RenderInit` blocks when run from current CLI context. Window likely never created in this context.

## Step 3 - Avoid repeating the same failure
- Do **not** rerun `dev/visual_test*.lua` in the same CLI context; it will block at `RenderInit` again.
- Next change to try: run the same test **via GUI session** (e.g., `launchctl asuser` or `open -a Terminal`), so `RenderInit` can attach to WindowServer.

## Step 4 - RenderInit via `launchctl asuser`
- Command: `launchctl asuser $(id -u) ... luajit -e 'RenderInit("window:SmokeTestGUI")'` (6s timeout)
- Result: Still hung at `RenderInit`. Same `hiservices-xpcservice` connection invalid error.
- Conclusion: `launchctl asuser` does **not** solve the window creation issue in this environment.

## Step 5 - Try AppleScript (Terminal `do script`)
- Command: `osascript -e 'tell application "Terminal" to do script "cd ...; ./dev/visual_test_20sec.lua"'`
- Result: AppleScript syntax error and `hiservices-xpcservice` connection invalid error.
- Conclusion: This approach failed here; avoid repeating without fixing AppleScript syntax or permissions.

## Step 6 - Prepare GUI-friendly launcher
- Created: `codex/run_visual_test_20sec.command`
- Purpose: When opened via Finder/Terminal, it runs `./dev/visual_test_20sec.lua` in a GUI Terminal session.
- Next action: Run `open codex/run_visual_test_20sec.command` (requires GUI access).

## Step 7 - Launch via GUI (open .command)
- Command: `open codex/run_visual_test_20sec.command`
- Result: Command executed (awaiting user confirmation whether window appeared).
- Next: If window still not visible, try alternate GUI launcher or check macOS permissions.

## Step 8 - User screenshot review (2026-02-03 06:58:55)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 6.58.55.png`
- Observed: Window titled "20-Second Visual Test - Metal Rendering" appears with blue background.
- Observed: Only faint magenta text at top-left and bottom-left; expected white/yellow text is not visible.
- Observed: Ring image is not visible.
- Conclusion: Window is created and clear color works, but text color and image rendering are failing. Likely shader/text pipeline issue persists (not just window init).

## Step 9 - Image-only test script
- Created: `dev/visual_test_image_only.lua` (no DrawString calls; only background + ring.png)
- Created: `codex/run_visual_test_image_only.command` for GUI execution
- Next action: `open codex/run_visual_test_image_only.command`

## Step 10 - Image-only GUI launch
- Command: `open codex/run_visual_test_image_only.command`
- Result: Command executed (awaiting user confirmation whether ring image appeared).

## Step 11 - User report for image-only GUI launch
- User reported: test window did not open.
- Conclusion: GUI launch ran but window did not appear (unknown if script stalled at RenderInit or never started).
- Next change: capture stdout/stderr to a log file to confirm where it stops.

## Step 12 - Add logging to image-only launcher
- Updated: `codex/run_visual_test_image_only.command`
- Change: redirect stdout/stderr to `codex/visual_test_image_only.log` for troubleshooting.
- Next action: `open codex/run_visual_test_image_only.command` and then inspect the log.

## Step 13 - Image-only log result
- Log file: `codex/visual_test_image_only.log`
- RenderInit succeeded and window was created (`Window created: 1792x1012`, Metal initialized).
- Image load failed: `ring.png` path not found (`stb_image: can't fopen`).
- Conclusion: Window exists, but **image missing due to incorrect asset path** when launched from GUI context. The test window may be hidden behind or not noticed; however, render loop is running.
- Next change: use an absolute path for `ring.png` to eliminate path resolution issues.

## Step 14 - Fix image path (absolute)
- Updated: `dev/visual_test_image_only.lua`
- Change: image path changed to absolute path under `pob2macos/PathOfBuilding.app/.../Assets/ring.png`.
- Reason: relative path was wrong when launched from GUI; caused `stb_image: can't fopen`.
- Next action: relaunch `codex/run_visual_test_image_only.command` and check log for successful image load.

## Step 15 - Image-only rerun with absolute path (log review)
- Image now loads successfully (1024x1024) and Metal draw calls are issued.
- Window creation confirmed by log; rendering loop is active.
- Remaining issue is **visibility** (user did not see window), not loading/drawing.
- Next change: make the window harder to miss (longer duration + bring Terminal/frontmost).

## Step 16 - Screenshot review (Image Only Test)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.03.40.png`
- Observed: Window appears with blue background.
- Observed: Image shows as a **solid magenta square** instead of ring.png.
- Conclusion: Image draw path works, but **texture sampling/format is wrong** (likely shader or swizzle issue).

## Step 17 - Root cause found in Metal shader
- File: `dev/simplegraphic/src/backend/metal/metal_backend.mm`
- Fragment shader currently **hard-coded to return magenta**:
  `return float4(1.0, 0.0, 1.0, 1.0);`
- This explains purple/magenta output for text and images.
- Fix: restore texture sampling logic from backup (`metal_backend.mm.backup-2026-02-01`).
- Requires rebuilding `SimpleGraphic.dylib` after change.

## Step 18 - Rebuild and deploy SimpleGraphic dylib
- Rebuilt `simplegraphic` via `cmake --build dev/simplegraphic/build` (warnings only).
- Updated runtime binaries:
  - `dev/runtime/SimpleGraphic.dylib`
  - `dev/runtime/libSimpleGraphic.dylib`
- Purpose: apply shader fix (remove forced magenta) to runtime used by tests.

## Step 19 - Image-only test relaunched after shader fix
- Command: `open codex/run_visual_test_image_only.command`
- Status: launched; awaiting user screenshot confirmation.

## Step 20 - Screenshot review after shader fix
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.07.37.png`
- Observed: Blue background; ring image now renders as a faint gray ring outline (not magenta).
- Conclusion: Shader fix worked; image sampling is now functional. Remaining issue is low contrast/appearance (likely premultiply/alpha or color scaling).

## Step 21 - Test with a different image asset
- Updated: `dev/visual_test_image_only.lua`
- Image path changed to: `Assets/itemsheaderuniqueleft.png`
- Goal: verify color visibility with a non-ring asset.
- Next action: relaunch image-only test and capture screenshot.

## Step 22 - Image-only test with itemsheaderuniqueleft.png
- Log confirms image loaded: 71x88, 4 channels RGBA.
- Window and render loop running.
- Awaiting user screenshot to verify visibility/color.

## Step 23 - Screenshot review (itemsheaderuniqueleft.png)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.09.35.png`
- Observed: Image renders with correct colors/details (brown/bronze header art).
- Conclusion: Texture sampling and color are working for non-ring assets. The ring asset is likely low-contrast/alpha-heavy.

## Step 24 - Text-only test script
- Created: `dev/visual_test_text_only.lua` (multi-color text samples only)
- Created: `codex/run_visual_test_text_only.command` (logs to `codex/visual_test_text_only.log`)
- Next action: `open codex/run_visual_test_text_only.command` and capture screenshot.

## Step 25 - Screenshot review (Text Only Test)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.11.26.png`
- Observed: Text renders in multiple colors (white/yellow/green/red/magenta). Visible but small and clustered at top-left.
- User report: rapid flicker at top-left (barely visible).
- Conclusion: Text rendering works, but likely flicker due to repeated glyph atlas updates or frame present timing.

## Step 26 - Add order logging to text-only test
- Updated: `dev/visual_test_text_only.lua`
- Change: log every 60 frames: `ProcessEvents -> SetClearColor -> DrawString` order.
- Purpose: verify ordering stability while observing flicker.
- Next action: rerun text-only test and capture screenshot + log.

## Step 27 - Text-only order log + user flicker report
- Log confirms consistent order: `ProcessEvents -> SetClearColor -> DrawString` (frame 0, 60, 120...)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.11.26.png`
- Observed: Multi-color text visible, small and clustered top-left.
- User report: rapid flicker at top-left.
- Conclusion: draw order is stable; flicker likely related to glyph atlas updates or very small text size.

## Step 28 - Screenshot review (Text Only Test) + user report
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.13.16.png`
- Observed: Text still small and clustered top-left; legibility poor.
- User report: flicker speed decreased, but text remains unreadable.
- Conclusion: Need to increase text size and/or position for readability, and reduce flicker by lowering updates.

## Step 29 - Remove frame counter update
- Updated: `dev/visual_test_text_only.lua`
- Change: removed dynamic frame counter to keep text static and reduce flicker.
- Next action: rerun text-only test and capture screenshot.

## Step 30 - Screenshot review after removing frame updates
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.15.04.png`
- Observed: Text still small and clustered; user reports white text still flickers.
- Conclusion: Flicker persists even without changing text content. Issue likely in glyph atlas update or present timing.

## Step 31 - Throttle text draw frequency
- Updated: `dev/visual_test_text_only.lua`
- Change: draw text only every 10th frame (to reduce flicker/update load).
- Next action: rerun text-only test and capture screenshot.

## Step 32 - User report after throttling text draw (every 10 frames)
- User report: entire text area still flickers; overall screen appears to flicker.
- Conclusion: Flicker persists even with reduced draw frequency. Likely in glyph atlas upload or present timing rather than per-frame text updates.

## Step 33 - Add glyph atlas update logging
- Updated: `dev/simplegraphic/src/rendering/sg_text.cpp`
- Added `ATLAS-UPDATE` log when glyph atlas texture is updated (includes frame number and codepoint).
- Rebuilt and deployed `SimpleGraphic.dylib` to `dev/runtime`.
- Next action: rerun text-only test and inspect `codex/visual_test_text_only.log` for atlas update timing.

## Step 34 - Atlas update log results
- `ATLAS-UPDATE` logs show many updates on frame 1, then **glyph count resets on frame 2** (e.g., `frame=2 glyphs=1`).
- This implies the glyph atlas is being recreated or cleared across frames.
- Likely cause of flicker: glyph atlas not persistent between frames.
- Next change: trace where font/atlas is reinitialized each frame (font cache lifetime).

## Step 35 - Screenshot review + user report (flicker unchanged)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.19.33.png`
- Observed: No visible text; user reports overall flicker unchanged.
- Conclusion: Flicker persists and text may be intermittently missing due to atlas resets.

## Step 36 - Screenshot review + user report (throttled draw)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 7.19.33.png`
- Observed: No visible text; user reports full-screen flicker continues.
- Note: Current test draws text only every 10 frames, so blinking is expected at ~6 FPS.
- Conclusion: Need a control test that draws a single large text line every frame to isolate persistent flicker.

## Step 37 - Control test: single large text line every frame
- Updated: `dev/visual_test_text_only.lua`
- Change: draw a single large white line every frame (`TEXT ONLY CONTROL - LARGE`).
- Purpose: isolate flicker independent of multi-line updates or throttling.
- Next action: rerun text-only test and capture screenshot.

## Step 38 - Screenshot review (Control large text)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.28.20.png`
- Observed: Large white text is clearly visible and stable in the top-left.
- Conclusion: Flicker is **not** inherent; large static text renders correctly. Issue likely tied to glyph atlas updates for smaller/multiple glyph sets or frequent font size changes.

## Step 39 - Two large lines test
- Updated: `dev/visual_test_text_only.lua`
- Change: added second line at same size (64px) to test multi-line stability.
- Next action: rerun text-only test and capture screenshot.

## Step 40 - Screenshot review (Two large lines)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.29.44.png`
- Observed: Two large lines render clearly and appear stable.
- Conclusion: Large text at a single size is stable; flicker likely tied to mixing sizes or small sizes.

## Step 41 - Mixed size test (large + small)
- Updated: `dev/visual_test_text_only.lua`
- Change: draw one large line (64px) + one small line (16px) to test size-mixing flicker.
- Next action: rerun text-only test and capture screenshot.

## Step 42 - Screenshot review (Mixed sizes)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.31.00.png`
- Observed: Small text appears; large line not visible in this capture.
- User report: flicker occurs when sizes are mixed.
- Conclusion: Size mixing likely triggers atlas resets or rendering instability; needs font cache persistence per size.

## Step 43 - Add font cache miss logging
- Updated: `dev/simplegraphic/src/rendering/sg_text.cpp`
- Added `FONT-CACHE-MISS` log when a font size/name is not found in cache.
- Rebuilt and deployed `SimpleGraphic.dylib` to `dev/runtime`.
- Next action: rerun mixed-size text test and inspect `codex/visual_test_text_only.log` for repeated cache misses.

## Step 44 - Screenshot review (Mixed sizes flicker)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.31.00.png`
- User report: flicker occurs when sizes are mixed.
- Observed: small text visible; large line not captured in screenshot.
- Conclusion: size mixing triggers instability; next isolate small-only to see if size itself flickers.

## Learning Summary (so far)
- Window creation and image draw path are working.
- Magenta output was caused by a debug shader forcing magenta; removing it restored texture sampling.
- Ring image appears faint; other assets render correctly (likely alpha/contrast issue in ring asset).
- Text rendering works for large sizes; two large lines are stable.
- Flicker is triggered when **small text** is involved or when **sizes are mixed**.
- Glyph atlas updates occur early and caching persists; issue likely not cache miss but update/present behavior with small glyphs.

## Step 45 - Change texture storage to Shared
- Updated: `dev/simplegraphic/src/backend/metal/metal_backend.mm`
- Change: set `storageMode = MTLStorageModeShared` for dummy texture, normal textures, and compressed textures.
- Reason: avoid potential synchronization issues with Managed textures when CPU updates glyph atlas.
- Rebuilt and deployed `SimpleGraphic.dylib` to `dev/runtime`.
- Next action: rerun mixed-size text test to see if flicker improves.

## Step 46 - Screenshot review after Shared storage change
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.39.58.png`
- User report: flicker persists.
- Observed: small text visible; large line not captured in screenshot.
- Conclusion: storageMode change to Shared did not resolve flicker.

## Step 47 - Fix: scale small text from base size
- Updated: `dev/simplegraphic/src/rendering/sg_text.cpp`
- Change: small text (< 64px) is now rasterized at 64px and scaled down in DrawString/Width/CursorIndex.
- Purpose: avoid mixing multiple atlas sizes and reduce flicker when small text is involved.
- Rebuilt and deployed `SimpleGraphic.dylib` to `dev/runtime`.
- Next action: rerun mixed-size text test and check for flicker reduction.

## Step 48 - Screenshot review after small-text scaling fix
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.44.08.png`
- Observed: Large and small text render together, no flicker reported.
- Conclusion: Scaling small text from 64px base resolves mixed-size flicker.

## Step 49 - Passive tree test launcher
- Created: `codex/run_passive_tree_test.command`
- Logs to: `codex/passive_tree_test.log`
- Next action: run GUI passive tree test after text flicker fix.

## Step 50 - Center passive tree view
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua`
- Change: compute tree bounds and center view (zoomLevel=0, zoom=1.0, set zoomX/zoomY).
- Purpose: ensure passive tree is visible on first frame.
- Next action: rerun passive tree test and capture screenshot.

## Step 51 - Screenshot review (Centered passive tree)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.51.21.png`
- Observed: Mostly dark background; user reports "something" visible in top-left.
- Conclusion: View centering partially helped but tree still not visible; likely zoom/scale too small or assets not loading.

## Step 52 - Draw center crosshair
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- Change: draw a simple "CENTER" marker at the screen center to verify transform alignment.
- Next action: rerun passive tree test and capture screenshot.

## Step 53 - Mark sample nodes on screen
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- Change: draw green markers for 5 sample nodes ("*" + N1..N5) after treeToScreen conversion.
- Purpose: verify whether nodes are off-screen or simply too dark.
- Next action: rerun passive tree test and capture screenshot.

## Step 54 - Screenshot review (node markers)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 18.57.43.png`
- Observed: Green node markers (N1..N5) appear scattered across the screen; center marker visible.
- Conclusion: Node positions map onto screen correctly; missing tree visuals are likely due to asset drawing (backgrounds/frames/orbits) not rendering, not camera/transform.

## Step 55 - Draw fixed PSSkillFrame asset
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- Change: draw `PSSkillFrame` at screen center to verify PNG asset visibility.
- Next action: rerun passive tree test and capture screenshot.

## Step 56 - Screenshot review (PSSkillFrame debug)
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 19.04.11.png`
- Observed: Node markers and center label visible; **PSSkillFrame not visible** at center.
- User report: flicker in top-left continues.
- Conclusion: PNG asset drawing path is failing for passive tree assets (or not loading as expected), while text markers render.

## Step 57 - Fix DrawAsset early return
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- Change: removed `data.found` check and restored original scale factor (1.33).
- Reason: PNG assets in `assets` table do not set `found`, causing DrawAsset to skip rendering.
- Next action: rerun passive tree test and check for visible assets.

## Step 58 - Screenshot review after DrawAsset fix
- Screenshot file: `~/Desktop/スクリーンショット 2026-02-03 19.07.42.png`
- Observed: Passive tree nodes and connectors are now visible (gold circles/lines). Some elements still flicker.
- User report: "mysterious image" flickers.
- Conclusion: Asset drawing path is now working. Remaining issue is flicker in some assets (likely per-frame asset choice / overlay state or texture filtering).

## Step 59 - Log PNG asset names during draw
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTree.lua`
  - `GetAssetByName` now stamps `_name` and `_source` (png/dds).
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
  - Logs first 40 PNG asset draws for first 2 frames with name and position.
- Purpose: identify which assets are being drawn when flicker occurs.
- Next action: rerun passive tree test and inspect `codex/passive_tree_test.log`.

## Step 60 - Log top-left asset draws
- Updated: `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- Change: log any asset drawn in top-left 250x250 region for first 5 frames (`ASSET_DRAW_TL`).
- Purpose: identify which asset is flickering in top-left.
- Next action: rerun passive tree test and inspect `codex/passive_tree_test.log`.

## Step 61 - Top-left asset log result
- `ASSET_DRAW_TL` produced **no entries**, meaning no assets were drawn in the top-left 250x250 region.
- Conclusion: flicker reported in top-left is likely **not** from PNG/DDS assets drawn via `DrawAsset`.
- Next: inspect direct `DrawImage` calls (background) or debug overlays.

- Step: Disabled Background2 draw in PassiveTreeView.lua; started passive tree test to see if top-left flicker persists. Awaiting result/screenshot.
- Step: Added debugOnlySingleAsset early return in PassiveTreeView.lua to render only PSSkillFrame and isolate flicker. Running passive tree test next.
- Step: In PassiveTreeView.lua, debug-only mode now draws a solid magenta rectangle (DrawImage(nil)) instead of a texture, to test if flicker is texture-specific. Running passive tree test next.
- Step: Moved debug-only solid rectangle draw/return to the top of PassiveTreeView:Draw so no text/asset draws occur. This isolates flicker to basic DrawImage(nil). Running passive tree test next.
- Step: Set debug-only mode to text-only (DrawString) with early return. Solid/texture disabled. Running passive tree test next.
- Step: Switched debug-only mode to texture-only (PSSkillFrame) with early return. Text/solid disabled. Running passive tree test next.
- Step: Removed DIAG-BYPASS immediate draw in metal_backend.mm (avoid overwriting shared vertex buffer mid-frame). Rebuilt and copied libSimpleGraphic.dylib. Reset debugOnlySingleAsset=false to return to full tree render. Running passive tree test next.
- Step: Flicker persisted; implemented triple-buffered vertex buffer + in-flight semaphore in metal backend. Rebuilt and deployed SimpleGraphic.dylib. Running passive tree test next.
- Step: Implemented batchStart to flush per-texture without resetting vertex buffer, increased buffer size, and kept triple buffering. Rebuilt and deployed SimpleGraphic.dylib. Running passive tree test next.
- Step: Fixed Metal completion handler to capture semaphore locally (avoid crash after shutdown). Rebuilt and deployed SimpleGraphic.dylib. Running passive tree test next.
- Result: Flicker resolved; images render and app no longer crashes after completion-handler semaphore fix. User saved screenshot on Desktop.
- Step: Restored normal PassiveTreeView rendering (debug-only modes off, debug overlays removed, Background2 draw re-enabled). Running passive tree test next.
- Cleanup: removed PassiveTreeView/PassiveTree debug logs and debug overlays; disabled draw param test; gated Metal debug prints; removed sg_core frame debug prints; rebuilt and redeployed SimpleGraphic.dylib.
- Follow-up: running interactive passive tree test for zoom/pan/hover checks (post-fix verification).
- Step: Increased test duration to 3600 frames (~60s) in Launch.lua for extended verification.
- Step: Implemented inputEvents in Launch.lua to enable zoom/pan in test harness (mouse buttons + keyboard wheel/page).
- Step: Implemented mouse wheel + input polling (sg_input_update, GetMouseWheelDelta) and wired Launch.lua to emit wheel events. Rebuilt and deployed SimpleGraphic.dylib.
- Step: Added Lua wrapper for GetMouseWheelDelta (dev/pob2_launch.lua) to stop OnFrame error. Retesting input/zoom.
- Step: Updated app bundle pob2_launch.lua to expose GetMouseWheelDelta (prevents nil call crash). Retesting input/zoom.
- Step: Improved input polling (focus clear for stuck clicks) and wheel delta handling for small scroll values. Rebuilt and deployed SimpleGraphic.dylib.
- Step: Updated app runtime SimpleGraphic.dylib to latest build (wheel + input polling). Retesting zoom/click.

## Step 36 - Input diagnostics overlay + hover clear (2026-02-03)
- Updated `dev/simplegraphic/src/window/sg_input.cpp`:
  - Clear mouse buttons + scroll when window not focused or cursor not hovered.
  - GetMouseWheelDelta now flushes fractional scroll to avoid oscillation.
- Updated passive tree test `Launch.lua`:
  - Removed arrow-key zoom fallback.
  - Added on-screen input diagnostics: `LB/RB/ALT/Wheel/Cursor` at top-left.
- Rebuilt and deployed `SimpleGraphic.dylib` to app runtime.
- Next: rerun passive tree test and report the overlay values while clicking and scrolling.

## Step 37 - Input overlay expansion + modifier clear
- `sg_input_update`: clear modifier keys (SHIFT/CTRL/ALT) when window not focused or cursor not hovered.
- Launch overlay expanded to show SHIFT/CTRL, DRAG state, mOver, cursor, and drag origin.
- Rebuilt and deployed SimpleGraphic dylib.
- Next: rerun passive tree test and confirm whether DRAG stays 1 when LB is 0, and whether ALT/SHIFT/CTRL are stuck.

## Step 38 - Harness input workaround verified
- User confirmed: pan stops correctly and zoom works after applying harness-only fixes (force-clear drag on LB up + direct zoom on wheel).
- Note: This is a test harness workaround; real app should fix input event mapping or zoom handling properly.

## Step 39 - Proper input event pipeline
- Implemented input polling in `pob2_launch.lua` (app + dev): edge-based OnKeyDown/OnKeyUp, wheel -> KeyUp, double-click detection.
- Passive tree Launch.lua now consumes OnKeyDown/OnKeyUp to build inputEvents; removed direct zoom/drag hacks.
- Next: rerun passive tree test to confirm pan/zoom still works without harness workarounds.
