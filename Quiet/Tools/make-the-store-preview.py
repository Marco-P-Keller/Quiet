#!/usr/bin/env python3
"""Cut the App Store preview from the TikTok spot: 24.5 seconds, 886 x 1920.

    /usr/local/bin/python3.12 Tools/make-the-store-preview.py              # all five
    /usr/local/bin/python3.12 Tools/make-the-store-preview.py fr es        # these
    /usr/local/bin/python3.12 Tools/make-the-store-preview.py de --draft   # fast, no blur
    /usr/local/bin/python3.12 Tools/make-the-store-preview.py de --stills 0.8,9.9,23
    /usr/local/bin/python3.12 Tools/make-the-store-preview.py en --boost   # the other cut

Two cuts. `preview.html` is the spot's story, in five languages. `boost.html`
(`--boost`, English only so far) is built for conversion instead: the claim is
on screen at frame 0, which is also the poster, because a preview autoplays
muted and most people give it three seconds. Written to `<language>-boost/`.

The page is `Tools/store-preview/preview.html`, the spot re-cut for the store
(what changed, and why, is at the top of it). Everything around the page —
the captures, the countdown set in the app's face, the music and the effects
on the page's own cues — is `make-the-tiktok.py`'s, called from here, so the
two films cannot drift apart in anything but the words and the frame.

What App Store Connect takes, and what this writes:

- 886 x 1920, the portrait size for the 6.9- and 6.5-inch iPhone;
- 15 to 30 seconds, 30 fps at most;
- H.264 High Profile level 4.0 at about 11 Mbit/s, and a stereo AAC track —
  it refuses a preview with no audio track at all.

Written to `Tools/shots/out/store-preview/<language>/`: `quiet-app-preview.mp4`
to upload, and `poster.png`, the frame to pick as the poster in App Store
Connect (the name and what it is, 23 seconds in).
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PAGE = HERE / "store-preview" / "preview.html"
BOOST = HERE / "store-preview" / "boost.html"
OUT = HERE / "shots" / "out" / "store-preview"
STORE = HERE.parent.parent / "store"
LANGUAGES = ["en", "de", "fr", "es", "pt-BR"]
STORE_LOCALE = {"en": "en-US", "de": "de-DE", "fr": "fr-FR", "es": "es-ES", "pt-BR": "pt-BR"}
POSTER_AT = 23.0

_spec = importlib.util.spec_from_file_location("tiktok", HERE / "make-the-tiktok.py")
tiktok = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tiktok)
preview = tiktok.preview


# --------------------------------------------------------------------------
# Words. The app's own sentences where the app has one; the listing's terms
# (Reels, the rule, the privacy lines) where the listing already has them.

WORDS = {
    "en": {
        "pov": "11:04 pm",
        "hook": ["You were just going to", "check Instagram."],
        "suddenly": "…and suddenly it’s 1:37 am.",
        "slams": ["Reels.", "Explore.", "Suggested.", "“Just five\nmore minutes.”"],
        "without": ["Instagram.", "Without *Reels*."],
        "kept": "Your feed, your friends and\nyour messages stay.",
        "gone": "gone.",
        "limit": ["You set a", "daily limit."],
        "over": "Then it’s over.",
        "nomore": "No “five more minutes”.",
        "ruleTitle": "The one rule:",
        "less": "Less", "lessWhen": "right away.",
        "more": "More", "moreWhen": "next week.",
        "ruleWhy": "So you can’t bargain with it\nat 11 pm.",
        "privacy": ["No account.", "No tracking.", "No ads."],
    },
    "de": {
        "pov": "23:04",
        "hook": ["Du wolltest nur kurz", "Instagram checken."],
        "suddenly": "…und plötzlich ist es 1:37.",
        "slams": ["Reels.", "Explore.", "Vorschläge.", "„Nur noch\n5 Minuten.“"],
        "without": ["Instagram.", "Ohne *Reels*."],
        "kept": "Dein Feed, deine Freunde und\ndeine Nachrichten bleiben.",
        "gone": "weg.",
        "limit": ["Du legst ein", "Tageslimit fest."],
        "over": "Dann ist Schluss.",
        "nomore": "Kein „nur noch 5 Minuten“.",
        "ruleTitle": "Die eine Regel:",
        "less": "Weniger", "lessWhen": "gilt sofort.",
        "more": "Mehr", "moreWhen": "erst nächste Woche.",
        "ruleWhy": "Damit du dein Limit nicht\num 23 Uhr aufweichst.",
        "privacy": ["Kein Konto.", "Kein Tracking.", "Keine Werbung."],
    },
    "fr": {
        "pov": "23:04",
        "hook": ["Tu voulais juste", "checker Instagram."],
        "suddenly": "…et soudain, il est 1 h 37.",
        "slams": ["Reels.", "Explorer.", "Suggestions.", "« Encore cinq\nminutes. »"],
        "without": ["Instagram.", "Sans *Reels*."],
        "kept": "Ton fil, tes amis et\ntes messages restent.",
        "gone": "disparu.",
        "limit": ["Tu fixes une", "limite par jour."],
        "over": "Puis c’est fini.",
        "nomore": "Pas de « encore cinq minutes ».",
        "ruleTitle": "La seule règle :",
        "less": "Moins", "lessWhen": "tout de suite.",
        "more": "Plus", "moreWhen": "dans huit jours.",
        "ruleWhy": "Pour que tu ne puisses pas\nnégocier à 23 h.",
        "privacy": ["Pas de compte.", "Pas de pistage.", "Pas de pub."],
    },
    "es": {
        "pov": "23:04",
        "hook": ["Solo ibas a", "mirar Instagram."],
        "suddenly": "…y de repente es la 1:37.",
        "slams": ["Reels.", "Explorar.", "Sugerencias.", "«Solo cinco\nminutos más.»"],
        "without": ["Instagram.", "Sin *Reels*."],
        "kept": "Tu feed, tus amigos y\ntus mensajes se quedan.",
        "gone": "fuera.",
        "limit": ["Pones un", "límite diario."],
        "over": "Y se acabó.",
        "nomore": "Nada de «cinco minutos más».",
        "ruleTitle": "La única regla:",
        "less": "Menos", "lessWhen": "al instante.",
        "more": "Más", "moreWhen": "en una semana.",
        "ruleWhy": "Para que no puedas negociar\na las 11 de la noche.",
        "privacy": ["Sin cuenta.", "Sin rastreo.", "Sin anuncios."],
    },
    "pt-BR": {
        "pov": "23:04",
        "hook": ["Você só ia", "olhar o Instagram."],
        "suddenly": "…e de repente é 1:37 da manhã.",
        "slams": ["Reels.", "Explorar.", "Sugestões.", "“Só mais cinco\nminutinhos.”"],
        "without": ["Instagram.", "Sem *Reels*."],
        "kept": "Seu feed, seus amigos e\nsuas mensagens ficam.",
        "gone": "sumiu.",
        "limit": ["Você define um", "limite diário."],
        "over": "E acabou.",
        "nomore": "Nada de “só mais cinco minutos”.",
        "ruleTitle": "A única regra:",
        "less": "Menos", "lessWhen": "na hora.",
        "more": "Mais", "moreWhen": "em uma semana.",
        "ruleWhy": "Pra você não negociar\nàs 11 da noite.",
        "privacy": ["Sem conta.", "Sem rastreio.", "Sem anúncios."],
    },
}


def copy(language: str) -> dict:
    table = json.loads(preview.STRINGS.read_text())["strings"]
    xc = "en" if language == "en" else language

    def app(key):
        entry = table[key].get("localizations", {}).get(xc)
        return entry["stringUnit"]["value"] if entry else key

    words = dict(WORDS[language])
    words["opening"] = app("Instagram,\nminus the parts\nthat keep you there.")
    words["tagline"] = app("No more doomscrolling.")
    words["password"] = app("You sign in on Instagram's own page. Your password never touches Quiet.").split(". ")[-1]
    words["name"] = "Quiet"
    # where the spot says "On the App Store", the store says what the app is:
    # its own subtitle, so the last frame and the listing say the same thing
    words["cta"] = (STORE / STORE_LOCALE[language] / "subtitle.txt").read_text().strip()
    return words


# --------------------------------------------------------------------------


def boost_music(length: float, marks: dict):
    """The quiet groove from the first frame, the loud half only under the clock."""
    rate = tiktok.RATE
    k = tiktok.np.arange(int(length * rate)) / rate
    loud_at, cut = marks["loud"], marks["cut"]
    quiet = tiktok.music(length, {"cut": 0.0, "back": 0.0, "drop0": marks["drop0"],
                                  "drop1": marks["drop1"], "end": marks["end"]})
    loud = tiktok.music(length, {"cut": cut, "back": length + 1, "drop0": 0.0,
                                 "drop1": 0.0, "end": marks["end"]})
    # the loud half comes in on the cut to night and stops dead on the cut back
    loud *= ((k >= loud_at) & (k < cut))[:, None]
    hole = 1 - tiktok.np.clip((k - (loud_at - 0.08)) / 0.08, 0, 1) * tiktok.np.clip((cut + 0.3 - k) / 0.3, 0, 1)
    return loud + quiet * hole[:, None]


def render(language: str, draft: bool, stills: str | None, boost: bool = False) -> None:
    # the spot's assets, into this film's folder, with this film's words
    tiktok.OUT = OUT
    tiktok.copy = copy
    tiktok.assets(language)

    target = OUT / (f"{language}-boost" if boost else language)
    target.mkdir(parents=True, exist_ok=True)
    silent = target / "silent.mp4"
    page = BOOST if boost else PAGE
    command = ["node", str(HERE / "render-page.mjs"), f"{page}?lang={language}", str(silent),
               "--viewport", "1080x2340", "--size", "886x1920"]
    if stills:
        command += ["--stills", stills, "--scale", "1"]
    elif draft:
        command += ["--scale", "1", "--samples", "1"]
    else:
        command += ["--scale", "1.5"]
    print(f"--- {language}")
    subprocess.run(command, check=True)
    if stills:
        return

    cues = json.loads((target / "silent.cues.json").read_text())
    marks = {c["type"][5:]: c["t"] for c in cues if c["type"].startswith("mark:")}
    length = marks["end"] + 0.1
    fx = tiktok.effects(length, [c for c in cues if not c["type"].startswith("mark:")])
    track = target / "track.wav"
    music = boost_music(length, marks) if boost else tiktok.music(length, marks)
    tiktok.write_wav(track, music + fx * 0.8)

    film = target / "quiet-app-preview.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(silent), "-i", str(track),
        "-map", "0:v", "-map", "1:a",
        "-c:v", "libx264", "-preset", "slow", "-profile:v", "high", "-level", "4.0",
        "-b:v", "11M", "-maxrate", "12M", "-bufsize", "24M", "-pix_fmt", "yuv420p", "-r", "30",
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
        "-shortest", "-movflags", "+faststart", str(film),
    ], check=True)
    # the boost cut's poster is its first frame, on purpose
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "0" if boost else str(POSTER_AT), "-i", str(film),
                    "-frames:v", "1", str(target / "poster.png")], check=True)
    print(f"  {film}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    stills = None
    if "--stills" in sys.argv:
        stills = sys.argv[sys.argv.index("--stills") + 1]
        args = [a for a in args if a != stills]
    for language in args or LANGUAGES:
        render(language, "--draft" in sys.argv, stills, "--boost" in sys.argv)


if __name__ == "__main__":
    main()
