# What is left

Everything in this list is either unverified or undecided. Nothing here is a
vague improvement: each item names what to do, why it matters, and how you
would know it came out right.

The order is deliberate. The first group decides whether the app works at all
for the person holding it. The second decides whether it can ship. The third is
the difference between an app that works and one worth keeping on the first
screen.

What is *not* on this list is anything the runner can already answer: the build,
the 62 unit tests, the UI test that walks from an empty install to Instagram and
back through a relaunch. Those run on every push and are green.

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

### 1.3 Logging in, all the way through

`ContentRules.internalDomains` holds five domains. A real sign-in can pass
through two-factor, a "save your login info" page, a security checkpoint, or
Facebook. Any of those on a sixth domain gets handed to Safari, and the login
dies halfway.

**Check:** sign in from a clean install, with 2FA on. **This is the failure that
makes the app useless on first run**, so it is the single most important thing
on this page.

### 1.4 Whether being signed in survives

The web view uses the persistent data store, so it should. Nobody has confirmed
it across a cold launch.

**Check:** sign in, kill the app, come back tomorrow morning. You should not see
a login page.

### 1.5 Posting a photo

`Info.plist` declares no `NSCameraUsageDescription` and no
`NSMicrophoneUsageDescription`. If a page's file input offers the camera, iOS
terminates the app on the spot — no crash report that names the cause, just a
disappearing app.

**Decide, then do:** either add both strings, or establish that posting from
Quiet is not a thing and watch what actually happens when someone taps `+`.
Leaving it as it is means the app can be killed by a tap.

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

---

## 2. What is needed before it can ship

### 2.1 The rejection risk, stated plainly

An app that is one company's website in a web view meets two review guidelines
head-on: **4.2** (minimum functionality) and **5.2.1** (another party's content
and brand). No code fixes this.

What helps: Quiet is a limiter, not a viewer — the daily budget, the weekly rule
and the removed surfaces are the product, and Instagram is the thing being
limited. Write the review notes to say that in three sentences, and hand the
reviewer a demo account. Expect a conversation, not a rubber stamp.

### 2.2 A privacy policy and a support page that exist

App Store Connect requires both as live URLs. Quiet collects nothing, which
makes the policy short — but a short page still has to be somewhere.

### 2.3 The listing

Screenshots at 6.9" and 6.5". Name (30 characters), subtitle (30), description,
keywords, age rating. The "not affiliated with or endorsed by Instagram or Meta"
line belongs in the description too, not only inside the app.

### 2.4 The first build on a real phone

The three secrets in the repository, then **Actions → TestFlight → Run
workflow**. Everything after the guard in that workflow — archive, export,
upload — has never run. Until it does, "it builds" and "it ships" are different
claims.

### 2.5 English, or not

Every string is English and written in the source. If the first person to use
this reads German, that is the first thing they notice. Either decide English is
the voice of the app, or move the strings into a `Localizable.strings` and mean
it — half a translation is worse than none.

### 2.6 The version on the first upload

`MARKETING_VERSION` is what a person sees; the build number comes from the run
number and only ever climbs. Confirm 1.0 is what you want written down forever,
because the first upload fixes it.

---

## 3. What is not yet good enough

### 3.1 The icon, on a home screen

It has only ever been judged as a file. Put it between other apps, in light and
dark, and in the App Library where it gets shrunk. A full stop has to still read
as a full stop at 40 points, and must not read as a bug on the screen.

### 3.2 The moment the curtain arrives

It fades in over 0.3 seconds, mid-scroll, without warning beyond the two
notices. It is the one dramatic moment the app has, and it has never been seen
by anyone. Watch it happen on a phone. If it feels like a crash, it is wrong; if
it feels like a page being closed, it is right.

### 3.3 The end of the day, in the hand

The long press answers with a haptic. The day ending does not. Consider one —
soft, once. Consider also that silence may be the better answer. Either way it
should be chosen rather than left.

### 3.4 The largest text anyone uses

Every size is a system text style, so it scales. Nobody has looked at the
curtain or the panel at the largest accessibility size, where a serif display
line and a wheel of numbers are both at risk.

### 3.5 VoiceOver, from an empty install

The status-bar gesture carries an accessibility element so the panel is
reachable. The whole path — setup, the wheel, browsing, the panel, the limit
screen — has never been driven with the screen curtain on.

### 3.6 Travelling

The day turns at 4 a.m. local, and the boundary is computed against the current
calendar. Fly two time zones and something has to give: either the day gets
short or it gets long. Decide which is correct before someone discovers it
mid-flight.

---

## How to use this

Items 1.1 through 1.5 need one evening with a phone, an account and TestFlight.
They are also the only ones that can prove the app does what it says. Everything
in part 2 is paperwork and decisions, and can be done while waiting for review.
Part 3 is the part that takes taste rather than time.
