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

It used to argue with a copy. Four numbers were written out again here by hand
and the geometry drawn a second time, so that the sheet could disagree with the
icon rather than merely repeat it. That was a good arrangement for a circle and
is a bad one now: the mark's sand level is solved rather than chosen, and a
hand-copy of a solved number is not a second opinion, it is a chance to be shown
an icon that is not the one that ships.

So it reads the PNG instead and shrinks it, which is both the thing that cannot
drift and the thing iOS itself does. Averaging every source pixel that lands in
a destination pixel is what a good downsample is; it is also, usefully, the
harshest honest test of a thin line, because a wall a pixel and a half wide
comes out grey rather than gone and you can see exactly how much of it is left.
"""

import struct
import zlib
from pathlib import Path

# iOS masks every icon with a continuous rounded square. An exponent near 4.6
# is close enough to judge a layout by.
SQUIRCLE = 4.6

WIDTH, HEIGHT = 1100, 560
SIZES = [180, 120, 87, 60]      # 60pt, 40pt, 29pt at 3x, and the App Library
SAMPLES = (-0.33, 0.0, 0.33)    # 3x3 supersampling, enough for a smooth edge


def read_png(path: Path):
    """The pixels of an 8-bit RGB PNG, as rows of (r, g, b).

    Only the one shape `make-icon.py` writes: no palette, no alpha, no
    interlacing. Anything else is a PNG this was not asked to read, and saying
    so is better than quietly producing a sheet of the wrong thing.
    """
    blob = path.read_bytes()
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")

    at, header, data = 8, None, bytearray()
    while at < len(blob):
        length = struct.unpack(">I", blob[at:at + 4])[0]
        kind = blob[at + 4:at + 8]
        payload = blob[at + 8:at + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">2I5B", payload)
        elif kind == b"IDAT":
            data += payload
        at += 12 + length

    side, tall, depth, colour, _, _, interlace = header
    if (depth, colour, interlace) != (8, 2, 0):
        raise ValueError(f"{path} is not the 8-bit RGB the icon is written as")

    raw = zlib.decompress(bytes(data))
    stride = side * 3
    pixels, previous = [], bytearray(stride)
    at = 0
    for _ in range(tall):
        filter_type, line = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            left = line[i - 3] if i >= 3 else 0
            up = previous[i]
            corner = previous[i - 3] if i >= 3 else 0
            if filter_type == 1:
                line[i] = (line[i] + left) & 0xFF
            elif filter_type == 2:
                line[i] = (line[i] + up) & 0xFF
            elif filter_type == 3:
                line[i] = (line[i] + (left + up) // 2) & 0xFF
            elif filter_type == 4:
                estimate = left + up - corner
                a, b, c = (abs(estimate - left), abs(estimate - up),
                           abs(estimate - corner))
                nearest = left if a <= b and a <= c else (up if b <= c else corner)
                line[i] = (line[i] + nearest) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unknown PNG filter {filter_type}")
        pixels.append([tuple(line[x * 3:x * 3 + 3]) for x in range(side)])
        previous = line
    return pixels


def shrink(source, side: int):
    """The artwork at `side` pixels, by averaging what falls in each one."""
    tall = len(source)
    scale = tall / side
    out = []
    for y in range(side):
        top, bottom = int(y * scale), max(int((y + 1) * scale), int(y * scale) + 1)
        row = []
        for x in range(side):
            left, right = int(x * scale), max(int((x + 1) * scale), int(x * scale) + 1)
            r = g = b = 0
            for sy in range(top, bottom):
                line = source[sy]
                for sx in range(left, right):
                    pixel = line[sx]
                    r += pixel[0]
                    g += pixel[1]
                    b += pixel[2]
            count = (bottom - top) * (right - left)
            row.append((r // count, g // count, b // count))
        out.append(row)
    return out


def _coverage(inside) -> float:
    hits = sum(1 for dy in SAMPLES for dx in SAMPLES if inside(dx, dy))
    return hits / (len(SAMPLES) ** 2)


def _mask(x: int, y: int, side: int) -> float:
    def inside(dx, dy):
        u = (x + 0.5 + dx) / side * 2 - 1
        v = (y + 0.5 + dy) / side * 2 - 1
        return abs(u) ** SQUIRCLE + abs(v) ** SQUIRCLE <= 1
    return _coverage(inside)


def icon(artwork, side: int):
    colours = shrink(artwork, side)
    alpha = [[_mask(x, y, side) for x in range(side)] for y in range(side)]
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
    here = Path(__file__).resolve().parent
    artwork = read_png(
        here.parent / "Quiet/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    )

    canvas = wallpapers()
    for origin, tones in ((0, ((214, 210, 202), (198, 194, 186))),
                          (WIDTH // 2, ((64, 64, 72), (52, 52, 60)))):
        left = origin + 60
        for side in SIZES:
            paste(canvas, placeholder(side, tones[0]), left, 70 - side // 6)
            paste(canvas, icon(artwork, side), left, 240 - side // 2)
            paste(canvas, placeholder(side, tones[1]), left, 420 - side // 6)
            left += side + 34

    destination = here / "icon-in-place.png"
    write_png(canvas, destination)
    print(f"wrote {destination} ({destination.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
