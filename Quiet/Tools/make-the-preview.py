#!/usr/bin/env python3
"""Cut the App Store preview: twenty-eight seconds of Quiet, moving.

    /usr/local/bin/python3.12 Tools/make-the-preview.py            # en and de
    /usr/local/bin/python3.12 Tools/make-the-preview.py fr es      # these
    /usr/local/bin/python3.12 Tools/make-the-preview.py --all
    /usr/local/bin/python3.12 Tools/make-the-preview.py en --stills  # six frames, no film

Written to `Tools/shots/out/preview/<language>/quiet-preview.mp4` at 886 x 1920,
30 fps, H.264 with a stereo AAC track — the portrait size App Store Connect
takes for the 6.9-inch and 6.5-inch iPhone, and the frame rate and codecs it
insists on. It refuses a preview with no audio track at all, so there is always
one, and it is written here rather than borrowed from anybody.

**Every picture of the app in it is a capture of the app.** Guideline 2.3.4
lets a preview carry text laid over it and nothing that is not the app — so the
screens are the same captures the screenshots are cut from, in
`Tools/shots/source`, moved rather than redrawn. Two things are animated *on*
them, and both are things the app itself does: the days of the chart arriving,
and the panel's first line counting down to the one it says when the day is
spent. That line is set again in the face, size and colour the app sets it in
(`Font.quietTitle`: New York, 28 pt, at 3x), fitted against the capture it
replaces; the strings are read out of `Localizable.xcstrings`, so the German
film says what the German app says.

No device frame, no hand, no star rating, no Apple mark: the same list of
refusals as `make-shots.py`, for the same reasons, plus the one Apple adds for
previews.

The story, in six scenes, each a claim the listing already makes:

    1  Instagram, without Reels.     the feed, and the hole where the tab was
    2  What isn't here.              five things, struck through one by one
    3  Your feed. Your people.       what is left alone
    4  No five more minutes.         the day runs out and the curtain comes down
    5  Less now. More next week.     the rule
    6  No account. No tracking.      the opening, and the name
"""

from __future__ import annotations

import importlib.util
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
REPO = PROJECT.parent

_spec = importlib.util.spec_from_file_location("shots", HERE / "make-shots.py")
shots = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(shots)

OUT = HERE / "shots" / "out" / "preview"
CAPTURES = HERE / "shots" / "capture"
STRINGS = PROJECT / "Quiet" / "Resources" / "Localizable.xcstrings"
ICON = PROJECT / "Quiet" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"
STORE = REPO / "store"

W, H = 886, 1920
FPS = 30
RATE = 48000
FADE = 0.4                      # every cut is a dissolve this long

LIGHT = shots.THEMES["light"]
DARK = shots.THEMES["dark"]
SERIF, SANS, HAND = shots.SERIF, shots.SANS, shots.HAND

MARGIN = 64
HEAD_TOP = 150
HEAD_SIZE = 74
HEAD_INDENT = 54
CARD_W = 620
CARD_TOP = 470

STORE_LOCALE = {"en": "en-US", "en-GB": "en-GB", "de": "de-DE",
                "es": "es-ES", "fr": "fr-FR", "pt-BR": "pt-BR"}


# --------------------------------------------------------------------------
# Time


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def span(t, a, b):
    return clamp((t - a) / (b - a)) if b > a else float(t >= a)


def out3(p):
    return 1 - (1 - p) ** 3


def inout(p):
    return 4 * p ** 3 if p < 0.5 else 1 - (-2 * p + 2) ** 3 / 2


def back(p, s=1.4):
    p -= 1
    return 1 + (s + 1) * p ** 3 + s * p ** 2


def mix(a, b, p):
    return tuple(round(x + (y - x) * p) for x, y in zip(a, b))


# --------------------------------------------------------------------------
# Words


def strings(language: str):
    table = json.loads(STRINGS.read_text())["strings"]
    xc = "en" if language == "en" else language

    def plain(key):
        entry = table[key].get("localizations", {}).get(xc)
        return entry["stringUnit"]["value"] if entry else key

    def plural(key, n):
        entry = table[key]["localizations"].get(xc) or table[key]["localizations"]["en"]
        forms = entry["variations"]["plural"]
        form = forms["one" if n == 1 else "other"]["stringUnit"]["value"]
        return form.replace("%lld", str(n))

    return {
        "left": lambda n: plain("%@ left today.").replace("%@", plural("%lld minutes", n)),
        "spent": plain("No time left today."),
    }


def slides(language: str):
    """The headlines, from the screenshots, so film and stills never disagree."""
    by_name = {}
    for name, _, head, sub, items, _ in shots.SLIDES_V2[language]:
        by_name[name or "absent"] = (head, sub, items)
    return by_name


def store_text(language: str, field: str) -> str:
    path = STORE / STORE_LOCALE[language] / f"{field}.txt"
    return path.read_text().strip() if path.exists() else ""


_faces: dict = {}


def face(path, size, weight=b"Regular"):
    key = (path, size, weight)
    if key not in _faces:
        _faces[key] = shots.font(path, size, weight)
    return _faces[key]


_lines: dict = {}


