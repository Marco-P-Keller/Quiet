#!/usr/bin/env python3
"""Check the App Store frames mechanically, before anybody uploads them.

Every way a screenshot fails App Store Connect is a way it looks fine on a
screen: a stray alpha channel, a size four pixels out, a caption that came out
the same colour as the ground, a frame composed from a photograph that never
arrived and is therefore a rectangle of dark. All four are invisible to a person
glancing at a run and all four cost a rejected upload, so they are measured
here rather than looked at.

    python3 Tools/read-the-shots.py shots/store-frames

Exits non-zero, and says which frame and which of the four.
"""

import json
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is missing: python3 -m pip install --user pillow")

TARGET = (1320, 2868)
GROUND = (15, 17, 20)

# Where the caption is and where the card is, as fractions of the height. Both
# are deliberately generous — this asks whether there is ink in the top of the
# frame and a photograph in the bottom of it, not whether the layout is to the
# pixel.
CAPTION = (0.05, 0.19)
CARD = (0.26, 0.92)

# A caption is ink on ground, so some of it is much lighter than the ground.
INK_ENOUGH = 120
# And there has to be a reasonable amount of it, or a single antialiased speck
# would pass. Half a per cent of the band is about one short line of type.
INK_SHARE = 0.004
# A photograph of a screen carries hundreds of distinct colours. A rectangle of
# ground carries one.
COLOURS_ENOUGH = 200


def band(image, top, bottom):
    return image.crop((0, round(image.height * top),
                       image.width, round(image.height * bottom)))


def look(path):
    """Everything wrong with one frame, as sentences."""
    wrong = []
    image = Image.open(path)

    if image.size != TARGET:
        wrong.append(f"is {image.width} x {image.height}, not {TARGET[0]} x {TARGET[1]}")
    if image.mode != "RGB":
        wrong.append(f"is {image.mode}; App Store Connect refuses an alpha channel")

    flat = image.convert("RGB")

    caption = band(flat, *CAPTION).convert("L")
    lit = sum(count for value, count in
              zip(range(256), caption.histogram()) if value >= INK_ENOUGH)
    share = lit / (caption.width * caption.height)
    if share < INK_SHARE:
        wrong.append(f"has no caption: {share:.4%} of the top band is ink, "
                     f"wanted {INK_SHARE:.2%}")

    card = band(flat, *CARD)
    colours = card.getcolors(maxcolors=1 << 16)
    if colours is None:
        colours = [None] * (COLOURS_ENOUGH + 1)  # more than the ceiling: fine
    if len(colours) < COLOURS_ENOUGH:
        wrong.append(f"carries no photograph: {len(colours)} colours in the card, "
                     f"wanted {COLOURS_ENOUGH}")

    return wrong


def main():
    where = sys.argv[1] if len(sys.argv) > 1 else "shots/store-frames"
    frames = []
    for root, _, files in os.walk(where):
        frames += [os.path.join(root, f) for f in sorted(files) if f.endswith(".png")]

    if not frames:
        sys.exit(f"No frames under {where}")

    manifest = os.path.join(where, "captions.json")
    if os.path.exists(manifest):
        with open(manifest) as file:
            listed = {f"{entry['language']}/{entry['file']}" for entry in json.load(file)}
        found = {os.path.relpath(f, where) for f in frames}
        missing = listed - found
        if missing:
            sys.exit("captions.json names frames that were not written: "
                     + ", ".join(sorted(missing)))

    bad = 0
    for frame in frames:
        wrong = look(frame)
        name = os.path.relpath(frame, where)
        if wrong:
            bad += 1
            for sentence in wrong:
                print(f"{name} {sentence}")
        else:
            print(f"{name} ok")

    print(f"{len(frames) - bad}/{len(frames)} frames ready to upload")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
