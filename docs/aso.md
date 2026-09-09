# Being found

Why the listing is worded the way it is, and what would move the number of
people who install this.

[The listing](store-listing.md) is the paste-ready side of this: the actual
strings, inside Apple's limits. This page is the argument behind them, kept
separately because the strings will change and the reasoning is what makes the
next change a decision rather than a guess.

**One honest limit first.** Nothing here rests on App Store search-volume data,
because none was available. It is reasoning from how the ranking is built, not
from numbers, and where that matters it is said out loud. Anything below that
could be settled by measurement should be, and mostly by Apple Search Ads,
which will sell you the volume for a term before you commit a name to it.

---

## What the store actually reads

Three fields, and no others: **name, subtitle, keywords**, in that order of
weight. Apple assembles phrases from words across all three, so `screen` and
`time` in the keyword field buy "screen time" as well as each word alone.

**The description is not indexed.** That is Google Play. On the App Store the
description is a conversion instrument — it is read by somebody already on the
page, deciding — and an hour spent tuning it for search is an hour spent on
nothing. This matters here more than it usually would: Quiet's description is
the one place "Instagram" may legitimately appear, and the fact that it appears
there buys exactly no visibility.

The fields are indexed **once per localisation**, which is the single largest
lever on this page and has its own section below.

---

## The name: own something small, or lose something large

Two strategies, and only one of them is available to an app with no users.

**Head terms** — "screen time", "app blocker", "digital detox" — carry the
volume and are held by Opal, Freedom, one sec and ScreenZen, each with years of
ranking history and tens of thousands of ratings. The thing to understand is
that for a contested query **text relevance does not decide the outcome**;
the popularity signal does. Putting "Screen Time" in the name does not make this
app rank for it. It makes the name generic and changes nothing else.

**A narrow term can be owned outright.** "Doomscrolling" has a fraction of the
traffic and perfect intent: somebody typing it is describing this app's problem
in this app's words, and there is almost nothing else competing for it. First on
a small word beats eightieth on a large one, and eightieth is what the large one
actually offers.

| | Pro | Contra |
| --- | --- | --- |
| `Quiet: Stop Doomscrolling` | winnable; perfect intent; distinctive in a results list, which lifts tap-through — itself a ranking input | small volume; the word will date; the big terms sit only in the weakest field |
| `Quiet: Screen Time & Focus` | the category phrase in the heaviest field | buys impressions it will not get, and spends the distinctiveness it would have got |
| `Quiet: Scroll Less` | short, quiet, on-brand | says neither what the app does nor to what; contains no word anybody types; spends 18 of 30 characters in the most valuable field on the page |

`No More` lost to `Stop` for three characters of filler that index for nothing,
and because it reads as a complaint where the app reads as a decision — the
first screen says "Instagram, minus the parts that keep you there", not "no more
Instagram".

**This decision has an expiry date, and it should be revisited rather than
inherited.** The niche strategy is right *because* the app has no popularity
signal. Once there is rating volume, or once Search Ads are buying impressions
on head terms, the arithmetic reverses and a name carrying "screen time" starts
to pay. The right name is not a constant; it is a function of how well known the
app already is.

## The subtitle: a good sentence that costs nothing

`Your feed, on a daily limit` yields three useful tokens once Apple has dropped
the stopwords — *feed*, *daily*, *limit* — and all three are generic. Something
like `A daily screen time limit` would yield four and include the category's
defining phrase.

It stays as it is anyway, and the reason is the same one that settled the name:
the phrase that swap would buy is unwinnable regardless, so the trade is a real
loss of meaning for a theoretical gain. The current line says *what* the app
does *to what*, in six words, which is conversion value the generic line does
not have. It is also changeable per version, so it can be tested later against
a listing that has traffic to test with.

## Keywords

The rule is that nothing may appear twice. A word in the subtitle is already
indexed, so buying it again in the keyword field spends characters on nothing —
which is how `limit`, `daily` and `feed` came out.

Two other kinds of waste came out with them. `off` is a preposition. `minutes`
is the unit the product is measured in, and nobody searches for an app by its
unit. `reels` was worse than waste: a third party's mark in a field that is
metadata exactly as the name and the icon are, bought for one word of traffic,
on the guideline this listing is already most exposed to.

