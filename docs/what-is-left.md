# What is left

Everything in this list is either unverified or undecided. Nothing here is a
vague improvement: each item names what to do, why it matters, and how you
would know it came out right.

The order is deliberate. The first group decides whether the app works at all
for the person holding it. The second decides whether it can ship. The third is
the difference between an app that works and one worth keeping on the first
screen.

What is *not* on this list is anything the runner can already answer: the build,
the unit tests, the UI test that walks from an empty install to Instagram and
back through a relaunch, the trim pass asked forty-odd questions on a page that
is not Instagram's, and every sentence in the app checked in both languages.
Those run on every push and are green.

A companion to this page — [verbesserungen.md](verbesserungen.md) — tracks the
thirty-eight improvements found in a read-through of the whole project, with
what has been done and what has not.

---

## 1. What only a real phone with a real account can answer

The runner sees Instagram signed out. Everything below is invisible to it, and
the first five items are the app's central promise.

### 1.1 The feed, signed in

Instagram does not keep Reels on the Reels tab. It injects them into the feed as
single tiles and as a horizontal row. `trim.js` finds a block by its text and
hides it; nobody has yet watched it do that on a real feed.

**Check:** scroll a signed-in feed for a full minute. An injected reel should be
gone, and the post above and below it should be untouched. **Fail looks like:**
a reel that survives, or — worse — a gap where an ordinary post used to be.

### 1.2 The tab bar, signed in

Signed out, three entries arrived: home, messages, profile. Signed in there are
five: home, search, create, reels, profile.

**Check:** which of them are still there. Then make a decision that is currently
unmade: search is the doorway to Explore, and finding someone already lives in
the panel. If the tab stays, Explore is one tap away behind a different door.

### 1.3 Logging in, all the way through — *still the most important line here*

`ContentRules.internalDomains` holds five domains. A real sign-in can pass
through two-factor, a "save your login info" page, a security checkpoint, or
Facebook. Any of those on a sixth domain gets handed to Safari, and the login
dies halfway.

The allowlist cannot be completed by guessing; that is what an allowlist is. So
what changed is not the list but the silence around it: a hand-off that happens
while somebody is in the middle of signing in now says so, names the address,
and the panel keeps that host. The failure has gone from "it does not work" to a
sentence with a domain in it.

**Check:** sign in from a clean install, with 2FA on. **This is still the
failure that makes the app useless on first run.** If it happens, the panel has
the answer written down.

### 1.4 Whether being signed in survives

The web view uses the persistent data store, so it should. Nobody has confirmed
it across a cold launch.

**Check:** sign in, kill the app, come back tomorrow morning. You should not see
a login page.

### 1.5 Posting a photo — *the app can no longer be killed by a tap*

`Info.plist` declared no `NSCameraUsageDescription` and no
`NSMicrophoneUsageDescription`. If a page's file input offered the camera, iOS
terminated the app on the spot — no crash report naming the cause, just a
disappearing app.

Four strings now, in both languages: camera, microphone, photo library, and
adding to the photo library. Quiet uses none of them itself and every sentence
says so; they exist so that a tap on somebody else's page cannot end the app.

**Check:** tap `+`, and long-press a picture and save it. What happens after the
prompt is Instagram's business, and whatever it is, the app is still running.

### 1.6 Video that waits to be asked

`mediaTypesRequiringUserActionForPlayback = .all`. Autoplay is one of the
hooks, and removing it was on purpose — but a story that sits still until
tapped may read as broken rather than as calm.

**Check on the phone, not here.** It is one line either way, and it cannot be
judged from a description.

### 1.7 The keyboard in a conversation

The browsing screen ignores the safe area on purpose, so its top edge is the top
of the screen. That is exactly the setting that breaks a page's own bottom
inset.

**Check:** open a DM and type. The field must not be under the keyboard, and it
must not be under the home indicator.

### 1.8 Saving a photo

**Check:** long-press an image. The share sheet should appear and Save Image
should work.

### 1.9 The room at the foot of a sheet

Instagram's sheets — switching accounts, sharing, the menu behind the three
dots — are pinned to the bottom edge of the glass, where Quiet draws its own
row. The page now pads the panel of a sheet by the height of the row, so what is
on the sheet ends above it. Which box gets the padding is decided by geometry
and by `position`, against fixtures rather than against Instagram: the harness
can say that a panel is found and a backdrop is not, and it cannot say that the
box it found is the one Instagram actually draws the sheet as.

**Check:** open the account switcher. Every row on it, and "Log In to an
Existing Account" at the foot, must be clear of the row, with the sheet's own
colour running on behind it. **Fail looks like:** the row across the button
still, or the sheet lifted off the bottom edge with a band of page showing under
it, or a sheet that jumps as it opens.

Both failures are visible from the same photograph, and neither is silent: where
the page cannot make the room it says so, and the row stands down and lets the
press through, which is what it did before any of this.

---

## 2. What is needed before it can ship

### 2.1 The rejection risk, stated plainly — *answered, as far as it can be*

An app that is one company's website in a web view meets two review guidelines
head-on: **4.2** (minimum functionality) and **5.2.1** (another party's content
and brand). No code fixes this.

