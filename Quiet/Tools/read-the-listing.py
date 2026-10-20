#!/usr/bin/env python3
"""Measure the listing, in every language, before anybody pastes it.

Everything in `store/` is text that goes into a field with a limit on it, and
every one of those limits is enforced at the far end by a form that truncates
or refuses. A subtitle of 31 characters is not a subtitle that looks slightly
long; it is a save button that does not work, found out in a browser tab at the
end of an afternoon rather than here in a second.

    python3 Tools/read-the-listing.py

Six things are checked, and the first two are the only ones a person would
think of:

1.  **The counts.** Name 30, subtitle 30, keywords 100, promotional text 170,
    description 4000 — Apple's, per localisation, characters not bytes. Accents
    matter here: `límite` is six characters and seven bytes, and counting the
    wrong one is how a field that fits is reported as one that does not.

2.  **A word bought twice.** Apple indexes the name and the subtitle as well as
    the keyword field, so a keyword that already appears in either is a slot
    spent on nothing. This is the cheapest ranking mistake there is and the
    hardest to see by reading.

3.  **A trademark in metadata.** Guideline 5.2.1. Factual reference to
    Instagram in the *description* is allowed and is all over it on purpose;
    the same word in the name, the subtitle or the keyword field is the fastest
    rejection this listing could buy. `reels` sat in the keyword field once.

4.  **Hard-wrapped paragraphs.** App Store Connect keeps every newline it is
    given. A description pasted out of a document wrapped at eighty columns
    renders as a ragged column of short lines on the product page, on every
    phone, for the life of the listing — and it looks exactly right in the text
    editor it was written in. So: one paragraph is one line, blank lines
    between.

5.  **The disclaimer.** Every description has to end saying the app is not
    affiliated with or endorsed by Instagram or Meta. It is half of the answer
    to 5.2.1 and it is one line to forget.

6.  **The finished screenshots**, if they have been composed: 1320 x 2868, no
    alpha channel, and not a rectangle of ground where a photograph should be.

Exits non-zero and says which field in which language.
"""

import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
STORE = HERE.parent.parent / "store"

# Everything in `store/` is a localisation except this one, which is a folder
# of folders: one per custom product page, each holding a promotional text per
# localisation. Checked, but not as a language.
CUSTOM = "custom-pages"
SLIDES = HERE / "shots" / "out" / "v2"

# Apple's, and they are characters rather than bytes or glyphs.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional-text": 170,
    "description": 4000,
}

ONE_LINE = ("name", "subtitle", "keywords", "promotional-text")

# Somebody else's marks. Checked in the three fields Apple treats as metadata
# and not in the description, where saying what the app is for requires the
# word.
MARKS = ("instagram", "insta", "reels", "meta", "facebook", "tiktok",
         "snapchat", "youtube", "whatsapp", "iphone", "apple")

# Both halves of the disclaimer, in the six languages the listing speaks. A
# description that names one and not the other is not the sentence Apple asks
# for.
DISCLAIMER = ("instagram", "meta")

TARGET = (1320, 2868)

# How many things the app keeps in the keychain, said in each language. This is
# the sentence that has now drifted twice: the app learned to remember one more
# thing and the pages went on saying the old number. `read-the-site.py` catches
# it in `privacy.html` and in the English listing; this catches it in the other
# thirty-eight, where nothing was looking at all.
#
# The count is read from `StoreKey` rather than typed here, so the only thing
# that needs maintaining is the word — and when the count changes, this fails
# loudly and says which word to change it to rather than passing quietly.
KEPT_IN_WORDS = {
    8: {
        "en-US": "eight", "en-GB": "eight", "en-AU": "eight", "en-CA": "eight",
        "de-DE": "acht", "nl-NL": "acht",
        "fr-FR": "huit", "fr-CA": "huit",
        "es-ES": "ocho", "es-MX": "ocho",
        "pt-BR": "oito", "pt-PT": "oito",
        "it": "otto", "ca": "vuit", "ro": "opt",
        "pl": "osiem", "cs": "osm", "sk": "osem", "hr": "osam",
        "ru": "восемь", "uk": "вісім",
        "sv": "åtta", "da": "otte", "no": "åtte", "fi": "kahdeksan",
        "hu": "nyolc", "tr": "sekiz", "el": "οκτώ",
        "ja": "8つ", "ko": "여덟", "zh-Hans": "八样", "zh-Hant": "八樣",
        "ar-SA": "ثمانية", "he": "שמונה", "hi": "आठ", "th": "แปด",
        "id": "delapan", "ms": "lapan", "vi": "tám",
        "sl-SI": "osem", "mr-IN": "आठ", "bn-BD": "আটটি", "gu-IN": "આઠ",
        "pa-IN": "ਅੱਠ", "ta-IN": "எட்டு", "te-IN": "ఎనిమిది", "kn-IN": "ಎಂಟು",
        "ml-IN": "എട്ട്", "or-IN": "ଆଠଟି", "ur-PK": "آٹھ",
    },
}

