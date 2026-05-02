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
RUNTIME="$RES/runtime"
VERSION="${VERSION:-dev}"

echo "==> mode=$mode  app=$APP"

# 1. Clean and create skeleton
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES" "$RUNTIME"

# 2. App bundle template (Info.plist, .icns)
cp "$ROOT/package/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/package/Resources/Info.plist" "$RES/"
cp "$ROOT/package/Resources/"*.icns "$RES/"

# 3. C++ build (PathOfBuilding binary + dylibs)
echo "==> Building native binary and dylibs..."
BUILD_DIR="$ROOT/pob2macos/simplegraphic/build"
mkdir -p "$BUILD_DIR"
( cd "$BUILD_DIR" && cmake .. && make -j )

# Copy build outputs. Adjust source paths if CMakeLists.txt installs elsewhere.
if [[ -f "$BUILD_DIR/PathOfBuilding" ]]; then
  cp "$BUILD_DIR/PathOfBuilding" "$APP/Contents/MacOS/PathOfBuilding"
fi
cp "$BUILD_DIR/"*.dylib "$RUNTIME/" 2>/dev/null || true

# 4. Lua source / data placement
if [[ "$mode" == "--dev" ]]; then
  echo "==> Dev mode: symlinking sources..."
  ln -sfn "$ROOT/src" "$RES/src"
  ln -sfn "$ROOT/runtime/lua" "$RUNTIME/lua"
  [[ -d "$ROOT/runtime/fonts" ]] && ln -sfn "$ROOT/runtime/fonts" "$RUNTIME/fonts"
  ln -sfn "$ROOT/tree-data" "$RES/TreeData"
else
  echo "==> Release mode: copying sources..."
  cp -R "$ROOT/src" "$RES/"
  cp -R "$ROOT/runtime/lua" "$RUNTIME/"
  [[ -d "$ROOT/runtime/fonts" ]] && cp -R "$ROOT/runtime/fonts" "$RUNTIME/"
  cp -R "$ROOT/tree-data" "$RES/TreeData"
fi

# 5. Root scripts and metadata into Resources/
cp "$ROOT/pob2_launch.lua" "$ROOT/LaunchServer.lua" "$RES/"
cp "$ROOT/manifest.xml" "$ROOT/changelog.txt" "$RES/"

# 6. SGPAK archives (rebuilt from current src/Assets and tree-data)
echo "==> Rebuilding SGPAK archives..."
PATH_OF_BUILDING_RES="$RES" bash "$ROOT/pob2macos/tools/rebuild_archives.sh"

# 7. Release: codesign + zip
if [[ "$mode" == "--release" ]]; then
  echo "==> Codesigning..."
  xattr -cr "$APP"
  codesign --force --deep --sign - "$APP"
  echo "==> Packing release zip..."
  ( cd "$DIST" && zip -ryq "PathOfBuilding-macOS-${VERSION}.zip" "PathOfBuilding.app" )
  echo "==> Built: $DIST/PathOfBuilding-macOS-${VERSION}.zip"
else
  echo "==> Built (dev): $APP"
fi