The answer is written and ready to paste, in
[the listing](store-listing.md#review-notes): three paragraphs saying what the
app is, in the order the questions will occur to whoever opens it, plus the one
thing that decides the outcome — a demo account, so a reviewer sees an app
rather than a login page. The name, the subtitle and the icon carry no
third-party trademark, deliberately.

Expect a conversation, not a rubber stamp. That part is not a task anybody can
finish in advance.

### 2.2 A privacy policy and a support page that exist — *now they do*

This section used to say both were written, in `site/`, published to `gh-pages`
by a workflow. None of that was true: there was no `site/`, there was no
workflow, and the `privacy.html` at the root of the repository belongs to a
different app entirely. It is the only thing on this page that has ever claimed
work that had not been done, which is worth recording, because a plan that lies
in one place is a plan nobody can use as a checklist.

They exist now. [`Quiet/site/`](../Quiet/site) holds an index, a privacy page
and a support page, each in English and German, served from what is in the
repository rather than from a copy pasted into a hosting panel — a privacy
policy that has drifted from the app it describes is worse than none, because it
is a wrong answer with a URL. `.github/workflows/pages.yml` publishes them, and
refuses to publish while the support page still carries its placeholder address.

Two things left, both by hand and both once:

> **Settings → Pages → Source: GitHub Actions**

and a real contact address in `site/support.html`, replacing
`support@example.invalid`. The workflow fails until that is done rather than
publishing a page that would fail review a week later.

### 2.3 The listing — *written*

Name, subtitle, promotional text, description, keywords, category, age rating,
privacy answers and the four screenshots with their captions are all in
[the listing](store-listing.md), inside Apple's character limits, with the
reasoning for every arguable choice.

The screenshots themselves come out of the `Screenshots` workflow at 1320 ×
2868 — the 6.9-inch size App Store Connect requires — as a downloadable
artifact.

### 2.4 The first build on a real phone — *the one thing still blocked*

The three secrets go into the repository, then **Actions → TestFlight → Run
workflow**. Everything after the guard in that workflow — archive, export,
upload — has never run, and cannot run until the secrets exist.

The `.p8` private key belongs in **Settings → Secrets and variables → Actions**
and nowhere else. Not in the repository, not in a message, not pasted into a
chat.

### 2.5 English, or not — *decided: both*

Every string is now in a catalogue with an English and a German entry, including
the sentences the app builds rather than writes — the ones that would otherwise
have shipped in English inside a German app. Two of them carry plural rules
rather than an `if`.

German runs about a third longer than English, so the screenshot workflow
photographs every screen in German too, and the layouts are looked at rather
than assumed.

### 2.6 The version on the first upload — *decided: 1.0*

`MARKETING_VERSION` is 1.0 and stays there. The build number comes from the
workflow's run number and only ever climbs, so it never has to be typed.

---

### 2.7 What the store listing now has to say

Three things arrived after the listing was written and belong in it:

* the app asks for camera, microphone and photo permissions — it does not use
  any of them itself, and the strings say so, but the reviewer's questionnaire
  asks;
* there is a way to have the app forget everything, which answers the obvious
  question about a limit kept in the keychain;
* Reels and Explore being deliberately absent is now said on the first screen
  rather than only in the listing.

---

## 3. What is not yet good enough

### 3.1 The icon, on a home screen — *looked at*

`Tools/look-at-icon.py` puts it where it is actually seen: 60 points between
other apps, 40 in Spotlight, 29 in Settings, on a light wallpaper and a dark
one, behind the rounded mask iOS applies whether the artwork expects it or not.

It holds at every size, and reads as a full stop rather than as dust on the
display. The smallest — the App Library — is where it comes closest to reading
as a camera lens, and is the size to look at again if the diameter ever changes.

### 3.2 The moment the curtain arrives — *seen, and answered*

It is now photographed on every push, in three variants, so the composition is
no longer a thing anybody imagines.

It also answers in the hand: one soft tap, the softest iOS has, at the moment it
takes — and only on the transition from reading to spent. Opening the app onto a
day that was already gone stays silent. What is still unjudged is the *feel* of
the fade at the moment it interrupts a scroll, which needs a phone.

### 3.3 The end of the day, in the hand — *decided: one soft tap*

The same argument the long press already won. A screen that replaces itself with
no warning reads as a fault unless something says the app meant it. Not a
notification tone: nothing has gone wrong and nothing has been achieved.

### 3.4 The largest text anyone uses — *photographed*

Every screen Quiet owns is now captured at
`UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge` as well as at the
ordinary size, which is where a serif display line of three words on two lines
and a wheel of numbers are most likely to break.

### 3.5 VoiceOver, from an empty install — *covered by tests*

Four tests drive every screen the way VoiceOver does: no swipes, no long
presses, elements found by the name they are announced under and then activated.
The panel behind the hidden gesture is the one that mattered, and it now has a
test that fails if the element standing in for the press ever disappears.

A real ear on a real phone is still worth an evening. What cannot happen any
more is the app silently becoming unreachable.

### 3.6 Travelling — *fixed*

It was not merely undecided; it was a hole. The local date moves a whole day in
either direction the moment a time zone changes, and a date that was merely
different was being read as a day that had passed — so a flight east handed out
a fresh allowance, and so did the flight back. Changing the zone in Settings did
the same thing without leaving the sofa.

A day now keeps the ending it was given when it began. The day you are in is as
long as it was born to be; the next one starts at 4 a.m. wherever you have
landed.

---

## How to use this

Everything above the line in part 1 needs one evening with a phone, an account
and TestFlight, and those five items are the only ones that can prove the app
does what it says. Below it, one switch (Pages), one upload (TestFlight), and a
conversation with a reviewer.
