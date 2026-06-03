#!/bin/bash
# scripts/convert-tree-dds.sh — normalize GGG 0.5+ tree art from .dds.zst to PNG.
#
# Why: from 0.17, GGG ships passive-tree sprites as `.dds.zst` *texture arrays*
# (zstd-compressed DDS; BC7/BC1/RGBA; one icon per array layer), addressed by
# tree.lua via `ddsCoords[sheet][name]=layerIndex`. The macOS SimpleGraphic.dylib
# renders only 2D images (stb_image) and blits sub-rects via
# `spriteCoords[sheet][name]={x,y,w,h}` — the model GGG used through 0.16, and the
# only path proven on this dylib (rebuilding the dylib is forbidden).
#
# Fix: scripts/convert_tree_dds.py decodes the referenced layers, packs them into
# a 2D atlas PNG written *into* the `.dds.zst` filename (stb_image sniffs PNG by
# magic — same keep-the-name trick as convert-tree-webp.sh), and rewrites tree.lua
# (ddsCoords -> spriteCoords). Idempotent: a no-op once ddsCoords is empty.
#
# When: run after syncing tree-data from upstream. build-app.sh runs it too.
# Requires python3 with: imagecodecs, Pillow, numpy, zstandard.
#   pip install imagecodecs Pillow numpy zstandard
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$ROOT/tree-data}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "convert-tree-dds: ERROR — python3 not found." >&2
  exit 1
fi

shopt -s nullglob
converted=0
for tree in "$TARGET"/*/tree.lua; do
  dir="$(dirname "$tree")"
  # convert_tree_dds.py is a no-op when ddsCoords is already empty (idempotent).
  if compgen -G "$dir/*.dds.zst" >/dev/null; then
    python3 "$ROOT/scripts/convert_tree_dds.py" "$tree" "$dir"
    converted=$((converted + 1))
  fi
done
echo "convert-tree-dds: processed $converted tree(s)  target=$TARGET"
