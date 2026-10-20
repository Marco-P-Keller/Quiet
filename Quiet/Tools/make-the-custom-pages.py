#!/usr/bin/env python3
"""The screenshot sets for the custom product pages.

App Store Connect allows thirty-five custom product pages. Each one has its own
screenshots, its own app previews, its own promotional text and **its own URL**
— and nothing else: the name, the subtitle, the description, the keywords and
the icon all come from the default page and cannot be changed. So a custom page
is not another listing. It is the same listing with a different first slide.

That is worth more than it sounds. Somebody arriving from a post about not
being able to stop at eleven at night and somebody arriving from a search for
"does any of this actually work" are asking different questions, and the
default page has to answer both with one opening frame. A custom page answers
one of them with its first three.

    python3 Tools/make-the-custom-pages.py

Reads the finished slides from `shots/out/v2/<language>/` and writes reordered
copies to `shots/out/cpp/<page>/<language>/`, renumbered so that dragging a
folder into App Store Connect puts them in the intended order. Nothing is
redrawn: run `make-shots.py v2` first, and these are the same eight files.

**The URL is issued, not constructed.** App Store Connect gives each page a
`ppid` when you create it — `https://apps.apple.com/…/id<app>?ppid=<uuid>`. It
cannot be guessed or written down in advance, which is why there is no table of
them here. Create the page, copy the URL it hands you, and put that under the
post or into the Search Ads ad group.
"""

import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V2 = HERE / "shots" / "out" / "v2"
OUT = HERE / "shots" / "out" / "cpp"

# The eight slides, by the name each capture has, in the order the default page
# swipes through them. Every page below is a permutation of exactly this list —
# no slide is dropped, because a slide dropped from a custom page is an
# argument the reader does not get to hear, and the argument is the same one.
DEFAULT = ["feed-open", "curtain", "settings", "absent",
           "feed", "record", "setup", "opening"]

# What each page leads with, and who is arriving.
#
# The rule for the order is that the **first three carry the decision** — that
# is what a search result shows and what somebody swipes before deciding — and
# that the remaining five still read as an argument rather than as leftovers.
PAGES = {
    # Somebody who knows exactly what their problem is: they cannot stop in the
    # evening. Lead with the day ending, then why the rule holds, then a month
    # of it. The answer to "will this actually stop me" in three frames.
    "the-day-ends": [
        "curtain", "settings", "record", "feed-open",
        "absent", "feed", "setup", "opening",
    ],

    # Somebody who has already installed a blocker and deleted it. They are not
    # asking what it is; they are asking whether it works. So: the record
    # first, the asymmetric rule second, the day ending third.
    "does-it-work": [
        "record", "settings", "curtain", "feed-open",
        "feed", "absent", "setup", "opening",
    ],

    # Somebody who wants to scroll less and is afraid of losing the thing
    # itself. The default page opens on what has been taken out; this one opens
    # on what is still there and gets to the limit fourth.
    "still-your-instagram": [
        "feed", "feed-open", "absent", "curtain",
        "settings", "record", "setup", "opening",
    ],

    # The page to put under a post on Hacker News or r/nosurf, where the first
    # question is who is watching. No account, no tracking, then the whole
    # trade stated up front, and only then the product.
    "nothing-kept": [
        "opening", "setup", "feed-open", "curtain",
        "absent", "feed", "settings", "record",
    ],
}


def main() -> int:
    if not V2.is_dir():
        sys.exit(f"No slides in {V2}. Run: python3 Tools/make-shots.py v2")

    languages = sorted(p.name for p in V2.iterdir() if p.is_dir())
    if not languages:
        sys.exit(f"No language folders in {V2}")

    for page, order in PAGES.items():
        missing = sorted(set(order) ^ set(DEFAULT))
        if missing:
            sys.exit(f"{page}: {', '.join(missing)} — a page has to be a "
                     f"permutation of the eight, not a selection.")
        print(f"{page}:  {' → '.join(order[:3])} …")
        for language in languages:
            source = V2 / language
            found = {p.name.split("-", 1)[1][:-4]: p for p in source.glob("*.png")}
            folder = OUT / page / language
            folder.mkdir(parents=True, exist_ok=True)
            # Emptied first: a renamed or reordered slide otherwise leaves its
            # old file behind and the folder somebody uploads from has nine.
            for stale in folder.glob("*.png"):
                stale.unlink()
            for index, stem in enumerate(order, 1):
                if stem not in found:
                    sys.exit(f"  {language}: no slide called {stem}")
                shutil.copy2(found[stem], folder / f"{index}-{stem}.png")
            print(f"  {folder.relative_to(HERE)}  {len(order)} slides")

    print(f"\n{len(PAGES)} pages x {len(languages)} languages. "
          f"Apple allows 35 pages in all.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
