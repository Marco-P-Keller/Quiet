#!/usr/bin/env python3
"""Compose the App Store screenshots from photographs of the running app.

App Store Connect wants 1320 x 2868 for the 6.9-inch iPhone, and it wants it
exactly: a smaller image is rejected on upload rather than scaled. The
`Screenshots` workflow already photographs every screen Quiet owns at precisely
that size, on a Pro Max, through the same build a person would install. This
turns those photographs into the five frames a listing needs, and it does not
draw a single pixel of app: whatever is inside the card came off a running
phone. Apple's guidelines require that, and it is also the only version worth
having — a mockup is a promise the app then has to keep.

What it adds is the part a screenshot cannot carry by itself.

*A caption.* Somebody scrolling search results reads two lines and decides. The
headline is the app's own serif, which is the one typographic decision Quiet has
already made, and it is set at the same size across the whole set so the five
frames read as a set rather than as five posters.

*The status bar goes.* Not retouched — cut. The 54 points above the app belong
to iOS, they carry a battery level and a time that mean nothing to a reader, and
the crop is honest in a way that painting over them is not. What is left starts
where the app starts.

*The ground.* `Paper.night`, which is the colour the app itself stands in, so
the frame around the card is the same dark as the card's own edges and there is
no seam.

    python3 Tools/make-the-store-shots.py --source shots/store --out shots/store-frames

Verified by `read-the-shots.py`, which is the thing that actually runs in CI:
the size, the absence of an alpha channel, and that every frame carries both a
caption and a photograph rather than a rectangle of ground.
"""

import argparse
import json
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - the message is the point
    sys.exit("Pillow is missing: python3 -m pip install --user pillow")


# --- What the listing says -------------------------------------------------
#
# Order is the whole argument. The first two or three frames carry most of the
# decision, so they are, in order: what is different (a feed with the endless
# surfaces gone), what nothing else does (a limit that is easy to lower and
# slow to raise), and that it actually bites (the day ending). Trust and the
# smallness of setting it up come after, for the person who is already reading.
#
# Headlines are short because they are read at a thumbnail's size. Every one of
# them is a sentence the app itself could say.

# Every frame is a screen Quiet drew itself. Not one of them is a photograph of
# Instagram, and that is a decision rather than an accident: a listing whose
# pictures are all somebody else's product raises guideline 5.2.1 before a
# reviewer has read a word, and the thing being sold here is the limiter, not
# the site it limits. The absence of Reels is a sentence; it is not a picture.
#
# The exception is allowed for and has to be supplied by hand. A photograph of
# a signed-in feed cannot come out of CI — no runner has an Instagram account —
# so if somebody drops one in as `feed.png`, from their own phone, it becomes
# the first frame and everything else moves down. Without it the set is these
# five and reads perfectly well.
#
# Order is the whole argument. The first two or three carry most of the
# decision, so they are: what the app is for, the one rule nothing else has,
# and the proof that the rule bites. Trust comes last, for somebody who is
# already reading.
#
# Four, not five. The screen the app opens with was in this set until the
# frames were looked at: it is one centred line on an otherwise empty page,
# which is right for a second and a half in a hand and is a blank rectangle at
# the size a listing is actually read. A frame whose card says nothing is worse
# than no frame, and four is inside the three-to-five that works.

FRAMES = [
    {
        "shot": "feed",
        "optional": True,
        "en": ("Your feed. Nothing else.",
               "Reels and Explore are not there. Suggestions are a switch."),
        "de": ("Dein Feed. Sonst nichts.",
               "Reels und Explore: nicht da. Vorschläge: ein Schalter."),
    },
    {
        "shot": "setup",
        "en": ("No Reels. No Explore.",
               "Your feed, your messages, your profile. Nothing else."),
        "de": ("Keine Reels. Kein Explore.",
               "Dein Feed, deine Nachrichten, dein Profil. Sonst nichts."),
    },
    {
        "shot": "limit",
        "en": ("Raise it once a week.",
               "Lower it whenever you like — that takes effect at once."),
        "de": ("Mehr nur einmal pro Woche.",
               "Weniger geht jederzeit — und sofort."),
    },
    {
        "shot": "curtain",
        "en": ("The day closes itself.",
               "When the minutes are gone, so is the app."),
        "de": ("Der Tag schließt sich.",
               "Sind die Minuten weg, ist die App weg."),
    },
    {
        "shot": "panel",
        "en": ("No account. No servers.",
               "Nothing collected, nothing to check, nothing to sign into."),
        "de": ("Kein Konto. Keine Server.",
               "Nichts gesammelt, nichts zu prüfen, nichts einzuloggen."),
    },
]


