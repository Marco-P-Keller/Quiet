#!/usr/bin/env python3
"""The published pages, against the app they describe.

    python3 Tools/read-the-site.py

`site/privacy.html` is the one document in this project that is a promise to a
stranger rather than a note to whoever comes next. It is also the document
furthest from the code: nothing imports it, nothing renders it, and no test has
ever opened it. So it drifts, silently, and the way it drifts is always the
same — the app learns to remember one more thing and the page still says four.

That is exactly what happened. The keychain went from four keys to five when
there was a way out to remember, and to six when the other phones arrived, and
through both of those the page went on saying four. A privacy policy that
undercounts what an app stores is not a stale document; it is the wrong answer
to the only question App Review asks it.

So the page is checked against the source of truth, which is `StoreKey`:

  1. Does the page's sentence — "Quiet keeps N things" — say the number of
     cases `StoreKey` actually has?
  2. Does the list under it have that many entries?
  3. Do the pages still say the things that must not quietly disappear — that
     the sync is off until asked for, that there is a way out, that the
     reminder exists?

And so is the **store description**, which carries the same number and drifted
in exactly the same way while this file watched the page beside it. It said
four long after the answer was six — on the App Store product page, which is
the sentence somebody reads before installing rather than after. It is the more
expensive of the two places to be wrong and it was the one nothing read.

What this cannot check is whether the sentences are *true*. Nothing can. It
checks the one kind of wrong that has already happened twice and would happen
again, and it costs a second.
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
STORAGE = HERE.parent / "Quiet" / "Core" / "Storage.swift"
SITE = HERE.parent.parent / "site"
LISTING = HERE.parent.parent / "docs" / "store-listing.md"

# Only as far as anybody would ever write one of these out in a sentence.
NUMBERS = {
    1: "one",
    2: "two",
    3: "three",
    4: "four",
    5: "five",
    6: "six",
    7: "seven",
    8: "eight",
    9: "nine",
    10: "ten",
}

# Sentences that carry a promise rather than a description. Each one is here
# because losing it would leave the pages saying something narrower than the
# truth, which for a privacy policy is the expensive direction.
#
# Matched loosely — a phrase, not a paragraph — so that the prose can be
# rewritten without this becoming a reason not to. Against the page with its
# whitespace run together, because a sentence in an HTML file wraps wherever
# the column ran out, and a phrase that straddles a line break is still the
# phrase.
MUST_SAY = [
    ("privacy.html", r"off until you (?:switch|turn) it on", "that the sync is opt-in"),
    ("privacy.html", r"your own iCloud", "where the sync goes"),
    ("privacy.html", r"[Ff]orget everything", "that there is a way out"),
    ("privacy.html", r"notification a day", "the daily reminder"),
    ("privacy.html", r"[Cc]amera", "the camera declaration"),
    ("support.html", r"[Cc]arry it between my devices", "how to reach the sync"),
    ("support.html", r"forget everything", "how to leave"),
]


def keys_in_source() -> list[str]:
    """The cases of `StoreKey`, in the order they are written."""
    text = STORAGE.read_text(encoding="utf-8")
    block = re.search(
        r"enum StoreKey[^{]*\{(.*?)\n\}", text, re.DOTALL
    )
    if not block:
        return []
    return re.findall(r"^\s*case\s+(\w+)", block.group(1), re.MULTILINE)


def keychain_list(html: str) -> tuple[str | None, int | None]:
    """The number the page says in words, and the length of the list under it."""
    html = re.sub(r"\s+", " ", html)
    said = re.search(r"Quiet keeps (\w+) things", html)
    listed = None
    if said:
        rest = html[said.end():]
        block = re.search(r"<ul>(.*?)</ul>", rest, re.DOTALL)
        if block:
            listed = len(re.findall(r"<li>", block.group(1)))
    return (said.group(1) if said else None), listed


def main() -> int:
    problems: list[str] = []

    keys = keys_in_source()
    if not keys:
        problems.append(f"{STORAGE.name}: could not find the cases of StoreKey.")

    privacy = SITE / "privacy.html"
    if not privacy.exists():
        problems.append(f"{privacy}: not there.")
    elif keys:
        html = privacy.read_text(encoding="utf-8")
        said, listed = keychain_list(html)
        want = NUMBERS.get(len(keys), str(len(keys)))
        if said is None:
            problems.append(
                "privacy.html: no sentence saying how many things are kept. "
                'It should read "Quiet keeps %s things".' % want
            )
        elif said != want:
            problems.append(
                'privacy.html says "Quiet keeps %s things"; StoreKey has %d: %s.'
                % (said, len(keys), ", ".join(keys))
            )
        if listed is None:
            problems.append("privacy.html: no list under that sentence.")
        elif listed != len(keys):
            problems.append(
                "privacy.html lists %d things; StoreKey has %d: %s."
                % (listed, len(keys), ", ".join(keys))
            )

    # The same number, in the other document that carries it. The listing
    # writes it as prose rather than as a list, so only the sentence is
    # checked — but the sentence is the whole of what went wrong.
    if keys:
        if not LISTING.exists():
            problems.append(f"{LISTING.name}: not there.")
        else:
            flat = re.sub(r"\s+", " ", LISTING.read_text(encoding="utf-8"))
            said = re.search(r"(\w+) things are kept, on your phone", flat)
            want = NUMBERS.get(len(keys), str(len(keys)))
            if said is None:
                problems.append(
                    "store-listing.md: the description no longer says how many "
                    'things are kept. It should read "%s things are kept, on '
                    'your phone".' % want.capitalize()
                )
            elif said.group(1).lower() != want:
                problems.append(
                    'store-listing.md says "%s things are kept"; StoreKey has '
                    "%d: %s." % (said.group(1), len(keys), ", ".join(keys))
                )

    for name, pattern, what in MUST_SAY:
        page = SITE / name
        if not page.exists():
            problems.append(f"{name}: not there.")
            continue
        flat = re.sub(r"\s+", " ", page.read_text(encoding="utf-8"))
        if not re.search(pattern, flat):
            problems.append(f"{name}: nothing about {what}.")

    if problems:
        print("The site and the app disagree:\n")
        for problem in problems:
            print(f"  {problem}")
        print()
        return 1

    print(
        f"The site: all good ({len(keys)} keys, and the pages "
        "and the listing say so)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
