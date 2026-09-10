#!/usr/bin/env python3
"""Compose the App Store screenshots.

Six slides at 1320 x 2868 — the 6.9-inch size App Store Connect demands, and the
only one it will not scale for you — in English and in German.

The phone is drawn in three dimensions: a real perspective projection of a box
with thickness, extruded from its back face to its front so the side of the
device is a surface rather than a line. That is the difference between a
screenshot pasted on a colour and a photograph of a thing, and at the width a
search result gives a slide it is most of what separates a listing that looks
made from one that looks assembled.

**Nothing here shows anybody else's content.** Not a photograph somebody took,
not a post somebody wrote, not a handle or a face belonging to a person who
never agreed to appear in an advertisement. Five of the six slides are Quiet's
own screens, captured from the simulator. The sixth is the feed, which is the
whole product and cannot be anything but somebody's — so it is the developer's
own account, own post, own like. See `LEGAL` at the foot of this file.

**And nothing here claims anything that is not true.** No star rating, no
"trusted by N people", no press logos, no Apple mark. Those are the standard
furniture of a listing like this one, and every one of them would be an
invention on an app that has never shipped. A screenshot is metadata, and
metadata that overstates is the kind an app gets removed for.

    python3 Tools/make-shots.py

Sources in `Tools/shots/source`, finished slides in `Tools/shots/out`. One
dependency, and only because something has to draw a glyph:

    pip install pillow
"""

import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit("This one needs Pillow:  pip install pillow")

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "shots" / "source"
OUT = HERE / "shots" / "out"

WIDTH, HEIGHT = 1320, 2868

# Two grounds, because the app has two and the screens were taken in each. Both
# are Quiet's own, from `Launch.colorset`, each pulled a shade away from the
# screen's so the device reads as lit rather than as a hole cut in the page.
THEMES = {
    "light": {
        "ground": (0xF2, 0xEE, 0xE5),
        "ink": (0x17, 0x16, 0x14),
        "muted": (0x6B, 0x66, 0x5E),
        "spark": (0xFF, 0xFF, 0xFF),
        "shadow": (0x8E, 0x86, 0x76),
        "mark": (0xC8, 0x21, 0x1E),
    },
    "dark": {
        "ground": (0x0A, 0x0B, 0x0D),
        "ink": (0xF4, 0xF1, 0xEA),
        "muted": (0x8E, 0x90, 0x96),
        "spark": (0xFF, 0xFF, 0xFF),
        "shadow": (0x00, 0x00, 0x00),
        "mark": (0xFF, 0x4B, 0x3F),
    },
}

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"
HAND = "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf"

MARGIN = 96
HEAD_TOP = 140
HEAD_SIZE = 100
HEAD_LEADING = 1.16
HEAD_INDENT = 78           # the second line, stepped in
SUB_SIZE = 41
SUB_LEADING = 1.42
SUB_GAP = 36

# The two corners. A display of this size rounds at about 14% of its own
# width; the frame is that plus the bezel, expressed against the front face's
# width so the body and the front can be cut to the same shape.
#
#   FRAME_RADIUS = (SCREEN_RADIUS + PAD) / (1 + 2 * PAD),  PAD = 0.028
SCREEN_RADIUS = 0.138
FRAME_RADIUS = 0.157

# The device, in model units. Thickness is what makes the side a surface.
MODEL_H = 2200.0
MODEL_T = 96.0
CAMERA = 8200.0
EXTRUDE_STEPS = 46

# Sized by height, not by width, and that is the whole of the difference
# between this working and not. The bottom of the screen is where Quiet's row
# stands — five entries, a clock where Reels used to be — and it is the only
# proof the first slide has. Fitting the device by width put that row past the
# bottom edge of the slide.
DEVICE_TOP = 584
DEVICE_BOTTOM = 2612       # leaving room under it for the annotation

# --------------------------------------------------------------------------
# Two dresses for the same set
#
# The house style is everything above: a serif headline, both grounds, and a
# device that stands clear of the bottom edge.
#
# The second is the uniform every listing in this category wears — cream
# throughout, a heavy sans, and the phone run most of the way off the frame.
# It is here to be *compared* against the house style at the size a search
# result actually gives a slide, which is the only size that decides anything.
# Louder is not better; louder is only louder, and the way to find out which
# one this app should wear is to look at the two strips side by side.
#
# What it does not borrow is the furniture those listings carry above the
# fold: a star rating, "trusted by N people", laurel wreaths, press marks.
# Those are the loudest things on a slide of this kind and every one of them
# would be false here — see LEGAL at the foot of this file. Copying a layout
# is fair. Copying a claim is not.

STYLES = {
    "house": {
        "head_face": SERIF, "head_light": b"Regular", "head_heavy": b"Bold",
        "head_top": 140, "head_size": 100, "head_leading": 1.16,
        "head_indent": 78, "sub_size": 41, "sub_leading": 1.42, "sub_gap": 36,
        "device_top": 584, "device_bottom": 2612,
        "device_bottom_noted": 2612, "one_ground": None,
    },
    # v2. The house style with its hierarchy fixed for the place these are
    # actually read: a row of thumbnails about 300 px wide, where the headline
    # is the only thing that survives and a 41 px subline is nine pixels of
    # grey noise. So the headline goes up to the largest size German will carry
    # and the subline goes up with it and stops being a whisper.
    "v2": {
        "head_face": SERIF, "head_light": b"Regular", "head_heavy": b"Bold",
        # 106, measured: "Mehr *nächste Woche*." is the longest line either
        # language has and it clears the margin by 47 px here and overruns at
        # 112. German decides the type size in this set, every time.
        "head_top": 132, "head_size": 106, "head_leading": 1.10,
        "head_indent": 86, "sub_size": 46, "sub_leading": 1.38, "sub_gap": 42,
        # A third of the way from the muted grey towards the ink. Readable at
        # thumbnail size without starting a fight with the headline.
        "sub_mix": 0.34, "hand_size": 84,
        # No sparkles. Four white stars scattered round a phone are the house
        # decoration of this category and they are doing nothing here except
        # softening a set whose whole argument is that it is serious about the
        # thing it does. Taking them out costs nothing and the slides do not
        # look emptier for it — they look composed rather than dressed.
        "sparkle": False,
        "device_top": 632, "device_bottom": 2652,
        # Only 64 px shorter than the rest, not 120. The annotated slide is the
        # hero and it was ending up with the smallest phone on the strip, which
        # is exactly backwards — the frame that has to sell the whole app was
        # the one giving its screen away to make room for a label.
        "device_bottom_noted": 2588, "one_ground": None,
    },
    "loud": {
        "head_face": SANS, "head_light": b"Semibold", "head_heavy": b"Black",
        # 96, not 100 and not 104. A heavy sans is wider than the serif at the
        # same size, and "Mehr *nächste Woche*." is the longest line either
        # language has: it overruns the margin at 100 and clears it by 37 px at
        # 96. German is where a line written to fit stops fitting.
        "head_top": 152, "head_size": 96, "head_leading": 1.13,
        "head_indent": 96, "sub_size": 42, "sub_leading": 1.40, "sub_gap": 42,
        # Bigger, and run down past where the house style stops. The bottom of
        # the screen still has to be on the slide — that is where the row is —
        # so this is as far as it goes without throwing away the proof.
        "device_top": 664, "device_bottom": 2792,
        # The annotated slide stops higher. At 2792 the phone reaches into the
        # band the hand-drawn label stands in and the two collide — which is
        # also what the listings this borrows from do: their first slide shows
        # the whole device, and only the ones without a label run off the frame.
        "device_bottom_noted": 2524, "one_ground": "light",
    },
}

