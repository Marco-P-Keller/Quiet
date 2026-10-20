# Everything that gets pasted into App Store Connect

**Fifty localisations** — every one App Store Connect offers — five fields
each, and nothing in any of them is longer than the field it goes into. The
last eleven (`sl-SI`, `mr-IN`, `bn-BD`, `gu-IN`, `pa-IN`, `ur-PK`, `ta-IN`,
`te-IN`, `kn-IN`, `ml-IN`, `or-IN`) were added in October 2026 and are listed
at the foot of this file. That is checked rather than believed:

    python3 Quiet/Tools/read-the-listing.py

[`paste-sheet.md`](paste-sheet.md) is all of it in one document, in the order to
paste it, with a character count under every field. It is **generated** from the
`.txt` files — edit those and run `read-the-listing.py --sheet` again:

    python3 Quiet/Tools/read-the-listing.py --sheet

Each file is exactly what goes in the box, whole: select all, copy, paste. The
descriptions have **one line per paragraph** on purpose. App Store Connect keeps
every newline it is given, so a description wrapped at eighty columns in an
editor renders as a ragged column of short lines on the product page, on every
phone, for the life of the listing — and it looks perfectly right in the editor
it was written in.

Why these words rather than other words is in
[`docs/store-listing.md`](../docs/store-listing.md); the strategy behind the
name, the keywords and the categories is in [`docs/aso.md`](../docs/aso.md).
This folder is the text itself.

---

## One thing here cannot be finished from a computer

