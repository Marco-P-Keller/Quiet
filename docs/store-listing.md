# The listing

Everything App Store Connect asks for, written out and ready to paste. Where a
choice is arguable the reasoning is here too, because the arguable ones are
where a listing gets rejected.

The counts in brackets are Apple's limits. Nothing below exceeds them.

---

## Name and subtitle

**Name** (30) — `Quiet: Scroll Less`

`Quiet` alone is almost certainly taken; App Store names are unique and it is an
ordinary English word. The suffix is what makes it available and it says what
the app is for.

**Subtitle** (30) — `Your feed, on a daily limit`

Neither the name nor the subtitle contains "Instagram", deliberately.
Referencing another company's trademark factually *in the description* is
allowed. Putting it in the name, the subtitle or the icon is the fastest way to
guideline 5.2.1, and it is the one line of the listing that is not worth
arguing about.

## Promotional text (170)

```
A daily limit that cannot be lifted in the moment it starts to bite. Lower it
whenever you like. Raise it once a week, starting the next day.
```

## Description (4000)

```
Quiet shows Instagram's mobile site with the endless surfaces taken out.

Your feed, your stories, your messages and your profile load the way you know
them. Reels and Explore are not there. The posts Instagram suggests between your
friends are — and one switch takes them out, which also gives the feed an end to
reach. You sign in on Instagram's own page, so your password never touches
Quiet.

Then there is a limit.

You choose how many minutes a day you want. While you are reading, that time
runs down — only while the app is in front of you, only while the page is
actually on screen. Two quiet notices, at five minutes and at one. When the time
is gone, the app closes for the day and says so.

You can lower your limit whenever you like, and it takes effect at once. You can
raise it once a week, and the new number starts the next day — never in the
moment you want five more minutes. That asymmetry is the whole app. The decision
you make calmly is allowed to bind the decision you make at eleven at night.

WHAT QUIET DOES NOT DO

• No account, no server of ours, no analytics, no advertising, no tracking.
  If you switch on carrying between devices, your limit and today's total go
  into your own iCloud — where only your devices can read them.
• No streaks, no weekly report, nothing to check. One notification exists and
  it is off until you ask for it: a single daily reminder, at an hour you pick,
  which stays quiet on any day you have already been.
• No countdown on the screen. A timer you can watch is a timer you do watch;
  what is left is in the panel, for the moments you actually want to know.
• No permission prompt unless you ask for the daily reminder.

Four things are kept, on your phone, in the keychain: your limit, today's total,
the furthest point in time the app has seen, and the day you set it up. They
survive deleting the app, on purpose. A limit you can lift by reinstalling is
not a limit.

The day turns at four in the morning rather than at midnight, so a late evening
belongs to the evening it feels like.

Quiet is not affiliated with or endorsed by Instagram or Meta. It is a limiter
for a site you already use, not a replacement for it, and it is not made by,
connected to, or supported by them.
```

## Keywords (100, comma separated, no spaces)

```
limit,screen,time,focus,minutes,daily,habit,less,scroll,feed,reels,off,attention,wellbeing,digital
```

Keywords are matched individually, so the name and subtitle words are left out —
Apple already indexes those, and repeating them wastes the field.

## URLs

| Field | Value |
| --- | --- |
| Privacy Policy URL | `https://marco-p-keller.github.io/Quiet/privacy.html` |
| Support URL | `https://marco-p-keller.github.io/Quiet/support.html` |
| Marketing URL | `https://marco-p-keller.github.io/Quiet/` |

Both required pages are in [`site/`](../site) and published to the `gh-pages`
branch by a workflow, so what is served is what is in the repository. They need
GitHub Pages switched on once: **Settings → Pages → Source: Deploy from a
branch → `gh-pages` → `/ (root)`**.

## Category

Primary **Utilities**, secondary **Health & Fitness**.

Health & Fitness is where digital-wellbeing apps usually sit, but this one shows
somebody else's social network, and a reviewer opening a Health & Fitness app
onto an Instagram feed has a question before they have read a word. Utilities is
the honest shelf: it is a tool that constrains something else.

## Age rating

Answer the questionnaire as follows. The rating that comes out is **17+**, and
that is correct.

* **User-generated content: yes, unrestricted.** Everything on the screen is
  Instagram's, which is exactly that.
* **Unrestricted web access: no.** The web view is confined to Instagram's own
  domains and the Meta domains a sign-in passes through. Everything else is
  handed to Safari; Instagram's own "open the app" link is refused outright.
  This is enforced by URL rules in `ContentRules`, not by hiding buttons.
