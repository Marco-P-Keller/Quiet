# Custom product pages

App Store Connect allows **thirty-five** of these and they cost nothing. Each
one is the same listing with a different first slide, a different promotional
text, and — the part that matters — **its own URL**.

What a custom page can change: screenshots, app previews, promotional text.
What it cannot: the name, the subtitle, the description, the keywords, the
icon. Those come from the default page and are the same everywhere. So a custom
page does not buy another keyword field and does not help search at all. It
buys **conversion**, by answering the question the arriving reader actually
has instead of the average of all of them.

Four are set out here. Twenty-eight of the thirty-five are still free.

| Page | Leads with | Who is arriving |
| --- | --- | --- |
| `the-day-ends` | the curtain — *No five more minutes* | somebody who knows their problem is the evening |
| `does-it-work` | the record — *The days behind you* | somebody who has installed a blocker before and deleted it |
| `still-your-instagram` | the feed — *Your feed. Your people.* | somebody afraid of losing the thing itself |
| `nothing-kept` | the opening — *No account. No tracking.* | Hacker News, r/nosurf, anywhere the first question is who is watching |

**The default page already leads with the feed without Reels**, which is why
none of these does. A custom page that opens on the same frame as the default
one is a slot spent on nothing — that was the first draft of
`still-your-instagram` and it is why that page now opens on what is *kept*
rather than on what has been taken out.

## The screenshots

    cd Quiet && python3 Tools/make-the-custom-pages.py

Reads the finished slides and writes reordered copies, renumbered so the folder
uploads in the intended order:

    Quiet/Tools/shots/out/cpp/<page>/<language>/

Six languages each — `en`, `en-GB`, `de`, `es`, `fr`, `pt-BR` — the same six the
default page has. Nothing is redrawn: these are the same eight PNGs in another
order, so `make-shots.py v2` has to have run first, and re-running it means
re-running this.

Every page carries all eight slides. Dropping one would be dropping an argument
the reader does not then get to hear, and it is the same argument on every page;
only the order changes.

## The promotional text

One file per localisation, per page, in the folder beside this one:

    store/custom-pages/<page>/<locale>.txt

Eleven localisations each — the ones the app itself speaks. A custom page in a
localisation you have not given it falls back to the default page's text, which
is correct rather than broken.

`python3 Quiet/Tools/read-the-listing.py` checks these against the same 170
characters as the default page's promotional text, and that the locale in the
filename is one that actually exists in `store/`.

## The URL is issued, not constructed

App Store Connect gives each page a `ppid` when you create it:

    https://apps.apple.com/<country>/app/<slug>/id<app-id>?ppid=<uuid>

It cannot be guessed or written down in advance, which is why there is no table
of them here. Create the page, copy the URL App Store Connect hands you, and put
**that** under the post or into the ad group. A link with an invented `ppid`
silently serves the default page, which looks like it worked.

## Where each one goes

* `nothing-kept` → the Hacker News post, the r/nosurf post, anywhere the
  audience's first question is about data rather than about scrolling.
* `the-day-ends` → anything written about the evening, about sleep, about not
  being able to stop.
* `does-it-work` → anyone who has already tried something in this category,
  which is most of the people who will read about it.
* `still-your-instagram` → the objection that comes up most often and is the
  hardest to answer in a search result: *but I don't want to lose Instagram*.

**They also attach to Apple Search Ads ad groups.** An ad group bidding on
"digital detox" can send its taps to `does-it-work` while one bidding on
"phone addiction" sends them to `the-day-ends`. That is where the custom pages
and the Search Ads budget compound instead of running separately — see
[`docs/aso.md`](../../docs/aso.md).

## What they are worth, and what they are not

A custom page does nothing for ranking. It is a conversion instrument, and its
value is measurable in App Store Connect: each page reports its own impressions
and conversion rate, against the default page as the control. That is the only
number here that will be real rather than reasoned — four pages is enough to
find out which of the four arguments actually lands, and that answer should
then change the **default** page's first slide.