def line_image(text: str, size: int, ink) -> Image.Image:
    """One headline line, light with its heavy word, on a clear layer."""
    key = (text, size, ink)
    if key in _lines:
        return _lines[key]
    light, heavy = face(SERIF, size), face(SERIF, size, b"Bold")
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    width = math.ceil(shots.measure(probe, text, light, heavy)) + 8
    layer = Image.new("RGBA", (width, round(size * 1.35)), ink + (0,))
    shots.rich(ImageDraw.Draw(layer), (0, 0), text, light, heavy, ink + (255,))
    _lines[key] = layer
    return layer


def headline_size(headline: str) -> int:
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    size = HEAD_SIZE
    while size > 40:
        light, heavy = face(SERIF, size), face(SERIF, size, b"Bold")
        widest = max(shots.measure(probe, line, light, heavy) + (HEAD_INDENT if i else 0)
                     for i, line in enumerate(headline.split("\n")))
        if widest <= W - 2 * MARGIN:
            return size
        size -= 2
    return size


def fade_paste(canvas: Image.Image, layer: Image.Image, xy, alpha: float) -> None:
    if alpha <= 0:
        return
    if alpha < 1:
        a = layer.getchannel("A").point(lambda v: round(v * alpha))
        layer = layer.copy()
        layer.putalpha(a)
    canvas.paste(layer, (round(xy[0]), round(xy[1])), layer)


def headline(canvas, text: str, ink, t: float, start: float = 0.05, top: int = HEAD_TOP):
    """Each line rises a little and arrives, the second a beat behind."""
    size = headline_size(text)
    for i, line in enumerate(text.split("\n")):
        p = out3(span(t, start + 0.16 * i, start + 0.16 * i + 0.75))
        layer = line_image(line, size, ink)
        x = MARGIN + (HEAD_INDENT if i else 0)
        y = top + i * round(size * 1.16) + (1 - p) * 34
        fade_paste(canvas, layer, (x, y), p)


def subline(canvas, text: str, ink, t: float, start: float, y: int, size: int = 30):
    sans = face(SANS, size)
    draw = ImageDraw.Draw(Image.new("L", (1, 1)))
    p = out3(span(t, start, start + 0.8))
    for i, row in enumerate(shots.wrap(draw, text, sans, W - 2 * MARGIN)):
        layer = Image.new("RGBA", (W, round(size * 1.5)), ink + (0,))
        ImageDraw.Draw(layer).text((MARGIN, 0), row, font=sans, fill=ink + (255,))
        fade_paste(canvas, layer, (0, y + i * round(size * 1.42) + (1 - p) * 16), p)


# --------------------------------------------------------------------------
# The screen


_masks: dict = {}


def rounded(size, radius):
    key = (size, radius)
    if key not in _masks:
        over = 3
        big = Image.new("L", (size[0] * over, size[1] * over), 0)
        ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1),
                                              radius=radius * over, fill=255)
        _masks[key] = big.resize(size, Image.LANCZOS)
    return _masks[key]


_shadows: dict = {}


