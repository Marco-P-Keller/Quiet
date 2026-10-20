#!/usr/bin/env python3
"""Cut the TikTok spot: 24 seconds, 1080 x 1920, loud and then quiet.

    /usr/local/bin/python3.12 Tools/make-the-tiktok.py            # de and en
    /usr/local/bin/python3.12 Tools/make-the-tiktok.py de --draft # fast, no blur
    /usr/local/bin/python3.12 Tools/make-the-tiktok.py de --stills 0.8,3.5,9.4

The animation itself is a web page, `Tools/tiktok/ad.html`, because a browser
is the best motion-graphics engine on this machine: real 3D, real type, real
compositing. `Tools/render-page.mjs` photographs it frame by frame in the
Chrome that is already installed, with a 180° shutter's worth of motion blur,
at twice the size and scaled down. This script does everything around that:

1. **Assets.** The same captures the store shots are cut from, cleaned the
   same way (`make-shots.py`), and the panel's countdown set in the app's own
   face (`make-the-preview.py`). Nothing on the phone is drawn by hand.
2. **The film**, silent, and the list of moments the page says make a sound.
3. **The sound**, written here: a beat for the loud half, a hard cut to
   nothing, and a slower groove for the quiet half — and the effects, placed on
   the page's own cues so they cannot drift from the picture.
4. **Two masters.** `quiet-tiktok.mp4` with that track, and
   `quiet-tiktok-sfx.mp4` with the effects alone — the one to take into TikTok
   Ads Manager or CapCut and lay a Commercial Music Library track under,
   which is what a spot on TikTok usually wants: a sound people already know.

Written to `Tools/shots/out/tiktok/<language>/`.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
TIKTOK = HERE / "tiktok"
OUT = HERE / "shots" / "out" / "tiktok"


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


preview = load("preview", "make-the-preview.py")
shots = preview.shots

RATE = 48000
BPM = 120
BEAT = 60 / BPM


# --------------------------------------------------------------------------
# Words. The app's own sentences where the app has one.


def copy(language: str) -> dict:
    table = json.loads(preview.STRINGS.read_text())["strings"]
    xc = "en" if language == "en" else language

    def app(key):
        entry = table[key].get("localizations", {}).get(xc)
        return entry["stringUnit"]["value"] if entry else key

    words = {
        "de": {
            "pov": "POV:",
            "hook": ["Du wolltest nur kurz", "Instagram checken."],
            "suddenly": "…und plötzlich ist es 1:37.",
            "slams": ["Reels.", "Explore.", "Vorschläge.", "„Nur noch\n5 Minuten.“"],
            "without": ["Instagram.", "Ohne *Reels*."],
            "gone": "weg.",
            "limit": ["Du legst ein", "Tageslimit fest."],
            "over": "Dann ist Schluss.",
            "nomore": "Kein „nur noch 5 Minuten“.",
            "ruleTitle": "Die eine Regel:",
            "less": "Weniger", "lessWhen": "gilt sofort.",
            "more": "Mehr", "moreWhen": "erst nächste Woche.",
            "ruleWhy": "Damit du dein Limit nicht\num 23 Uhr aufweichst.",
            "privacy": ["Kein Konto.", "Kein Tracking.", "Keine Werbung."],
            "cta": "Jetzt im App Store",
        },
        "en": {
            "pov": "POV:",
            "hook": ["You were just going to", "check Instagram."],
            "suddenly": "…and suddenly it’s 1:37 am.",
            "slams": ["Reels.", "Explore.", "Suggested.", "“Just five\nmore minutes.”"],
            "without": ["Instagram.", "Without *Reels*."],
            "gone": "gone.",
            "limit": ["You set a", "daily limit."],
            "over": "Then it’s over.",
            "nomore": "No “five more minutes”.",
            "ruleTitle": "The one rule:",
            "less": "Less", "lessWhen": "right away.",
            "more": "More", "moreWhen": "next week.",
            "ruleWhy": "So you can’t bargain with it\nat 11 pm.",
            "privacy": ["No account.", "No tracking.", "No ads."],
            "cta": "On the App Store",
        },
    }[language]
    words["opening"] = app("Instagram,\nminus the parts\nthat keep you there.")
    words["tagline"] = app("No more doomscrolling.")
    words["password"] = app("You sign in on Instagram's own page. Your password never touches Quiet.").split(". ")[-1]
    words["name"] = "Quiet"
    return words


# --------------------------------------------------------------------------
# Pictures


def assets(language: str) -> Path:
    folder = OUT / "assets" / language
    folder.mkdir(parents=True, exist_ok=True)
    source = lambda name: Image.open(shots.photograph_for(language, name))

    feed_open = shots.clean_status_bar(source("feed-open"))
    feed_open.save(folder / "feed-open.png")
    feed_open.crop((0, 0, 1179, 320)).save(folder / "feed-head.png")
    feed_open.crop((0, 2310, 1179, 2556)).save(folder / "feed-nav.png")

    # The feed as one long page, for the scroll that opens the film: the
    # stories and three posts, each cut between Instagram's own header and its
    # own tab bar, and cut short of anything that belongs to somebody else.
    pieces = [
        (source("feed"), 320, 2306),
        (source("feed-open"), 320, 2300),
        (source("feed-b"), 330, 2250),
        (source("feed-a"), 320, 2270),
    ]
    strip = Image.new("RGB", (1179, sum(b - a for _, a, b in pieces)), "white")
    y = 0
    for image, a, b in pieces:
        strip.paste(image.convert("RGB").crop((0, a, 1179, b)), (0, y))
        y += b - a
    strip.save(folder / "feed-strip.jpg", quality=92)

    words = preview.strings(language)
    panel = preview.Panel(source("record"), words)
    full = [1.0] * len(panel.bars)
    for n in (3, 2, 1):
        panel.frame(full, words["left"](n)).save(folder / f"panel-{n}.png")
    panel.frame(full, words["spent"]).save(folder / "panel-0.png")

    source("curtain").convert("RGB").save(folder / "curtain.png")
    source("opening").convert("RGB").save(folder / "opening.png")
    Image.open(preview.ICON).convert("RGB").resize((512, 512), Image.LANCZOS).save(folder / "icon.png")

    rng = np.random.default_rng(3)
    grain = rng.normal(128, 38, (512, 512)).clip(0, 255).astype(np.uint8)
    Image.fromarray(grain).save(folder / "grain.png")

    (folder / "copy.js").write_text(
        "window.COPY = " + json.dumps(copy(language), ensure_ascii=False, indent=1) + ";\n"
    )
    return folder


# --------------------------------------------------------------------------
# Sound
#
# Everything here is synthesis — no samples, nothing borrowed. The loud half is
# a four-on-the-floor at 120 with an arpeggio pushing it; it stops dead on the
# cut to the paper, because silence is the whole joke of the name. The quiet
# half is the same tempo with half the urgency: an electric piano, a lazy kick,
# a shaker.


def t_axis(n):
    return np.arange(n) / RATE


def smooth(x, width):
    width = max(1, int(width))
    kernel = np.hanning(width + 2)[1:-1]
    return np.convolve(x, kernel / kernel.sum(), mode="same")


def highpass(x, width):
    return x - smooth(x, width)


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.l = np.zeros(self.n)
        self.r = np.zeros(self.n)

    def add(self, at, mono, gain=1.0, pan=0.5):
        s = int(at * RATE)
        if s >= self.n or s + len(mono) <= 0:
            return
        a, b = max(0, s), min(self.n, s + len(mono))
        chunk = mono[a - s:b - s] * gain
        self.l[a:b] += chunk * np.sqrt(1 - pan)
        self.r[a:b] += chunk * np.sqrt(pan)

    def stereo(self):
        return np.stack([self.l, self.r], 1)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


rng = np.random.default_rng(11)


def kick(big=1.0):
    k = t_axis(int(0.5 * RATE))
    f = 54 + 120 * np.exp(-k * 38)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-k * (7 / big))
    click = highpass(rng.normal(0, 1, len(k)), 8) * np.exp(-k * 700) * 0.6
    return np.tanh((body + click) * 2.4) * 0.8


def clap():
    k = t_axis(int(0.35 * RATE))
    noise = rng.normal(0, 1, len(k))
    band = highpass(smooth(noise, 5), 40)
    env = np.zeros(len(k))
    for d in (0.0, 0.011, 0.022):
        env += np.exp(-np.clip(k - d, 0, None) * 60) * (k >= d)
    env += np.exp(-k * 14) * 0.35
    body = np.sin(2 * np.pi * 190 * k) * np.exp(-k * 40) * 0.3
    return (band * env + body) * 0.55


def hat(open_=False):
    k = t_axis(int((0.25 if open_ else 0.06) * RATE))
    x = highpass(rng.normal(0, 1, len(k)), 4)
    return x * np.exp(-k * (14 if open_ else 70)) * 0.22


def shaker():
    k = t_axis(int(0.09 * RATE))
    x = highpass(rng.normal(0, 1, len(k)), 6)
    env = np.sin(np.pi * np.clip(k / 0.09, 0, 1)) ** 3
    return x * env * 0.12


def bass(midi, length, drive=1.0):
    k = t_axis(int(length * RATE))
    f = hz(midi)
    x = np.sin(2 * np.pi * f * k) + 0.25 * np.sin(2 * np.pi * 2 * f * k)
    env = np.clip(k / 0.005, 0, 1) * np.clip((length - k) / 0.03, 0, 1)
    return np.tanh(x * drive) * env * 0.5


def pluck(midi, length=0.25, bright=6):
    k = t_axis(int(length * RATE))
    f = hz(midi)
    x = sum(np.sin(2 * np.pi * f * h * k) / h * np.exp(-k * bright * h) for h in range(1, 7))
    return x * np.clip(k / 0.003, 0, 1) * np.exp(-k * 9) * 0.35


def epiano(midi, length):
    k = t_axis(int(length * RATE))
    f = hz(midi)
    tine = np.sin(2 * np.pi * f * k + 0.9 * np.exp(-k * 6) * np.sin(2 * np.pi * f * 7 * k))
    body = 0.5 * np.sin(2 * np.pi * 2 * f * k) * np.exp(-k * 3)
    env = np.clip(k / 0.004, 0, 1) * np.exp(-k * 1.1) * np.clip((length - k) / 0.25, 0, 1)
    return (tine + body) * env * 0.24


def bell(midi, length=3.0):
    k = t_axis(int(length * RATE))
    f = hz(midi)
    x = np.sin(2 * np.pi * f * k + 2.2 * np.exp(-k * 1.6) * np.sin(2 * np.pi * f * 3.5 * k))
    return x * np.clip(k / 0.002, 0, 1) * np.exp(-k * 1.4) * 0.3


def whoosh(length=0.45, up=True, gain=1.0):
    k = t_axis(int(length * RATE))
    x = rng.normal(0, 1, len(k))
    lo, hi = smooth(x, 60), smooth(x, 6)
    p = k / length
    mix_ = p if up else 1 - p
    y = lo * (1 - mix_) + hi * mix_
    env = np.sin(np.pi * np.clip(p, 0, 1)) ** 2
    return y * env * 0.9 * gain


def riser(length):
    k = t_axis(int(length * RATE))
    p = k / length
    noise = rng.normal(0, 1, len(k))
    # the filter opens as it rises: dull air at the start, hiss at the top
    x = (highpass(noise, 30) * (1 - p) + highpass(noise, 3) * p) * p ** 2 * 0.5
    tone = np.sin(2 * np.pi * np.cumsum(220 + 880 * p ** 2) / RATE) * p ** 3 * 0.12
    return x + tone


def thud(gain=1.0):
    k = t_axis(int(1.6 * RATE))
    x = np.sin(2 * np.pi * np.cumsum(40 + 50 * np.exp(-k * 12)) / RATE) * np.exp(-k * 3)
    air = smooth(rng.normal(0, 1, len(k)), 30) * np.exp(-k * 9) * 0.6
    return np.tanh((x + air) * 1.4) * 0.8 * gain


def pop(pitch=1.0):
    k = t_axis(int(0.08 * RATE))
    f = (700 + 900 * np.exp(-k * 60)) * pitch
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-k * 45) * 0.35


def tick(high=False):
    k = t_axis(int(0.05 * RATE))
    x = np.sin(2 * np.pi * (2600 if high else 2100) * k) * np.exp(-k * 160)
    return (x + highpass(rng.normal(0, 1, len(k)), 3) * np.exp(-k * 500) * 0.4) * 0.3


def scribble(length):
    k = t_axis(int(length * RATE))
    x = highpass(rng.normal(0, 1, len(k)), 5)
    wobble = 0.55 + 0.45 * np.sin(2 * np.pi * 11 * k) ** 2
    return x * wobble * np.sin(np.pi * np.clip(k / length, 0, 1)) * 0.10


def room(x, seconds=1.8, seed=1, wet=0.25):
    r = np.random.default_rng(seed)
    m = int(seconds * RATE)
    k = np.arange(m) / RATE
    ir = smooth(r.normal(0, 1, m), 3) * np.exp(-k * (6.9 / seconds))
    ir /= np.sqrt((ir ** 2).sum())
    size = 1 << int(np.ceil(np.log2(len(x) + m)))
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return x + wet * tail


def music(length, marks) -> np.ndarray:
    """The loud half, the silence, the quiet half."""
    m = Mix(length)
    cut, back, dark0, dark1, end = marks["cut"], marks["back"], marks["drop0"], marks["drop1"], marks["end"]

    # ---- loud: three bars in A minor, A F G, pushing
    roots = [45, 41, 43]
    arp = [[57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67]]
    sixteenth = BEAT / 4
    t = 0.0
    while t < cut - 1e-6:
        bar = min(2, int(t // (4 * BEAT)))
        step = int(round(t / sixteenth))
        if step % 4 == 0:
            m.add(t, kick(), 0.7)
        if step % 8 == 4:
            m.add(t, clap(), 0.8, 0.52)
        m.add(t, hat(step % 4 == 2), 1.3 if step % 2 else 0.75, 0.62)
        if step % 4 == 2:
            m.add(t, bass(roots[bar], sixteenth * 1.8, 3.0), 0.6)
        note = arp[bar][(step * 3) % 4] + (12 if step % 8 >= 6 else 0)
        m.add(t, pluck(note, 0.22, 4), 1.0, 0.35 + 0.3 * ((step % 4) / 3))
        t += sixteenth
    # the last bar tightens: a clap roll into the cut
    roll = 4 * BEAT * 2
    t = roll
    while t < cut - 1e-6:
        speed = BEAT / 2 if t < roll + 2 * BEAT else BEAT / 4
        m.add(t, clap(), 0.35 + 0.4 * (t - roll) / (cut - roll), 0.45)
        t += speed
    loud = m.stereo()
    # sidechain: everything but the kick ducks on the beat
    k = t_axis(m.n)
    duck = 1 - 0.45 * np.exp(-((k % BEAT)) * 14)
    loud *= duck[:, None]
    loud[int(cut * RATE):] = 0          # the cut is a cut: no tail

    # ---- quiet: Fmaj7 Em7 Dm7 Cmaj7, laid back
    q = Mix(length)
    chords = [[53, 57, 60, 64, 67], [52, 55, 59, 62, 64], [50, 53, 57, 60, 64], [48, 52, 55, 59, 62]]
    bar_len = 4 * BEAT
    t, i = back, 0
    while t < end - 0.05:
        chord = chords[i % 4]
        hits = [(0.0, 1.0), (1.5 * BEAT, 0.6), (3.0 * BEAT, 0.45)]
        for off, g in hits:
            at = t + off
            if at >= end:
                continue
            for j, note in enumerate(chord[1:]):
                q.add(at + 0.012 * j, epiano(note + 12 * (j > 2), bar_len - off + 0.8), g, 0.35 + 0.1 * j)
        q.add(t, bass(chord[0] - 12, bar_len * 0.9, 2.0), 0.5)
        drums = not (dark0 <= t < dark1)
        if drums:
            q.add(t, kick(1.3), 0.55)
            q.add(t + 1.5 * BEAT, kick(1.3), 0.4)
            q.add(t + 2 * BEAT, clap(), 0.45, 0.5)
            for s in range(8):
                q.add(t + s * BEAT / 2 + 0.012 * (s % 2), shaker(), 0.8 if s % 2 else 0.45, 0.6)
        t += bar_len
        i += 1
    quiet = q.stereo()
    quiet[:, 0] = room(quiet[:, 0], 1.6, 3, 0.35)
    quiet[:, 1] = room(quiet[:, 1], 1.6, 4, 0.35)
    fade = np.clip((end - k) / 0.6, 0, 1)
    quiet *= fade[:, None]
    return loud * 0.85 + quiet * 0.55


def effects(length, cues) -> np.ndarray:
    m = Mix(length)
    for cue in cues:
        at, kind = cue["t"], cue["type"]
        if kind == "pop":
            m.add(at, pop(cue.get("pitch", 1.0)), 0.9, 0.5)
        elif kind == "whoosh":
            m.add(at - 0.18, whoosh(0.45, True, cue.get("gain", 1.0)), 0.55, 0.4)
        elif kind == "whip":
            m.add(at - 0.12, whoosh(0.3, True, 1.3), 0.7, 0.3)
        elif kind == "slam":
            m.add(at, thud(0.9), 0.8)
            m.add(at, clap(), 0.4)
        elif kind == "impact":
            m.add(at, thud(1.0), 1.0)
        elif kind == "riser":
            m.add(at, riser(cue["length"]), 0.55)
        elif kind == "roll":
            # the clock: ticks that speed up with the digits
            n, a, b = 38, at, at + cue["length"]
            for j in range(n):
                p = j / (n - 1)
                s = 0.5 - 0.5 * np.cos(np.pi * p)
                m.add(a + (b - a) * s, tick(j % 2 == 0), 0.35, 0.4 + 0.2 * (j % 2))
        elif kind == "tick":
            m.add(at, tick(cue.get("high", False)), 1.0, 0.5)
        elif kind == "bell":
            m.add(at, bell(76), 0.7, 0.45)
            m.add(at + 0.04, bell(83), 0.35, 0.55)
        elif kind == "scribble":
            m.add(at, scribble(cue["length"]), 1.0, 0.55)
        elif kind == "curtain":
            m.add(at, whoosh(0.6, False, 0.8), 0.6)
        elif kind == "thud":
            m.add(at, thud(0.7), 0.8)
        elif kind == "swell":
            m.add(at - 0.2, whoosh(0.6, True, 0.7), 0.5)
    fx = m.stereo()
    fx[:, 0] = room(fx[:, 0], 1.0, 5, 0.18)
    fx[:, 1] = room(fx[:, 1], 1.0, 6, 0.18)
    return fx


def write_wav(path: Path, x: np.ndarray) -> None:
    peak = np.abs(x).max() or 1.0
    x = np.tanh(x / peak * 1.2) / np.tanh(1.2) * 0.9
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# --------------------------------------------------------------------------


def render(language: str, draft: bool, stills: str | None) -> None:
    folder = assets(language)
    target = OUT / language
    target.mkdir(parents=True, exist_ok=True)
    page = f"{TIKTOK / 'ad.html'}?lang={language}"
    silent = target / "silent.mp4"
    command = ["node", str(HERE / "render-page.mjs"), page, str(silent)]
    if stills:
        command += ["--stills", stills, "--scale", "1" if draft else "2"]
    elif draft:
        command += ["--scale", "1", "--samples", "1"]
    print(f"--- {language}")
    subprocess.run(command, check=True)
    if stills:
        return

    cues = json.loads((target / "silent.cues.json").read_text())
    marks = {c["type"]: c["t"] for c in cues if c["type"].startswith("mark:")}
    marks = {k[5:]: v for k, v in marks.items()}
    length = marks["end"] + 0.1
    fx = effects(length, [c for c in cues if not c["type"].startswith("mark:")])
    write_wav(target / "track.wav", music(length, marks) + fx * 0.8)
    write_wav(target / "sfx.wav", fx)

    for name, audio in (("quiet-tiktok.mp4", "track.wav"), ("quiet-tiktok-sfx.mp4", "sfx.wav")):
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(silent), "-i", str(target / audio),
            "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "slow", "-crf", "16",
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
        render(language, "--draft" in sys.argv, stills)


if __name__ == "__main__":
    main()
