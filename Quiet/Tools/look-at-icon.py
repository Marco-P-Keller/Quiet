#!/usr/bin/env python3
"""Put the icon where it will actually be seen, and look at it.

An icon judged as a 1024-pixel file is an icon nobody has judged. What matters
is 60 points on a home screen between other apps, 40 in Spotlight, 29 in
Settings, and whatever the App Library shrinks it to — on a light wallpaper and
a dark one, behind the rounded mask iOS applies whether the artwork expects it
or not.

This draws that sheet. It is deliberately a separate script from
`make-icon.py`: one draws the icon, the other argues with it.

    python3 Tools/look-at-icon.py        # writes icon-in-place.png

The verdict the first sheet produced, when the mark was a full stop: it held at
every size and read as a full stop rather than as dust on the display. That
verdict was about legibility and it was the wrong question. A full stop is
legible and says nothing; it needed somebody to have been told what it meant
first, which is the one thing an icon on a stranger's home screen cannot count
on. The mark is an hourglass now, and the question this sheet asks is the same
one it always asked: at thirty points, in a folder, is it still that object?
"""

import struct
import zlib
from pathlib import Path

# Kept in step with make-icon.py by hand. They are three numbers and this file
# exists to disagree with them, so importing them would defeat the point.
BACKGROUND = (0x19, 0x18, 0x16)
MARK = (0xF2, 0xEE, 0xE7)
WIDTH_OF_GLASS = 0.430
HEIGHT_OF_GLASS = 0.545
CAP = 0.047
WAIST = 0.024
SAND = 0.46
OPTICAL_LIFT = 0.012

# iOS masks every icon with a continuous rounded square. An exponent near 4.6
# is close enough to judge a layout by.
SQUIRCLE = 4.6

WIDTH, HEIGHT = 1100, 560
SIZES = [180, 120, 87, 60]      # 60pt, 40pt, 29pt at 3x, and the App Library
SAMPLES = (-0.33, 0.0, 0.33)    # 3x3 supersampling, enough for a smooth edge


def _coverage(inside) -> float:
    hits = sum(1 for dy in SAMPLES for dx in SAMPLES if inside(dx, dy))
    return hits / (len(SAMPLES) ** 2)


def _mask(x: int, y: int, side: int) -> float:
    def inside(dx, dy):
        u = (x + 0.5 + dx) / side * 2 - 1
        v = (y + 0.5 + dy) / side * 2 - 1
        return abs(u) ** SQUIRCLE + abs(v) ** SQUIRCLE <= 1
    return _coverage(inside)


def _glass(x: int, y: int, side: int) -> float:
    """How much of this pixel the mark covers, and how solidly.

    Written out again rather than imported, which is the whole point of this
    file: two implementations of one shape disagree loudly, and one
    implementation checked against itself agrees about anything.
    """
    centre_x = side / 2
    centre_y = side / 2 - OPTICAL_LIFT * side
    top = centre_y - HEIGHT_OF_GLASS * side / 2
    bottom = centre_y + HEIGHT_OF_GLASS * side / 2
    half = WIDTH_OF_GLASS * side / 2
    neck = WAIST * side / 2
    lid = CAP * side / 2

    def in_glass(px, py, upper):
        first, last = top + 2 * lid, bottom - 2 * lid
        if upper:
            if not first <= py <= centre_y:
                return False
            fallen = (py - first) / (centre_y - first)
        else:
            if not centre_y <= py <= last:
                return False
            fallen = (last - py) / (last - centre_y)
        return abs(px - centre_x) <= half + (neck - half) * fallen

    def in_lid(px, py):
        for at in (top + lid, bottom - lid):
            along = min(max(px, centre_x - half + lid), centre_x + half - lid)
            dx, dy = px - along, py - at
            if dx * dx + dy * dy <= lid * lid:
                return True
        return False

    ink = _coverage(lambda dx, dy: in_lid(x + 0.5 + dx, y + 0.5 + dy)
                    or in_glass(x + 0.5 + dx, y + 0.5 + dy, False))
    sand = _coverage(lambda dx, dy: in_glass(x + 0.5 + dx, y + 0.5 + dy, True))
    return max(ink, sand * SAND)


def icon(side: int):
    colours = [[(0, 0, 0)] * side for _ in range(side)]
    alpha = [[0.0] * side for _ in range(side)]
    for y in range(side):
        for x in range(side):
            outside = _mask(x, y, side)
            if outside <= 0:
                continue
            covered = _glass(x, y, side)
            colours[y][x] = tuple(
                round(b + (m - b) * covered) for b, m in zip(BACKGROUND, MARK)
            )
            alpha[y][x] = outside
    return colours, alpha


def placeholder(side: int, tone):
    """A neighbouring app, so the icon is never judged on its own."""
    colours = [[tone] * side for _ in range(side)]
    alpha = [[_mask(x, y, side) for x in range(side)] for y in range(side)]
    return colours, alpha


def wallpapers():
    canvas = []
    for y in range(HEIGHT):
        row = []
        drift = y / HEIGHT
        for x in range(WIDTH):
            if x < WIDTH // 2:
                row.append((round(228 - 26 * drift), round(224 - 26 * drift), round(216 - 24 * drift)))
            else:
                row.append((round(38 + 14 * drift), round(38 + 14 * drift), round(44 + 14 * drift)))
        canvas.append(row)
    return canvas


def paste(canvas, art, left: int, top: int) -> None:
    colours, alpha = art
    for y, row in enumerate(colours):
        for x, colour in enumerate(row):
            a = alpha[y][x]
            if a <= 0:
                continue
            cy, cx = top + y, left + x
            if 0 <= cy < HEIGHT and 0 <= cx < WIDTH:
                under = canvas[cy][cx]
                canvas[cy][cx] = tuple(round(u + (c - u) * a) for u, c in zip(under, colour))


def write_png(canvas, path: Path) -> None:
    rows = bytearray()
    for row in canvas:
        rows.append(0)
        for pixel in row:
            rows.extend(pixel)

    def chunk(kind: bytes, payload: bytes) -> bytes:
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">2I5B", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    canvas = wallpapers()
    for origin, tones in ((0, ((214, 210, 202), (198, 194, 186))),
                          (WIDTH // 2, ((64, 64, 72), (52, 52, 60)))):
        left = origin + 60
        for side in SIZES:
            paste(canvas, placeholder(side, tones[0]), left, 70 - side // 6)
            paste(canvas, icon(side), left, 240 - side // 2)
            paste(canvas, placeholder(side, tones[1]), left, 420 - side // 6)
            left += side + 34

    destination = Path(__file__).resolve().parent / "icon-in-place.png"
    write_png(canvas, destination)
    print(f"wrote {destination} ({destination.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
