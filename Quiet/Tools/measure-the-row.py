#!/usr/bin/env python3
"""
Measure Quiet's floating row in a simulator screenshot.

    python3 Tools/measure-the-row.py shot.png

This exists because a disagreement about two millimetres cost four rounds of
build, upload, install and look. Two of those rounds were spent arguing about
which build was on the phone, which is not a question anybody should have to
answer by eye. A number printed on every push settles it: if CI says the island
stands twenty-five points off the bottom edge and a photograph says thirteen,
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

# A step in luminance that is an edge rather than a gradient.
EDGE = 12

# How many rows in a row have to agree before an edge is believed. The island
# casts a shadow, and a shadow fades in over about twenty points; on a light
# background its first rows are a step of their own. Three rows of the same
# thing is a capsule, one row is weather.
SURE = 3


def measure(path):
    image = Image.open(path).convert("L")
    width, height = image.size
    points = POINTS.get(width, width / 3)
    scale = width / points
    pixels = image.load()

    x = round(width * 0.25)
    column = [pixels[x, y] for y in range(height)]
    ground = column[height - 1]

    def different(y):
        return y >= 0 and abs(column[y] - ground) > EDGE

    bottom = None
    for y in range(height - 1, SURE, -1):
        if all(different(y - n) for n in range(SURE)):
            bottom = y
            break
    if bottom is None:
        return None, "nothing but background down that column"

    inside = column[bottom]
    top = bottom
    while top > 0 and abs(column[top] - inside) <= EDGE:
        top -= 1

    return {
        "screen": f"{width}x{height} px, {points:g} pt wide, {scale:g}x",
        "column": f"x = {x} px",
        "lift": (height - 1 - bottom) / scale,
        "height": (bottom - top) / scale,
    }, None


def main():
    if len(sys.argv) != 2:
        print("usage: measure-the-row.py <screenshot.png>", file=sys.stderr)
        return 2
    found, trouble = measure(sys.argv[1])
    if trouble:
        print(f"Could not find the row: {trouble}")
        return 1
    print(f"Screen:      {found['screen']}")
    print(f"Column:      {found['column']}")
    print(f"Row height:  {found['height']:.1f} pt")
    print(f"Stands off:  {found['lift']:.1f} pt from the bottom edge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