# Set by main() before each pass. A module-level dial rather than an argument
# threaded through nine functions, because every one of those functions would
# only be passing it on.
STYLE = STYLES["house"]


# Where the side buttons sit, as fractions of the device's half-height, top
# negative. Three on one side and one on the other, which is the arrangement
# every phone has had for fifteen years and the thing the eye checks without
# being asked to.
BUTTONS = [(-0.46, -0.38), (-0.32, -0.16), (-0.12, 0.06)]
BUTTONS_RIGHT = [(-0.34, -0.08)]

# The status bar, measured off a 1320-wide capture from the simulator, and
# scaled from that width so a photograph from a narrower phone lands in the
# same places.
REFERENCE_W = 1320
STATUS_H = 186
ISLAND = (472, 42, 847, 151)
STATUS_MIDDLE = 97
CLOCK_X = 218


# --------------------------------------------------------------------------
# Type


def font(path: str, size: int, weight: bytes):
    face = ImageFont.truetype(path, size)
    try:
        face.set_variation_by_name(weight)
    except Exception:
        pass
    return face


def spans(text: str) -> list[tuple[str, bool]]:
    """Split on `*` into (run, is emphasised) pairs.

    The headline carries one heavy word and sets the rest light. Weight is doing
    the job a colour would do in somebody else's palette — Quiet has no accent
    colour, deliberately, and inventing one for the store would be advertising a
    different app.
    """
    out, emphasis = [], False
    for run in text.split("*"):
        if run:
            out.append((run, emphasis))
        emphasis = not emphasis
    return out


def rich(draw, xy, text: str, light, heavy, fill) -> float:
    x, y = xy
    for run, emphasis in spans(text):
        face = heavy if emphasis else light
        draw.text((x, y), run, font=face, fill=fill)
        x += draw.textlength(run, font=face)
    return x


def measure(draw, text: str, light, heavy) -> float:
    return sum(
        draw.textlength(run, font=heavy if emphasis else light)
        for run, emphasis in spans(text)
    )


def wrap(draw, text: str, face, width: int) -> list[str]:
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words, line = paragraph.split(), ""
        for word in words:
            trial = f"{line} {word}".strip()
            if draw.textlength(trial, font=face) <= width or not line:
                line = trial
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def caption(draw, theme: dict, headline: str, subline: str) -> int:
    """Headline over subline, and where the pair ended.

    The headline's second line is stepped in. That is the one piece of the
    layout with no reason behind it beyond the eye: a two-line title set flush
    reads as a paragraph, and stepped reads as a title.
    """
    size = STYLE["head_size"]
    light = font(STYLE["head_face"], size, STYLE["head_light"])
    heavy = font(STYLE["head_face"], size, STYLE["head_heavy"])
    sub = font(SANS, STYLE["sub_size"], b"Regular")

    lines = headline.split("\n")
    if len(lines) > 2:
        print(f"    ! headline runs to {len(lines)} lines: {headline!r}")

    y = STYLE["head_top"]
    for i, line in enumerate(lines):
        x = MARGIN + (STYLE["head_indent"] if i else 0)
        if measure(draw, line, light, heavy) + x > WIDTH - MARGIN:
            print(f"    ! headline line overruns: {line!r}")
        rich(draw, (x, y), line, light, heavy, theme["ink"])
        y += round(size * STYLE["head_leading"])

    mix = STYLE.get("sub_mix", 0.0)
    tone = tuple(round(m + (i - m) * mix)
                 for m, i in zip(theme["muted"], theme["ink"]))

    y += STYLE["sub_gap"] - round(size * (STYLE["head_leading"] - 1))
    for line in wrap(draw, subline, sub, WIDTH - 2 * MARGIN):
        draw.text((MARGIN, y), line, font=sub, fill=tone)
        y += round(STYLE["sub_size"] * STYLE["sub_leading"])
    return y


# --------------------------------------------------------------------------
# The status bar


