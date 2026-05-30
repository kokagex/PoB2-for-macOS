#!/bin/bash
# scripts/convert-tree-webp.sh — normalize GGG tree art from webp to PNG content.
#
# Why: GGG ships passive-tree art (grindinggear/poe2-skilltree-export prerelease,
# e.g. tag 0.5.0 "0.5.0 Preview") as .webp. The macOS SimpleGraphic.dylib's
# stb_image build does NOT decode webp ("stb_image: unknown image type"), and
# rebuilding the dylib is forbidden (breaks the UI — see pob2macos CLAUDE.md).
#
# Fix: convert each webp to PNG *content* while KEEPING the .webp filename.
# tree.lua references the asset names verbatim ("skills.webp", "background.webp",
# ...) and stb_image sniffs format by magic bytes, so swapping the bytes png-for-
# webp is transparent — no tree.lua edit and no .gitignore change (tree-data
# webp/png are ignored as transient, locally-fetched build inputs).
#
# When: run after syncing tree-data from upstream (new tree art arrives as webp).
# build-app.sh also runs this so release bundles are always safe.
#
# Idempotent: files already in PNG format are skipped. Requires dwebp (libwebp;
# `brew install webp`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$ROOT/tree-data}"

if ! command -v dwebp >/dev/null 2>&1; then
  echo "convert-tree-webp: ERROR — dwebp not found. Install with: brew install webp" >&2
  exit 1
fi

converted=0
skipped=0
while IFS= read -r -d '' f; do
  if file "$f" | grep -qi "Web/P"; then
    tmp="$(mktemp)"
    if dwebp "$f" -o "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$f"
      converted=$((converted + 1))
    else
      rm -f "$tmp"
      echo "convert-tree-webp: WARN — dwebp failed on $f" >&2
    fi
  else
    skipped=$((skipped + 1))
  fi
done < <(find "$TARGET" -type f -name '*.webp' -print0)

echo "convert-tree-webp: converted=$converted skipped(already-png)=$skipped  target=$TARGET"
