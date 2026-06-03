#!/usr/bin/env python3
"""convert_tree_dds.py — make GGG 0.5+ texture-array tree art renderable on macOS.

Background: from 0.17, GGG ships passive-tree sprites as `.dds.zst` *texture
arrays* (zstd-compressed DDS, BC7/BC1/RGBA, arraySize layers — one icon per
layer). tree.lua addresses them via `ddsCoords[sheet][name]=layerIndex`. The
macOS SimpleGraphic.dylib renders only 2D images (stb_image) and blits sub-rects
via `spriteCoords[sheet][name]={x,y,w,h}` — the model GGG used through 0.16 and
the only path proven on this dylib (0.16 `ddsCoords` is empty). The dylib cannot
be rebuilt.

This script bridges the two: for each referenced sheet it decodes the used array
layers, packs them into a single 2D atlas PNG (written *into* the `.dds.zst`
filename so stb_image sniffs PNG by magic — same keep-the-name trick as
convert-tree-webp.sh), and rewrites tree.lua to drop ddsCoords and emit the
equivalent spriteCoords. The renderer then draws 0.17 art unchanged.

skills-disabled_* sheets are skipped: 0.16 had no disabled sheet and the renderer
desaturates the active icon for unallocated nodes, so they are redundant here.

Usage: convert_tree_dds.py <tree.lua> <sheet-dir>   (edits tree.lua in place,
overwrites the referenced *.dds.zst files with PNG content)
"""
import math, re, struct, sys, zstandard
import numpy as np
import imagecodecs
from PIL import Image

BC1 = (70, 71, 72)
BC7 = (97, 98, 99)
RGBA = (28, 29, 87)


def parse_ddscoords(txt):
    i = txt.index("ddsCoords={"); j = i + len("ddsCoords="); d = 0; k = j
    while k < len(txt):
        if txt[k] == "{": d += 1
        elif txt[k] == "}":
            d -= 1
            if d == 0: break
        k += 1
    blk = txt[j:k + 1]
    sheets = {}
    for m in re.finditer(r'\["([^"]+\.dds\.zst)"\]=\{', blk):
        name = m.group(1); s = m.end() - 1; dd = 0; p = s
        while p < len(blk):
            if blk[p] == "{": dd += 1
            elif blk[p] == "}":
                dd -= 1
                if dd == 0: break
            p += 1
        body = blk[s:p + 1]
        # ddsCoords entries use TWO Lua key syntaxes, both mapping name->layer:
        #   ["art/.../Icon.dds"]=N   (quoted path keys)
        #   JewelFrameAllocated=N    (bare identifier keys — UI frame sprites!)
        # Capturing only the quoted form silently drops the frame overlays
        # (PSSkillFrame*, *Frame{Allocated,CanAllocate,Unallocated}) that
        # nodeOverlay needs, which crashes PassiveTree.lua:302 (nil asset).
        entries = {}
        for em in re.finditer(r'(?:\["([^"]+)"\]|([A-Za-z_][\w.-]*))\s*=\s*(\d+)', body):
            key = em.group(1) if em.group(1) is not None else em.group(2)
            entries[key] = int(em.group(3))
        sheets[name] = entries
    return sheets, (i, k + 1)  # block span in txt