# Japanese, Korean, both Chinese and Thai do not put spaces between words, so
# the number has to be looked for as a substring there and as a whole word
# everywhere else.
SCRIPTLESS = {"ja", "ko", "zh-Hans", "zh-Hant", "th"}

STORAGE = HERE.parent / "Quiet" / "Core" / "Storage.swift"


def kept_in_the_keychain() -> int:
    """The number of `StoreKey` cases, which is the number every description
    has to agree with."""
    import re
    text = STORAGE.read_text(encoding="utf-8")
    block = re.search(r"enum StoreKey[^{]*\{(.*?)\n\}", text, re.DOTALL)
    if not block:
        return 0
    return len(re.findall(r"^\s*case\s+(\w+)", block.group(1), re.MULTILINE))


def read(path: Path) -> str:
    """The text as it will be pasted — trailing newlines are the file's, not
    the field's, and App Store Connect drops them."""
    return path.read_text(encoding="utf-8").rstrip("\n")


def folded(text: str) -> str:
    """Lowercase and stripped of accents, which is how a search field matches
    and how a duplicate hides: `limite` and `límite` are one word."""
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn")


def words(text: str) -> set:
    out = set()
    for piece in folded(text).replace(",", " ").replace(":", " ").split():
        piece = piece.strip(".,;:!?«»\"'’“”()")
        if len(piece) > 2:
            out.add(piece)
    return out


def check(locale: Path, complaints: list) -> dict:
    counts = {}
    fields = {}

    for field, limit in LIMITS.items():
        path = locale / f"{field}.txt"
        if not path.exists():
            complaints.append(f"{locale.name}: no {field}.txt")
            continue
        text = read(path)
        fields[field] = text
        counts[field] = len(text)

        if len(text) > limit:
            complaints.append(
                f"{locale.name}/{field}: {len(text)} characters, {limit} allowed "
                f"— {len(text) - limit} over")
        if field in ONE_LINE and "\n" in text:
            complaints.append(f"{locale.name}/{field}: has a line break in it")
        if not text.strip():
            complaints.append(f"{locale.name}/{field}: empty")

    # 2 and 3. The keyword field, which is where both the waste and the
    # rejection live.
    if "keywords" in fields:
        keywords = fields["keywords"]
        if " " in keywords:
            complaints.append(
                f"{locale.name}/keywords: has a space in it — Apple counts it "
                f"and indexes nothing for it")
        terms = [t for t in keywords.split(",")]
        if any(not t for t in terms):
            complaints.append(f"{locale.name}/keywords: an empty term (two commas)")
        seen = [folded(t) for t in terms if t]
        for term in set(seen):
            if seen.count(term) > 1:
                complaints.append(f"{locale.name}/keywords: '{term}' twice")

        elsewhere = words(fields.get("name", "")) | words(fields.get("subtitle", ""))
        for term in seen:
            if term in elsewhere:
                complaints.append(
                    f"{locale.name}/keywords: '{term}' is already in the name or "
                    f"subtitle, which Apple indexes anyway")

    for field in ("name", "subtitle", "keywords"):
        if field not in fields:
            continue
        low = folded(fields[field])
        for mark in MARKS:
            if mark in low:
                complaints.append(
                    f"{locale.name}/{field}: contains '{mark}' — a third-party "
                    f"mark in metadata is guideline 5.2.1")

    # 4 and 5. The description, which is the one field long enough to hide
    # something in.
    if "description" in fields:
        lines = fields["description"].split("\n")
        for number, line in enumerate(lines[:-1]):
            if line.strip() and lines[number + 1].strip():
                complaints.append(
                    f"{locale.name}/description: line {number + 1} is followed by "
                    f"another line of text — App Store Connect keeps every "
                    f"newline, so a paragraph has to be one line")
                break
        low = folded(fields["description"])
        for half in DISCLAIMER:
            if half not in low:
                complaints.append(
                    f"{locale.name}/description: never says '{half}' — the "
                    f"disclaimer is half the answer to 5.2.1")

    return counts


