#!/usr/bin/env python3
"""Draw Quiet's app icon.

One line on a dark field. It is the "minus" in "Instagram, minus the parts that
keep you there", and it is a screen with nothing on it. At 60 points on a home
screen it still reads as a single deliberate stroke rather than a smudge, which
is the only thing an icon this small has to do.

Kept as a script rather than a checked-in mystery PNG so the shape can be
argued with. Uses nothing but the standard library.

    python3 Tools/make-icon.py
"""

import struct
import zlib
from pathlib import Path

SIZE = 1024
BACKGROUND = (0x19, 0x18, 0x16)   # warm near-black, never pure black
STROKE = (0xF2, 0xEE, 0xE7)       # warm off-white, never pure white

STROKE_WIDTH = 0.46 * SIZE        # of the icon's width
STROKE_THICKNESS = 0.050 * SIZE   # thick enough to survive being shrunk
FEATHER = 1.0                     # pixels of anti-aliasing


def coverage(x: float, y: float) -> float:
    """How much of the pixel at (x, y) the stroke covers, from 0 to 1.

    The stroke is a capsule: a horizontal segment with round caps. Distance to
    a segment is cheap to compute exactly, so the edge can be anti-aliased
    properly instead of being stair-stepped.
    """
    half_length = (STROKE_WIDTH - STROKE_THICKNESS) / 2
    radius = STROKE_THICKNESS / 2
    centre = SIZE / 2

    dx = max(abs(x - centre) - half_length, 0.0)
    dy = y - centre
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
            for background, stroke in zip(BACKGROUND, STROKE):
                rows.append(round(background + (stroke - background) * alpha))
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
