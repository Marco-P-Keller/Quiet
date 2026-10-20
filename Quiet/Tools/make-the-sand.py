#!/usr/bin/env python3
"""Sand: twenty-one seconds, one idea. The feed never ends; your time does.

    /usr/local/bin/python3.12 Tools/make-the-sand.py              # de and en
    /usr/local/bin/python3.12 Tools/make-the-sand.py de --draft   # 1x, no blur
    /usr/local/bin/python3.12 Tools/make-the-sand.py de --stills 1.5,4.8,7.5,11,16
    /usr/local/bin/python3.12 Tools/make-the-sand.py de --audio-only

1080 x 1920. The picture is `Tools/sand/sand.html`, photographed by
`Tools/render-page.mjs`; the rest is here.

A feed runs, faster and faster, and stops dead — the sound with it. Then it
comes apart into grains, and the grains pour into an hourglass: *the*
hourglass, Quiet's icon, every grain landing on a pixel of the icon's own sand
in the icon's own colour. The glass draws itself round them and the whole thing
shrinks into the icon.

The feed is not Instagram's and not anyone's: the posts are painted, soft
colour where photographs would be, so nothing in it belongs to somebody else.
The words claim only what the app does — a feed that ends, once a day.

Written to `Tools/shots/out/sand/<language>/`: `quiet-sand.mp4` with the score,
`quiet-sand-sfx.mp4` with the effects alone.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE / "shots" / "out" / "sand"


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


film = load("film", "make-the-film.py")
tiktok = film.tiktok
preview = film.preview
RATE = tiktok.RATE


# --------------------------------------------------------------------------
# Words


def copy(language: str) -> dict:
    lines = {
        "de": ["Der Feed endet nie.", "Deine Zeit schon.", "Quiet gibt ihm ein Ende."],
        "en": ["The feed never ends.", "Your time does.", "Quiet gives it one."],
    }[language]
    words = film.copy(language)
    return {"lines": lines, "name": "Quiet", "tagline": words["endTagline"], "store": words["store"]}


# --------------------------------------------------------------------------
# The glass and the sand, taken apart from the icon


SAND = np.array([213, 199, 174.0])
GLASS = np.array([242, 238, 231.0])
GROUND = 26.0
STEP = 2.2          # icon pixels between grains


def grow(mask: np.ndarray, size: int) -> np.ndarray:
    image = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(size))
    return np.asarray(image) > 127


def glyph(folder: Path) -> dict:
    icon = Image.open(preview.ICON).convert("RGB")
    assert icon.size == (1024, 1024)
    icon.save(folder / "icon.png")
    a = np.asarray(icon).astype(float)
    lum = a.mean(2)

    glass_core = lum >= 226
    zone = grow(glass_core, 7)
    sand_core = (lum > 150) & (lum < 226) & ~zone
    under = grow(sand_core, 13)
    edge = (lum > 35) & (lum <= 150) & ~zone

    # the sand, running on under the glass so that no seam shows between them
    sand = np.zeros((1024, 1024, 4))
    sand[..., :3] = SAND
    sand[sand_core, :3] = a[sand_core]
    alpha = np.zeros((1024, 1024))
    alpha[sand_core] = 1
    alpha[under & zone] = 1
    alpha[edge] = np.clip((lum[edge] - GROUND) / (SAND.mean() - GROUND), 0, 1)
    sand[..., 3] = alpha * 255
    Image.fromarray(sand.round().astype(np.uint8), "RGBA").save(folder / "sand.png")

    glass = np.zeros((1024, 1024, 4))
    glass[..., :3] = GLASS
    over = zone & under
    ga = np.zeros((1024, 1024))
    ga[zone] = np.clip((lum[zone] - GROUND) / (GLASS.mean() - GROUND), 0, 1)
    ga[over] = np.clip((lum[over] - SAND.mean()) / (GLASS.mean() - SAND.mean()), 0, 1)
    glass[..., 3] = ga * 255
    Image.fromarray(glass.round().astype(np.uint8), "RGBA").save(folder / "glass.png")

    # the waist: the row, between the bulbs, where the glass is narrowest
    solid = lum > 35
    rows = range(380, 660)
    width = [(np.nonzero(solid[y])[0].ptp() if solid[y].any() else 9999) for y in rows]
    neck_y = int(list(rows)[int(np.argmin(width))])
    xs = np.nonzero(solid[neck_y])[0]
    neck_x = float(xs.mean())
    ys = np.nonzero(solid.any(1))[0]

    # one grain for every pixel of sand, on a jittered grid
    rng = np.random.default_rng(5)
    grains = sand_core | (edge & (alpha > 0.5))
    upper, lower = [], []
    for gy in np.arange(0, 1024, STEP):
        for gx in np.arange(0, 1024, STEP):
            x, y = gx + rng.uniform(0, STEP), gy + rng.uniform(0, STEP)
            ix, iy = min(int(x), 1023), min(int(y), 1023)
            if not grains[iy, ix]:
                continue
            colour = a[iy, ix] if sand_core[iy, ix] else SAND
            entry = [round(x, 1), round(y, 1), *[int(v) for v in colour]]
            (upper if y < neck_y else lower).extend(entry)
    return {"neck": [neck_x, neck_y], "top": int(ys.min()), "bottom": int(ys.max()),
            "upper": upper, "lower": lower}


def assets(language: str) -> Path:
    folder = OUT / "assets" / language
    folder.mkdir(parents=True, exist_ok=True)
    shape = glyph(folder)
    rng = np.random.default_rng(3)
    Image.fromarray(rng.normal(128, 38, (512, 512)).clip(0, 255).astype(np.uint8)).save(folder / "grain.png")
    (folder / "data.js").write_text(
        "window.COPY = " + json.dumps(copy(language), ensure_ascii=False) + ";\n"
        + "window.GLYPH = " + json.dumps(shape, separators=(",", ":")) + ";\n"
    )
    print(f"  {len(shape['upper']) // 5 + len(shape['lower']) // 5} grains, waist at {shape['neck']}")
    return folder


# --------------------------------------------------------------------------
# The score. D minor while it runs; nothing at all when it stops; D major
# when it has an end.

piano, pad = film.piano, film.pad


def click_bank(n=24):
    bank = []
    for i in range(n):
        length = int(RATE * tiktok.rng.uniform(0.002, 0.006))
        k = tiktok.t_axis(length)
        x = tiktok.highpass(tiktok.rng.normal(0, 1, length), 2) * np.exp(-k * tiktok.rng.uniform(700, 1500))
        bank.append(x * tiktok.rng.uniform(0.3, 1.0))
    return bank


def whine(length, f0, f1):
    k = tiktok.t_axis(int(length * RATE))
    p = k / length
    return np.sin(2 * np.pi * np.cumsum(f0 + (f1 - f0) * p ** 2) / RATE) * p ** 2.5 * 0.05


def hiss(envelope_times, envelope, length):
    """Air with sand in it: noise shaped by how many grains are in flight."""
    n = int(length * RATE)
    k = tiktok.t_axis(n)
    level = np.interp(k, envelope_times, envelope, left=0, right=0)
    noise = tiktok.rng.normal(0, 1, n)
    x = tiktok.highpass(tiktok.smooth(noise, 4), 40) * 0.6 + tiktok.highpass(noise, 3) * 0.25
    return x * level


def score(length: float, marks: dict, cues: list) -> tuple[np.ndarray, np.ndarray]:
    freeze = marks["freeze"]

    # ---- the run: its own mix, so that it can be cut off with its reverb
    run = tiktok.Mix(length)
    run.add(0.0, pad([38, 45], freeze + 0.5, 2.0), 1.0)
    for at, note, v in ((marks["line1"], 69, 0.42), (marks["line1"] + 0.55, 65, 0.38), (marks["line1"] + 1.1, 62, 0.36)):
        run.add(at, piano(note, 3.0, v), 1.0, 0.45)
    feed = marks["feed"]
    run.add(feed + 0.4, tiktok.riser(freeze - feed - 0.4) * 0.55, 0.7)
    run.add(freeze - 1.8, whine(1.8, 2400, 3600), 0.7, 0.55)
    beat, t = 0.95, feed + 0.2
    while t < freeze:
        run.add(t, tiktok.kick(0.9), 0.32)
        run.add(t + 0.16, tiktok.kick(0.7), 0.18)
        t += beat
        beat = max(0.36, beat * 0.84)
    for cue in cues:
        if cue["type"] == "flick":
            run.add(cue["t"] - 0.05, tiktok.whoosh(0.28, True, 0.5 + 0.5 * cue["p"]), 0.35, 0.5)
        elif cue["type"] == "card":
            run.add(cue["t"], tiktok.tick(cue.get("high", False)), 0.35 + 0.35 * cue["p"], 0.5)
        elif cue["type"] == "ping":
            run.add(cue["t"], tiktok.pop(1.3 + 0.2 * cue["p"]), 0.3, cue["pan"])
    x = run.stereo()
    x[:, 0] = tiktok.room(x[:, 0], 1.6, 3, 0.3)
    x[:, 1] = tiktok.room(x[:, 1], 1.6, 4, 0.3)
    k = tiktok.t_axis(len(x))
    x *= np.clip((freeze - k) / 0.006, 0, 1)[:, None]        # and then nothing

    # ---- the sand
    m = tiktok.Mix(length)
    release, l2, l3, end = marks["release"], marks["line2"], marks["line3"], marks["shrink"]
    m.add(release, pad([38, 50, 57, 64, 65], l2 + 1.6 - release, 1.4), 1.0)
    m.add(release + 0.05, piano(50, 4.0, 0.34), 1.0, 0.4)
    m.add(release + 0.2, piano(57, 4.0, 0.3), 1.0, 0.55)
    for at, note in ((l2, 69), (l2 + 0.5, 67), (l2 + 1.0, 65), (l2 + 1.6, 64)):
        m.add(at, piano(note, 3.2, 0.42), 1.0, 0.5)
    m.add(l2 + 1.6, pad([46, 53, 58, 62, 65], 2.4, 0.8), 1.0)         # B-flat
    m.add(l2 + 3.4, pad([45, 53, 57, 60, 64], l3 - l2 - 3.0, 0.8), 1.0)  # F over A
    m.add(l2 + 3.4, piano(60, 3.0, 0.3), 1.0, 0.6)
    m.add(l3, pad([43, 50, 57, 62, 64], 1.5, 0.6), 1.0)                # G, suspended
    m.add(l3 + 1.25, pad([45, 52, 57, 61, 64], end - l3 - 0.9, 0.5), 1.0)  # A
    for at, note, v in ((l3, 62, 0.4), (l3 + 0.45, 64, 0.38), (l3 + 1.25, 61, 0.42)):
        m.add(at, piano(note, 3.0, v), 1.0, 0.5)
    for j, note in enumerate([38, 50, 57, 62, 66, 69, 74, 78]):
        m.add(end + 0.05 * j, piano(note, 5.5, 0.62), 1.0, 0.25 + 0.07 * j)
    m.add(end, pad([50, 57, 62, 66, 69], length - end, 0.6), 1.0)
    m.add(marks["name"], piano(78, 4.0, 0.34), 1.0, 0.6)
    m.add(marks["name"] + 0.6, piano(81, 4.0, 0.28), 1.0, 0.45)
    m.add(marks["tag"] + 0.3, piano(74, 4.0, 0.3), 1.0, 0.5)
    y = m.stereo()
    y[:, 0] = tiktok.room(y[:, 0], 3.0, 7, 0.5)
    y[:, 1] = tiktok.room(y[:, 1], 3.0, 8, 0.5)
    k = tiktok.t_axis(len(y))
    y *= (np.clip((k - release + 0.02) / 0.02, 0, 1) * np.clip((length - 0.05 - k) / 1.4, 0, 1))[:, None]
    return x, y


def effects(length: float, cues: list, marks: dict) -> np.ndarray:
    m = tiktok.Mix(length)
    bank = click_bank()
    lands = [c for c in cues if c["type"] == "land"]
    for i, cue in enumerate(lands):
        m.add(cue["t"], bank[i % len(bank)], 0.05 * cue.get("g", 1.0), cue["pan"])
    # the air the grains fall through, as loud as there are grains in it
    flight = next(c for c in cues if c["type"] == "flight")
    times, level = np.array(flight["t"]), np.array(flight["n"], float)
    level = np.sqrt(level / max(1.0, level.max()))
    air = hiss(times, level * 0.05, length)
    m.l += air
    m.r += np.roll(air, 97)
    m.add(marks["release"], tiktok.whoosh(1.4, True, 0.5), 0.3, 0.45)
    m.add(marks["shrink"] + 0.1, tiktok.whoosh(1.2, False, 0.4), 0.25, 0.5)
    fx = m.stereo()
    fx[:, 0] = tiktok.room(fx[:, 0], 1.2, 5, 0.25)
    fx[:, 1] = tiktok.room(fx[:, 1], 1.2, 6, 0.25)
    k = tiktok.t_axis(len(fx))
    fx *= (k >= marks["freeze"] + 0.3)[:, None]
    return fx


# --------------------------------------------------------------------------


def render(language: str, draft: bool, stills: str | None, audio_only: bool = False) -> None:
    print(f"--- {language}")
    assets(language)
    target = OUT / language
    target.mkdir(parents=True, exist_ok=True)
    page = f"{HERE / 'sand' / 'sand.html'}?lang={language}"
    silent = target / "silent.mp4"
    command = ["node", str(HERE / "render-page.mjs"), page, str(silent)]
    if stills:
        command += ["--stills", stills, "--scale", "1" if draft else "2"]
    elif draft:
        command += ["--scale", "1", "--samples", "1"]
    if not audio_only:
        subprocess.run(command, check=True)
    if stills:
        return

    cues = json.loads((target / "silent.cues.json").read_text())
    marks = {c["type"][5:]: c["t"] for c in cues if c["type"].startswith("mark:")}
    length = marks["stop"]
    run, music = score(length, marks, cues)
    fx = effects(length, cues, marks)
    tiktok.write_wav(target / "track.wav", run + music + fx)
    tiktok.write_wav(target / "sfx.wav", run * 0.5 + fx)
    for name, audio in (("quiet-sand.mp4", "track.wav"), ("quiet-sand-sfx.mp4", "sfx.wav")):
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