def check_the_count(locale: Path, kept: int, complaints: list) -> None:
    """Does this description say how many things the app keeps, and is it the
    number the app actually keeps?"""
    path = locale / "description.txt"
    if not path.exists():
        return
    words = KEPT_IN_WORDS.get(kept)
    if words is None:
        complaints.append(
            f"StoreKey has {kept} cases and this file only knows how to say "
            f"the numbers {sorted(KEPT_IN_WORDS)} — add a row to KEPT_IN_WORDS "
            f"and correct every description, which is the point of this check")
        return
    word = words.get(locale.name)
    if word is None:
        complaints.append(f"{locale.name}: no word for '{kept}' in KEPT_IN_WORDS")
        return
    # As a word, not as a substring, or the check passes on an accident: Dutch
    # `wachttijd` contains `acht`, Swedish and Norwegian have their own, and a
    # check that cannot fail is worse than no check. The scripts that do not
    # put spaces between words are matched as substrings, because there is no
    # boundary there to match on.
    import re
    haystack = folded(read(path))
    needle = folded(word)
    if locale.name in SCRIPTLESS:
        found = needle in haystack
    else:
        found = re.search(rf"(?<!\w){re.escape(needle)}(?!\w)", haystack) is not None
    if not found:
        complaints.append(
            f"{locale.name}/description: never says '{word}' — the app keeps "
            f"{kept} things in the keychain and the description has to say so")


def look_at_the_slides(complaints: list) -> dict:
    """What is composed, and whether it could be uploaded."""
    found = {}
    if not SLIDES.exists():
        return found
    try:
        from PIL import Image
    except ImportError:
        print("(Pillow is missing, so the slides were not looked at)")
        return found

    for folder in sorted(p for p in SLIDES.iterdir() if p.is_dir()):
        frames = sorted(folder.glob("*.png"))
        found[folder.name] = len(frames)

        # Numbered 1..n with nothing missing and nothing left over. A renamed
        # slide leaves its old file behind, the folder still looks like a set,
        # and what gets uploaded is nine frames in the wrong order.
        numbers = sorted(int(f.name.split("-")[0]) for f in frames
                         if f.name.split("-")[0].isdigit())
        # Two slides are held while the feed captures are of an older build
        # (`make-shots.py` says so in `held.txt`): six frames numbered 2 3 4 6 7 8
        # is then the set, not a set with files missing.
        held = (SLIDES / "held.txt").exists() and numbers == [2, 3, 4, 6, 7, 8]
        if held:
            found[folder.name] = len(frames)
        elif numbers != list(range(1, len(frames) + 1)):
            complaints.append(
                f"{folder.name}: {len(frames)} frames numbered {numbers} — a "
                f"renamed slide has left its old file behind")

        for frame in frames:
            image = Image.open(frame)
            where = f"{folder.name}/{frame.name}"
            if image.size != TARGET:
                complaints.append(
                    f"{where}: {image.size[0]} x {image.size[1]}, and App Store "
                    f"Connect takes {TARGET[0]} x {TARGET[1]} or nothing")
            if image.mode in ("RGBA", "LA", "P"):
                complaints.append(f"{where}: has an alpha channel, which is rejected")
            # `getcolors` answers None when there are more colours than it was
            # asked to count, which is the healthy case and reads as the empty
            # one. The first version of this check called every frame with a
            # photograph in it a frame without one.
            colours = image.convert("RGB").getcolors(maxcolors=4096)
            if colours is not None and len(colours) < 24:
                complaints.append(f"{where}: is nearly one colour — a frame that "
                                  f"was composed without its photograph")
    return found


# The order the sheet is written in, and the order to fill App Store Connect
# in. The first group is every localisation the *app* also speaks, so the store
# page and the screens behind it are in the same language; the rest are a store
# page in front of an app in English, which is a real trade and is said out
# loud in each of those descriptions.
SPOKEN = ["en-US", "en-GB", "en-AU", "en-CA", "de-DE", "es-ES", "es-MX",
          "fr-FR", "fr-CA", "pt-BR", "pt-PT"]