What the freed room bought is in [the listing](store-listing.md#keywords-100-comma-separated-no-spaces).
The pairing to understand is `social` + `media`, which was missing: Apple builds
phrases from the words it is given, and without `media` the three commonest
shapes of query in this category — "social media detox", "social media
blocker", "social media addiction" — were all unreachable for five characters.

**What is deliberately still absent is `instagram`.** It would be, by a
distance, the highest-intent term available, and it is the same 5.2.1 exposure
that `reels` was. This app already carries more of that risk than most; spending
the remaining budget on a keyword would be the worst available trade. It is a
real and permanent cost of the positioning, not an oversight.

## Categories

Set out in full in [the listing](store-listing.md#category). The short version:
Photo & Video was actively harmful and is gone, Productivity is where the
competition stands and therefore where Apple's adjacency placements will show
this app, and Health & Fitness is a free secondary that catches the browse
intent Photo & Video was catching wrongly.

The cost of Productivity is that its charts are unreachable. Utilities would
have been chartable and its browsers want scanners and VPNs. Being seen beside
the right apps beats being ranked among the wrong ones.

## Localisation, which was at zero

The listing existed in English (U.S.) only: **151 characters of indexed text,
for the whole world.** Each additional localisation is another 30 + 30 + 100, in
markets with less competition, and this app is bilingual already — the German
screenshots have been rendering in CI for weeks.

German matters twice over. Search is one; the other is that the publisher is
Swiss and the app speaks German, so without it somebody in Zurich reads an
English product page over a German app.

English (U.K.) is the lever nobody reaches for: not a word of it needs
translating, and it is a **second keyword field** serving the U.K., Australia,
Ireland and New Zealand. Filled with the terms the U.S. field had no room for
rather than a copy of it, the same app covers twice the vocabulary.

Drafts for both are in [the listing](store-listing.md#the-other-localisations).
The German ones want a native ear before they ship.

---

## The two things that move more than any of the above

### Ratings, and when the app asks for one

Rating count and average feed both the ranking and the conversion rate, and a
new app has neither. `Applause` puts the App Store's question exactly once, ever
— a deliberate restraint that is not up for negotiation and is not the problem.

The problem was **when**. The rule was five minutes of the app on screen, and at
the smallest limit Quiet allows, five minutes is somebody's *first sitting*. The
single shot was being spent on a person who had opened the app and seen nothing
it promises: the promise is that the limit **holds**, and holding is a thing
that takes days to notice.

It now takes five minutes **across three separate days** — somebody who was cut
off and came back anyway, which is the only endorsement this app can honestly
earn. The number of prompts has not changed. The probability that a prompt finds
somebody able to answer it has.

What was considered and rejected: asking at the curtain. It is the obvious
"moment of delight" and it is the wrong one — a five-star sheet on the far side
of the screen that just took the day away is the app asking to be praised for a
loss. `RootView` has refused to put the question anywhere but the browsing
screen since long before this page existed, and that refusal stands.

### Editorial

**Nominations**, in App Store Connect under *Featured Content*. It is free, and
for this app it is realistically the largest single source of installs available
— larger than any keyword decision on this page.

Apple features apps with a point of view, and the evidence here is unusually
concrete for a 1.0:

* a design that borrows from nothing, including from the site it displays;
* accessibility that is tested rather than asserted — four UI tests drive every
  screen the way VoiceOver does, and every screen is photographed at the largest
  text size iOS offers;
* no data collection of any kind, and a privacy page that names what is kept and
  where;
* two languages, in the app and in the store;
* a subject Apple has an institutional interest in.

It is a lottery. The ticket costs half an hour and the odds are better than they
look.

Two more that cost nothing and are worth doing once there is traffic:
**Product Page Optimization** — free A/B testing of icon and screenshots, and
the icon is the largest conversion lever in a results list — and an **App
Preview video**, because the product is an *absence* and absence is hard to
photograph and easy to film.

---

## In order

| | | Effort | Confidence |
| --- | --- | --- | --- |
| 1 | Drop Photo & Video for Health & Fitness | a minute | high — the only item that removes harm rather than adding good |
| 2 | German localisation (assets exist) | an hour | high |
| 3 | Submit the nomination | half an hour | a lottery, with the highest ceiling on the page |
| 4 | The rating prompt at three days | done | high |
| 5 | `media` and `phone` in the keywords | done | medium |
| 6 | English (U.K.) as a second keyword field | half an hour | medium |
| 7 | Product Page Optimization | later | needs traffic first |

Items 4 and 5 are in the repository. The rest are settings and text in App Store
Connect, and none of them can be done from here.
