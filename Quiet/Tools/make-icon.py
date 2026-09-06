#!/usr/bin/env python3
"""Draw Quiet's app icon.

An hourglass, half run through, on a dark field.

The mark before this was a full stop — the sentence that ends the scrolling,
set in one shape. It was the most elegant thing the app could have put on a
home screen and it said nothing to anybody who had not already been told. At
sixty points between other icons it is a dot; at thirty, in a folder, it is
dust on the display.

An hourglass says the thing instead of alluding to it, and it says the *right*
thing, which a clock does not. A clock runs for ever, and is somebody else's
app besides. An hourglass runs **out**. It holds a fixed amount, it is spending
it, and when it is empty the day is over — which is the whole of Quiet in one
shape, and it is already the shape the app draws in its own row for the last
five minutes.

The sand that has fallen is solid and the sand still up there is most of the
way back to the ground. That is not decoration: it is the same two-tone the row
uses, and it is what keeps the mark from reading as a bow tie at the size where
the waist becomes a hairline.

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

# The glass, as fractions of the icon. Much wider and it reads as an egg timer
# on a shelf; much narrower and it reads as a letter.
WIDTH = 0.430
HEIGHT = 0.545

# The two lids. Thick enough to survive being drawn at thirty points, thin
# enough that what you notice is the glass between them.
CAP = 0.047

# Where the sand goes through. A hairline reads as two triangles that happen to
# touch; this reads as one object with a neck.
WAIST = 0.024

# How much of the mark the sand still up there is.
#
# A third was tried first and read as a second, darker shape sitting on top of
# the mark — a funnel rather than an hourglass. Near half, the two halves are
# plainly one object with one of them fuller, which is what an hourglass looks
# like, and at thirty points the difference washes out into a solid silhouette
# rather than into a hole.
SAND = 0.46

# A mark at the exact geometric centre reads as sitting slightly low. Lifting it
# by a little over one percent is the correction every typographer makes without
# thinking, and the reason this looks placed rather than calculated.
OPTICAL_LIFT = 0.012

# Four by four inside each pixel, which is seventeen levels of grey along an
# edge. The mark before this was a circle and could be anti-aliased by
# arithmetic — the distance to a point is exact. A pair of triangles and two
# capsules is not one shape but four, and sampling them is both shorter to read
# and impossible to get subtly wrong.
STEPS = (-0.375, -0.125, 0.125, 0.375)


def _px(fraction: float) -> float:
    return fraction * SIZE


CENTRE_X = SIZE / 2
CENTRE_Y = SIZE / 2 - _px(OPTICAL_LIFT)

TOP = CENTRE_Y - _px(HEIGHT) / 2
BOTTOM = CENTRE_Y + _px(HEIGHT) / 2
HALF = _px(WIDTH) / 2
NECK = _px(WAIST) / 2
LID = _px(CAP) / 2


def _in_glass(x: float, y: float, upper: bool) -> bool:
    """Inside the half of the glass above, or below, the neck.

    A triangle with its base at a lid and its apex at the neck is, at any one
    height, an interval — so the whole test is one interpolation and one
    comparison, and there is no polygon arithmetic to get wrong.
    """
    # The glass runs between the lids rather than under them, so a lid is a bar
    # across the end and not a bar with two corners of triangle poking past it.
    top, bottom = TOP + 2 * LID, BOTTOM - 2 * LID
    if upper:
        if not top <= y <= CENTRE_Y:
            return False
        fallen = (y - top) / (CENTRE_Y - top)
    else:
        if not CENTRE_Y <= y <= bottom:
            return False
        fallen = (bottom - y) / (bottom - CENTRE_Y)
    return abs(x - CENTRE_X) <= HALF + (NECK - HALF) * fallen


def _in_lid(x: float, y: float) -> bool:
    """Inside either lid: a capsule the width of the glass, at each end."""
    for centre in (TOP + LID, BOTTOM - LID):
        along = min(max(x, CENTRE_X - HALF + LID), CENTRE_X + HALF - LID)
        dx, dy = x - along, y - centre
        if dx * dx + dy * dy <= LID * LID:
            return True
    return False


def _coverage(x: int, y: int, inside) -> float:
    hits = sum(
        1
        for dy in STEPS
        for dx in STEPS
        if inside(x + 0.5 + dx, y + 0.5 + dy)
    )
    return hits / (len(STEPS) ** 2)


def render() -> bytes:
    rows = bytearray()
    for row in range(SIZE):
        rows.append(0)  # PNG filter type: none
        for column in range(SIZE):
            ink = _coverage(
                column, row, lambda x, y: _in_lid(x, y) or _in_glass(x, y, False)
            )
            sand = _coverage(column, row, lambda x, y: _in_glass(x, y, True))
            # The sand first and the ink over it, so a lid drawn across the top
            # of the sand is the lid's colour rather than a blend of the two.
            weight = max(ink, sand * SAND)
            for background, mark in zip(BACKGROUND, MARK):
                rows.append(round(background + (mark - background) * weight))
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