**Slides 1 and 5 are photographs of a signed-in feed, and the ones in the
repository are of a build nobody can install any more.** They show Instagram's
own house, magnifier and paper plane inside Quiet's bottom row — artwork the app
used to read out of Instagram's navigation bar and re-draw, and which was taken
out for the reason set out in
[`docs/store-and-legal.md`](../docs/store-and-legal.md#3-instagrams-glyphs-in-quiets-own-row).
A listing whose first screenshot advertises the one thing the app was changed to
stop doing is worth catching before a reviewer catches it.

They also show a **hole** where the third entry should be. The build in those
photographs had four icons and no clock. The row has five now, and the middle
one is a clock counting today down — which is the whole app in one glyph, and
the thing the red arrow on slide 1 is pointing at.

Everything else in the set was re-photographed from the current build, in all
six of the app's languages. These two need a phone with an account on it:

1. Install the current build (TestFlight, from `dev2`) and sign in.
2. Open the feed, scroll until a whole post of **your own** is on the glass —
   the like count, the caption and the date visible, the bottom row visible.
   Nobody else's photograph, handle or face anywhere in the frame; the rule is
   at the foot of `Quiet/Tools/make-shots.py` and it is not a formality.
3. Screenshot. That is `feed-open.png`.
4. Scroll to the top, where the story row, the header and your profile picture
   are. Screenshot. That is `feed.png`.
5. Drop both into `Quiet/Tools/shots/source/`, overwriting what is there.
6. `cd Quiet && /usr/local/bin/python3.12 Tools/make-shots.py v2`

Until that is done the two frames in the set are the old ones, and the other six
are current. The composer says `(shared capture)` for anything falling back to a
shared photograph, so a missing one is visible rather than assumed.

---

## The screenshots

Composed, at 1320 × 2868 — the 6.9-inch size, which is the only one App Store
Connect insists on and the only one it will not scale for you. The app is iPhone
only, so there is no iPad set to make.

    cd Quiet && /usr/local/bin/python3.12 Tools/make-shots.py v2

**That interpreter, on this machine, and not `python3`.** The default `python3`
here is 3.14 with no Pillow; `/usr/bin/python3` is Xcode's 3.9 and has Pillow
but is too old for the type annotations in the script, which it reports as a
`TypeError` that reads like a bug in the code rather than a wrong Python.

And the app's own six screens, when the app has changed:

    cd Quiet && Tools/photograph-for-the-store.sh

Three minutes a language, straight off a simulator, in all six. It writes into
`Tools/shots/fresh/`; copy across to `Tools/shots/source/` once you have looked.

| App Store Connect localisation | Folder |
| --- | --- |
| English (U.S.) | `Quiet/Tools/shots/out/v2/en/` |
| English (U.K.) | `Quiet/Tools/shots/out/v2/en-GB/` |
| German | `Quiet/Tools/shots/out/v2/de/` |
| Spanish (Spain) | `Quiet/Tools/shots/out/v2/es/` |
| Spanish (Mexico) | `Quiet/Tools/shots/out/v2/es/` — the same eight files |
| French | `Quiet/Tools/shots/out/v2/fr/` |
| Portuguese (Brazil) | `Quiet/Tools/shots/out/v2/pt-BR/` |

Eight slides each, numbered in the order they are swiped through. Upload them in
that order; the first three are what a search result shows, and they carry the
decision.

| # | What it answers |
| --- | --- |
| 1 | what is it — the feed, with the tab that never ends gone |
| 2 | and there is a limit — the day ending |
| 3 | why does it hold — lower now, higher next week |
| 4 | what else is gone — set in type and struck through |
| 5 | what is still there — stories, messages, profiles |
| 6 | what happens over a month — a bar for every day |
| 7 | what am I giving up — the whole trade on the first screen |
| 8 | can I trust you — no account, no tracking |

`sheet-<language>.png` beside each folder is the eight side by side at the size
a search result actually gives them, which is the only size that decides
anything. It is for looking at, not for uploading.

**Every one of the fifty has a set of its own**, composed in its language:

    cd Quiet && /usr/local/bin/python3.12 Tools/make-shots.py v2

The six languages the app speaks are set by Pillow from `make-shots.py`. The
other forty-four are set by Chrome (`Tools/render-captions.mjs`), because Pillow
here has no text shaping and sets Arabic unjoined, Hebrew back to front and
Hindi and Thai with their marks adrift. The words are in
[`Tools/shot_captions.py`](../Quiet/Tools/shot_captions.py), written for this
listing and not yet read by a native speaker. The phone in them shows the
English app, which is what somebody who installs it in Italian gets; the
captions around it are in the listing's language. The phone is drawn once per
slide and the languages are laid over it, so all fifty come out in about ten
minutes.

| App Store Connect localisation | Folder under `Tools/shots/out/v2/` |
| --- | --- |
| English (Australia), English (Canada) | `en/` |
| Spanish (Spain), Spanish (Mexico) | `es/` |
| French (France), French (Canada) | `fr/` |
| Portuguese (Brazil), Portuguese (Portugal) | `pt-BR/` |
| Dutch | `nl/` |
| Arabic | `ar/` |
| every other | the folder of the same name, without the region: `it/`, `ja/`, `zh-Hans/`, `sl/`, `ur/` … |

**Six slides are made, not eight.** Slides 1 and 5 are the feed, and
`source/feed.png` and `source/feed-open.png` are photographs of a build whose
bottom row had four icons and no clock. A screenshot has to match the build it
is uploaded with, so `make-shots.py` refuses them by hash (`RETIRED`) and says
so; they return by themselves when those two files are replaced by captures of
the current build, which is the one thing above that cannot be done from a
computer. The slide that used to strike through "Suggested accounts" and
"Autoplay" is corrected as well: the app shows suggested posts unless asked not
to and has no autoplay switch, so neither belongs on a list of what Quiet takes
out.

The upload does not need dragging. App Store Connect's own API takes the files
from the page it is open in: a set per localisation, the old frames deleted, the
new ones uploaded and put in order, which is fifty localisations in a quarter
of an hour instead of fifty afternoons of dragging.

**Not the `app-store-screenshots` artifact from CI.** The `Screenshots` workflow
composes a second, older, five-frame set with `make-the-store-shots.py`, which
predates this one and has no feed in it. The eight above are what goes up.

---

## What goes where, per localisation

App Store Connect splits these across two pages, and the language picker sits at
the top of both. Add all seven languages once and the picker carries them
everywhere.

**App Information → Localizable Information**, which is not tied to a version:

| App Store Connect field | File |
| --- | --- |
| Name | `<locale>/name.txt` |
| Subtitle | `<locale>/subtitle.txt` |
| Privacy Policy URL | the one URL in [`app-information.md`](app-information.md), the same in all seven |

**Distribution → App Store → the version**, which is the page that goes to
review:

| App Store Connect field | File |
| --- | --- |
| Promotional Text | `<locale>/promotional-text.txt` |
| Description | `<locale>/description.txt` |
| Keywords | `<locale>/keywords.txt` |
| Support URL | the one URL in [`app-information.md`](app-information.md), the same in all seven |
| Marketing URL | likewise |
| Screenshots | the folder for that language, above |
| What's New | nothing — App Store Connect does not ask on a first release |

The three URLs are per-language fields with one value between them: there is one
support page and one privacy page, and pasting the same address seven times is
the whole of it. Nothing is missing when they look identical.

Everything else — categories, age rating, privacy answers, export compliance,
copyright, the review notes — is **not localisable at all** and is entered once,
in English. That is App Store Connect's design, not an omission here.

**Promotional text is the one field that can be changed without a new build**,
at any time, including after the app is live. It sits above the description and
is the only place a listing can answer something that has come up.

**The keyword field is never the same twice.** A word already in the name or the
subtitle is indexed anyway, so spending a keyword slot on it buys nothing —
which is why `feed`, `daily` and `limit` are missing from the English keywords
and `Tageslimit` from the German. The checker fails on a repeat.

Then, once, not per language: [`app-information.md`](app-information.md) —
categories, age rating, privacy, URLs, export compliance — and
[`review-notes.txt`](review-notes.txt) into **App Review Information → Notes**,
with a demo Instagram account beside it.

And, when the default page is up, [`custom-pages/`](custom-pages) — four
alternate product pages, each with its own screenshots, its own promotional
text and its own URL. They do nothing for search and a good deal for
conversion; Apple allows thirty-five and these use four.

---

## The eleven the app also speaks

| | Name | Subtitle |
| --- | --- | --- |
| `en-US` | Quiet: Stop Doomscrolling | Your feed, on a daily limit |
| `en-GB` | Quiet: Stop Doomscrolling | Your feed, on a daily limit |
| `de-DE` | Quiet: Weniger Doomscrolling | Dein Feed, mit Tageslimit |
| `es-ES` | Quiet: Menos scroll infinito | Tu feed, con un límite diario |
| `es-MX` | Quiet: Menos scroll infinito | Tu feed, con un límite diario |
| `fr-FR` | Quiet : Stop au scroll infini | Ton fil, une limite par jour |
| `pt-BR` | Quiet: Menos scroll infinito | Seu feed, com limite diário |

Apple searches three fields and no others — name, subtitle, keywords — and it
searches them **once per localisation**. One localisation is 151 characters of
indexed text for the entire world. Thirty-nine is a keyword field per market, in
markets with far less competition in them.

For these eleven, the app itself also speaks the language, so the store page and
the screens behind it agree. **That is not true of the other twenty-eight**, and
what to do about it is the next section.

**`en-GB` is the lever nobody reaches for.** Not a word of it needs translating
— it is the U.S. text — and it is a second keyword field, read in the United
Kingdom, Australia, Ireland and New Zealand and alongside the local language in
most European storefronts. It carries the head terms the British storefront
cannot do without, because there `en-GB` *replaces* the American field rather
than adding to it, and spends what is left on four words the U.S. field had no
room for.

**`es-MX` is the same lever again, pointed at America.** The American storefront
reads two fields, and the second one is Spanish (Mexico) — so a localisation
that is the Spanish text with a single word changed, `movil` to `celular`, is
another hundred indexed characters in the largest storefront there is, plus the
whole of Latin America, for about a minute of work. Upload the `es/` screenshots
to it as well.

Both of those rest on how Apple pairs languages to storefronts, which Apple
does not publish; the reasoning and the uncertainty are set out in
[`docs/store-listing.md`](../docs/store-listing.md#what-a-storefront-indexes-which-decides-the-rest-of-this-section).

**The Romance names buy a phrase rather than a word.** "Doomscrolling" is the
English coinage and it does not carry the same traffic in Spanish, French or
Portuguese, where the thing is called *scroll infinito*, *scroll infini*,
*rolagem infinita*. So the name buys the phrase somebody types and the keyword
field buys `doomscrolling` behind it, where it costs thirteen characters instead
of a name.

**The German drafts want a native ear before they ship**, and so, more so, do
the Spanish, French and Portuguese ones. Nothing here has been checked against
how people in those markets actually search; a listing is an expensive place to
find that out by accident. The app's own six languages were translated with the
same care and are in front of a reviewer either way — but the keyword fields in
particular are guesses made in good faith, and the first thing worth paying a
native speaker an hour for.

---

## The twenty-eight where the app is in English

Italian, Dutch, Polish, Japanese, Chinese and twenty-three more. The listing is
in their language; the app's own screens are not — a phone set to Italian gets
an English Quiet, because iOS falls back to the app's development language.

**Every one of those descriptions says so, in that language, in one line above
the disclaimer.** It costs a little conversion and it buys the review that does
not say "not in my language, one star", which is the review that sinks a 1.0 in
a small storefront. It is also the same argument as slide 7 of the screenshots:
the whole trade, up front.

So they are worth shipping in this order rather than all at once:

1. **The eleven above.** No caveat at all — ship them with the first release.
2. **Italian, Dutch, Polish, Turkish, Swedish, Danish, Norwegian, Finnish,
   Indonesian.** Large App Store markets with strong English, where an English
   app is ordinary and the extra keyword field is real.
3. **Japanese, Korean, Chinese (both), Thai, Vietnamese, Arabic, Hebrew,
   Hindi.** Same upside and a worse mismatch: English competence is lower, and
   Arabic and Hebrew are read right to left by an app that has never been laid
   out that way. Worth having, worth having *after* the app has any reviews at
   all.
4. **Russian — do not ship this one yet.** Meta is designated an extremist
   organisation in Russia and Instagram is blocked there; a Russian-language
   listing for an Instagram limiter is a legal question rather than a marketing
   one, and the text is in `store/ru/` for the day that changes.

**And none of the twenty-eight has been read by a native speaker.** Neither have
the eleven, strictly, but the eleven are languages the app itself was translated
into with care. These are careful translations by one pair of hands, and the
keyword fields in particular are reasoned guesses about how people search in a
market nobody here has looked at. The cheapest possible improvement to this
folder is an hour of a native speaker's time per language, starting with the
markets you actually care about.

## Before the first upload

* The app name must be **unique across the App Store**. `Quiet: Stop
  Doomscrolling` almost certainly is; `Quiet` alone almost certainly is not, and
  that is what the suffix is for. Find out in App Store Connect before anything
  else here matters.
* **Nominate it** under *Featured Content*. It is free, it takes half an hour,
  and for this app it is realistically a larger source of installs than every
  keyword decision in this folder put together. What to put in it is in
  [`docs/aso.md`](../docs/aso.md#editorial).
* Look at the CI run for the commit being built before asking anybody to wait
  for an archive.
* If there is ever an appetite for more forms: **en-AU** and **en-CA** take the
  `en-GB` text unaltered, **fr-CA** takes the French, **pt-PT** takes the
  Brazilian with its pronouns turned around. Each is another indexed keyword
  field and none of them is another translation.

---

## The eleven added in October 2026

App Store Connect added eleven more localisations after the first thirty-nine,
under codes that carry a region: `sl-SI`, `mr-IN`, `bn-BD`, `gu-IN`, `pa-IN`,
`ur-PK`, `ta-IN`, `te-IN`, `kn-IN`, `ml-IN`, `or-IN` — Slovenian, Marathi,
Bengali, Gujarati, Punjabi, Urdu, Tamil, Telugu, Kannada, Malayalam and Odia.
The bare codes (`sl`, `bn`, …) are refused with "The language specified is not
listed for localization". The folders here use the codes Apple wants.

They are the same case as the twenty-eight above: the listing is in their
language and the app is in English, and every description says so in one line
above the disclaimer. They were created through the API together with their
name and subtitle (which live on the App Information page and come into being,
empty, the moment the version localisation does), and each folder has a
`whats-new.txt` as well, which the other thirty-nine do not — theirs were
typed straight into App Store Connect.

**Every one of these eleven was written without a native reader.** Odia,
Malayalam, Kannada and Telugu in particular are worth an hour of somebody who
speaks them before the app has been in their stores for long, and so are the
keyword fields. The facts in them are the facts in `en-US/description.txt` and
nothing was added or left out; the checker holds them to the same limits, the
same eight-things rule and the same disclaimer as the rest.
