#!/usr/bin/env python3
"""Draw Quiet's app icon.

A full stop, on a dark field.

The first attempt was a horizontal line — the "minus" in "Instagram, minus the
parts that keep you there". Rendered at size it read as a minus *button*, or a
progress bar: a control rather than a mark. A period does not have that problem,
and it says the better half of the idea anyway. Quiet is the sentence that ends
the scrolling. It is the app's own best line, set in one shape:

    That's all for today.

Kept as a script rather than a checked-in mystery PNG so the shape can be
argued with. Uses nothing but the standard library.

    python3 Tools/make-icon.py
"""

import struct
import zlib
from pathlib import Path

SIZE = 1024
BACKGROUND = (0x19, 0x18, 0x16)   # warm near-black, never pure black
MARK = (0xF2, 0xEE, 0xE7)         # warm off-white, never pure white

# Big enough to be a deliberate mark at a home screen's 60 points rather than a
# speck of dust; small enough that what you notice first is the space round it.
DIAMETER = 0.175 * SIZE

# A mark at the exact geometric centre reads as sitting slightly low. Lifting it
# by a little over one percent is the correction every typographer makes without
# thinking, and the reason this looks placed rather than calculated.
OPTICAL_LIFT = 0.013 * SIZE

FEATHER = 1.0                     # pixels of anti-aliasing


def coverage(x: float, y: float) -> float:
    """How much of the pixel at (x, y) the mark covers, from 0 to 1.

    Distance to a point is exact and cheap, so the edge can be anti-aliased
    properly instead of being stair-stepped.
    """
    radius = DIAMETER / 2
    dx = x - SIZE / 2
    dy = y - (SIZE / 2 - OPTICAL_LIFT)
    distance = (dx * dx + dy * dy) ** 0.5

    if distance <= radius - FEATHER / 2:
        return 1.0
    if distance >= radius + FEATHER / 2:
        return 0.0
    return (radius + FEATHER / 2 - distance) / FEATHER


def render() -> bytes:
    rows = bytearray()
    for row in range(SIZE):
        rows.append(0)  # PNG filter type: none
        y = row + 0.5
        for column in range(SIZE):
            alpha = coverage(column + 0.5, y)
            for background, mark in zip(BACKGROUND, MARK):
                rows.append(round(background + (mark - background) * alpha))
    return bytes(rows)


def chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))


def write_png(path: Path) -> None:
    header = struct.pack(">2I5B", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB, no alpha
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(render(), 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


if __name__ == "__main__":
    destination = (
        Path(__file__).resolve().parent.parent
        / "Quiet/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    )
    write_png(destination)
    print(f"wrote {destination} ({destination.stat().st_size:,} bytes)")
