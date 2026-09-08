#!/usr/bin/env python3
"""Draw Quiet's app icon.

An hourglass, most of the way through, on a dark field.

The mark before this was a full stop, and the argument against it was that it
said nothing to anybody who had not already been told. An hourglass says the
thing instead of alluding to it, and it says the *right* thing, which a clock
does not. A clock runs for ever, and is somebody else's app besides. An
hourglass runs **out**. It holds a fixed amount, it is spending it, and when it
is empty the day is over.

The first hourglass was two solid triangles with a bar across each end, and the
tone of the upper triangle dimmed to stand for sand. Three things were wrong
with it, and all three are the difference between a shape that means an
hourglass and an hourglass:

* The triangles' base corners poked out past the rounded ends of the bars, so
  the mark had four small spikes on it — at a hundred and eighty pixels a
  hairline, at sixty a burr.
* Both chambers were full. An hourglass with a full top *and* a full bottom
  holds twice what it can hold, and the eye knows it before it can say why.
* Nothing was running. The state was carried entirely by a grey wash, which is
  a rendering artefact wearing the costume of an idea.

So this one is a glass with sand in it rather than a silhouette that alludes to
one, and the state is carried by where the sand *is*:

* **The glass is drawn, not implied.** A wall of constant weight all the way
  round, closed by a lid at each end, with a throat between the chambers that
  is parallel rather than a vertex — which is what stops it reading as a bow
  tie at the size where the waist becomes a hairline.
* **The sand still up there has a funnel in it**, because sand draining through
  a hole does, and the chamber below it is dark, because it is empty.
* **The sand that has fallen is a heap** — steep-sided, flat-footed, resting on
  the floor, the way a poured cone actually sits.
* **The two agree.** `HEAP` and `LEVEL` below are not chosen: they are solved
  for, so that the heap plus the sand in mid-air holds exactly what the upper
  chamber has lost. Nobody will measure it. Everybody can see when it is wrong.

Kept as a script rather than a checked-in mystery PNG so the shape can be
argued with. Uses nothing but the standard library.

    python3 Tools/make-icon.py        # writes the 1024 the app ships
    python3 Tools/look-at-icon.py     # then look at it small, which is the test
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024

# The field. Warm near-black, never pure black, and not quite flat: a tenth of
# a stop lighter at the top than at the bottom. It is eight levels across a
# thousand pixels, which is invisible as a gradient and legible as light coming
# from above — the difference between a dark icon and an unlit one.
SKY_ABOVE = (0x1D, 0x1C, 0x19)
SKY_BELOW = (0x15, 0x14, 0x12)

# The glass: warm off-white, never pure white.
GLASS = (0xF2, 0xEE, 0xE7)

# The sand, a shade down and a shade warmer than the glass holding it.
#
# Not decoration, and not the old grey wash either. Two materials that are the
# same colour are one material, and at a thousand pixels the glass would then
# have no edge wherever it was full. At sixty points the difference washes out
# and the mark goes solid, which is exactly the right way for it to fail.
SAND = (0xD5, 0xC7, 0xAE)

# The glass, as fractions of the square. Taller than wide by about the ratio a
# real one has; much squarer and it reads as an egg timer on a shelf.
HEIGHT = 0.585          # lid to lid
WIDTH = 0.415           # the widest thing there is
CAP = 0.044             # a lid, which is a capsule as wide as the glass
WALL = 0.026            # the glass itself, measured across the wall
THROAT = 0.017          # half the opening between the chambers
THROAT_HEIGHT = 0.020   # how much of the neck is parallel rather than curved

# Where the sand still up there comes to, as a fraction of the way from under
# the top lid down to the throat. This is the one number here chosen by eye, and
# it is the right one to choose by eye: it is what somebody actually reads off
# the icon. How much has *gone* is then arithmetic, not taste — see below, where
# it turns out to be far more than the picture suggests, because a chamber that
# is wide at the top holds most of what it holds at the top.
SURFACE = 0.26

# The funnel in the sand that is still up there, measured at its deepest.
DISH = 0.032

# Where the falling sand has got down to. It leaves the throat at the throat's
# own width and narrows, because sand in mid-air is going faster the further it
# has fallen and the same amount of it has to fit through a thinner column.
FALL = 0.024

# The sides of a poured heap. One is a dome, two is a cone with a point on it;
# a little under two is a cone with the point knocked off, which is what sand
# does when it lands on sand.
PILE = 1.35

# A mark at the exact geometric centre reads as sitting slightly low. Lifting it
# by a little over one percent is the correction every typographer makes without
# thinking, and the reason this looks placed rather than calculated.
OPTICAL_LIFT = 0.012

# Sub-scanlines per row of pixels, which is how many levels of grey a nearly
# horizontal edge gets. Across a wall it gets all of them: every shape here is
# an interval in x at a given y, so the horizontal coverage is arithmetic
# rather than a count of samples that happened to land inside.
STEPS = 16


def _px(fraction: float) -> float:
    return fraction * SIZE


CENTRE_X = SIZE / 2
CENTRE_Y = SIZE / 2 - _px(OPTICAL_LIFT)

TOP = CENTRE_Y - _px(HEIGHT) / 2
BOTTOM = CENTRE_Y + _px(HEIGHT) / 2
HALF = _px(WIDTH) / 2
LID = _px(CAP) / 2
SKIN = _px(WALL)

# The lid's own centre line, which is where its capsule is at full width. The
# glass wall starts there rather than under the lid, so the two meet where they
# are both exactly `HALF` from the middle and the join has no step in it and no
# corner poking past. That single choice is what the old mark's four spikes
# were the absence of.
SHOULDER = TOP + LID
FOOTING = BOTTOM - LID

# Where the sand can be: under one lid, over the other.
CEILING = TOP + 2 * LID
FLOOR = BOTTOM - 2 * LID

NECK_ABOVE = CENTRE_Y - _px(THROAT_HEIGHT) / 2
NECK_BELOW = CENTRE_Y + _px(THROAT_HEIGHT) / 2
NECK = _px(THROAT)              # inside the throat
NECK_OUT = NECK + SKIN          # outside it

SPAN = NECK_ABOVE - SHOULDER
FLARE = HALF - NECK_OUT


def _outside(y: float) -> float:
    """Half the width of the glass, outside the wall, at this height.

    The profile is a smoothstep, and the two things that matters about it are
    at its ends: it leaves the lid vertically and it arrives at the throat
    vertically. So the mark has a straight side under each lid and a parallel
    neck in the middle, and the diagonal is only the part in between — which is
    an hourglass. A straight taper is a bow tie, and a taper that arrives at
    the neck still moving is a funnel.
    """
    height = abs(y - CENTRE_Y)
    if height <= _px(THROAT_HEIGHT) / 2:
        return NECK_OUT
    t = min(max((height - _px(THROAT_HEIGHT) / 2) / SPAN, 0.0), 1.0)
    return NECK_OUT + FLARE * t * t * (3 - 2 * t)   # 0 at the throat, 1 at the lid


def _inside(y: float) -> float:
    """Half the width of the cavity at this height.

    Not `_outside(y) - SKIN`. Taking the wall off horizontally leaves it
    thinner wherever the glass is diagonal — a quarter thinner at the steepest
    point here, which is plainly visible and is the usual reason a drawn shape
    looks slightly wrong without anybody being able to say where. Taking it off
    along the normal instead costs one square root and gives a wall of one
    weight the whole way round.
    """
    height = abs(y - CENTRE_Y)
    if height <= _px(THROAT_HEIGHT) / 2:
        slope = 0.0
    else:
        t = min(max((height - _px(THROAT_HEIGHT) / 2) / SPAN, 0.0), 1.0)
        slope = FLARE * 6 * t * (1 - t) / SPAN
    return _outside(y) - SKIN * math.sqrt(1 + slope * slope)


def _dish(y: float, level: float) -> float:
    """How far out from the middle the sand starts, inside the funnel.

    Above the level there is no sand at all; below the funnel's deepest point
    there is nothing but sand. In between it is a ring, and this is its hole.
    """
    if y <= level:
        return _inside(y)
    fallen = (y - level) / _px(DISH)
    if fallen >= 1:
        return 0.0
    return _inside(level) * math.sqrt(1 - fallen)


def _fall(y: float, apex: float) -> float:
    """Half the width of the falling sand, this far below the throat.

    A stream leaves an opening at the opening's width and thins as it speeds
    up, and how fast it thins is not a taste: the same sand per second through
    a column going faster is a column that is narrower by the fourth root. One
    constant, fitted so it arrives at the heap at `FALL`, and the shape of the
    pour comes out on its own — a quick purse below the neck and then a fall
    that is very nearly parallel.
    """
    drop = y - NECK_BELOW
    if drop < 0 or y > apex:
        return 0.0
    length = max(apex - NECK_BELOW, 1.0)
    ease = length / ((NECK / (_px(FALL) / 2)) ** 4 - 1)
    return NECK * (1 + drop / ease) ** -0.25


def _heap(y: float, height: float) -> float:
    """Half the width of the heap at this height, which is nothing above it."""
    if height <= 0 or y < FLOOR - height or y > FLOOR:
        return 0.0
    risen = (FLOOR - y) / height
    return min(_inside(FLOOR) * max(1 - risen, 0.0) ** (1 / PILE), _inside(y))


def _volume(low: float, high: float, radius) -> float:
    """What a solid of revolution between two heights holds, over pi.

    The mark is a section through something round, so the sand in it is not an
    area on a page. A heap that balanced by area would be a heap that held
    rather less than the chamber above it has lost, and it would be wrong in
    the direction nobody checks.
    """
    steps = 1200
    step = (high - low) / steps
    if step <= 0:
        return 0.0
    total = 0.0
    for i in range(steps):
        r = radius(low + (i + 0.5) * step)
        total += r * r
    return total * step


def _solve(target: float, low: float, high: float, holds) -> float:
    """The one value between two bounds at which `holds` is `target`."""
    for _ in range(60):
        middle = (low + high) / 2
        if holds(middle) > target:
            low = middle
        else:
            high = middle
    return (low + high) / 2


CAPACITY = _volume(CEILING, NECK_BELOW, _inside)


def _still_up(level: float) -> float:
    def radius(y: float) -> float:
        outer, inner = _inside(y), _dish(y, level)
        return math.sqrt(max(outer * outer - inner * inner, 0.0))
    return _volume(level, NECK_BELOW, radius)


def _has_fallen(height: float) -> float:
    apex = FLOOR - height
    return _volume(FLOOR - height, FLOOR, lambda y: _heap(y, height)) + _volume(
        NECK_BELOW, apex, lambda y: _fall(y, apex)
    )


# The one thing the eye is given, and the one thing the arithmetic is then held
# to. Balancing this the other way round — pick how much has run, solve for the
# surface — was tried and is wrong: a glass with well over half its sand gone
# still has a surface barely a seventh of the way down, so the honest number
# draws a picture that says nothing has happened yet.
#
# `_has_fallen` rises with the heap and has no other root, so this is one
# bisection and it cannot find the wrong answer.
LEVEL = CEILING + SURFACE * (NECK_BELOW - CEILING)
FALLEN = CAPACITY - _still_up(LEVEL)
HEAP = _solve(FALLEN, FLOOR - NECK_BELOW, 0.0, _has_fallen)
APEX = FLOOR - HEAP

# The heap has to stop short of the throat, or the falling sand has nowhere to
# be falling and the middle of the mark closes up into a column.
assert APEX - NECK_BELOW > _px(0.06), "the heap has grown up into the neck"


# ── The run ──────────────────────────────────────────────────────────────────
#
# The icon is one pose. The app draws the same glass *running*, over the second
# and a half it holds its opening screen, and a pose part of the way there is
# not something either of the two numbers above can be scaled towards: the sand
# still up there and the heap under it are each solved out of a volume, and
# halving a volume does not halve either length.
#
# So the whole path is solved here too, and it turns out to be three findings
# rather than a table of numbers, which is why what gets copied into
# `Design.swift` is so short:
#
# * **The crater comes first, and it costs a quarter of the sand.** The chamber
#   is at its widest under the top lid, so the dish that sand draining through a
#   hole digs into a full one holds a great deal — twenty-six percent of
#   everything that runs, before the surface has moved at all. That is not a
#   liberty; it is what the icon's own `DISH` is worth in a chamber this shape,
#   and it is why the mark's first half-second is a dimple deepening rather than
#   a level dropping.
# * **The crater deepens linearly.** Its width goes as the square root of its
#   depth, so its volume goes as its depth, so at a constant rate it deepens at
#   a constant rate. No table.
# * **The heap grows linearly too**, and for a related reason: a heap of this
#   profile holds a fixed multiple of its own height times the floor it stands
#   on, so at a constant rate it rises at a constant rate. Also no table.
#
# Which leaves one curve — where the surface has got to, once the crater is dug
# — and thirteen numbers describe it to within a hundredth of a point at the
# size the opening draws the mark.
#
# Constant rate throughout, because that is what an hourglass does. A tank
# empties more slowly as it empties; sand does not, which is the whole reason a
# glass of it can be used to measure anything at all. Nothing here eases.


def _hole(y: float, level: float, dish: float) -> float:
    """`_dish`, with the depth of the funnel asked for rather than assumed."""
    if y <= level:
        return _inside(y)
    if dish <= 0:
        return 0.0
    fallen = (y - level) / dish
    if fallen >= 1:
        return 0.0
    return _inside(level) * math.sqrt(1 - fallen)


def _above(level: float, dish: float) -> float:
    """What is still in the upper chamber, at this surface and this funnel."""

    def radius(y: float) -> float:
        outer, inner = _inside(y), _hole(y, level, dish)
        return math.sqrt(max(outer * outer - inner * inner, 0.0))

    return _volume(level, NECK_BELOW, radius)


# Brim full, flat, nothing dug and nothing gone: where the run starts.
BRIMFUL = _volume(CEILING, NECK_BELOW, _inside)

# And where it ends, which is the icon. The run is measured against this, so
# that "all the way through" means "the thing on the home screen" rather than
# an empty glass the app never draws.
RUN = BRIMFUL - _above(LEVEL, _px(DISH))

# How much of the run is spent digging the funnel, with the surface still up
# against the lid, and how much is spent before the first grain lands.
CRATER = (BRIMFUL - _above(CEILING, _px(DISH))) / RUN
LANDING = _has_fallen(0.0) / RUN

# Enough points to draw the one thing here that is a curve. Twelve intervals
# put linear interpolation within 0.0002 of the square of the solved value,
# which is a hundredth of a point on the mark at the size the opening draws it.
STOPS = 12
LEVELS = [
    _solve(
        BRIMFUL - (CRATER + (1 - CRATER) * step / STOPS) * RUN,
        CEILING,
        NECK_BELOW,
        lambda surface: _above(surface, _px(DISH)),
    )
    for step in range(STOPS + 1)
]

assert abs(LEVELS[0] - CEILING) < 1e-6, "the crater does not end at the lid"
assert abs(LEVELS[-1] - LEVEL) < 1e-6, "the run does not end at the icon"




def _glass(y: float):
    """The spans of glass across this scanline: the wall, and the two lids."""
    spans = []
    for centre in (SHOULDER, FOOTING):
        rise = y - centre
        if abs(rise) <= LID:
            reach = HALF - LID + math.sqrt(LID * LID - rise * rise)
            spans.append((CENTRE_X - reach, CENTRE_X + reach))
    if SHOULDER <= y <= FOOTING:
        outer = _outside(y)
        if CEILING <= y <= FLOOR:
            inner = _inside(y)
            spans.append((CENTRE_X - outer, CENTRE_X - inner))
            spans.append((CENTRE_X + inner, CENTRE_X + outer))
        else:
            spans.append((CENTRE_X - outer, CENTRE_X + outer))
    return spans


def _sand(y: float):
    """The spans of sand across this scanline: what is left, what is falling,
    and what has landed."""
    spans = []
    if LEVEL <= y <= NECK_BELOW:
        outer, hole = _inside(y), _dish(y, LEVEL)
        if hole <= 0:
            spans.append((CENTRE_X - outer, CENTRE_X + outer))
        elif hole < outer:
            spans.append((CENTRE_X - outer, CENTRE_X - hole))
            spans.append((CENTRE_X + hole, CENTRE_X + outer))
    stream = _fall(y, APEX)
    if stream > 0:
        spans.append((CENTRE_X - stream, CENTRE_X + stream))
    heap = _heap(y, HEAP)
    if heap > 0:
        spans.append((CENTRE_X - heap, CENTRE_X + heap))
    return spans


def _merge(spans):
    merged = []
    for low, high in sorted(spans):
        if merged and low <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], high)
        else:
            merged.append([low, high])
    return merged


def _lay(row, edges, spans, weight: float) -> None:
    """Add a scanline's worth of coverage to a row.

    The two pixels a span ends in get the fraction of themselves it covers; the
    ones between get all of it, and they get it through `edges` — one addition
    and one subtraction rather than one per pixel, which is the difference
    between this taking two seconds and taking twenty.
    """
    for low, high in spans:
        low, high = max(low, 0.0), min(high, float(SIZE))
        if high <= low:
            continue
        first, last = int(low), min(int(math.ceil(high)) - 1, SIZE - 1)
        if first == last:
            row[first] += (high - low) * weight
            continue
        row[first] += (first + 1 - low) * weight
        row[last] += (high - last) * weight
        edges[first + 1] += weight
        edges[last] -= weight


def render() -> bytes:
    out = bytearray()
    for line in range(SIZE):
        glass = [0.0] * SIZE
        sand = [0.0] * SIZE
        glass_edges = [0.0] * (SIZE + 1)
        sand_edges = [0.0] * (SIZE + 1)
        for step in range(STEPS):
            y = line + (step + 0.5) / STEPS
            _lay(glass, glass_edges, _merge(_glass(y)), 1 / STEPS)
            _lay(sand, sand_edges, _merge(_sand(y)), 1 / STEPS)

        field = line / (SIZE - 1)
        sky = [a + (b - a) * field for a, b in zip(SKY_ABOVE, SKY_BELOW)]

        out.append(0)  # PNG filter type: none
        running_glass = running_sand = 0.0
        for column in range(SIZE):
            running_glass += glass_edges[column]
            running_sand += sand_edges[column]
            g = min(max(glass[column] + running_glass, 0.0), 1.0)
            s = min(max(sand[column] + running_sand, 0.0), 1.0 - g)
            for ground, mark, grain in zip(sky, GLASS, SAND):
                out.append(round(ground + (mark - ground) * g + (grain - ground) * s))
    return bytes(out)


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
    # The numbers that were solved rather than chosen, so that a change to the
    # shape says out loud what it did to the sand.
    print(
        f"  surface    {SURFACE:.0%} down the glass, which is {FALLEN / CAPACITY:.0%} run through\n"
        f"  heap       {HEAP / (FLOOR - NECK_BELOW):.0%} of the chamber it stands in\n"
        f"  clearance  {(APEX - NECK_BELOW) / SIZE:.3f} of the square, throat to heap\n"
        f"  balance    {_has_fallen(HEAP) / FALLEN:.3f} of what is missing is accounted for"
    )
    # The app draws this mark too, at the foot of the opening and in the row,
    # and it cannot solve for these — one of them takes sixty bisections over a
    # numeric integral. So they are printed here to be copied into `Hourglass`
    # in Design.swift, and the two lengths are in the same units everything
    # else there is: fractions of the icon's square.
    print(
        "\n  Design.swift's Hourglass wants:\n"
        f"    static let level: CGFloat = {(LEVEL - TOP) / SIZE:.4f}\n"
        f"    static let heap: CGFloat = {HEAP / SIZE:.4f}"
    )
    # And the run, for the opening screen. Three lines and a short table,
    # because the two things that could have needed one turned out to be
    # straight — see the section above.
    print(
        "\n    static let crater: CGFloat = "
        f"{CRATER:.4f}\n"
        f"    static let landing: CGFloat = {LANDING:.4f}\n"
        "    static let levels: [CGFloat] = ["
    )
    for start in range(0, len(LEVELS), 4):
        row = LEVELS[start:start + 4]
        print("        " + ", ".join(f"{(y - TOP) / SIZE:.4f}" for y in row) + ",")
    print("    ]")
