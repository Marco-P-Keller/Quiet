#!/usr/bin/env python3
"""Cut the film: forty-three seconds of Quiet, shown the way a keynote shows a
feature.

    /usr/local/bin/python3.12 Tools/make-the-film.py              # de and en
    /usr/local/bin/python3.12 Tools/make-the-film.py de --draft   # 1x, no blur
    /usr/local/bin/python3.12 Tools/make-the-film.py de --stills 6.5,12.9,21.0
    /usr/local/bin/python3.12 Tools/make-the-film.py de --audio-only  # re-score the last film

1080 x 1920. The picture is `Tools/film/film.html`, photographed by
`Tools/render-page.mjs`; the rest is here.

**What it is made of is the app.** Every screen on the phone is a capture —
the feed, the row, the panel, the limit, the curtain, the opening — and every
movement *on* the screen is one the app makes: the tab bar's empty slot taking
the clock, the panel coming up, the limit screen pushed in and the wheel turned
on it, the day counting out and the curtain coming down. Where a moment has to
be rebuilt to be moved, it is rebuilt from the capture rather than drawn:

* the chart grows through `make-the-preview.py`'s `Panel`, which lifts the
  capture's own bars and puts them back a row of pixels at a time;
* the panel's first line is set in the face the app sets it in, fitted
  against the capture it replaces;
* the wheel is the capture with its rows taken out and put back on the same
  cylinder they were photographed on — 233 px radius, 21.9° a row, measured
  off `limit-<language>-light.png` — in the same face, size and two greys.

The words are Quiet's where Quiet has them, and none of them claims anything
the app does not do: suggestions are a switch, not gone, so the film says Reels
and Explore are gone and says nothing about suggestions.

Written to `Tools/shots/out/film/<language>/`: `quiet-film.mp4` with the score,
`quiet-film-sfx.mp4` with the effects alone for laying a licensed track under.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
OUT = HERE / "shots" / "out" / "film"
CAPTURES = HERE / "shots" / "capture"


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


tiktok = load("tiktok", "make-the-tiktok.py")
preview = tiktok.preview
shots = preview.shots

RATE = tiktok.RATE
K = 560 / 1320            # capture pixels to screen points on the film's phone
KF = 560 / 1179           # the same, for the 1179-wide photographs of the feed


# --------------------------------------------------------------------------
# Words


def copy(language: str) -> dict:
    table = json.loads(preview.STRINGS.read_text())["strings"]
    xc = "en" if language == "en" else language

    def app(key):
        entry = table[key].get("localizations", {}).get(xc)
        return entry["stringUnit"]["value"] if entry else key

    def phrase(n):
        entry = table["%lld minutes"]["localizations"].get(xc) or table["%lld minutes"]["localizations"]["en"]
        forms = entry["variations"]["plural"]
        return forms["one" if n == 1 else "other"]["stringUnit"]["value"].replace("%lld", str(n))

    text = {
        "de": {
            "open1": "Der Feed hört nie auf.",
            "open2": "Ab jetzt schon.",
            "f1Title": "Keine Reels.",
            "f1Sub": "Reels und Explore sind weg.\nFeed, Leute und Nachrichten bleiben.",
            "f1Cap": "Wo Reels war, ist jetzt deine Zeit.",
            "f2Title": "Sieh, was du\nzurückbekommst.",
            "f2Sub": "Ein Balken pro Tag. Dein Limit als Linie.",
            "f3Title": "Du bestimmst,\nwie lange.",
            "f3Sub": "Die Zeit zählt nur, solange\nInstagram vor dir ist.",
            "f4Title": "Dann ist Schluss.",
            "f4Sub": "Kein „nur noch fünf Minuten“.\nBis morgen, 4 Uhr.",
            "less": "Weniger", "lessWhen": "gilt sofort.",
            "more": "Mehr", "moreWhen": "erst nächste Woche.",
            "days": ["M", "D", "M", "D", "F", "S", "S"],
            "ruleWhy": "Entschieden von dir, der gerade nicht scrollt.",
            "privacy": ["Kein Konto.", "Kein Tracking.", "Keine Werbung."],
            "store": "Im App Store",
        },
        "en": {
            "open1": "The feed never ends.",
            "open2": "Until now.",
            "f1Title": "No Reels.",
            "f1Sub": "Reels and Explore are gone.\nYour feed, your people, your messages stay.",
            "f1Cap": "Where Reels was, your time is now.",
            "f2Title": "See the time\nyou get back.",
            "f2Sub": "A bar for every day. Your limit as a line.",
            "f3Title": "You decide\nhow long.",
            "f3Sub": "Time only counts while\nInstagram is in front of you.",
            "f4Title": "Then it’s over.",
            "f4Sub": "No “five more minutes”.\nUntil 4 am tomorrow.",
            "less": "Less", "lessWhen": "right away.",
            "more": "More", "moreWhen": "next week.",
            "days": ["M", "T", "W", "T", "F", "S", "S"],
            "ruleWhy": "Decided by the you who isn’t scrolling.",
            "privacy": ["No account.", "No tracking.", "No ads."],
            "store": "On the App Store",
        },
    }[language]
    text["tagline"] = app("Instagram,\nminus the parts\nthat keep you there.")
    text["endTagline"] = app("No more doomscrolling.")
    text["password"] = app("You sign in on Instagram's own page. Your password never touches Quiet.").split(". ")[-1]
    text["name"] = "Quiet"
    text["wheel"] = [phrase(n) for n in WHEEL]
    return text


WHEEL = [5, 10, 15, 20, 30, 45, 60, 90, 120]

# The wheel, measured off the capture (1320-wide pixels).
WHEEL_CENTER_Y = 1266
WHEEL_RADIUS = 233
WHEEL_STEP = 21.9
WHEEL_BAND = (111, 1219, 1209, 1315)
WHEEL_BLANK = (60, 1026, 1260, 1508)


# --------------------------------------------------------------------------
# Pictures


def clock_icon(feed_b: Image.Image) -> Image.Image:
    """The clock from Quiet's own row, lifted off its glass as ink and alpha."""
    crop = feed_b.convert("RGB").crop((540, 2352, 640, 2452))
    a = np.asarray(crop).astype(float)
    ground = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3)]), 0)
    lum = a.mean(2)
    alpha = np.clip((ground.mean() - lum) / (ground.mean() - 20), 0, 1)
    out = np.zeros((100, 100, 4), np.uint8)
    out[..., :3] = 0
    out[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def assets(language: str) -> Path:
    folder = OUT / "assets" / language
    folder.mkdir(parents=True, exist_ok=True)
    source = lambda name: Image.open(shots.photograph_for(language, name))  # noqa: E731

    feed_open = shots.clean_status_bar(source("feed-open"))
    feed_open.save(folder / "feed-open.png")
    feed_open.crop((0, 2318, 1179, 2445)).save(folder / "bar.png")
    clock_icon(source("feed-b")).save(folder / "clock.png")

    # the endless feed of the cold open, as in the spot
    pieces = [(source("feed"), 320, 2306), (source("feed-open"), 320, 2300),
              (source("feed-b"), 330, 2250), (source("feed-a"), 320, 2270)]
    strip = Image.new("RGB", (1179, sum(b - a for _, a, b in pieces)), "white")
    y = 0
    for image, a, b in pieces:
        strip.paste(image.convert("RGB").crop((0, a, 1179, b)), (0, y))
        y += b - a
    strip.save(folder / "feed-strip.jpg", quality=88)

    words = preview.strings(language)
    panel = preview.Panel(source("record"), words)
    n = len(panel.bars)
    frames = 16
    for j in range(frames):
        p = j / (frames - 1)
        grown = [preview.out3(preview.clamp(p * 1.7 - i * 0.12)) for i in range(n)]
        panel.frame(grown, None).save(folder / f"record-{j:02d}.png")
    full = [1.0] * n
    for m in range(1, 10):
        panel.frame(full, words["left"](m)).save(folder / f"panel-{m}.png")
    panel.frame(full, words["spent"]).save(folder / "panel-0.png")

    # the limit screen with its wheel lifted out, so the page can turn it
    limit_path = CAPTURES / f"limit-{language}-light.png"
    limit = shots.clean_status_bar(Image.open(limit_path))
    blank = limit.copy()
    ground = limit.getpixel((WHEEL_BLANK[0] - 20, WHEEL_BLANK[1] + 40))
    ImageDraw.Draw(blank).rectangle(WHEEL_BLANK, fill=ground)
    blank.save(folder / "limit-blank.png")

    source("curtain").convert("RGB").save(folder / "curtain.png")
    source("opening").convert("RGB").save(folder / "opening.png")
    Image.open(preview.ICON).convert("RGB").resize((512, 512), Image.LANCZOS).save(folder / "icon.png")
    rng = np.random.default_rng(3)
    Image.fromarray(rng.normal(128, 38, (512, 512)).clip(0, 255).astype(np.uint8)).save(folder / "grain.png")

    geometry = {
        "wheelCenterY": WHEEL_CENTER_Y, "wheelRadius": WHEEL_RADIUS, "wheelStep": WHEEL_STEP,
        "wheelBand": WHEEL_BAND, "wheelGround": [int(v) for v in ground[:3]],
        "headline": [int(panel.head_x), int(panel.head[0]), int(panel.head[1])],
        "chart": [int(v) for v in panel.chart], "bars": len(panel.bars),
    }
    (folder / "copy.js").write_text(
        "window.COPY = " + json.dumps(copy(language), ensure_ascii=False, indent=1) + ";\n"
        + "window.GEOMETRY = " + json.dumps(geometry) + ";\n"
    )
    return folder


# --------------------------------------------------------------------------
# The score. D major, 96 to the minute, a felt piano over a pulse — and, like
# the spot, one place where it all stops: the curtain.

BPM = 96
BEAT = 60 / BPM
BAR = 4 * BEAT


def piano(midi, length=2.5, velocity=0.6):
    k = tiktok.t_axis(int(length * RATE))
    f = tiktok.hz(midi)
    x = np.zeros(len(k))
    for n in range(1, 11):
        fn = n * f * np.sqrt(1 + 0.00035 * n * n)
        if fn > 12000:
            break
        amp = (1 / n ** 1.25) * (velocity ** (0.4 * (n - 1)))   # felt: soft blows have few partials
        x += amp * np.sin(2 * np.pi * fn * k + n) * np.exp(-k * (0.9 + 0.55 * n))
    hammer = tiktok.smooth(tiktok.rng.normal(0, 1, len(k)), 12) * np.exp(-k * 90) * 0.15
    env = np.clip(k / 0.004, 0, 1) * np.clip((length - k) / 0.25, 0, 1)
    return (x + hammer) * env * velocity * 0.22


def pad(midis, length, attack=1.2):
    k = tiktok.t_axis(int(length * RATE))
    x = np.zeros(len(k))
    for m in midis:
        f = tiktok.hz(m)
        for d in (-0.003, 0.003):
            for n in range(1, 6):
                x += np.sin(2 * np.pi * f * n * (1 + d) * k + n * 1.3 + d * 400) / n ** 1.6
    env = np.clip(k / attack, 0, 1) ** 2 * np.clip((length - k) / 1.0, 0, 1)
    return x * env * 0.018


def rim():
    k = tiktok.t_axis(int(0.08 * RATE))
    x = np.sin(2 * np.pi * 1750 * k) * np.exp(-k * 90) + tiktok.highpass(tiktok.rng.normal(0, 1, len(k)), 3) * np.exp(-k * 160) * 0.5
    return x * 0.16


def score(length: float, marks: dict) -> np.ndarray:
    m = tiktok.Mix(length)
    on, groove, curtain, rule, privacy, end = (marks[k] for k in ("screenOn", "groove", "curtain", "rule", "privacy", "end"))

    chords = [  # D(add9), A/C#, Bm7, Gmaj7
        [50, 57, 62, 64, 66], [49, 57, 61, 64, 69], [47, 54, 62, 66, 69], [43, 55, 59, 62, 66],
    ]

    # cold open: a low D held, two notes where the two lines land
    m.add(0.0, pad([38, 45], on + 0.5, 2.5), 1.0)
    m.add(marks["line1"], piano(74, 3.0, 0.45), 1.0, 0.45)
    m.add(marks["line2"], piano(69, 3.0, 0.5), 1.0, 0.55)
    m.add(marks["line2"] + 0.35, piano(62, 3.0, 0.4), 1.0, 0.5)

    # the reveal: air rising into the screen coming on, and the chord
    rise = on - 4.2
    m.add(4.2, tiktok.riser(rise) * 0.5, 0.6)
    m.add(on, tiktok.thud(0.6), 0.6)
    for j, note in enumerate([50, 57, 62, 66, 69, 74]):
        m.add(on + 0.03 * j, piano(note, 4.0, 0.62), 1.0, 0.3 + 0.08 * j)
    m.add(on, pad([50, 57, 62, 66], groove - on + 1.0, 0.8), 1.0)

    # the features: a pulse, an arpeggio, a bass; nothing but the pad and the
    # piano once the curtain has come down
    t, i = groove, 0
    while t < privacy + 0.01:
        chord = chords[i % 4]
        live = not (curtain - 0.3 <= t < rule)
        quiet_rule = rule <= t < privacy
        if live:
            m.add(t, pad(chord[1:], BAR + 0.8, 0.4), 0.8)
            m.add(t, tiktok.bass(chord[0] - 12, BAR * 0.95, 2.2), 0.24)
        if live and not quiet_rule:
            for b in range(4):
                m.add(t + b * BEAT, tiktok.kick(1.4), 0.3 if b % 2 == 0 else 0.17)
                m.add(t + b * BEAT + BEAT / 2, rim(), 0.55, 0.58)
                for s in range(2):
                    m.add(t + b * BEAT + s * BEAT / 2 + 0.01, tiktok.shaker(), 0.7 if s else 0.4, 0.62)
        pattern = [0, 2, 3, 4, 2, 3, 1, 3] if live else [0, 2, 4, 3]
        step = BAR / len(pattern)
        for s, idx in enumerate(pattern):
            note = chord[1 + idx % 4] + (12 if idx >= 3 else 0)
            m.add(t + s * step, piano(note, 1.6, 0.42 if s % 2 else 0.5), 1.5, 0.35 + 0.06 * (s % 5))
        t += BAR
        i += 1

    # the end: the tonic, rung open, and let go
    for j, note in enumerate([38, 50, 57, 62, 66, 69, 74, 78]):
        m.add(end + 0.04 * j, piano(note, 4.8, 0.66), 1.0, 0.25 + 0.07 * j)
    m.add(end, pad([50, 57, 62, 66, 69], marks["stop"] - end, 0.6), 1.0)

    x = m.stereo()
    x[:, 0] = tiktok.room(x[:, 0], 2.4, 7, 0.45)
    x[:, 1] = tiktok.room(x[:, 1], 2.4, 8, 0.45)
    k = tiktok.t_axis(len(x))
    x *= np.clip((marks["stop"] - k) / 1.2, 0, 1)[:, None]
    return x


def effects(length: float, cues: list) -> np.ndarray:
    m = tiktok.Mix(length)
    for cue in cues:
        at, kind = cue["t"], cue["type"]
        if kind == "tap":
            m.add(at, tiktok.tick(False) * 0.6, 0.8)
            m.add(at, tiktok.pop(0.8) * 0.5, 0.6)
        elif kind == "detent":
            m.add(at, tiktok.tick(True) * 0.5, 0.7, 0.5)
        elif kind == "slide":
            m.add(at - 0.1, tiktok.whoosh(0.4, True, 0.5), 0.35, 0.45)
        elif kind == "lift":
            m.add(at, tiktok.whoosh(0.5, True, 0.4), 0.35, 0.5)
        elif kind == "settle":
            m.add(at, tiktok.pop(1.25), 0.5, 0.5)
        elif kind == "tick":
            m.add(at, tiktok.tick(cue.get("high", False)), 0.7, 0.5)
        elif kind == "curtain":
            m.add(at, tiktok.whoosh(0.7, False, 0.8), 0.5)
        elif kind == "thud":
            m.add(at, tiktok.thud(0.7), 0.75)
        elif kind == "dot":
            m.add(at, tiktok.pop(0.9 + 0.05 * cue.get("i", 0)), 0.35, 0.4 + 0.03 * cue.get("i", 0))
        elif kind == "word":
            m.add(at, tiktok.pop(1.1), 0.25, 0.5)
    fx = m.stereo()
    fx[:, 0] = tiktok.room(fx[:, 0], 1.0, 5, 0.2)
    fx[:, 1] = tiktok.room(fx[:, 1], 1.0, 6, 0.2)
    return fx


# --------------------------------------------------------------------------


def render(language: str, draft: bool, stills: str | None, audio_only: bool = False) -> None:
    assets(language)
    target = OUT / language
    target.mkdir(parents=True, exist_ok=True)
    page = f"{HERE / 'film' / 'film.html'}?lang={language}"
    silent = target / "silent.mp4"
    command = ["node", str(HERE / "render-page.mjs"), page, str(silent)]
    if stills:
        command += ["--stills", stills, "--scale", "1" if draft else "2"]
    elif draft:
        command += ["--scale", "1", "--samples", "1"]
    print(f"--- {language}")
    if not audio_only:
        subprocess.run(command, check=True)
    if stills:
        return

    cues = json.loads((target / "silent.cues.json").read_text())
    marks = {c["type"][5:]: c["t"] for c in cues if c["type"].startswith("mark:")}
    length = marks["stop"] + 0.1
    fx = effects(length, [c for c in cues if not c["type"].startswith("mark:")])
    tiktok.write_wav(target / "track.wav", score(length, marks) + fx * 0.7)
    tiktok.write_wav(target / "sfx.wav", fx)
    for name, audio in (("quiet-film.mp4", "track.wav"), ("quiet-film-sfx.mp4", "sfx.wav")):
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(silent), "-i", str(target / audio),
            "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "slow", "-crf", "15",
            "-pix_fmt", "yuv420p", "-profile:v", "high", "-r", "30",
            "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "256k", "-ar", "48000",
            "-shortest", "-movflags", "+faststart", str(target / name),
        ], check=True)
        print(f"  {target / name}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    stills = None
    if "--stills" in sys.argv:
        stills = sys.argv[sys.argv.index("--stills") + 1]
        args = [a for a in args if a != stills]
    for language in args or ["de", "en"]:
        render(language, "--draft" in sys.argv, stills, "--audio-only" in sys.argv)


if __name__ == "__main__":
    main()