# --- The palette -----------------------------------------------------------
#
# Paper.night and Paper.ink, out of Design.swift, in eight bits. The card is
# photographed in the dark appearance, so its own edges are this exact colour
# and the card does not sit *on* the ground so much as float in it. The
# hairline is Paper.rule — ink at twelve per cent — which is what the app draws
# every other border with.

GROUND = (15, 17, 20)
INK = (239, 236, 230)
INK_SOFT = 0.55
RULE = 0.12

# The 6.9-inch size, which is the one App Store Connect requires.
TARGET = (1320, 2868)

# The status bar, in points. Every iPhone with a Dynamic Island uses 54, and at
# three times that is 162 pixels on both the Pro Max and the Pro — which is why
# this is a number of points and a scale rather than a number of pixels.
STATUS_BAR_POINTS = 54
POINT_HEIGHTS = {2868: 956, 2796: 932, 2622: 874, 2556: 852}

# Geometry, as fractions of the canvas, so that a different size composes the
# same picture rather than the same pixel counts in the wrong places.
MARGIN = 0.1061          # 140 px at 1320 wide
CAP_TOP = 0.0586         # 168 px
HEAD_LEADING = 1.12
SUB_LEADING = 1.36
GAP_HEAD_SUB = 0.0105    # 30 px
GAP_CAP_CARD = 0.0202    # 58 px, and only as a floor
RADIUS = 0.0439          # 58 px
# One line each, and therefore the same number of lines each. The first set
# composed had four English headlines on one line and the fifth on two, and
# four German ones on two and the fifth on one — inside the rules as written
# and visibly a set of unrelated posters. A headline that needs a second line
# is a headline that needs shortening, which is the same thing App Store
# advice means by three to five words.
HEAD_LINES = 1
SUB_LINES = 2
HEAD_MAX = 0.0363        # 104 px, and it only ever comes down from here
HEAD_MIN = 0.0209        # 60 px
SUB_MAX = 0.0188         # 54 px
SUB_MIN = 0.0115         # 33 px


# --- Type ------------------------------------------------------------------
#
# Quiet says everything it means in a serif — `Font.quietDisplay` is
# `.system(.largeTitle, design: .serif)`, which is New York on Apple's
# platforms. So the headline is New York where there is one, and the nearest
# serif anywhere else. The sentence underneath is the system sans, the way the
# app sets `quietNote`.
#
# The candidates are tried in order and the one that loads wins. Falling back to
# Pillow's bitmap default would produce a frame that looks like a ransom note
# and no error at all, so that case is fatal instead.

SERIF = [
    ("/System/Library/Fonts/NewYork.ttf", "Semibold"),
    ("/System/Library/Fonts/Supplemental/Georgia Bold.ttf", None),
    ("/System/Library/Fonts/Supplemental/Charter.ttc", None),
    ("/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf", None),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", None),
]

SANS = [
    ("/System/Library/Fonts/SFNS.ttf", "Regular"),
    ("/System/Library/Fonts/Helvetica.ttc", None),
    ("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", None),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", None),
]


class Face:
    """One typeface, at whatever size is asked for, remembered between asks."""

    def __init__(self, candidates, what):
        self.path = self.variation = None
        for path, variation in candidates:
            if os.path.exists(path):
                self.path, self.variation = path, variation
                break
        if self.path is None:
            sys.exit(
                f"No {what} font on this machine. Tried:\n  "
                + "\n  ".join(p for p, _ in candidates)
            )
        self.sizes = {}

    def at(self, size):
        if size not in self.sizes:
            font = ImageFont.truetype(self.path, size)
            if self.variation:
                # New York and SF are variable fonts, and a named instance is
                # the only way to ask for a weight. An older FreeType raises
                # rather than lying, which is why this is allowed to fail: the
                # regular weight of the right typeface beats the bold weight of
                # the wrong one.
                try:
                    font.set_variation_by_name(self.variation)
                except (OSError, AttributeError):
                    pass
            self.sizes[size] = font
        return self.sizes[size]

    def __str__(self):
        return self.path + (f" ({self.variation})" if self.variation else "")


