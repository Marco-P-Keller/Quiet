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
them. Reels, Explore and the accounts suggested between your friends are not
there. You sign in on Instagram's own page, so your password never touches
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

Four, in this order, all from the app's own screens rather than from Instagram's
pages. A listing whose screenshots are all somebody else's product invites the
question the review notes are there to answer.

They are produced by the `Screenshots` workflow at 1320 × 2868, which is the
6.9-inch size App Store Connect requires; a smaller one is rejected on upload
rather than scaled. Download them from the run's artifact.

| # | File | Caption |
| --- | --- | --- |
| 1 | `setup.png` | Instagram, minus the parts that keep you there. |
| 2 | `limit.png` | Less takes effect at once. More waits a week. |
| 3 | `curtain.png` | When the day is spent, the app closes. |
| 4 | `panel.png` | No account. No servers. Nothing to check. |

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