def shadow_of(size, radius, blur):
    key = (size, radius, blur)
    if key not in _shadows:
        pad = blur * 3
        small = 4
        m = Image.new("L", ((size[0] + 2 * pad) // small, (size[1] + 2 * pad) // small), 0)
        ImageDraw.Draw(m).rounded_rectangle(
            (pad // small, pad // small, (pad + size[0]) // small, (pad + size[1]) // small),
            radius=radius // small, fill=255)
        m = m.filter(ImageFilter.GaussianBlur(blur / small))
        _shadows[key] = (m.resize((size[0] + 2 * pad, size[1] + 2 * pad), Image.BILINEAR), pad)
    return _shadows[key]


def card(canvas, screen: Image.Image, cx: float, top: float, width: float,
         alpha: float = 1.0, shade=(0, 0, 0), shade_strength: float = 0.28,
         zoom: float = 1.0, focus: float = 0.5):
    """The capture, with its corners and a shadow, and nothing else around it.

    `zoom` moves a camera inside the screen rather than growing the card: the
    frame stays where it is and what is in it comes closer.
    """
    width = round(width)
    height = round(width * screen.height / screen.width)
    view = screen
    if zoom > 1.0001:
        cw, ch = screen.width / zoom, screen.height / zoom
        cy = clamp(focus * screen.height, ch / 2, screen.height - ch / 2)
        cxs = screen.width / 2
        view = screen.crop((round(cxs - cw / 2), round(cy - ch / 2),
                            round(cxs + cw / 2), round(cy + ch / 2)))
    face_img = view.resize((width, height), Image.BICUBIC, reducing_gap=2.0)
    radius = round(width * shots.SCREEN_RADIUS)
    x, y = round(cx - width / 2), round(top)

    if alpha <= 0:
        return (x, y, width, height)
    sh, pad = shadow_of((width, height), radius, 34)
    sh = sh.point(lambda v: round(v * shade_strength * alpha))
    canvas.paste(Image.new("RGB", sh.size, shade), (x - pad, y - pad + 26), sh)
    mask = rounded((width, height), radius)
    if alpha < 1:
        mask = mask.point(lambda v: round(v * alpha))
    canvas.paste(face_img.convert("RGB"), (x, y), mask)
    return (x, y, width, height)


def band_rows(image: Image.Image, top: int, bottom: int, threshold: int = 40):
    """Runs of rows that hold anything but the paper, between two heights."""
    a = np.asarray(image.convert("RGB")).astype(int)
    ground = a[top + 2, 30]
    diff = np.abs(a - ground).sum(2) > threshold
    rows = np.where(diff[top:bottom, 60:image.width - 60].any(1))[0] + top
    out = []
    if len(rows):
        start = prev = rows[0]
        for r in rows[1:]:
            if r > prev + 3:
                out.append((start, prev))
                start = r
            prev = r
        out.append((start, prev))
    return out, diff, ground


# --------------------------------------------------------------------------
# The panel, taken apart so it can be put together again over time


class Panel:
    """The record capture: its headline, and its chart one bar at a time."""

    def __init__(self, image: Image.Image, words):
        self.image = image.convert("RGB")
        self.words = words
        a = np.asarray(self.image).astype(int)
        self.a = a
        bands, diff, ground = band_rows(self.image, 330, 2400)
        self.ground = tuple(int(v) for v in ground)

        # The headline is the first thing under the navigation; the chart is
        # the tallest thing on the page.
        self.head = next(b for b in bands if b[1] - b[0] > 40)
        # ...and in French it runs to a second line ("Il te reste 20 minutes /
        # aujourd'hui."), which is a second band just under the first, of the
        # same height. Missed, it was left standing under a first line
        # squeezed to hold the whole sentence.
        self.head_lines = [self.head]
        for b in bands[bands.index(self.head) + 1:]:
            h, last = b[1] - b[0], self.head_lines[-1]
            if b[0] - last[1] < 45 and abs(h - (last[1] - last[0])) < 30:
                self.head_lines.append(b)
            else:
                break
        chart = max(bands, key=lambda b: b[1] - b[0])
        c0, c1 = chart
        self.chart = chart

        lum = a.mean(2)
        foot = c1 - 4
        solid = lum[foot] < 215
        bars, x = [], 0
        while x < self.image.width:
            if solid[x]:
                start = x
                while x < self.image.width and solid[x]:
                    x += 1
                if x - start > 40:
                    mid = (start + x) // 2
                    col = lum[c0:c1 + 1, mid] < 225
                    y = c0
                    while y <= c1 and not col[y - c0:y - c0 + 5].all():
                        y += 1
                    bars.append((start, x, y - 3, c1))
            x += 1
        self.bars = bars

        # The dashed line at the limit crosses the bars. Found where no bar
        # stands, and redrawn across the ones that are not there yet.
        left = bars[0][0] - 12 if bars else 0
        empty = diff[c0:c1 + 1, 90:max(91, left)]
        self.dash_rows = [c0 + r for r in np.where(empty.any(1))[0]]
        self.empty = self.image.copy()
        e = np.asarray(self.empty).copy()
        for x0, x1, y0, y1 in bars:
            above = a[max(0, c0 - 6), x0 - 2:x1 + 3].mean(0)
            below = a[min(a.shape[0] - 1, c1 + 6), x0 - 2:x1 + 3].mean(0)
            for y in range(y0 - 2, y1 + 3):
                k = (y - (c0 - 6)) / ((c1 + 6) - (c0 - 6))
                e[y, x0 - 2:x1 + 3] = (above * (1 - k) + below * k).astype(np.uint8)
        if self.dash_rows and left > 120:
            for y in self.dash_rows:
                row = a[y, 90:left]
                on = np.abs(row - np.array(self.ground)).sum(1) > 40
                starts = [i for i in range(1, len(on)) if on[i] and not on[i - 1]]
                if len(starts) >= 2:
                    period = int(np.median(np.diff(starts)))
                    length = int(np.median([
                        next((j for j in range(s, len(on)) if not on[j]), len(on)) - s
                        for s in starts]))
                    ink = row[on].mean(0)
                    phase = starts[0] + 90
                    for x0, x1, _, _ in bars:
                        for x in range(x0 - 2, x1 + 3):
                            if (x - phase) % period < length:
                                e[y, x] = ink
        self.empty = Image.fromarray(e.astype(np.uint8))
        self.bar_images = [self.image.crop((x0, y0, x1, y1 + 1)) for x0, x1, y0, y1 in bars]

        # The line, fitted: 28 pt at 3x, the optical size it is set at, and the
        # tracking iOS gives it — measured off this capture rather than assumed.
        h0, h1 = self.head
        ink_cols = np.where(diff[h0:h1 + 1, 60:self.image.width - 60].any(0))[0] + 60
        self.pitch = (self.head_lines[-1][0] - h0) / max(1, len(self.head_lines) - 1)
        self.head_x = int(ink_cols[0])
        measured = int(ink_cols[-1] - ink_cols[0])
        self.font = ImageFont.truetype(SERIF, 84)
        try:
            self.font.set_variation_by_axes([28, 400, 0])
        except Exception:
            pass
        original = words["left"](9)
        first = original
        if len(self.head_lines) > 1:
            # the first line is the run of words whose width is nearest it
            parts = original.split(" ")
            first = min((" ".join(parts[:k]) for k in range(1, len(parts))),
                        key=lambda run: abs(self.run_width(run, 0.0) - measured))
        plain = self.run_width(first, 0.0)
        self.tracking = (measured - plain) / max(1, len(first) - 1)
        self.room = self.image.width - 2 * self.head_x
        probe = ImageDraw.Draw(Image.new("L", (1, 1)))
        self.head_y = h0 - probe.textbbox((0, 0), original, font=self.font)[1]
        dark = a[h0:h1 + 1, self.head_x:ink_cols[-1]].reshape(-1, 3)
        self.ink = tuple(int(v) for v in dark[dark.sum(1).argsort()[:200]].mean(0))

        # The paper behind the line, rebuilt from the rows above and below it,
        # because the panel's ground has a light on it and is not one colour.
        top, bottom = h0 - 16, self.head_lines[-1][1] + 16
        self.patch_box = (40, top, self.image.width - 40, bottom)
        above = a[top - 3:top, 40:self.image.width - 40].mean(0)
        below = a[bottom + 1:bottom + 4, 40:self.image.width - 40].mean(0)
        k = np.linspace(0, 1, bottom - top)[:, None, None]
        self.patch = Image.fromarray((above[None] * (1 - k) + below[None] * k).astype(np.uint8))
        self._frames: dict = {}

    def run_width(self, text: str, tracking: float) -> float:
        probe = ImageDraw.Draw(Image.new("L", (1, 1)))
        box = probe.textbbox((0, 0), text, font=self.font)
        return (box[2] - box[0]) + tracking * (len(text) - 1)

    def wrap(self, text: str) -> list[str]:
        lines = [""]
        for word in text.split(" "):
            trial = (lines[-1] + " " + word).strip()
            if lines[-1] and self.run_width(trial, self.tracking) > self.room:
                lines.append(word)
            else:
                lines[-1] = trial
        return lines

    def set_line(self, image: Image.Image, text: str) -> None:
        image.paste(self.patch, self.patch_box[:2])
        draw = ImageDraw.Draw(image)
        for n, line in enumerate(self.wrap(text)):
            probe_box = draw.textbbox((0, 0), line, font=self.font)
            x = self.head_x - probe_box[0]
            y = self.head_y + round(n * self.pitch)
            for ch in line:
                draw.text((x, y), ch, font=self.font, fill=self.ink)
                x += draw.textlength(ch, font=self.font) + self.tracking

    def frame(self, grown: list[float], line: str | None) -> Image.Image:
        key = (tuple(round(g, 3) for g in grown), line)
        if key in self._frames:
            return self._frames[key]
        image = self.empty.copy()
        c1 = self.chart[1]
        for (x0, x1, y0, y1), bar, g in zip(self.bars, self.bar_images, grown):
            h = round(bar.height * clamp(g))
            if h > 0:
                image.paste(bar.crop((0, 0, bar.width, h)), (x0, c1 + 1 - h))
        if line is not None:
            self.set_line(image, line)
        if len(self._frames) > 64:
            self._frames.clear()
        self._frames[key] = image
        return image


# --------------------------------------------------------------------------
# A pen


def arrow(canvas, start, tip, progress: float, colour) -> None:
    """The first slide's red arrow, drawn as the pen would draw it."""
    if progress <= 0:
        return
    over = 3
    x0 = int(min(start[0], tip[0]) - 60)
    y0 = int(min(start[1], tip[1]) - 60)
    x1 = int(max(start[0], tip[0]) + 60)
    y1 = int(max(start[1], tip[1]) + 60)
    layer = Image.new("L", ((x1 - x0) * over, (y1 - y0) * over), 0)
    draw = ImageDraw.Draw(layer)

    def s(p):
        return ((p[0] - x0) * over, (p[1] - y0) * over)

    reach = max(140.0, start[1] - tip[1])
    dx = tip[0] - start[0]
    c1 = (start[0] + dx * 0.10, start[1] - reach * 0.44)
    c2 = (tip[0] - dx * 0.05, tip[1] + reach * 0.92)

    def at(t):
        u = 1 - t
        return (u**3 * start[0] + 3*u*u*t * c1[0] + 3*u*t*t * c2[0] + t**3 * tip[0],
                u**3 * start[1] + 3*u*u*t * c1[1] + 3*u*t*t * c2[1] + t**3 * tip[1])

    steps = 140
    spine = [at(i / steps) for i in range(steps + 1)]
    head_len = 34.0
    cut = steps
    while cut > 2 and math.dist(spine[cut], tip) < head_len:
        cut -= 1
    drawn = max(2, round(cut * clamp(progress / 0.85)))
    left, right = [], []
    for i in range(drawn + 1):
        ax, ay = spine[max(0, i - 1)]
        bx, by = spine[min(drawn, i + 1)]
        n = math.hypot(bx - ax, by - ay) or 1.0
        nx, ny = -(by - ay) / n, (bx - ax) / n
        w = 1.0 + 3.3 * (0.22 + 0.78 * math.sin(math.pi * i / cut) ** 0.5)
        x, y = spine[i]
        left.append(s((x + nx * w, y + ny * w)))
        right.append(s((x - nx * w, y - ny * w)))
    draw.polygon(left + right[::-1], fill=255)
    head = clamp((progress - 0.85) / 0.15)
    if head > 0:
        base = spine[cut]
        length = math.dist(base, tip) * head or 1.0
        ux, uy = (tip[0] - base[0]), (tip[1] - base[1])
        n = math.hypot(ux, uy) or 1.0
        ux, uy = ux / n, uy / n
        end = (base[0] + ux * length, base[1] + uy * length)
        flare = 10.0 * head
        draw.polygon([s(end), s((base[0] - uy * flare, base[1] + ux * flare)),
                      s((base[0] + ux * length * 0.34, base[1] + uy * length * 0.34)),
                      s((base[0] + uy * flare, base[1] - ux * flare))], fill=255)
    mask = layer.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    canvas.paste(Image.new("RGB", mask.size, colour), (x0, y0), mask)


# --------------------------------------------------------------------------
# Scenes. Each is a length and a function of the time since it began.


def enter(t, start=0.0, length=1.0):
    """How a screen arrives: from below, a little small, and settling."""
    p = out3(span(t, start, start + length))
    return p, (1 - p) * 240, 0.94 + 0.06 * p


class Scene:
    duration = 4.0
    ground = LIGHT

    def canvas(self, theme=None):
        return Image.new("RGB", (W, H), (theme or self.ground)["ground"])


class Hook(Scene):
    duration = 4.9
    ground = LIGHT

    def __init__(self, language):
        self.screen = shots.clean_status_bar(Image.open(shots.photograph_for(language, "feed-open")))
        for name, _, head, _, _, note in shots.SLIDES_V2[language]:
            if name == "feed-open":
                self.head, self.note = head, note
        self.hand = ImageFont.truetype(HAND, 56)

    def render(self, t):
        c = self.canvas()
        headline(c, self.head, LIGHT["ink"], t, 0.0)
        p, dy, sc = enter(t, 0.12, 1.1)
        drift = 1 + 0.025 * span(t, 0.8, self.duration + FADE)
        width = 560 * sc * drift
        top = 420 + dy - (drift - 1) * 560
        x, y, w, h = card(c, self.screen, W / 2, top, width, alpha=clamp(p * 1.6),
                          shade=LIGHT["shadow"], shade_strength=0.55)

        label, (u, v) = self.note
        tip = (x + u * w, y + v * h + 8)
        write = span(t, 1.55, 2.05)
        if write > 0:
            layer = Image.new("RGBA", (W, 110), LIGHT["mark"] + (0,))
            d = ImageDraw.Draw(layer)
            d.text((MARGIN + 6, 18), label, font=self.hand, fill=LIGHT["mark"] + (255,))
            box = d.textbbox((MARGIN + 6, 18), label, font=self.hand)
            reveal = Image.new("L", layer.size, 0)
            edge = box[0] + (box[2] - box[0] + 20) * out3(write)
            ImageDraw.Draw(reveal).rectangle((0, 0, edge, layer.height), fill=255)
            layer.putalpha(ImageChops.multiply(layer.getchannel("A"), reveal))
            c.paste(layer, (0, H - 150), layer)
            start = ((box[0] + box[2]) / 2 + 30, H - 150 + box[1] - 10)
            arrow(c, start, tip, inout(span(t, 1.95, 2.75)), LIGHT["mark"])
        return c


class Absent(Scene):
    duration = 4.5
    ground = DARK

    def __init__(self, language):
        self.head, self.sub, self.items = slides(language)["absent"]
        self.size = 68
        probe = ImageDraw.Draw(Image.new("L", (1, 1)))
        while self.size > 44 and max(probe.textlength(i, font=face(SERIF, self.size))
                                     for i in self.items) > W - 2 * MARGIN:
            self.size -= 2

    def render(self, t):
        c = self.canvas()
        headline(c, self.head, DARK["ink"], t, 0.0)
        serif = face(SERIF, self.size)
        top, step = 560, round(self.size * 1.75)
        draw = ImageDraw.Draw(c)
        for i, item in enumerate(self.items):
            appear = out3(span(t, 0.3 + 0.09 * i, 0.9 + 0.09 * i))
            strike = inout(span(t, 1.25 + 0.3 * i, 1.62 + 0.3 * i))
            dim = span(t, 1.62 + 0.3 * i, 2.0 + 0.3 * i)
            if appear <= 0:
                continue
            ink = mix(DARK["ink"], DARK["muted"], dim * 0.75)
            layer = Image.new("RGBA", (W, step), ink + (0,))
            d = ImageDraw.Draw(layer)
            d.text((MARGIN, 0), item, font=serif, fill=ink + (255,))
            box = d.textbbox((MARGIN, 0), item, font=serif)
            if strike > 0:
                y = round(box[1] + (box[3] - box[1]) * 0.52)
                x1 = box[0] - 6 + (box[2] - box[0] + 12) * strike
                d.rounded_rectangle((box[0] - 6, y - 2, x1, y + 2), radius=2, fill=DARK["ink"] + (255,))
            fade_paste(c, layer, (0, top + i * step + (1 - appear) * 26), appear)
        subline(c, self.sub, DARK["muted"], t, 2.9, top + len(self.items) * step + 40)
        return c


class Feed(Scene):
    duration = 3.5
    ground = DARK

    def __init__(self, language):
        self.head = slides(language)["feed"][0]
        self.screen = shots.clean_status_bar(Image.open(shots.photograph_for(language, "feed")))

    def render(self, t):
        c = self.canvas()
        headline(c, self.head, DARK["ink"], t, 0.0)
        p, dy, sc = enter(t, 0.05, 1.0)
        drift = 1 + 0.03 * span(t, 0.6, self.duration + FADE)
        card(c, self.screen, W / 2, CARD_TOP - 30 + dy, CARD_W * sc,
             alpha=clamp(p * 1.6), shade=(0, 0, 0), shade_strength=0.8,
             zoom=drift, focus=0.42)
        return c


class Limit(Scene):
    """The day running out, and the curtain."""

    duration = 7.0
    ground = LIGHT
    count_from, count_start, count_step = 9, 1.95, 0.27

    def __init__(self, language):
        self.words = strings(language)
        self.head = slides(language)["curtain"][0]
        self.panel = Panel(Image.open(shots.photograph_for(language, "record")), self.words)
        self.curtain = Image.open(shots.photograph_for(language, "curtain")).convert("RGB")
        self.spent_at = self.count_start + self.count_from * self.count_step
        self.drop = (self.spent_at + 0.5, self.spent_at + 1.35)

    def ticks(self):
        """When the line changes, for the soundtrack."""
        return [self.count_start + i * self.count_step for i in range(self.count_from + 1)]

    def render(self, t):
        fall = inout(span(t, *self.drop))
        theme = {k: mix(LIGHT[k], DARK[k], fall) for k in ("ground", "ink", "shadow")}
        c = Image.new("RGB", (W, H), theme["ground"])
        headline(c, self.head, theme["ink"], t, 0.0)

        n = len(self.panel.bars)
        grown = [out3(span(t, 0.55 + 0.11 * i, 1.25 + 0.11 * i)) for i in range(n)]
        if t < self.count_start:
            line = None
        else:
            step = int((t - self.count_start) / self.count_step)
            value = self.count_from - step
            line = self.words["left"](value) if value >= 1 else self.words["spent"]
        screen = self.panel.frame(grown, line)

        p, dy, sc = enter(t, 0.05, 1.0)
        drift = 1 + 0.02 * span(t, 0.8, self.drop[0])
        width = CARD_W * sc
        if fall > 0:
            curtain = screen.copy()
            h = curtain.height
            edge = round(h * fall)
            curtain.paste(self.curtain.crop((0, h - edge, curtain.width, h)), (0, 0))
            shade = Image.new("L", (curtain.width, 90), 0)
            for i in range(90):
                ImageDraw.Draw(shade).line((0, i, curtain.width, i), fill=round(70 * (1 - i / 90) ** 2 * (1 - fall)))
            if edge < h:
                curtain.paste((0, 0, 0), (0, edge), shade.crop((0, 0, curtain.width, min(90, h - edge))))
            screen = curtain
        settle = span(t, self.drop[1], self.duration + FADE)
        card(c, screen, W / 2, CARD_TOP + dy, width, alpha=clamp(p * 1.6),
             shade=theme["shadow"], shade_strength=0.55 + 0.25 * fall,
             zoom=drift + 0.05 * out3(settle), focus=0.45)
        return c


class Rule(Scene):
    duration = 4.5
    ground = LIGHT

    def __init__(self, language):
        self.head = slides(language)["settings"][0]
        limit = CAPTURES / f"limit-{language}-light.png"
        if limit.exists():
            self.screen = shots.clean_status_bar(Image.open(limit))
            self.focus = 0.40
        else:
            self.screen = Image.open(shots.photograph_for(language, "settings")).convert("RGB")
            self.focus = 0.50

    def render(self, t):
        c = self.canvas()
        headline(c, self.head, LIGHT["ink"], t, 0.0)
        p, dy, sc = enter(t, 0.05, 1.0)
        # The camera comes closer by the whole card growing, not by cropping
        # into it: the sentence that is the rule runs the full width of the
        # screen, and a crop cuts it off at both ends.
        near = inout(span(t, 1.1, 3.4))
        width = CARD_W * sc * (1 + 0.40 * near)
        height = width * self.screen.height / self.screen.width
        rest = CARD_TOP + dy
        closer = 1160 - self.focus * height
        card(c, self.screen, W / 2, rest + (closer - rest) * near, width,
             alpha=clamp(p * 1.6), shade=LIGHT["shadow"], shade_strength=0.55)
        return c


class Close(Scene):
    duration = 6.3
    ground = DARK

    def __init__(self, language):
        self.head = slides(language)["opening"][0]
        self.screen = Image.open(shots.photograph_for(language, "opening")).convert("RGB")
        bands, _, ground = band_rows(self.screen, 600, 2300)
        self.glass_ground = tuple(int(v) for v in ground)
        glass = next(b for b in bands if b[1] - b[0] > 60)
        a = np.asarray(self.screen).astype(int)
        cols = np.where((np.abs(a[glass[0]:glass[1] + 1] - ground).sum(2) > 40).any(0))[0]
        pad = 14
        self.glass_box = (cols[0] - pad, glass[0] - pad, cols[-1] + pad, glass[1] + pad)
        self.glass = self.screen.crop(self.glass_box)

        icon = Image.open(ICON).convert("RGB").resize((236, 236), Image.LANCZOS)
        self.icon = icon
        self.icon_mask = rounded((236, 236), round(236 * 0.2237))
        self.name = store_text(language, "name").split(":")[0] or "Quiet"
        self.subtitle = store_text(language, "subtitle")

    def turned(self, t) -> Image.Image:
        turn = inout(span(t, 0.9, 1.7)) * 180
        if turn <= 0:
            return self.screen
        image = self.screen.copy()
        glass = self.glass.rotate(-turn, resample=Image.BICUBIC, fillcolor=self.glass_ground)
        image.paste(glass, self.glass_box[:2])
        return image

    def render(self, t):
        c = self.canvas()
        out = inout(span(t, 3.05, 3.65))
        if out < 1:
            layer = self.canvas()
            headline(layer, self.head, DARK["ink"], t, 0.0)
            p, dy, sc = enter(t, 0.05, 1.0)
            card(layer, self.turned(t), W / 2, CARD_TOP + dy, CARD_W * sc,
                 alpha=clamp(p * 1.6), shade=(0, 0, 0), shade_strength=0.8,
                 zoom=1 + 0.03 * span(t, 0.8, 3.6), focus=0.5)
            c = Image.blend(c, layer, 1 - out) if out > 0 else layer

        if t > 3.3:
            k = t - 3.3
            pop = back(clamp(k / 0.7))
            a = clamp(k / 0.35)
            size = max(2, round(236 * (0.82 + 0.18 * pop)))
            icon = self.icon.resize((size, size), Image.LANCZOS)
            mask = rounded((size, size), round(size * 0.2237)).point(lambda v: round(v * a))
            cy = 760
            c.paste(icon, (round(W / 2 - size / 2), round(cy - size / 2)), mask)

            words = out3(span(k, 0.35, 1.05))
            wordmark = face(SERIF, 112, b"Bold")
            layer = Image.new("RGBA", (W, 160), DARK["ink"] + (0,))
            d = ImageDraw.Draw(layer)
            d.text((W / 2, 70), self.name, font=wordmark, fill=DARK["ink"] + (255,), anchor="mm")
            fade_paste(c, layer, (0, 930 + (1 - words) * 24), words)

            under = out3(span(k, 0.65, 1.35))
            layer = Image.new("RGBA", (W, 70), DARK["muted"] + (0,))
            d = ImageDraw.Draw(layer)
            d.text((W / 2, 35), self.subtitle, font=face(SANS, 38), fill=DARK["muted"] + (255,), anchor="mm")
            fade_paste(c, layer, (0, 1090 + (1 - under) * 16), under)
        return c


SCENES = [Hook, Absent, Feed, Limit, Rule, Close]


# --------------------------------------------------------------------------
# The film


def timeline(scenes):
    starts, at = [], 0.0
    for s in scenes:
        starts.append(at)
        at += s.duration - FADE
    return starts, at + FADE


def frame_at(scenes, starts, t):
    live = [(s, t - a) for s, a in zip(scenes, starts) if a <= t < a + s.duration]
    if len(live) == 1:
        return live[0][0].render(live[0][1])
    (first, t1), (second, t2) = live[-2], live[-1]
    p = inout(clamp(t2 / FADE))
    return Image.blend(first.render(t1), second.render(t2), p)


# --------------------------------------------------------------------------
# The sound. Quiet, as it should be: a pad that breathes, a tick for every
# minute the panel counts off, and the room going still when the curtain lands.


def soundtrack(length: float, marks: dict) -> np.ndarray:
    n = int(length * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(7)
    left = np.zeros(n)
    right = np.zeros(n)

    def hz(midi):
        return 440.0 * 2 ** ((midi - 69) / 12)

    def envelope(start, stop, attack, release):
        e = np.clip((t - start) / attack, 0, 1) * np.clip((stop - t) / release, 0, 1)
        return np.sin(e * np.pi / 2) ** 2

    # Four chords, slow. Fmaj9, Am7, Dm9, Bbmaj9 — then back to F for the name.
    chords = [[53, 60, 64, 67, 69], [57, 60, 64, 67, 71], [50, 57, 60, 64, 65],
              [46, 53, 57, 60, 62], [53, 60, 64, 67, 72]]
    curtain = marks["curtain"]
    edges = [0.0, 6.0, 11.5, curtain, marks["close"] + 3.0, length]
    for i, chord in enumerate(chords):
        a, b = edges[i], edges[i + 1] + 1.2
        env = envelope(a - 0.2, b, 1.6, 1.8)
        for j, m in enumerate(chord):
            f = hz(m)
            for detune, pan in ((-0.0025, 0.3), (0.0025, 0.7)):
                phase = rng.uniform(0, 2 * np.pi)
                wave_ = np.sin(2 * np.pi * f * (1 + detune) * t + phase)
                wave_ += 0.18 * np.sin(2 * np.pi * 2 * f * (1 + detune) * t + phase)
                trem = 1 + 0.12 * np.sin(2 * np.pi * (0.13 + 0.03 * j) * t + j)
                v = wave_ * env * trem * (0.05 if j == 0 else 0.03)
                left += v * (1 - pan)
                right += v * pan

    # After the curtain: the pad falls away almost to nothing, and comes back
    # for the name.
    duck = 1 - 0.85 * np.clip((t - curtain) / 0.6, 0, 1) * np.clip((marks["close"] + 3.3 - t) / 1.2, 0, 1)
    left *= duck
    right *= duck

    def pluck(at, midi, gain=0.16, pan=0.5, decay=1.6):
        s = int(at * RATE)
        if s >= n:
            return
        k = np.arange(n - s) / RATE
        f = hz(midi)
        v = (np.sin(2 * np.pi * f * k) + 0.35 * np.sin(2 * np.pi * 2 * f * k) * np.exp(-k * 5)
             + 0.12 * np.sin(2 * np.pi * 3 * f * k) * np.exp(-k * 9))
        v *= np.exp(-k / decay) * np.clip(k / 0.004, 0, 1) * gain
        left[s:] += v * (1 - pan)
        right[s:] += v * pan

    melody = [(0.25, 72), (0.55, 76), (4.55, 74), (8.7, 77), (8.95, 76)]
    for at, m in melody:
        pluck(at, m, 0.10, 0.4 + 0.2 * (m % 3) / 2)
    for at in marks["scenes"][1:]:
        pluck(at + 0.05, 84, 0.05, 0.62, 1.1)

    # A clock, one soft click per minute.
    for i, at in enumerate(marks["ticks"]):
        s = int(at * RATE)
        k = np.arange(int(0.03 * RATE)) / RATE
        click = rng.normal(0, 1, len(k)) * np.exp(-k * 380)
        click = np.convolve(click, np.ones(6) / 6, mode="same")
        body = np.sin(2 * np.pi * (2400 if i % 2 else 2000) * k) * np.exp(-k * 260)
        v = (click * 0.5 + body * 0.5) * 0.11
        left[s:s + len(v)] += v * 0.55
        right[s:s + len(v)] += v * 0.45

    # The curtain: air moving, then the softest landing.
    a, b = marks["drop"]
    s, e = int(a * RATE), int(b * RATE)
    noise = rng.normal(0, 1, e - s + int(0.4 * RATE))
    for _ in range(3):
        noise = np.convolve(noise, np.ones(24) / 24, mode="same")
    k = np.arange(len(noise)) / len(noise)
    swell = np.sin(np.pi * np.clip(k * 1.15, 0, 1)) ** 2 * 0.22
    left[s:s + len(noise)] += noise * swell
    right[s:s + len(noise)] += noise * swell * 0.9
    k = np.arange(int(1.8 * RATE)) / RATE
    thud = (np.sin(2 * np.pi * 58 * k) + 0.4 * np.sin(2 * np.pi * 87 * k)) * np.exp(-k * 3.2) * np.clip(k / 0.01, 0, 1) * 0.26
    s = int(b * RATE)
    left[s:s + len(thud)] += thud[: n - s]
    right[s:s + len(thud)] += thud[: n - s]

    # And the name: the chord, rung.
    at = marks["close"] + 3.3
    for j, m in enumerate([65, 69, 72, 76, 79]):
        pluck(at + 0.07 * j, m, 0.07, 0.3 + 0.1 * j, 2.6)

    # A room, by convolution with decaying noise — different on each side.
    def room(x, seed):
        r = np.random.default_rng(seed)
        m = int(2.4 * RATE)
        k = np.arange(m) / RATE
        ir = r.normal(0, 1, m) * np.exp(-k * 2.6)
        for _ in range(2):
            ir = np.convolve(ir, np.ones(4) / 4, mode="same")
        ir /= np.sqrt((ir ** 2).sum())
        size = 1 << int(np.ceil(np.log2(len(x) + m)))
        wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
        return 0.72 * x + 0.34 * wet

    left, right = room(left, 1), room(right, 2)
    fade = np.clip((length - t) / 1.4, 0, 1) * np.clip(t / 0.05, 0, 1)
    left *= fade
    right *= fade
    peak = max(np.abs(left).max(), np.abs(right).max())
    gain = 10 ** (-3 / 20) / peak
    return np.stack([left, right], 1) * gain


def write_wav(path: Path, samples: np.ndarray) -> None:
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def film(language: str, stills: bool = False) -> Path:
    scenes = [S(language) for S in SCENES]
    starts, length = timeline(scenes)
    folder = OUT / language
    folder.mkdir(parents=True, exist_ok=True)
    print(f"--- {language}: {length:.2f} s, {round(length * FPS)} frames")
    if not (15 <= length <= 30):
        sys.exit(f"  App Store Connect takes 15 to 30 seconds; this is {length:.2f}")

    if stills:
        moments = [a + s.duration * 0.72 for s, a in zip(scenes, starts)]
        moments.insert(4, starts[3] + scenes[3].spent_at - 0.8)
        frames = [frame_at(scenes, starts, m) for m in moments]
        sheet = Image.new("RGB", (len(frames) * 450, 960), (60, 60, 60))
        for i, f in enumerate(frames):
            sheet.paste(f.resize((443, 960), Image.LANCZOS), (i * 450, 0))
        sheet.save(folder / "stills.png")
        print(f"  {folder / 'stills.png'}")
        return folder / "stills.png"

    limit = scenes[3]
    marks = {
        "scenes": starts,
        "ticks": [starts[3] + x for x in limit.ticks()],
        "drop": (starts[3] + limit.drop[0], starts[3] + limit.drop[1]),
        "curtain": starts[3] + limit.drop[1],
        "close": starts[5],
    }
    audio = folder / "soundtrack.wav"
    write_wav(audio, soundtrack(length, marks))

    target = folder / "quiet-preview.mp4"
    ffmpeg = subprocess.Popen([
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(audio),
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
        "-preset", "slow", "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
        "-r", str(FPS), "-c:a", "aac", "-b:a", "256k", "-ar", str(RATE), "-ac", "2",
        "-shortest", "-movflags", "+faststart", str(target),
    ], stdin=subprocess.PIPE)
    total = round(length * FPS)
    for i in range(total):
        frame = frame_at(scenes, starts, i / FPS)
        ffmpeg.stdin.write(frame.tobytes())
        if i % 90 == 0:
            print(f"  {i:4d}/{total}", flush=True)
    ffmpeg.stdin.close()
    if ffmpeg.wait():
        sys.exit("ffmpeg failed")
    frame_at(scenes, starts, 0.9).save(folder / "poster.png")
    print(f"  {target}")
    return target


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    languages = list(shots.SLIDES_V2) if "--all" in sys.argv else (args or ["en", "de"])
    for language in languages:
        film(language, stills="--stills" in sys.argv)


if __name__ == "__main__":
    main()