def blend(colour, ground, alpha):
    return tuple(round(g + (c - g) * alpha) for c, g in zip(colour, ground))


def width_of(draw, text, font):
    return draw.textlength(text, font=font)


def wrap(draw, text, font, limit):
    """Greedy wrap. Returns the lines, or None if a single word will not fit."""
    lines, line = [], ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if width_of(draw, candidate, font) <= limit:
            line = candidate
            continue
        if line:
            lines.append(line)
        if width_of(draw, word, font) > limit:
            return None
        line = word
    if line:
        lines.append(line)
    return lines


def fits_everywhere(draw, texts, face, size, limit, allowed_lines):
    for text in texts:
        lines = wrap(draw, text, face.at(size), limit)
        if lines is None or len(lines) > allowed_lines:
            return False
    return True


def one_size_for_all(draw, texts, face, limit, allowed_lines, biggest, smallest):
    """The largest size at which *every* caption in the set still fits.

    One size across the five frames rather than one per frame. A set whose
    headlines are each as large as they happen to fit reads as five unrelated
    posters; the eye notices the inconsistency long before it reads a word.
    """
    for size in range(biggest, smallest - 1, -1):
        if fits_everywhere(draw, texts, face, size, limit, allowed_lines):
            return size
    # Returning the smallest anyway would draw a caption straight through the
    # sentence underneath it and say nothing.
    sys.exit(
        f"No size between {smallest} and {biggest} px fits every caption in "
        f"{allowed_lines} line(s). Shorten the longest: "
        + max(texts, key=len)
    )


def status_bar_pixels(height):
    points = POINT_HEIGHTS.get(height)
    if points is None:
        # Every iPhone Pillow will ever be handed here is three times its
        # points, so this is a fallback rather than a guess.
        return round(height * STATUS_BAR_POINTS / (height / 3))
    return round(height * STATUS_BAR_POINTS / points)


def rounded(card, radius):
    """The card, with its corners taken off, composited onto the ground.

    Returned flat — no alpha survives this function, because no alpha may
    survive into the file: App Store Connect rejects a screenshot with an
    alpha channel.
    """
    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, card.width - 1, card.height - 1), radius=radius, fill=255
    )
    out = Image.new("RGB", card.size, GROUND)
    out.paste(card, (0, 0), mask)
    return out, mask


def compose(source, headline, subtitle, head_face, sub_face, head_size, sub_size):
    width, height = TARGET
    canvas = Image.new("RGB", (width, height), GROUND)
    draw = ImageDraw.Draw(canvas)

    margin = round(width * MARGIN)
    limit = width - 2 * margin

    head_line = round(head_size * HEAD_LEADING)
    sub_line = round(sub_size * SUB_LEADING)
    gap = round(height * GAP_HEAD_SUB)

    # The caption's box is the same height on every frame whether or not its
    # words fill it, so the cards line up across the set.
    cap_top = round(height * CAP_TOP)
    cap_height = HEAD_LINES * head_line + gap + SUB_LINES * sub_line

    y = cap_top
    for line in wrap(draw, headline, head_face.at(head_size), limit) or [headline]:
        draw.text((margin, y), line, font=head_face.at(head_size), fill=INK)
        y += head_line

    y = cap_top + HEAD_LINES * head_line + gap
    soft = blend(INK, GROUND, INK_SOFT)
    for line in wrap(draw, subtitle, sub_face.at(sub_size), limit) or [subtitle]:
        draw.text((margin, y), line, font=sub_face.at(sub_size), fill=soft)
        y += sub_line

    # The photograph, with iOS's own 54 points taken off the top.
    shot = Image.open(source).convert("RGB")
    shot = shot.crop((0, status_bar_pixels(shot.height), shot.width, shot.height))

    # One margin for the whole frame: the card is as wide as the caption and
    # stands the same distance off the bottom as it does off the sides, so
    # there is a single number in the composition rather than three that nearly
    # agree. What is left over goes above the card, under the caption, which is
    # the one gap that can absorb it without looking like an accident.
    scale = limit / shot.width
    card_height = round(shot.height * scale)
    card_top = height - margin - card_height
    floor = cap_top + cap_height + round(height * GAP_CAP_CARD)
    if card_top < floor:
        # A taller screenshot than any iPhone takes. Give the caption its room
        # and let the card be smaller than the caption is wide.
        card_top = floor
        scale = (height - margin - card_top) / shot.height
        card_height = round(shot.height * scale)
    card = shot.resize((round(shot.width * scale), card_height), Image.LANCZOS)

    radius = round(width * RADIUS)
    card, mask = rounded(card, radius)
    x = margin if card.width == limit else (width - card.width) // 2
    canvas.paste(card, (x, card_top), mask)

    # A hairline where the card meets the ground. Both are Paper.night, so
    # without it the card has no edge at all on the screens that are mostly
    # dark; with it, it has the same edge every border in the app has.
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x, card_top, x + card.width - 1, card_top + card.height - 1),
        radius=radius,
        outline=blend(INK, GROUND, RULE),
        width=2,
    )
    return canvas


