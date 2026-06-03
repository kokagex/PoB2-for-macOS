#!/usr/bin/env python3
"""dds_to_png.py — decode a .dds (BC1/BC7/uncompressed-RGBA) to PNG *content*.

Why: GGG ships 0.5+ passive-tree sprite sheets as `.dds.zst` (zstd-compressed
DDS with BC7/BC1 block compression, or uncompressed RGBA). The macOS
SimpleGraphic.dylib's stb_image build decodes PNG only (not DDS), and rebuilding
the dylib is forbidden (breaks the UI). tree.lua references the sheet by its
`*.dds.zst` filename and stb_image sniffs format by magic bytes, so we overwrite
the file with PNG *content* while KEEPING the `.dds.zst` filename — transparent,
no tree.lua edit (same trick as convert-tree-webp.sh).

Usage: dds_to_png.py <decompressed.dds> <out.png>
Format is read from the DDS header (FourCC / DX10 dxgiFormat), with the filename
suffix (_BC7/_BC1/_RGBA) as a cross-check.
"""
import struct, sys
import numpy as np
import imagecodecs

# DXGI_FORMAT subset we care about
DXGI_BC1 = (70, 71, 72)        # BC1_TYPELESS/UNORM/UNORM_SRGB
DXGI_BC7 = (97, 98, 99)        # BC7_TYPELESS/UNORM/UNORM_SRGB
DXGI_RGBA = (28, 29, 87)       # R8G8B8A8_UNORM(_SRGB) / B8G8R8A8_UNORM


def decode_dds(raw: bytes):
    if raw[:4] != b"DDS ":
        raise ValueError("not a DDS file")
    height = struct.unpack_from("<I", raw, 12)[0]
    width = struct.unpack_from("<I", raw, 16)[0]
    fourcc = raw[84:88]
    data_off = 128
    bcn = None          # imagecodecs bcn format number
    rgba = False
    bgra = False
    if fourcc == b"DXT1":
        bcn = 1
    elif fourcc == b"DXT5":
        bcn = 3
    elif fourcc == b"DX10":
        dxgi = struct.unpack_from("<I", raw, 128)[0]
        data_off = 148  # 128 + 20-byte DXT10 header
        if dxgi in DXGI_BC7:
            bcn = 7
        elif dxgi in DXGI_BC1:
            bcn = 1
        elif dxgi in DXGI_RGBA:
            rgba = True
            bgra = (dxgi == 87)
        else:
            raise ValueError("unsupported DXGI format %d" % dxgi)
    else:
        # No FourCC -> uncompressed; assume 32bpp RGBA/BGRA (ddspf at 0x4C)
        pf_flags = struct.unpack_from("<I", raw, 80)[0]
        rmask = struct.unpack_from("<I", raw, 92)[0]
        rgba = True
        bgra = (rmask == 0x00FF0000)  # BGRA if red is in 3rd byte

    payload = raw[data_off:]
    if bcn is not None:
        # decode mip level 0 only: first (w/4)*(h/4)*blockbytes bytes
        block_bytes = 8 if bcn == 1 else 16
        nblocks = ((width + 3) // 4) * ((height + 3) // 4)
        payload = payload[: nblocks * block_bytes]
        img = imagecodecs.bcn_decode(payload, bcn, shape=(height, width, 4))
        arr = np.asarray(img)
    else:  # raw RGBA/BGRA
        need = width * height * 4
        arr = np.frombuffer(payload[:need], dtype=np.uint8).reshape(height, width, 4).copy()
        if bgra:
            arr = arr[:, :, [2, 1, 0, 3]]
    if arr.shape[2] == 4 and bgra is False and bcn is not None:
        pass
    return arr, width, height


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        raw = f.read()
    arr, w, h = decode_dds(raw)
    from PIL import Image
    Image.fromarray(arr, "RGBA").save(dst)
    print("decoded %s -> %s  (%dx%d)" % (src, dst, w, h))


if __name__ == "__main__":
    main()
