#!/usr/bin/env python3
"""
Measure Quiet's floating row in a simulator screenshot.

    python3 Tools/measure-the-row.py shot.png

This exists because a disagreement about two millimetres cost four rounds of
build, upload, install and look. Two of those rounds were spent arguing about
which build was on the phone, which is not a question anybody should have to
answer by eye. A number printed on every push settles it: if CI says the island
stands thirty-eight points off the bottom edge and a photograph says twenty-five,
the photograph is of an older build and there is nothing to debate.

It measures the drawn thing rather than the constant. Reading `islandLift` back
out of the source would prove only that the source says what it says.

The screenshot has to be taken before the page arrives, while Quiet's own cover
is still up, so that the island stands on a flat colour. `-QuietRehearsal
island` does that.

The column is a quarter of the way across on purpose: far enough in to be past
the capsule's rounded corner, far enough out to miss the home indicator, which
the system draws over the app and which is the brightest thing on the screen.
"""

import sys
from PIL import Image

# Screens Quiet runs on, by the width of their screenshot. Everything current
# is three pixels to the point; the fallback says so rather than guessing.
POINTS = {750: 375, 828: 414, 1080: 360, 1125: 375, 1170: 390, 1179: 393,
          1206: 402, 1242: 414, 1284: 428, 1290: 430, 1320: 440}

# Two thresholds, because the two questions are not the same one.
#
# DIFFERENT is "this is not the background". It is small, because a translucent
# capsule over a plain colour is a gentle difference — over white it is about
# thirteen levels — and a threshold set to catch a bold edge would miss it.
#
# FLAT is "these rows are the same thing". It is smaller still, because that is
# what tells a capsule from a shadow: a capsule is a plateau and a shadow is a
# ramp.
DIFFERENT = 6
FLAT = 4

# How tall a plateau has to be before it is believed to be the row. The row is
# about fifty points; a shadow is about twenty and never flat. This is the whole
# reason the first version of this script answered 2.3 points and 8.7 points —
# it found the leading edge of the island's own shadow and reported it as the
# island, which is exactly the mistake it exists to catch somebody else making.
PLATEAU = 30

def measure(path):
    image = Image.open(path).convert("L")
    width, height = image.size
    points = POINTS.get(width, width / 3)
    scale = width / points
    pixels = image.load()

    x = round(width * 0.25)
    column = [pixels[x, y] for y in range(height)]
    ground = column[height - 1]

    def profile():
        """What the column actually looked like, always printed.

        A measurement nobody can check is a number to be argued with. Every
        second point over the bottom hundred and forty, so a surprising answer
        can be understood from the log rather than from another build."""
        rows = []
        for pt in range(0, 140, 2):
            y = height - 1 - round(pt * scale)
            if y < 0:
                break
            rows.append(f"{pt}:{column[y]}")
        return " ".join(rows)

    tall = max(2, round(PLATEAU * scale))

    def plateau_at(y):
        """Is y inside a run of rows that agree, and that are not the ground?"""
        value = column[y]
        if abs(value - ground) <= DIFFERENT:
            return False
        if y - tall < 0:
            return False
        return all(abs(column[y - n] - value) <= FLAT for n in range(tall))

    inside = None
    for y in range(height - 1, tall, -1):
        if plateau_at(y):
            inside = y
            break
    if inside is None:
        return None, "no flat band down that column that is not the background"

    value = column[inside]
    bottom = inside
    while bottom + 1 < height and abs(column[bottom + 1] - value) <= FLAT:
        bottom += 1
    top = inside
    while top > 0 and abs(column[top - 1] - value) <= FLAT:
        top -= 1

    return {
        "screen": f"{width}x{height} px, {points:g} pt wide, {scale:g}x",
        "column": f"x = {x} px, ground {ground}, row {value}",
        "lift": (height - 1 - bottom) / scale,
        "height": (bottom - top + 1) / scale,
        "profile": profile(),
    }, None


# How far the drawn thing may be from what the source says before it counts as
# wrong. One point of it is the capsule's own soft edge, which a threshold has
# to cut somewhere; the rest is room to round.
TOLERANCE = 2.5


def main():
    if len(sys.argv) not in (2, 4) or (len(sys.argv) == 4 and sys.argv[2] != "--expect"):
        print("usage: measure-the-row.py <screenshot.png> [--expect <points>]",
              file=sys.stderr)
        return 2
    found, trouble = measure(sys.argv[1])
    if trouble:
        print(f"Could not find the row: {trouble}")
        return 1
    print(f"Screen:      {found['screen']}")
    print(f"Column:      {found['column']}")
    print(f"Row height:  {found['height']:.1f} pt")
    print(f"Stands off:  {found['lift']:.1f} pt from the bottom edge")
    print(f"Up the column, every 2 pt from the bottom edge:")
    print(f"  {found['profile']}")

    if len(sys.argv) == 4:
        expected = float(sys.argv[3])
        off = abs(found["lift"] - expected)
        if off > TOLERANCE:
            print()
            print(f"WRONG. The source says the row stands {expected:g} pt off the")
            print(f"bottom edge and it is drawn at {found['lift']:.1f} pt — {off:.1f} pt out.")
            print("Something between the app and the window is moving the whole")
            print("screen. That is the bug this check exists for; it has happened")
            print("once already, and it cost four builds and two wrong answers.")
            return 1
        print(f"Agrees with the source ({expected:g} pt), within {TOLERANCE:g} pt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