def dds_layer_mip0(raw, layer):
    """Return RGBA ndarray for mip0 of array `layer` (0-based)."""
    fourcc = raw[84:88]
    if fourcc == b"DX10":
        dxgi = struct.unpack_from("<I", raw, 128)[0]
        arr = struct.unpack_from("<I", raw, 140)[0]
        off = 148
    else:
        raise ValueError("non-DX10 DDS not expected")
    w = struct.unpack_from("<I", raw, 16)[0]
    h = struct.unpack_from("<I", raw, 12)[0]
    body = len(raw) - off
    stride = body // arr
    base = off + layer * stride
    if dxgi in BC1:
        n = ((w + 3) // 4) * ((h + 3) // 4) * 8
        a = imagecodecs.bcn_decode(raw[base:base + n], 1, shape=(h, w, 4))
        return np.asarray(a), w, h
    if dxgi in BC7:
        n = ((w + 3) // 4) * ((h + 3) // 4) * 16
        a = imagecodecs.bcn_decode(raw[base:base + n], 7, shape=(h, w, 4))
        return np.asarray(a), w, h
    if dxgi in RGBA:
        n = w * h * 4
        a = np.frombuffer(raw[base:base + n], np.uint8).reshape(h, w, 4).copy()
        if dxgi == 87:  # BGRA
            a = a[:, :, [2, 1, 0, 3]]
        return a, w, h
    raise ValueError("unsupported dxgi %d" % dxgi)


def lua_sprite_table(sprite_coords):
    """Emit spriteCoords={...} Lua, sorted for determinism."""
    out = ["spriteCoords={"]
    for sheet in sorted(sprite_coords):
        out.append('\t\t["%s"]={' % sheet)
        for name in sorted(sprite_coords[sheet]):
            x, y, w, h = sprite_coords[sheet][name]
            out.append('\t\t\t["%s"]={' % name)
            out.append("\t\t\t\th=%d," % h)
            out.append("\t\t\t\tw=%d," % w)
            out.append("\t\t\t\tx=%d," % x)
            out.append("\t\t\t\ty=%d" % y)
            out.append("\t\t\t},")
        out.append("\t\t},")
    out.append("\t}")
    return "\n".join(out)


def main():
    tree_path, sheet_dir = sys.argv[1], sys.argv[2]
    txt = open(tree_path, encoding="utf-8").read()
    sheets, _ = parse_ddscoords(txt)
    # Idempotency: if ddsCoords is already empty, this tree.lua was already
    # converted (build-app.sh re-runs us). Re-running would wipe spriteCoords.
    if not any(sheets.values()):
        print("convert_tree_dds: ddsCoords already empty -> already converted, skip")
        return
    import os
    dctx = zstandard.ZstdDecompressor()
    sprite_coords = {}
    skipped = []
    for sheet, entries in sheets.items():
        zpath = "%s/%s" % (sheet_dir, sheet)
        if sheet.startswith("skills-disabled") or not entries:
            skipped.append((sheet, "empty" if not entries else "disabled"))
            if os.path.exists(zpath):  # unreferenced raw array -> drop it
                os.remove(zpath)
            continue
        raw = dctx.decompress(open(zpath, "rb").read())
        # decode each referenced layer
        tiles = {}
        tw = th = 0
        for name, layer in entries.items():
            arr, w, h = dds_layer_mip0(raw, layer - 1)  # 1-based -> 0-based
            tiles[name] = arr; tw, th = w, h
        n = len(tiles)
        cols = max(1, math.ceil(math.sqrt(n)))
        rows = math.ceil(n / cols)
        atlas = np.zeros((rows * th, cols * tw, 4), np.uint8)
        coords = {}
        for idx, name in enumerate(sorted(tiles)):
            cx, cy = (idx % cols) * tw, (idx // cols) * th
            atlas[cy:cy + th, cx:cx + tw] = tiles[name]
            coords[name] = (cx, cy, tw, th)
        # The macOS dylib routes image loads by EXTENSION: `.dds.zst` goes to a
        # zstd+DDS decoder (which chokes on PNG bytes — "Failed to get DDS
        # decompressed size"), so the atlas must be written as a real `.png`.
        # spriteCoords is keyed by this `.png` filename; the original `.dds.zst`
        # is removed (unreferenced after the rewrite).
        png_name = sheet[:-len(".dds.zst")] + ".png"
        Image.fromarray(atlas, "RGBA").save("%s/%s" % (sheet_dir, png_name), format="PNG")
        if os.path.exists(zpath):
            os.remove(zpath)
        sprite_coords[png_name] = coords
        print("  atlas %-44s %d tiles %dx%d -> %dx%d" % (png_name, n, tw, th, atlas.shape[1], atlas.shape[0]))
    print("skipped:", ", ".join("%s(%s)" % s for s in skipped))

    # rewrite tree.lua: ddsCoords={}  +  spriteCoords=<generated>
    txt2 = re.sub(r"ddsCoords=\{.*?\n\t\},", "ddsCoords={\n\t},", txt, count=1, flags=re.S)
    new_sprites = lua_sprite_table(sprite_coords)
    if "spriteCoords={" in txt2:
        txt2 = re.sub(r"spriteCoords=\{.*?\n\t\}", new_sprites, txt2, count=1, flags=re.S)
    else:
        # insert after ddsCoords block
        txt2 = txt2.replace("ddsCoords={\n\t},", "ddsCoords={\n\t},\n\t" + new_sprites + ",", 1)
    open(tree_path, "w", encoding="utf-8").write(txt2)
    print("tree.lua rewritten: %d sheets -> spriteCoords, ddsCoords emptied" % len(sprite_coords))


if __name__ == "__main__":
    main()