def ground_under(image: Image.Image, status_h: int) -> tuple[int, int, int]:
    y = status_h - 4
    edge = list(range(0, 90)) + list(range(image.width - 90, image.width))
    samples = [image.getpixel((x, y)) for x in edge]
    return tuple(sorted(c[i] for c in samples)[len(samples) // 2] for i in range(3))


def clean_status_bar(image: Image.Image) -> Image.Image:
    """Repaint it: 9:41, three indicators, and an empty island.

    Apple's own screenshots have said 9:41 since 2007. What matters more here is
    what goes: the hour the photograph happened to be taken, the bell saying the
    phone was silenced, and — on every photograph used here — a Live Activity
    from another app carrying a stranger's face. That last one is why this is
    not optional.
    """
    image = image.convert("RGB")
    k = image.width / REFERENCE_W

    def s(v: float) -> int:
        return round(v * k)

    status_h = s(STATUS_H)
    fill = ground_under(image, status_h)
    ink = (0x19, 0x18, 0x16) if sum(fill) > 384 else (0xF2, 0xEE, 0xE7)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, image.width, status_h), fill=fill)

    left, top, right, foot = (s(v) for v in ISLAND)
    draw.rounded_rectangle((left, top, right, foot),
                           radius=(foot - top) // 2, fill=(0, 0, 0))

    middle = s(STATUS_MIDDLE)
    draw.text((s(CLOCK_X), middle), "9:41", font=font(SANS, s(52), b"Semibold"),
              fill=ink, anchor="mm")

    edge = image.width - s(62)
    bx1, by1 = edge - s(75), middle - s(19)
    bx2, by2 = edge, middle + s(19)
    draw.rounded_rectangle((bx1, by1, bx2, by2), radius=s(12), outline=ink, width=s(4))
    draw.rounded_rectangle((bx2 + s(4), middle - s(9), bx2 + s(9), middle + s(9)),
                           radius=s(3), fill=ink)
    draw.rounded_rectangle((bx1 + s(7), by1 + s(7), bx1 + s(55), by2 - s(7)),
                           radius=s(6), fill=ink)

    wx, wy = bx1 - s(40), middle + s(14)
    for radius in (s(34), s(22), s(10)):
        draw.arc((wx - radius, wy - radius, wx + radius, wy + radius),
                 start=218, end=322, fill=ink, width=s(9))
    draw.ellipse((wx - s(5), wy - s(5), wx + s(5), wy + s(5)), fill=ink)

    sx = wx - s(46)
    for i, height in enumerate((13, 21, 29, 37)):
        x = sx - (3 - i) * s(17)
        draw.rounded_rectangle(
            (x, middle + s(19) - s(height), x + s(11), middle + s(19)),
            radius=s(4), fill=ink,
        )
    return image


# --------------------------------------------------------------------------
# Three dimensions


def solve(matrix: list[list[float]], rhs: list[float]) -> list[float]:
    """Gaussian elimination with partial pivoting, for one 8x8 system.

    Written out rather than imported. Everything in this folder has one
    dependency and a good reason for it; a linear solver is thirty lines and not
    a good enough reason for a second.
    """
    n = len(rhs)
    a = [row[:] + [rhs[i]] for i, row in enumerate(matrix)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(a[r][col]))
        a[col], a[pivot] = a[pivot], a[col]
        divisor = a[col][col]
        a[col] = [v / divisor for v in a[col]]
        for row in range(n):
            if row != col and a[row][col]:
                factor = a[row][col]
                a[row] = [v - factor * w for v, w in zip(a[row], a[col])]
    return [a[i][n] for i in range(n)]


def coefficients(destination, source) -> list[float]:
    """The eight numbers Pillow wants, mapping destination back to source."""
    matrix, rhs = [], []
    for (x, y), (u, v) in zip(destination, source):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        rhs.append(u)
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        rhs.append(v)
    return solve(matrix, rhs)


def pose(corners, yaw: float, pitch: float, roll: float):
    """Rotate model points and project them with perspective."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cr, sr = math.cos(roll), math.sin(roll)
    out = []
    for x, y, z in corners:
        x, z = x * cy + z * sy, -x * sy + z * cy
        y, z = y * cp - z * sp, y * sp + z * cp
        x, y = x * cr - y * sr, x * sr + y * cr
        f = CAMERA / (CAMERA - z)
        out.append((x * f, y * f))
    return out


def frame_shade(t: float):
    """The colour of the frame at depth `t`, from back face to front.

    Not a straight ramp. A milled edge is dark where it turns away, and carries
    one bright band where the chamfer catches the light just before the rim —
    which is the whole of what makes brushed metal read as metal rather than as
    a grey wall. The band is a gaussian centred near the front, so the very
    front edge settles back down instead of blowing out.
    """
    value = 58 + 78 * t + 155 * math.exp(-(((t - 0.86) / 0.11) ** 2))
    grey = min(246, round(value))
    return (grey, grey, min(255, grey + 5), 255)


def soft_mask(size, radius: int, over: int = 4) -> Image.Image:
    """A rounded-rectangle mask with smooth edges.

    Pillow does not antialias `rounded_rectangle`; it lays down hard pixels. One
    hard-edged card is invisible, forty-six of them composited down the side of
    a phone is a staircase — which is what the frame looked like until this
    existed. Drawn four times over and shrunk back, which is the whole trick.
    """
    big = Image.new("L", (size[0] * over, size[1] * over), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, big.width - 1, big.height - 1), radius=radius * over, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def slant(size, bright: int, dim: int, steps: int = 96) -> Image.Image:
    """A diagonal ramp, brightest at the top-left.

    The light in these slides comes from up and to the left — that is where the
    sheen on the glass starts and which way the shadow falls. A rim that is
    equally bright the whole way round contradicts both, and an edge lit from
    everywhere at once is the thing that reads as a drawing of a phone.
    """
    small = Image.new("L", (steps, steps))
    pixels = small.load()
    for y in range(steps):
        for x in range(steps):
            t = (x + y) / (2 * (steps - 1))
            pixels[x, y] = round(bright + (dim - bright) * t)
    return small.resize(size, Image.BICUBIC)


def card(size, radius: int, fill, mask: Image.Image | None = None) -> Image.Image:
    plate = Image.new("RGBA", size, fill[:3] + (255,))
    plate.putalpha(mask if mask is not None else soft_mask(size, radius))
    return plate


def aa_polygon(canvas: Image.Image, points, fill, over: int = 4) -> None:
    """One polygon with smooth edges, drawn in its own bounding box.

    Supersampling the whole slide to draw a button would be four times the
    memory for a shape sixty pixels wide, so the oversampling happens only where
    the shape is.
    """
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    pad = 3
    x0, y0 = max(0, int(min(xs)) - pad), max(0, int(min(ys)) - pad)
    x1, y1 = min(WIDTH, int(max(xs)) + pad), min(HEIGHT, int(max(ys)) + pad)
    if x1 <= x0 or y1 <= y0:
        return
    big = Image.new("L", ((x1 - x0) * over, (y1 - y0) * over), 0)
    ImageDraw.Draw(big).polygon(
        [((x - x0) * over, (y - y0) * over) for x, y in points], fill=255
    )
    mask = big.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    canvas.paste(Image.new("RGB", mask.size, fill), (x0, y0), mask)


def warp(flat: Image.Image, quad) -> Image.Image:
    """Put a flat picture onto a quadrilateral, at canvas size."""
    source = [(0, 0), (flat.width, 0), (flat.width, flat.height), (0, flat.height)]
    return flat.transform(
        (WIDTH, HEIGHT), Image.PERSPECTIVE,
        coefficients(quad, source), Image.BICUBIC,
    )


def device(canvas: Image.Image, theme: dict, screen: Image.Image, yaw: float,
           bottom: float | None = None):
    """A shadow, a body with thickness, and the screen.

    The body is not a polygon. It is one rounded rectangle projected twenty-two
    times, walking from the back face to the front — which gives the side of the
    device its rounded corners for free and gives the frame the gradient a
    milled edge actually has. A polygon would put four sharp corners behind a
    rounded screen, and there is no angle at which that does not read as wrong.
    """
    aspect = screen.height / screen.width
    half_w, half_h = MODEL_H / aspect / 2, MODEL_H / 2
    bezel = MODEL_H * 0.012
    outer_w, outer_h = half_w + bezel, half_h + bezel

    def face(z):
        return [(-outer_w, -outer_h, z), (outer_w, -outer_h, z),
                (outer_w, outer_h, z), (-outer_w, outer_h, z)]

    pitch, roll = math.radians(3.5), math.radians(-2.2 if yaw > 0 else 2.2)
    back = pose(face(-MODEL_T / 2), yaw, pitch, roll)
    front = pose(face(MODEL_T / 2), yaw, pitch, roll)

    xs = [p[0] for p in back + front]
    ys = [p[1] for p in back + front]
    foot = STYLE["device_bottom"] if bottom is None else bottom
    scale = (foot - STYLE["device_top"]) / (max(ys) - min(ys))
    dx = WIDTH / 2 - (min(xs) + max(xs)) / 2 * scale
    dy = STYLE["device_top"] - min(ys) * scale

    def place(points):
        return [(x * scale + dx, y * scale + dy) for x, y in points]

    def place3(points):
        return place(pose(points, yaw, pitch, roll))

    back, front = place(back), place(front)

    # Two shadows, because an object on a surface casts two: a wide soft one
    # from the room, and a tight dark one where it comes nearest the ground. One
    # blur alone reads as a sticker with a drop shadow on it.
    # One light, so one direction. This used to flip with the pose — the
    # shadow fell left on the odd slides and right on the even ones — which
    # nothing else in the slide agrees with: the sheen enters at the top left
    # and the chamfer is brightest there. A key light does not move because the
    # object turned, and a shadow falling towards the light is the kind of
    # wrongness a reader feels without being able to name.
    lean = 26
    for spread, offset, blur, weight in ((1.0, 46, 60, 120), (0.0, 16, 18, 96)):
        silhouette = Image.new("L", (WIDTH, HEIGHT), 0)
        ImageDraw.Draw(silhouette).polygon(
            [(x + lean * spread, y + offset) for x, y in front], fill=weight
        )
        canvas.paste(
            Image.new("RGB", (WIDTH, HEIGHT), theme["shadow"]),
            (0, 0), silhouette.filter(ImageFilter.GaussianBlur(blur)),
        )

    # The body, walked from back to front onto a layer of its own.
    #
    # Onto a layer, and not straight onto the slide, because forty-six cards
    # composited one over the next each contribute their own soft edge, and the
    # sum of forty-six soft edges is a staircase down the side of the phone.
    # Gathered first and blurred once, the staircase becomes the slight
    # softness a photographed edge has anyway.
    body = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    plate_h = 1400
    plate = (round(plate_h * (outer_w / outer_h)), plate_h)
    # The same fraction the front face uses. They were 18% and 15.9% of their
    # own width, which is close enough to look intentional and far enough to
    # leave a hairline of body showing outside the front at each corner — a
    # double edge, exactly where the eye checks whether a shape is one object.
    radius = round(plate[0] * FRAME_RADIUS)
    edges = soft_mask(plate, radius)          # made once, worn by every layer
    for step in range(EXTRUDE_STEPS):
        t = step / (EXTRUDE_STEPS - 1)
        quad = [(bx + (fx - bx) * t, by + (fy - by) * t)
                for (bx, by), (fx, fy) in zip(back, front)]
        body.alpha_composite(warp(card(plate, radius, frame_shade(t), edges), quad))
    # Forty-six bands across twenty pixels of visible side are narrower than a
    # pixel each, and sub-pixel bands interfere into stripes. Half a pixel of
    # blur is below what the eye resolves on the finished slide and above what
    # the interference needs to disappear.
    body = body.filter(ImageFilter.GaussianBlur(0.9))
    canvas.paste(body, (0, 0), body)

    # The buttons, on whichever side is actually facing us.
    #
    # Worked out from the geometry rather than assumed: the side you can see is
    # the one whose back edge projects outside its front edge, and which side
    # that is flips with the pose. Drawn after the body and before the screen,
    # so the front face covers the half of each button that is behind it.
    sees_left = back[0][0] < front[0][0]
    edge = -1 if sees_left else 1
    stand = outer_w * 1.021
    for top, foot in (BUTTONS if sees_left else BUTTONS_RIGHT):
        for depth, shade in ((0.36, (108, 108, 114)), (0.20, (176, 176, 182))):
            aa_polygon(canvas, place3([
                (edge * stand, outer_h * top, -MODEL_T * depth),
                (edge * stand, outer_h * foot, -MODEL_T * depth),
                (edge * stand, outer_h * foot, MODEL_T * depth),
                (edge * stand, outer_h * top, MODEL_T * depth),
            ]), shade)

    # And the front: a black rim with the screen inside it.
    pad = round(screen.width * 0.028)
    glass = screen.convert("RGBA")
    # The corner, measured off the thing itself rather than chosen by eye. A
    # phone this size rounds its display at about 14% of the display's width;
    # this was at 9.9%, and a screen squarer than a real one is the first tell
    # a mockup gives. The frame is concentric with it — an outer radius is an
    # inner radius plus the width of the border between them, and any other
    # pair leaves the bezel fat at the corners and thin down the sides.
    inner = round(screen.width * SCREEN_RADIUS)
    outer = inner + pad
    plate = Image.new("RGBA", (glass.width + 2 * pad, glass.height + 2 * pad),
                      (0, 0, 0, 0))
    face_draw = ImageDraw.Draw(plate)
    face_draw.rounded_rectangle(
        (0, 0, plate.width - 1, plate.height - 1), radius=outer, fill=(12, 12, 14, 255)
    )
    # The chamfer, lit from where the light actually is: bright as it turns
    # over at the top left, gone by the bottom right.
    rim = Image.new("L", plate.size, 0)
    ImageDraw.Draw(rim).rounded_rectangle(
        (2, 2, plate.width - 3, plate.height - 3), radius=outer - 2,
        outline=255, width=4,
    )
    plate.paste(Image.new("RGBA", plate.size, (188, 188, 196, 255)), (0, 0),
                ImageChops.multiply(rim, slant(plate.size, 210, 26)))

    mask = Image.new("L", glass.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, glass.width - 1, glass.height - 1), radius=inner, fill=255,
    )
    plate.paste(glass, (pad, pad), mask)

    inside = Image.new("L", plate.size, 0)
    ImageDraw.Draw(inside).rounded_rectangle(
        (pad, pad, plate.width - pad - 1, plate.height - pad - 1),
        radius=inner, fill=255,
    )

    # The glass sits a shade below the frame, so its own edge is in shadow all
    # the way round. Without this the screenshot reads as printed on the front
    # of the phone rather than lying under glass.
    lip = Image.new("L", plate.size, 0)
    ImageDraw.Draw(lip).rounded_rectangle(
        (pad, pad, plate.width - pad - 1, plate.height - pad - 1),
        radius=inner, outline=255, width=max(2, round(pad * 0.26)),
    )
    # Tight. The first attempt was three times this wide and half as sharp, and
    # on a white screen it stopped reading as an edge and started reading as a
    # thumbprint. A lip is a few pixels of shadow or it is dirt.
    lip = ImageChops.multiply(lip.filter(ImageFilter.GaussianBlur(pad * 0.20)), inside)
    plate.paste(Image.new("RGBA", plate.size, (0, 0, 0, 255)), (0, 0),
                lip.point(lambda v: round(v * 0.30)))

    # Two reflections, because glass gives two: the room, wide and soft, and
    # the window it is standing in, narrow and far brighter.
    #
    # How much of either survives depends on what is underneath. A lit screen
    # washes a reflection out and a dark one hands it back — so the strength is
    # measured off the screenshot instead of being one number for all seven
    # slides, which is why the old fixed 30 was invisible on the feed and about
    # right on the curtain.
    # `tobytes` rather than `getdata`: one byte per pixel for an "L" image,
    # and not deprecated out from under this in Pillow 14.
    counts = screen.convert("L").resize((24, 24), Image.BILINEAR).tobytes()
    lit = sum(counts) / (len(counts) * 255)
    w, h = plate.size

    def wash(points, strength: int, blur: float) -> None:
        layer = Image.new("L", plate.size, 0)
        ImageDraw.Draw(layer).polygon(points, fill=max(0, strength))
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
        plate.paste(Image.new("RGBA", plate.size, (255, 255, 255, 255)), (0, 0),
                    ImageChops.multiply(layer, inside))

    wash([(-w * 0.10, h * 0.105), (w * 0.62, -h * 0.040),
          (w * 1.10, h * 0.300), (w * 1.10, h * 0.445),
          (-w * 0.10, h * 0.265)], round(54 - 28 * lit), w * 0.060)
    wash([(-w * 0.10, h * 0.036), (w * 0.56, -h * 0.056),
          (w * 0.63, -h * 0.029), (-w * 0.10, h * 0.080)],
         round(46 - 24 * lit), w * 0.014)

    layer = warp(plate, front)
    canvas.paste(layer, (0, 0), layer)

    # Hand back a way to point at something *on the screen*.
    #
    # The arrow on the first slide has to land on one icon in a row that is
    # being drawn in perspective, and a coordinate typed in by hand is a
    # coordinate that is wrong the next time any of this moves. So the same
    # projection that put the screen there answers where a point on it ended up.
    forward = coefficients(
        [(0, 0), (plate.width, 0), (plate.width, plate.height), (0, plate.height)],
        front,
    )
    a, b, c, d, e, f, g, h = forward

    def on_screen(u: float, v: float) -> tuple[float, float]:
        px, py = pad + u * glass.width, pad + v * glass.height
        den = g * px + h * py + 1
        return ((a * px + b * py + c) / den, (d * px + e * py + f) / den)

    return on_screen


# --------------------------------------------------------------------------
# Decoration


def sparkle(canvas: Image.Image, theme: dict, x: int, y: int, radius: int,
            alpha: int) -> None:
    """A four-pointed star with concave sides, from a polar formula."""
    # An astroid — x = R cos³t, y = R sin³t. Points on the axes, concave
    # between them, which is the shape a sparkle actually is. A polar formula
    # with a fractional exponent, which is what this was first, gives four fat
    # lobes and reads as a flower.
    points = []
    for i in range(160):
        t = 2 * math.pi * i / 160
        points.append((x + radius * math.cos(t) ** 3,
                       y + radius * math.sin(t) ** 3))
    layer = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(layer).polygon(points, fill=alpha)
    canvas.paste(Image.new("RGB", (WIDTH, HEIGHT), theme["spark"]), (0, 0),
                 layer.filter(ImageFilter.GaussianBlur(1.4)))


def scatter(canvas: Image.Image, theme: dict, seed: int) -> None:
    """Four of them, in the same places every time.

    Deterministic on purpose. A set that is regenerated has to come back
    identical, or the only way to tell a real change from noise is to look at
    every slide again.
    """
    spots = [(0.11, 0.255, 62, 165), (0.89, 0.205, 92, 135),
             (0.94, 0.55, 46, 105), (0.07, 0.60, 38, 92)]
    # The set is mirrored as a set, not one spot at a time. Flipping each spot
    # on its own parity sent the first two to the same side on every even seed,
    # where they landed 50 px apart and stacked into one grey smudge against
    # the phone's corner. Four positions were chosen to be spread; mirroring
    # them together is the only move that keeps them spread.
    flip = seed % 2 == 0
    for fx, fy, r, a in spots:
        x = WIDTH * (fx if flip else 1 - fx)
        sparkle(canvas, theme, round(x), round(HEIGHT * fy), r, a)


def annotate(canvas: Image.Image, theme: dict, label: str, tip) -> None:
    """A hand-drawn label with an arrow, pointing at one thing on the screen.

    The only annotation in the set, and it earns its place: the whole claim of
    the first slide is a tab that is not there, and an absence is the one thing
    a screenshot cannot show — so the arrow points at the hole where it was.

    The row keeps five slots and fills four of them for the first ten seconds
    after the app opens, which is the state photographed here. That gap in the
    middle is not a retouch and not a mock-up; it is what somebody sees when
    they open Quiet, and it is the clearest picture the app has of what it does.

    Three things were wrong with the first one and all three are the same
    mistake — it was drawn with the blunt tools instead of the ones this file
    already has. `ImageDraw.line` does not antialias, so the curve arrived as a
    staircase. A constant nine-pixel width is a pipe, not a stroke off a pen.
    And the head was a fat isoceles triangle landing dead centre in an empty
    tab slot, where it read as a play button — the app's caption says Reels is
    *gone* and its own arrow drew one back in.

    So: a cubic, a width that swells through the belly and thins into the head,
    a head that is slim and notched at the back, and every part of it through
    `aa_polygon` like the rest of the furniture on the slide.

    **And it is red**, which is the one place in this whole set that carries a
    colour. `spans()` says a few screens up that Quiet has no accent colour and
    that inventing one for the store would be advertising a different app, and
    that still holds for the type — the headlines get weight, not hue. This is
    not type. It is a marker laid over a photograph, saying *look at this one
    spot*, and a marker that matches everything around it is not a marker. It
    stays off the headline, off the subline and off the other six slides, which
    is what keeps it reading as a pointer rather than as a brand.
    """
    draw = ImageDraw.Draw(canvas)
    face = ImageFont.truetype(HAND, STYLE.get("hand_size", 76))
    anchor = (MARGIN, HEIGHT - 176)
    draw.text(anchor, label, font=face, fill=theme["mark"])
    box = draw.textbbox(anchor, label, font=face)

    start = ((box[0] + box[2]) / 2, box[1] - 26)
    # A cubic, not a quadratic. One control point can only bow a line; two let
    # it leave the words going up, run along under the phone, and arrive at the
    # target from directly below — which is the only approach that points *into*
    # the gap rather than across it.
    reach = max(140.0, start[1] - tip[1])
    span = tip[0] - start[0]
    c1 = (start[0] + span * 0.10, start[1] - reach * 0.44)
    c2 = (tip[0] - span * 0.05, tip[1] + reach * 0.92)

    def at(t: float) -> tuple[float, float]:
        u = 1 - t
        return (u**3 * start[0] + 3*u*u*t * c1[0] + 3*u*t*t * c2[0] + t**3 * tip[0],
                u**3 * start[1] + 3*u*u*t * c1[1] + 3*u*t*t * c2[1] + t**3 * tip[1])

    steps = 120
    spine = [at(i / steps) for i in range(steps + 1)]

    # Where the head starts, walked back along the curve rather than typed in,
    # so the join stays square to the stroke however the pose moves the target.
    head_len = 52.0
    cut = steps
    while cut > 2 and math.dist(spine[cut], tip) < head_len:
        cut -= 1

    def half_width(t: float) -> float:
        """A pen leaves thin, swells, and thins again as the hand lifts."""
        return 1.3 + 4.9 * (0.22 + 0.78 * math.sin(math.pi * t) ** 0.50)

    left, right = [], []
    for i in range(cut + 1):
        ax, ay = spine[max(0, i - 1)]
        bx, by = spine[min(cut, i + 1)]
        length = math.hypot(bx - ax, by - ay) or 1.0
        nx, ny = -(by - ay) / length, (bx - ax) / length
        x, y = spine[i]
        w = half_width(i / cut)
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    aa_polygon(canvas, left + right[::-1], theme["mark"])

    base = spine[cut]
    length = math.dist(base, tip) or 1.0
    dx, dy = (tip[0] - base[0]) / length, (tip[1] - base[1]) / length
    nx, ny = -dy, dx
    flare = 15.0
    aa_polygon(canvas, [
        tip,
        (base[0] + nx * flare, base[1] + ny * flare),
        (base[0] + dx * length * 0.34, base[1] + dy * length * 0.34),
        (base[0] - nx * flare, base[1] - ny * flare),
    ], theme["mark"])


# --------------------------------------------------------------------------
# Slides


def photographed(source: Path, theme: dict, headline: str, subline: str,
                 seed: int, note=None) -> Image.Image:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), theme["ground"])
    if STYLE.get("sparkle", True):
        scatter(canvas, theme, seed)
    yaw = math.radians(13 if seed % 2 == 0 else -13)
    on_screen = device(canvas, theme, clean_status_bar(Image.open(source)), yaw,
                       STYLE["device_bottom_noted"] if note else None)
    caption(ImageDraw.Draw(canvas), theme, headline, subline)
    if note:
        label, target = note
        annotate(canvas, theme, label, on_screen(*target))
    return canvas


def typeset(theme: dict, headline: str, subline: str, items: list[str],
            seed: int) -> Image.Image:
    """The one slide with no phone on it.

    Everything Quiet removes is removed — by construction there is no screen
    that shows it, and a photograph of the feed it was taken out of would have
    to be somebody's feed. So the claim is set in type and struck through, which
    also makes it the only slide that can be read whole at the size a search
    result gives it.
    """
    canvas = Image.new("RGB", (WIDTH, HEIGHT), theme["ground"])
    if STYLE.get("sparkle", True):
        scatter(canvas, theme, seed)
    draw = ImageDraw.Draw(canvas)
    bottom = caption(draw, theme, headline, subline)

    size = 96
    face = font(STYLE["head_face"], size, STYLE["head_light"])
    step = round(size * 2.05)
    block = step * (len(items) - 1) + size
    y = bottom + (HEIGHT - 150 - bottom - block) // 2

    for item in items:
        draw.text((MARGIN, y), item, font=face, fill=theme["ink"])
        box = draw.textbbox((MARGIN, y), item, font=face)
        middle = (box[1] + box[3]) // 2
        draw.line((MARGIN - 14, middle, box[2] + 14, middle),
                  fill=theme["muted"], width=7)
        y += step
    return canvas


# The six, in the order they are swiped through.
#
# **The first slide is the product.** Two earlier versions of this set led with
# Quiet's own screens — the curtain, the panel, the one the app opens with —
# which are the pleasant ones to design and none of which show what the app
# *is*. Somebody on a store page is asking one question, and it is not what the
# settings look like. It is: is this my Instagram, and what has been taken out.
#
#   1. what is it                the feed, with an arrow at the missing tab
#   2. and there is a limit      the curtain
#   3. why does it hold          the asymmetric rule
#   4. what else is gone         five things, struck through
#   5. what am I giving up       the trade, on the app's own first screen
#   6. can I trust you           nothing kept, nothing sent
#
# `*` marks the run set in the heavy weight. `source` of None is the
# typographic slide.
SLIDES = {
    "en": [
        ("feed", "light", "Instagram,\nwithout *Reels*.",
         "The same feed, the same people, the same messages. Where the Reels "
         "tab was, there is nothing at all.", [],
         ("Reels was here", (0.50, 0.951))),
        ("curtain", "dark", "No *five more*\nminutes.",
         "When today’s time is spent, Quiet closes for the day — and there is "
         "nothing on the screen to argue with.", [], None),
        ("panel-tomorrow", "light", "Less *now*.\nMore *next week*.",
         "Lower your daily limit whenever you like; it applies at once. Raising "
         "it waits a week and starts the next day.", [], None),
        (None, "dark", "What *isn’t* here.",
         "Taken out by address, not hidden behind a setting you could switch "
         "back on at eleven at night.",
         ["Reels", "Explore", "Suggested accounts", "Autoplay",
          "Streaks and reports"], None),
        ("feed-open", "dark", "Everything else\nis *untouched*.",
         "Like, comment, send, save — Instagram’s own page, exactly as it "
         "was. Quiet takes surfaces away and puts nothing in their place.",
         [], None),
        ("setup", "light", "The whole trade,\n*up front*.",
         "What Quiet takes away and what it leaves alone, on the first screen, "
         "before you choose anything.", [], None),
        ("opening", "dark", "No account.\nNo *tracking*.",
         "No servers of ours, no analytics, no advertising. Nothing to check "
         "and nothing to beat — one reminder a day, only if you ask.", [], None),
    ],
    "de": [
        ("feed", "light", "Instagram,\nohne *Reels*.",
         "Derselbe Feed, dieselben Menschen, dieselben Nachrichten. Wo der "
         "Reels-Tab war, ist einfach nichts.", [],
         ("Hier war Reels", (0.50, 0.951))),
        ("curtain", "dark", "Keine *fünf*\nMinuten mehr.",
         "Ist die Zeit für heute weg, schließt Quiet den Tag — und auf dem "
         "Bildschirm steht nichts, mit dem sich verhandeln ließe.", [], None),
        ("panel-light", "light", "Weniger *sofort*.\nMehr *nächste Woche*.",
         "Das Tageslimit senken geht jederzeit und gilt sofort. Erhöhen wartet "
         "eine Woche und gilt ab dem nächsten Tag.", [], None),
        (None, "dark", "Was *nicht* da ist.",
         "Über die Adresse entfernt, nicht hinter einer Einstellung versteckt, "
         "die sich um elf Uhr abends zurückschalten lässt.",
         ["Reels", "Explore", "Vorgeschlagene Konten", "Autoplay",
          "Serien und Berichte"], None),
        ("feed-open", "dark", "Alles andere\nbleibt *unberührt*.",
         "Liken, kommentieren, senden, speichern — Instagrams eigene Seite, "
         "genau wie vorher. Quiet nimmt Flächen weg und setzt nichts an ihre "
         "Stelle.", [], None),
        ("setup", "light", "Der ganze Handel,\n*vorab*.",
         "Was Quiet wegnimmt und was es unangetastet lässt — auf dem ersten "
         "Bildschirm, bevor du irgendetwas wählst.", [], None),
        ("opening", "dark", "Kein Konto.\nKein *Tracking*.",
         "Keine Server von uns, keine Analytics, keine Werbung. Nichts zum "
         "Nachsehen, nichts zu schlagen — eine Erinnerung am Tag.", [], None),
    ],
}


# v2, and two things move.
#
# **The hero is the post, not the story row.** Slide 1 was the top of the feed:
# a story ring, an author line, and the picture running off the bottom of the
# glass. It showed the tab was missing and nothing else. The scrolled frame
# shows a whole post — the like count, the comment count, the caption, the date
# — *and* the missing tab, in one photograph. Somebody deciding whether this is
# their Instagram gets the answer from that frame and not from the other one.
#
# **So the arrow moves with it**, and it says what it is rather than what it
# was: `No Reels`, which is the phrase somebody would search for.
#
# That frees the story-row capture for the job it is actually best at. Slide 5
# used to be the same photograph as slide 1 with a different caption over it —
# two slides, one picture, which is a slide wasted. Now it carries the story
# row, the header and the profile, under the claim they are all still there.
SLIDES_V2 = {
    "en": [
        ("feed-open", "light", "Instagram,\nwithout *Reels*.",
         "The same feed, the same people, the same messages. The tab that "
         "never ends is simply gone.", [], ("No Reels", (0.50, 0.951))),
        ("curtain", "dark", "No *five more*\nminutes.",
         "When today’s time is spent, Quiet closes for the day — and there is "
         "nothing on the screen to argue with.", [], None),
        ("panel-light", "light", "Less *now*.\nMore *next week*.",
         "Lowering your daily limit takes effect at once. Raising it waits a "
         "week and starts the next day.", [], None),
        (None, "dark", "What *isn’t* here.",
         "Taken out by address, not hidden behind a setting you could switch "
         "back on at eleven at night.",
         ["Reels", "Explore", "Suggested accounts", "Autoplay",
          "Streaks and reports"], None),
        ("feed", "dark", "Your feed.\nYour *people*.",
         "Stories, messages, comments, profiles — all of it, exactly where it "
         "was, on Instagram’s own page.", [], None),
        ("setup", "light", "The whole trade,\n*up front*.",
         "What Quiet takes away and what it leaves alone, on the first screen, "
         "before you choose anything.", [], None),
        ("opening", "dark", "No account.\nNo *tracking*.",
         "No servers of ours, no analytics, no advertising. Nothing to check "
         "and nothing to beat.", [], None),
    ],
    "de": [
        ("feed-open", "light", "Instagram,\nohne *Reels*.",
         "Derselbe Feed, dieselben Menschen, dieselben Nachrichten. Der Tab "
         "ohne Ende ist einfach weg.", [], ("Keine Reels", (0.50, 0.951))),
        ("curtain", "dark", "Keine *fünf*\nMinuten mehr.",
         "Ist die Zeit für heute weg, schließt Quiet den Tag — und auf dem "
         "Bildschirm steht nichts, mit dem sich verhandeln ließe.", [], None),
        ("panel-light", "light", "Weniger *sofort*.\nMehr *nächste Woche*.",
         "Das Tageslimit senken gilt sofort. Erhöhen wartet eine Woche und "
         "gilt ab dem nächsten Tag.", [], None),
        (None, "dark", "Was *nicht* da ist.",
         "Über die Adresse entfernt, nicht hinter einer Einstellung versteckt, "
         "die sich um elf Uhr abends zurückschalten lässt.",
         ["Reels", "Explore", "Vorgeschlagene Konten", "Autoplay",
          "Serien und Berichte"], None),
        ("feed", "dark", "Dein Feed.\nDeine *Leute*.",
         "Stories, Nachrichten, Kommentare, Profile — alles da, genau wo es "
         "war, auf Instagrams eigener Seite.", [], None),
        ("setup", "light", "Der ganze Handel,\n*vorab*.",
         "Was Quiet wegnimmt und was es unangetastet lässt — auf dem ersten "
         "Bildschirm, bevor du irgendetwas wählst.", [], None),
        ("opening", "dark", "Kein Konto.\nKein *Tracking*.",
         "Keine Server von uns, keine Analytics, keine Werbung. Nichts zum "
         "Nachsehen, nichts zu schlagen.", [], None),
    ],
    "es": [
        ("feed-open", "light", "Instagram,\nsin *Reels*.",
         "El mismo feed, la misma gente, los mismos mensajes. La pestaña que "
         "no termina nunca simplemente no está.", [],
         ("Sin Reels", (0.50, 0.951))),
        ("curtain", "dark", "Ni *cinco*\nminutos más.",
         "Cuando el tiempo de hoy se acaba, Quiet cierra el día — y en la "
         "pantalla no queda nada con lo que discutir.", [], None),
        ("panel-light", "light", "Menos *ahora*.\nMás *en una semana*.",
         "Bajar tu límite diario surte efecto de inmediato. Subirlo espera "
         "una semana y empieza al día siguiente.", [], None),
        (None, "dark", "Lo que *no* está.",
         "Quitado por dirección, no escondido detrás de un ajuste que podrías "
         "volver a activar a las once de la noche.",
         ["Reels", "Explorar", "Cuentas sugeridas", "Autoplay",
          "Rachas e informes"], None),
        ("feed", "dark", "Tu feed.\nTu *gente*.",
         "Historias, mensajes, comentarios, perfiles — todo, exactamente "
         "donde estaba, en la propia página de Instagram.", [], None),
        ("setup", "light", "Todo el trato,\n*de entrada*.",
         "Lo que Quiet quita y lo que deja en paz, en la primera pantalla, "
         "antes de que elijas nada.", [], None),
        ("opening", "dark", "Sin cuenta.\nSin *rastreo*.",
         "Ningún servidor nuestro, ninguna analítica, ninguna publicidad. "
         "Nada que revisar y nada que superar.", [], None),
    ],
    "fr": [
        ("feed-open", "light", "Instagram,\nsans *Reels*.",
         "Le même fil, les mêmes gens, les mêmes messages. L’onglet qui ne "
         "finit jamais a simplement disparu.", [],
         ("Pas de Reels", (0.50, 0.951))),
        ("curtain", "dark", "Pas *cinq*\nminutes de plus.",
         "Quand le temps du jour est passé, Quiet ferme la journée — et il "
         "n’y a rien à l’écran avec quoi discuter.", [], None),
        ("panel-light", "light", "Moins *maintenant*.\nPlus *dans huit jours*.",
         "Baisser ta limite quotidienne prend effet tout de suite. La relever "
         "attend une semaine et commence le lendemain.", [], None),
        (None, "dark", "Ce qui *n’est pas* là.",
         "Retiré par adresse, pas caché derrière un réglage que tu pourrais "
         "réactiver à onze heures du soir.",
         ["Reels", "Explorer", "Comptes suggérés", "Autoplay",
          "Séries et rapports"], None),
        ("feed", "dark", "Ton fil.\nTes *gens*.",
         "Stories, messages, commentaires, profils — tout y est, exactement "
         "où c’était, sur la page d’Instagram elle-même.", [], None),
        ("setup", "light", "Tout le marché,\n*d’emblée*.",
         "Ce que Quiet retire et ce qu’il laisse tranquille, sur le premier "
         "écran, avant que tu choisisses quoi que ce soit.", [], None),
        ("opening", "dark", "Pas de compte.\nPas de *pistage*.",
         "Aucun serveur à nous, aucune analyse, aucune publicité. Rien à "
         "vérifier et rien à battre.", [], None),
    ],
    "pt-BR": [
        ("feed-open", "light", "Instagram,\nsem *Reels*.",
         "O mesmo feed, as mesmas pessoas, as mesmas mensagens. A aba que não "
         "acaba nunca simplesmente sumiu.", [],
         ("Sem Reels", (0.50, 0.951))),
        ("curtain", "dark", "Nem *mais cinco*\nminutos.",
         "Quando o tempo de hoje acaba, o Quiet fecha o dia — e não há nada "
         "na tela com que discutir.", [], None),
        ("panel-light", "light", "Menos *agora*.\nMais *em uma semana*.",
         "Baixar seu limite diário vale na hora. Aumentar espera uma semana "
         "e começa no dia seguinte.", [], None),
        (None, "dark", "O que *não* está aqui.",
         "Tirado por endereço, não escondido atrás de um ajuste que você "
         "poderia religar às onze da noite.",
         ["Reels", "Explorar", "Contas sugeridas", "Autoplay",
          "Sequências e relatórios"], None),
        ("feed", "dark", "Seu feed.\nSuas *pessoas*.",
         "Stories, mensagens, comentários, perfis — tudo, exatamente onde "
         "estava, na própria página do Instagram.", [], None),
        ("setup", "light", "O acordo inteiro,\n*de cara*.",
         "O que o Quiet tira e o que ele deixa em paz, na primeira tela, "
         "antes de você escolher qualquer coisa.", [], None),
        ("opening", "dark", "Sem conta.\nSem *rastreio*.",
         "Nenhum servidor nosso, nenhuma análise, nenhuma publicidade. Nada "
         "para conferir e nada para superar.", [], None),
    ],
}

# Which set each dress wears. Assigned here rather than inside STYLES because
# STYLES is declared with the geometry, up where the other measurements live,
# and the slides are written down here.
STYLES["house"]["slides"] = SLIDES
STYLES["loud"]["slides"] = SLIDES
STYLES["v2"]["slides"] = SLIDES_V2


def photograph_for(language: str, name: str) -> Path | None:
    for candidate in (SOURCE / language / f"{name}.png", SOURCE / f"{name}.png"):
        if candidate.exists():
            return candidate
    return None


def contact_sheet(paths: list[Path], into: Path) -> None:
    """The six side by side, small. Not for uploading.

    A screenshot set is swiped through in about a second and judged as a strip,
    and the strip is the one view that never exists while you are making them
    one at a time.
    """
    if not paths:
        return
    width = 400
    height = round(HEIGHT * width / WIDTH)
    sheet = Image.new("RGB", (len(paths) * (width + 24) + 24, height + 48),
                      (0x1A, 0x19, 0x18))
    for i, path in enumerate(paths):
        sheet.paste(Image.open(path).resize((width, height), Image.LANCZOS),
                    (24 + i * (width + 24), 24))
    sheet.save(into)


def draw_set(root: Path, language: str, slides: list) -> None:
    folder = root / language
    folder.mkdir(parents=True, exist_ok=True)
    made: list[Path] = []
    for index, (name, mood, head, sub, items, note) in enumerate(slides, 1):
        ground = STYLE["one_ground"] or mood
        theme = THEMES[ground]
        if name is None:
            image, stem, tag = typeset(theme, head, sub, items, index), "absent", ""
        else:
            source = photograph_for(language, name)
            if source is None:
                print(f"  {language}: no {name}.png, skipped")
                continue
            image = photographed(source, theme, head, sub, index, note)
            stem = name
            tag = "" if source.parent.name == language else "   (shared capture)"
        path = folder / f"{index}-{stem}.png"
        image.save(path)
        made.append(path)
        print(f"  {path.relative_to(HERE)}  {WIDTH}x{HEIGHT}  {ground}{tag}")
    contact_sheet(made, root / f"sheet-{language}.png")


def main() -> None:
    if not SOURCE.is_dir():
        sys.exit(f"No source photographs in {SOURCE}")

    global STYLE
    asked = sys.argv[1:] or list(STYLES)
    unknown = [name for name in asked if name not in STYLES]
    if unknown:
        sys.exit(f"No such style: {', '.join(unknown)}. "
                 f"There is {' and '.join(STYLES)}.")

    for name in asked:
        STYLE = STYLES[name]
        # The house style keeps the path it has always had; anything else gets
        # a room of its own, so the two can be looked at without one of them
        # having overwritten the other.
        root = OUT if name == "house" else OUT / name
        print(f"{name}:")
        for language, slides in STYLE["slides"].items():
            draw_set(root, language, slides)


# The rule, for whoever re-shoots these.
#
# A screenshot in a listing is an advertisement, and three things can be wrong
# with one that a web view showing the same pixels to one reader does not raise:
#
#   * somebody's photograph is theirs, and a listing is a commercial use of it;
#   * somebody's face or handle in an advertisement is their likeness, used to
#     sell something they were never asked about;
#   * a page of another company's marks, in marketing rather than in the
#     product, is what guideline 5.2.1 is written about.
#
# So: shoot Quiet's own screens, or shoot Instagram's while signed in as
# yourself with nothing of anybody else's on the glass. Never the feed of
# accounts you follow, never the story row, never a suggestion, never a like
# count with a stranger's name on it. If a person who is not you can be
# recognised in it, it does not go in the listing.
#
# The same applies to what the slides *say*. No rating, no download count, no
# "as seen in", no Apple mark, no press logo. Every one of those is available to
# draw and none of them is true yet.
LEGAL = __doc__


if __name__ == "__main__":
    main()