def find(directories, language, shot):
    for directory in directories:
        path = os.path.join(directory, language, shot + ".png")
        if os.path.exists(path):
            return path
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="shots/store",
                        help="photographs from CI, in per-language directories")
    parser.add_argument("--by-hand", default="Tools/store-shots",
                        help="photographs a runner cannot take, kept in the repository")
    parser.add_argument("--out", default="shots/store-frames")
    parser.add_argument("--languages", default="en,de")
    args = parser.parse_args()

    head_face, sub_face = Face(SERIF, "serif"), Face(SANS, "sans")
    print(f"headline: {head_face}\nsentence: {sub_face}")

    scratch = ImageDraw.Draw(Image.new("RGB", TARGET, GROUND))
    limit = TARGET[0] - 2 * round(TARGET[0] * MARGIN)
    directories = [args.source, args.by_hand]

    missing, manifest = [], []
    for language in args.languages.split(","):
        language = language.strip()
        found = [(f, find(directories, language, f["shot"])) for f in FRAMES]
        absent = [f["shot"] for f, path in found if path is None and not f.get("optional")]
        if len(absent) == len(FRAMES) - 1:
            print(f"no photographs for {language} at all, skipping the language")
            continue
        missing += [f"{language}/{shot}" for shot in absent]

        # One size per language, over that language's own captions: German is a
        # third longer than English and would otherwise drag the English
        # headlines down with it. Over the captions actually being used, so a
        # frame nobody could photograph does not set the size of the ones that
        # were.
        using = [f for f, path in found if path is not None]
        head_size = one_size_for_all(
            scratch, [f[language][0] for f in using], head_face, limit, HEAD_LINES,
            round(TARGET[1] * HEAD_MAX), round(TARGET[1] * HEAD_MIN))
        sub_size = one_size_for_all(
            scratch, [f[language][1] for f in using], sub_face, limit, SUB_LINES,
            round(TARGET[1] * SUB_MAX), round(TARGET[1] * SUB_MIN))
        print(f"{language}: headline {head_size} px, sentence {sub_size} px")

        out = os.path.join(args.out, language)
        os.makedirs(out, exist_ok=True)
        order = 0
        for frame, path in found:
            if path is None:
                if frame.get("optional"):
                    print(f"  (no {frame['shot']}.png supplied — the set goes without it)")
                continue
            order += 1
            headline, subtitle = frame[language]
            image = compose(path, headline, subtitle,
                            head_face, sub_face, head_size, sub_size)
            name = f"{order}-{frame['shot']}.png"
            # No alpha, no metadata, sRGB by omission — three of the things App
            # Store Connect refuses an upload over.
            image.save(os.path.join(out, name), "PNG")
            manifest.append({"language": language, "file": name,
                             "from": os.path.relpath(path), "headline": headline,
                             "sentence": subtitle})
            print(f"  {name}  {headline}")

    if not manifest:
        sys.exit(f"No photographs under {args.source} or {args.by_hand}")

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "captions.json"), "w") as file:
        json.dump(manifest, file, indent=2, ensure_ascii=False)
    print(f"{len(manifest)} frames in {args.out}")

    # A set that is quietly one frame short is the failure this cannot afford:
    # it uploads, it looks fine, and the argument has a hole in it.
    if missing:
        sys.exit("Photographs missing for: " + ", ".join(missing))


if __name__ == "__main__":
    main()