* Everything else: none.

## App privacy

**Data Not Collected.** Answer "No" to the first question and there is nothing
further to fill in.

That is not a convenient reading. Quiet has no networking of its own, no
identifiers, no SDKs and no server to send anything to. The Instagram session
lives in the app's web storage exactly as it would in Safari, which is Meta's
collection, disclosed by Meta, in Meta's own listing.

The optional iCloud sync does not change the answer. Apple's own guidance is
that data stored in a user's private CloudKit or key-value store — which the
developer cannot read and never receives — is not data the developer collects.
It is the same category as a document in the user's iCloud Drive. Nothing there
is linked to an identity, because there is no identity: a limit, a wait, and a
handful of running totals under an anonymous per-device name.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `false` in `Info.plist`, so App Store
Connect stops asking at every upload. Quiet uses no cryptography beyond the
HTTPS iOS provides.

## Version

**1.0.** The build number comes from the workflow's run number and only ever
climbs, so it never needs to be typed. The marketing version is the one a person
sees, and the first upload fixes it forever — 1.0 is what a first release should
say.

---

## Screenshots

Seven, in English and in German, built by `Tools/make-shots.py` and finished at
1320 × 2868 — the 6.9-inch size App Store Connect requires, a smaller one being
rejected on upload rather than scaled. Most captures come from the simulator at
that size; three come from a real phone at 1179 × 2556 and are scaled into the
device by the same projection as everything else.

The untouched phone captures are kept in `Tools/shots/originals`, with an index
saying where each one goes, which three are not used and why, and exactly what
was retouched out of the one that was. Keeping them is not sentiment: a slide
that cannot be re-cut from its own frame has to be re-shot from scratch.

    python3 Tools/make-shots.py            # all three
    python3 Tools/make-shots.py v2        # → Tools/shots/out/v2/{en,de}/
    python3 Tools/make-shots.py house     # → Tools/shots/out/{en,de}/
    python3 Tools/make-shots.py loud      # → Tools/shots/out/loud/{en,de}/

### Three sets, and v2 is the one to upload

**v2** is the house style with its hierarchy fixed for the place these are
actually read — a row of thumbnails about 300 px wide, in which the headline is
the only thing that survives. Three things change and all three are about that
row:

* **The headline is as large as German will carry.** 106 pt: `Mehr *nächste
  Woche*.` is the longest line either language has, and it clears the margin by
  47 px there and overruns at 112. German sets the type size in this set, every
  time.
* **The subline stops being a whisper.** It was 41 pt of muted grey, which is
  nine pixels of noise at the size that decides anything. Now 46 pt, and a
  third of the way from the grey towards the ink.
* **The hero is the post, not the story row.** Slide 1 was the top of the feed
  — a story ring, an author line, and a picture running off the bottom of the
  glass. The scrolled frame shows a whole post *and* the missing tab: the like
  count, the comment count, the caption and the date, over a row with a hole in
  it. Somebody deciding whether this is their Instagram gets the answer from
  that frame and not from the other one. The arrow moved with it and now says
  `No Reels` rather than `Reels was here` — the phrase somebody would search
  for.

* **No sparkles.** Four white stars scattered around a phone are the house
  decoration of this whole category, and they were softening a set whose entire
  argument is that it is serious about the thing it does. The slides do not
  look emptier without them; they look composed rather than dressed.
* **One red marker, and only one.** The arrow and its label on slide 1 are the
  only colour anywhere in the set. `spans()` in `Tools/make-shots.py` says
  Quiet has no accent colour and that inventing one for the store would be
  advertising a different app — and that still holds for the type, which gets
  weight rather than hue. This is not type. It is a marker laid over a
  photograph saying *look at this one spot*, and a marker that matches
  everything around it is not a marker. It stays off the headline, off the
  subline and off the other six slides, which is what keeps it reading as a
  pointer rather than as a brand.

That also fixed a slide that was being wasted: slides 1 and 5 used to be the
same photograph under two different captions. The story-row capture now carries
slide 5 on its own, under the claim that the stories, the messages and the
profile are all still there — which is the thing it is a picture of.

**House** is the original: the same slides, a smaller headline, the quieter
subline, and slide 1 on the story row. **Loud** is the uniform this whole
category wears — cream throughout, a heavy sans, the phone run most of the way
off the frame. Every listing you will be compared against on the shelf looks
like the third one.

All three exist as contact sheets (`sheet-en.png` in each folder), and the
comparison worth making is at the size a search result gives a slide, because
that is the only size that decides anything.

