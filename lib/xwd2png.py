#!/usr/bin/env python3
"""Convert an xwd screenshot to PNG, with no third-party dependency.

Usage: xwd2png.py IN.xwd|- OUT.png [x y w h]
Reads stdin when IN is "-". Only 24-bit depth, 32 bits per pixel xwd files are supported
(what Xvfb produces). The optional x y w h arguments crop the output.
"""
import struct
import sys
import zlib

if len(sys.argv) not in (3, 7):
    sys.exit(__doc__)

source = sys.argv[1]
data = sys.stdin.buffer.read() if source == "-" else open(source, "rb").read()
header = struct.unpack(">25I", data[:100])
size, _, _, depth, width, height, _, _, _, order, _, bpp, stride, _, red, green, blue, _, _, colors, *_ = header
if not (depth == 24 and bpp == 32 and order == 0 and red == 0xFF0000 and green == 0xFF00 and blue == 0xFF):
    sys.exit("xwd2png: unsupported xwd format (expected 24-bit depth, 32 bpp, LSB first)")

start = size + colors * 12
x0, y0, crop_width, crop_height = map(int, sys.argv[3:7]) if len(sys.argv) == 7 else (0, 0, width, height)
if not (0 <= x0 and 0 <= y0 and crop_width > 0 and crop_height > 0 and x0 + crop_width <= width and y0 + crop_height <= height):
    sys.exit(f"xwd2png: area outside the screen ({width}x{height})")

rows = []
for y in range(y0, y0 + crop_height):
    row = data[start + y * stride + x0 * 4 : start + y * stride + (x0 + crop_width) * 4]
    rows.append(b"\0" + b"".join(bytes((row[i + 2], row[i + 1], row[i])) for i in range(0, len(row), 4)))
raw = zlib.compress(b"".join(rows), 9)


def chunk(tag, value):
    return struct.pack(">I", len(value)) + tag + value + struct.pack(">I", zlib.crc32(tag + value) & 0xFFFFFFFF)


png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", crop_width, crop_height, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", raw)
    + chunk(b"IEND", b"")
)
with open(sys.argv[2], "wb") as output:
    output.write(png)