SHEET_HEADER = """# Every field, in every language

Generated by `Tools/read-the-listing.py --sheet` from the files in `store/`.
**Do not edit this file** — edit the `.txt` beside it and run the tool again.
The files are what counts; this is one place to read and copy them from.

Each field is followed by its character count and Apple's limit. Nothing here
is over.

"""


def sheet() -> str:
    """Everything in `store/`, in one document, in the order to paste it."""
    out = [SHEET_HEADER]
    locales = sorted(p for p in STORE.iterdir()
                     if p.is_dir() and p.name != CUSTOM)
    order = ([p for name in SPOKEN for p in locales if p.name == name] +
             [p for p in locales if p.name not in SPOKEN])

    out.append("The app itself speaks six languages. The listing speaks "
               f"{len(order)}.\n")
    out.append("* **In the app's own languages:** " +
               ", ".join(f"`{p.name}`" for p in order
                         if p.name in SPOKEN) + "\n")
    out.append("* **Store page only, app in English:** " +
               ", ".join(f"`{p.name}`" for p in order
                         if p.name not in SPOKEN) + "\n")

    for locale in order:
        spoken = "" if locale.name in SPOKEN else "  — app in English"
        out.append(f"\n---\n\n## {locale.name}{spoken}\n")
        for field, limit in LIMITS.items():
            path = locale / f"{field}.txt"
            if not path.exists():
                continue
            text = read(path)
            out.append(f"\n**{field}** — {len(text)}/{limit}\n")
            out.append(f"\n```\n{text}\n```\n")
    return "".join(out)


def main() -> int:
    if not STORE.exists():
        sys.exit(f"No {STORE}")

    if "--sheet" in sys.argv:
        into = STORE / "paste-sheet.md"
        into.write_text(sheet(), encoding="utf-8")
        print(f"{into.relative_to(STORE.parent)}  "
              f"{len(into.read_text(encoding='utf-8')):,} characters")

    complaints: list = []
    locales = sorted(p for p in STORE.iterdir()
                     if p.is_dir() and p.name != CUSTOM)
    if not locales:
        sys.exit(f"No localisations in {STORE}")

    kept = kept_in_the_keychain()
    if not kept:
        complaints.append("could not read the cases of StoreKey")

    table = {}
    for locale in locales:
        table[locale.name] = check(locale, complaints)
        if kept:
            check_the_count(locale, kept, complaints)

    header = f"{'':10}" + "".join(f"{field.split('-')[0][:6]:>10}"
                                  for field in LIMITS)
    print(header)
    print(f"{'':10}" + "".join(f"{'(' + str(limit) + ')':>10}"
                               for limit in LIMITS.values()))
    for name, counts in table.items():
        row = f"{name:10}"
        for field, limit in LIMITS.items():
            count = counts.get(field)
            row += f"{'—' if count is None else count:>10}"
        print(row)

    # The custom product pages. Only one customisable field on a custom page
    # has a limit on it — the name, subtitle, description and keywords all come
    # from the default page and cannot be changed — so this is a short check,
    # and it is the whole of what a file here can get wrong.
    pages = 0
    custom = STORE / CUSTOM
    if custom.is_dir():
        known = {p.name for p in locales}
        for page in sorted(p for p in custom.iterdir() if p.is_dir()):
            pages += 1
            for path in sorted(page.glob("*.txt")):
                text = read(path)
                if path.stem not in known:
                    complaints.append(
                        f"{CUSTOM}/{page.name}/{path.name}: '{path.stem}' is "
                        f"not one of the localisations in store/")
                if len(text) > LIMITS["promotional-text"]:
                    complaints.append(
                        f"{CUSTOM}/{page.name}/{path.name}: {len(text)} "
                        f"characters, {LIMITS['promotional-text']} allowed")
                if "\n" in text:
                    complaints.append(
                        f"{CUSTOM}/{page.name}/{path.name}: has a line break")

    slides = look_at_the_slides(complaints)
    if slides:
        print()
        print("slides:   " + "  ".join(f"{k} {v}" for k, v in slides.items()))
    if pages:
        print(f"custom:   {pages} product pages, "
              f"{35 - pages} of Apple's 35 still free")

    print()
    if complaints:
        for complaint in complaints:
            print(f"  ✗ {complaint}")
        print(f"\n{len(complaints)} to fix.")
        return 1
    print(f"{len(locales)} localisations, every field inside its limit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