What loud does **not** borrow is the furniture those listings carry above the
fold: a star rating, "trusted by 500K+ people", laurel wreaths, an Apple mark.
They are the loudest things on a slide of that kind, they are the first thing
the eye lands on, and every one of them would be a lie on an app that has not
shipped. Copying a layout is fair; copying a claim is not. When the numbers are
real they can go in, and the layout is already there to hold them.

**The first slide is the product**, and two earlier versions of this set got
that wrong: they led with Quiet's own screens — the curtain, the panel, the
screen the app opens with — which are the pleasant ones to design and none of
which show what the app *is*. Somebody on a store page is asking one question,
and it is not what the settings look like. It is: is this my Instagram, and what
has been taken out of it.

So slide one is the feed, with Instagram's own header on it and Quiet's row
along the bottom — where the third entry, the one Instagram gives to Reels, is a
clock counting today down. The whole app is in one photograph.

| # | Screen | Caption | Answers |
| --- | --- | --- | --- |
| 1 | feed, light | Instagram, without **Reels**. | **what is it** |
| 2 | curtain, dark | No **five more** minutes. | and there is a limit |
| 3 | panel, light | Less **now**. More **next week**. | why does it hold |
| 4 | *set in type*, dark | What **isn't** here. | what else is gone |
| 5 | the feed again, dark | Everything else is **untouched**. | what is still there |
| 6 | setup, light | The whole trade, **up front**. | what am I giving up |
| 7 | opening, dark | No account. No **tracking**. | can I trust you |

Slides 4 and 5 are a pair and are meant to be swiped as one: the removals set in
type and struck through, then a photograph of everything that was left alone.
Four says what is gone, and on its own it reads as a smaller Instagram. Five is
the answer to the question four raises — the like count, the comment count, the
caption and the date, on Instagram's own page, with the empty tab slot still at
the foot of it. It is also the brightest slide in the set: a white screen on
Quiet's dark ground, which is what a listing wants at the size a search result
gives it.

Slide 3's English capture is the panel with the day spent **and a raise already
queued** — `Daily limit 20 minutes` over `45 minutes from tomorrow`. The caption
has claimed the asymmetry since the first version of this set; that capture is
the first one that shows it. The German slide still uses the light panel, and
should be re-shot in the same state, because a German listing wants a German
screenshot more than it wants this detail.

### How they are drawn

The phone is a real perspective projection of a box with thickness, extruded
from its back face to its front in twenty-two steps — which is what gives the
side of the device a surface and its corners a radius, and what separates a
photograph of a thing from a screenshot pasted onto a colour. The maths is in
`Tools/make-shots.py`; the linear solver is written out rather than imported,
because the whole toolchain here has one dependency and a good reason for it.

**One light, and a corner measured rather than chosen.** Everything on the
front now agrees about where the light is: the reflection enters at the top
left, the chamfer is brightest where it turns over there, and the shadow falls
away from it on every slide. It used to flip sides with the pose, so half the
set had a phone throwing its shadow towards the light — the kind of wrongness a
reader feels without being able to name it. The display's corner is 14% of its
own width, which is what a phone this size actually does; it was 9.9%, and a
screen squarer than a real one is the first tell a mockup gives. The frame is
concentric with it, because an outer radius is an inner radius plus the border
between them and any other pair leaves the bezel fat at the corners.

The glass carries two reflections, a wide soft one and a narrow bright one, and
how much of either survives is measured off the screenshot underneath — a lit
screen washes a reflection out and a dark one hands it back. One fixed strength
for all seven was invisible on the feed and about right on the curtain.

Two things follow from that projection rather than from a coordinate somebody
typed. The device is sized by **height**, so the bottom of the screen — where
Quiet's row stands — is always on the slide; fitting it by width put the row
past the bottom edge and threw away the only proof slide 1 has. And the arrow on
slide 1 is aimed at a point given in *screen* coordinates and run through the
same projection, so it lands on the clock however the pose changes.

The arrow is the only annotation in the set and it earns its place: the claim is
a tab that is **not** there, and an absence is the one thing a screenshot cannot
show. It points at what stands in its place, and says *Reels was here*.

**A version with that slot empty was asked for and not made.** It would read
more strongly, and it would be a picture of an app that does not exist: the
clock is not decoration, it is the button that opens Quiet's own settings
(`BrowserScreen.swift`, announced to VoiceOver as "Quiet settings"), and there
is no state in which the row has four entries. Retouching it out would show a
reviewer one thing and hand them another, and it would delete the only way into
the panel from the picture. The arrow makes the same point and is true.

