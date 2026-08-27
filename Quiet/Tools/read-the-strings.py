#!/usr/bin/env python3
"""Every sentence in the app, in both languages.

    python3 Tools/read-the-strings.py

The app decided to be English and German, and that decision has a failure mode
nothing catches: a new sentence is written in Swift, Xcode adds it to the
catalogue with no German beside it, and it ships — in English, inside a German
app, on a screen nobody who wrote it ever reads in German. That has already
happened once in this project's history; the note in what-is-left describing
the fix is about exactly that class of bug.

So this asks four questions, and every one of them is a thing that has gone
wrong somewhere:

  1. Is every key translated into every language the catalogue claims?
  2. Is any entry marked as needing work — `new`, `needs_review`, or a stale
     `translated` with no value at all?
  3. Do the two languages agree about the format specifiers they carry? A
     German string that has lost its `%@` does not read oddly; it crashes, or
     silently prints the wrong thing.
  4. Does every entry with a plural rule carry that rule in both languages?
     Languages do not agree about how many plurals there are, and half a rule
     is worse than none.

It exits non-zero with a list, so CI can be the thing that notices rather than
somebody reading a screenshot.
"""

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
CATALOGUES = [
    HERE.parent / "Quiet" / "Resources" / "Localizable.xcstrings",
    HERE.parent / "Quiet" / "Resources" / "InfoPlist.xcstrings",
]

# What Xcode writes when a string has been added but not answered.
UNFINISHED = {"new", "needs_review", "stale"}

# `%@`, `%lld`, `%1$@` and friends. Not `%%`, which is a literal per cent.
SPECIFIER = re.compile(r"%(?:\d+\$)?[-+ #0]*[\d.*]*(?:ll|l|h|hh|z|t|q)?[@dioux X eEfgGcsp]")


def specifiers(text):
    """The format specifiers in a string, as a sorted list.

    Sorted rather than in order: a translation is allowed to move `%@` and
    `%lld` past each other, because word order is the whole reason positional
    specifiers exist. What it is not allowed to do is lose one or invent one.
    """
    return sorted(SPECIFIER.findall(text or ""))


def units(localisation):
    """Every string unit under one language, plural variations included."""
    found = []
    if "stringUnit" in localisation:
        found.append((None, localisation["stringUnit"]))
    variations = localisation.get("variations", {})
    for kind, cases in variations.items():
        for case, holder in cases.items():
            if "stringUnit" in holder:
                found.append((f"{kind}.{case}", holder["stringUnit"]))
    return found


def check(path):
    """Every complaint about one catalogue, as a list of strings."""
    if not path.exists():
        return [f"{path.name} is not there"]

    catalogue = json.loads(path.read_text(encoding="utf-8"))
    source = catalogue.get("sourceLanguage", "en")
    strings = catalogue.get("strings", {})

    # The languages this catalogue claims, taken from the catalogue rather than
    # written down here — so adding a third language is one edit, not two.
    languages = {source}
    for entry in strings.values():
        languages.update(entry.get("localizations", {}).keys())

    complaints = []
    for key, entry in sorted(strings.items()):
        localisations = entry.get("localizations", {})

        # A key that is its own English text needs no English entry, which is
        # how a string catalogue works and why this is not simply "every
        # language must be present".
        expected = languages - {source}
        if entry.get("shouldTranslate") is False:
            continue

        for language in sorted(expected):
            if language not in localisations:
                complaints.append(f"{key!r} has no {language}")
                continue

            # What the source says, case by case. Compared like for like,
            # because the singular of a plural rule is written out in words in
            # every language — "1 minute", "1 Minute" — and comparing that
            # against the plural's `%lld` would flag every correct rule in the
            # catalogue.
            source_by_case = {
                name: unit.get("value")
                for name, unit in units(localisations.get(source, {}))
            }

            for name, unit in units(localisations[language]):
                where = f"{key!r} [{language}{'/' + name if name else ''}]"
                state = unit.get("state")
                value = unit.get("value")
                if state in UNFINISHED:
                    complaints.append(f"{where} is marked {state}")
                if not value:
                    complaints.append(f"{where} is empty")
                    continue

                # The key is the English text for Localizable, so it stands in
                # when the catalogue carries no separate source entry. For
                # InfoPlist the key is a plist key and carries no specifiers,
                # so this only bites where it should.
                if name in source_by_case:
                    against = source_by_case[name]
                elif not source_by_case:
                    against = key
                else:
                    complaints.append(f"{where} has no {source} to be checked against")
                    continue

                if specifiers(against) and specifiers(value) != specifiers(against):
                    complaints.append(
                        f"{where} carries {specifiers(value)} "
                        f"where the source carries {specifiers(against)}"
                    )

            # Half a plural rule is worse than none: the language that has one
            # will use it and the one that does not will print the other
            # language's grammar.
            plural_here = "variations" in localisations[language]
            plural_elsewhere = any(
                "variations" in localisations.get(other, {})
                for other in localisations
            )
            if plural_elsewhere and not plural_here:
                complaints.append(f"{key!r} has a plural rule but {language} does not")

    return complaints


def main():
    trouble = []
    for path in CATALOGUES:
        found = check(path)
        print(f"{path.name}: {len(found)} to fix" if found else f"{path.name}: all good")
        trouble += [f"{path.name}: {line}" for line in found]

    if trouble:
        print()
        for line in trouble:
            print(f"  {line}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
