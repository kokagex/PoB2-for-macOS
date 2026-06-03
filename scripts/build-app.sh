#!/bin/bash
# scripts/build-app.sh — assemble PathOfBuilding.app from repo sources.
#
# Usage:
#   bash scripts/build-app.sh --dev      # symlink sources for fast iteration
#   bash scripts/build-app.sh --release  # cp + codesign + zip (default)
#
# Optional env:
#   VERSION=x.y.z   release zip will be named PathOfBuilding-macOS-x.y.z.zip
set -euo pipefail

mode="${1:---release}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/PathOfBuilding.app"
RES="$APP/Contents/Resources"
VERSION="${VERSION:-dev}"

echo "==> mode=$mode  app=$APP"

# 1. Clean and create skeleton (runtime/ is created by section 4 below)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES"

# 2. App bundle template (Info.plist, .icns)
cp "$ROOT/package/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/package/Resources/Info.plist" "$RES/"
cp "$ROOT/package/Resources/"*.icns "$RES/"

# 3. Launcher script (zsh wrapper that exec's luajit pob2_launch.lua)
cp "$ROOT/package/MacOS/PathOfBuilding" "$APP/Contents/MacOS/PathOfBuilding"
chmod +x "$APP/Contents/MacOS/PathOfBuilding"

# 3b. Normalize tree art: GGG ships passive-tree sprites as webp, which the
# macOS dylib's stb_image cannot decode. Convert webp -> PNG content in place
# (idempotent) before copying/symlinking. Covers both --dev (symlink reads
# source) and --release (cp copies source). See scripts/convert-tree-webp.sh.
bash "$ROOT/scripts/convert-tree-webp.sh" "$ROOT/tree-data"

# 3c. Normalize 0.5+ tree art shipped as `.dds.zst` texture arrays (BC7/BC1):
# decode + repack into 2D atlas PNGs and rewrite tree.lua ddsCoords->spriteCoords
# so the stb_image-only dylib can render it. Idempotent. See convert-tree-dds.sh.
bash "$ROOT/scripts/convert-tree-dds.sh" "$ROOT/tree-data"

# 4. Lua source, runtime (lua libs + dylibs), tree data
# Note: dylibs (SimpleGraphic, libSimpleGraphic, CharInput) are tracked in
# runtime/ as fixed assets — pob2macos/.claude/CLAUDE.md says rebuilding
# SimpleGraphic.dylib breaks the UI, so they live here as committed binaries.
if [[ "$mode" == "--dev" ]]; then
  echo "==> Dev mode: symlinking sources..."
  ln -sfn "$ROOT/src" "$RES/src"
  ln -sfn "$ROOT/runtime" "$RES/runtime"
  ln -sfn "$ROOT/tree-data" "$RES/TreeData"
else
  echo "==> Release mode: copying sources..."
  cp -R "$ROOT/src" "$RES/"
  cp -R "$ROOT/runtime" "$RES/"
  cp -R "$ROOT/tree-data" "$RES/TreeData"
fi

# 4b. Compatibility symlinks: Lua code references Assets/... and Data/...
# with paths relative to Contents/Resources/ (CWD at runtime). Pre-refactor
# these were tracked symlinks pointing into src/Assets and src/Data; we
# recreate them at build time so the Lua paths keep resolving.
( cd "$RES" && ln -sfn src/Assets Assets && ln -sfn src/Data Data )

# 5. Root scripts and metadata into Resources/
cp "$ROOT/pob2_launch.lua" "$ROOT/LaunchServer.lua" "$RES/"
cp "$ROOT/manifest.xml" "$ROOT/changelog.txt" "$RES/"

# 6. SGPAK archives. Rebuild from current src/Assets + tree-data,
# or borrow pre-built sgpak from a directory (for environments
# without zstandard installed).
if [[ -n "${ARCHIVES_DIR:-}" ]]; then
  echo "==> Borrowing prebuilt SGPAK archives from $ARCHIVES_DIR"
  mkdir -p "$RES/archives"
  cp "$ARCHIVES_DIR/"*.sgpak "$RES/archives/"
else
  echo "==> Rebuilding SGPAK archives..."
  PATH_OF_BUILDING_RES="$RES" bash "$ROOT/pob2macos/tools/rebuild_archives.sh"
fi

# 7. Release: codesign + zip
if [[ "$mode" == "--release" ]]; then
  # cp -R copies src/TreeData (a tracked symlink -> ../tree-data) into the bundle
  # as a dangling symlink pointing outside the bundle. xattr -cr and
  # codesign --deep both abort on it ("No such file" / "Too many levels of
  # symbolic links"). The 0.5 tree data is already present as a real copy under
  # $RES/TreeData, so this in-src link is redundant. Strip any dangling symlinks
  # before signing.
  echo "==> Removing dangling symlinks before codesign..."
  find "$APP" -type l ! -exec test -e {} \; -delete
  echo "==> Codesigning..."
  xattr -cr "$APP"
  codesign --force --deep --sign - "$APP"
  echo "==> Packing release zip..."
  ( cd "$DIST" && zip -ryq "PathOfBuilding-macOS-${VERSION}.zip" "PathOfBuilding.app" )
  echo "==> Built: $DIST/PathOfBuilding-macOS-${VERSION}.zip"
else
  echo "==> Built (dev): $APP"
fi