### What the set deliberately does not say

Listings of this shape usually carry a star rating, a "trusted by N people"
line, press logos, an Apple mark. All of them are easy to draw and every one
would be an invention on an app that has never shipped. A screenshot is
metadata; metadata that overstates is the kind an app gets removed for, and none
of it is true yet. When it is true, it can go in.

### Where slide 1 comes from

Every other slide is Quiet's own screen, captured from the simulator, carrying
nobody's content. Slide 1 cannot be: the feature is the feed, and a feed is
somebody's. So it is a real photograph — of a post from an account the developer
owns, liked by the developer, with the developer's own profile picture in the
row. Nothing in it belongs to anybody else.

Getting there took three passes, and the first two are worth remembering because
both looked finished:

1. A celebrity's post. Somebody's copyrighted photograph and somebody's
   likeness, in an advertisement.
2. Instagram's own corporate account. Better — no private person — but still a
   post nobody involved here wrote.
3. The developer's own post. What ships.

Even then, other people survived into the frame in three places, and all three
were edited out rather than argued down:

* the three profile pictures in the **"Liked by …" row** — other accounts'
  photographs, forty pixels wide. Removed, and the line closed up to the left
  margin, which is where Instagram puts it anyway when there is nothing to show
  there;
* a **story avatar** peeking from behind the floating row in the English
  capture, filled row by row with the colour of the row above it so the pill's
  own edge survived;
* the **next post's author line** under the row in the German one.

Two artefacts were deliberately *not* removed: a pair of dots at the right of
the row and a hairline below it, both belonging to the post underneath. They
identify nobody, and the first attempt at taking them out cut a notch in the
row's rounded end — a screenshot that has been over-retouched looks faked, which
costs more than a stray pixel.

Small is not the test. Whose it is, is the test.

The one thing slide 1 still accepts is **guideline 5.2.1**: a caption is
marketing copy, on the same shelf as a name and a subtitle, and this one says
"Instagram". Factual, non-affiliating, and the whole point of the app — but not
free. It is a considered risk, not an oversight.

The rule the rest of the set follows, and the one to keep when re-shooting, is
at the foot of `Tools/make-shots.py`: *if a person who is not you can be
recognised in it, it does not go in the listing.*

### The two feed photographs

`source/feed.png` is English; `source/de/feed.png` is a German post, so the
German listing shows a German feed rather than an English one under German
captions. Any slide can be localised the same way: a file in `source/<lang>/`
wins over the shared one, and the script prints "(shared capture)" for anything
still falling back, so a missing translation is visible rather than assumed.

---

## Review notes

Paste this into **App Review Information → Notes**. It is short because a
reviewer reads a great many of these, and it answers the three questions this
app actually raises, in the order they will occur to them.

```
Quiet is a self-control tool, not an Instagram client. It exists to enforce a
daily time limit on a site the user already uses: minutes are chosen, spent
while browsing, and when they run out the app closes for the day. Lowering the
limit takes effect immediately; raising it is allowed once every seven days and
starts the following day, which is the point of the app.

It shows Instagram's own mobile website in a web view. It adds no social
features of its own — no posting, messaging, moderation or accounts — so all
content, and all reporting and blocking of that content, is Instagram's, reached
through Instagram's own interface. Sign-in happens on Instagram's page; the app
never sees a password. Navigation is restricted by URL to Instagram's domains,
including the Meta domains a sign-in passes through; anything else opens in
Safari.

We are not affiliated with, endorsed by, or sponsored by Instagram or Meta, and
the app says so on its own About screen and in the description. The name, icon
and subtitle use no third-party trademark.

To see the whole app quickly: the daily limit and the end-of-day screen are
reachable without waiting — please contact us and we will supply a build with
the limit pre-spent, or set the limit to its minimum of 5 minutes and leave the
app open.
```

Add a demo Instagram account under **Sign-in required** as well. A reviewer who
cannot sign in sees a login page and nothing else, and "it looked like a
website" is the review this app cannot afford.

## What to expect

Guidelines **4.2** (minimum functionality) and **5.2.1** (third-party content
and marks) both point at an app like this one. The answer to 4.2 is that the
functionality is the limiter — the rules engine, the asymmetric change, the day
boundary — and the web view is the thing being limited. The answer to 5.2.1 is
that the content is reached through the owner's own site and interface, under
the owner's own sign-in, with no branding borrowed and a disclaimer in two
places.

Both answers are true. Neither is automatic. Expect a conversation.
