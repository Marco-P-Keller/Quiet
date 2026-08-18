# Quiet

Instagram, minus the parts that were built to keep you there — and a daily limit
that cannot be lifted in the moment it starts to bite.

An iPhone app. SwiftUI, iOS 17, no third-party dependencies, no servers, no
account, no analytics, and not a single permission prompt.

---

## What it does

Open the app. There's your feed. Your stories. Your DMs. Your profile.

What's gone is Reels, Explore, and the accounts Instagram wedges between your
friends' posts. You sign in on Instagram's own page, inside a web view — the
password never passes through any code in this repository.

Then there's the limit. You set how much time you want each day. When it's up,
the screen ends the day and there is nothing on it to argue with.

**The rule that makes it work is asymmetric:**

| You ask for | When it applies | What it costs |
| --- | --- | --- |
| **Less** | Immediately | Nothing. As often as you like. |
| **More** | The next day | Your one change for the week. |

Most limits fail because you can lift them the second they get annoying. This
one can't be: raising it never returns time to the day you're already in, and
the next raise is seven days away. The decision belongs to the version of you
who isn't already scrolling.

## Building it

Requires Xcode 16 or later.

```sh
open Quiet.xcodeproj     # then set your team and bundle identifier, and Run
```

The bundle identifier ships as `com.example.quiet`. Change it in the target's
Signing & Capabilities before running on a device.

If the project file ever refuses to open, `project.yml` regenerates an
equivalent one:

```sh
brew install xcodegen && xcodegen generate
```

Tests: `⌘U`, or

```sh
xcodebuild test -scheme Quiet -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

They also run on every push — see [What is verified](#what-is-verified).

The app icon is drawn by a script rather than checked in as a mystery PNG:

```sh
python3 Tools/make-icon.py
```

## How it is put together

```
Quiet/
├── Core/          Pure logic. Foundation only, no UI, no WebKit.
│   ├── QuietDay        The day, which begins at 4 a.m.
│   ├── TimeSource      A clock that will not run backwards
│   ├── LimitPolicy     The rule above, as ~60 lines of pure functions
│   ├── UsageLedger     Today's total, and nothing else
│   ├── ContentRules    Which addresses open and which do not
│   ├── Storage         Four keys, one protocol
│   └── Notice          One sentence, for three seconds
├── Platform/      Keychain.
├── Session/       QuietSession — which screen, how much is left, what changed.
├── Web/           The web view, and the CSS and JavaScript injected into it.
└── UI/            Three screens and a panel.
```

`Core` knows nothing about the rest. Everything worth arguing about lives there,
which is why it is also where the tests are.

### The three layers that remove Reels

Defence in depth, in order of how much weight each carries:

1. **`ContentRules`** refuses to open the addresses. This is the layer that
   holds, because URLs are part of how Instagram works and do not change when
   somebody reorganises a stylesheet. It matches whole path components, so
   `/reels/` is blocked and the profile `@reelstuff` is not.
2. **`trim.css`** hides the entrances, so nothing invites a tap that would then
   be refused. Every selector matches on an address or an ARIA role — never on a
   class name, because Instagram's class names are generated and change weekly.
3. **`trim.js`** catches what the other two cannot: suggestion blocks, which
   carry no address and can only be recognised by their wording, and route
   changes made by Instagram's own client without loading a page.

If the trim files ever fail to load out of the bundle, the app says so on screen
in red rather than quietly becoming the thing it replaces.

### How the limit holds

* **Time is counted from device uptime**, never from differences between
  wall-clock readings. Changing the date does not add minutes.
* **Only foreground time counts** — and only while Instagram is actually on
  screen. Not while the panel is open, not while the phone is locked.
* **The day starts at 4 a.m.**, so a session that runs past midnight does not
  collect a second allowance at exactly the wrong hour.
* **The clock cannot run backwards.** Quiet remembers the furthest point in time
  it has seen and refuses to report anything earlier, so turning the date back
  freezes time rather than granting a fresh week.
* **State lives in the keychain**, which outlives the app. Deleting Quiet and
  installing it again does not reset your limit or your weekly cooldown. This is
  stated in setup, before you choose, because nobody should find it out by
  accident.

## Craft

The parts that are easy to skip and obvious once missing:

* **Dynamic Type everywhere.** Every size is a system text style; nothing is set
  in fixed points. Setup and the limit screen are built around scroll views with
  the action pinned to the bottom, so they still work at the largest settings.
* **VoiceOver reaches the hidden gesture.** The status-bar strip is a labelled
  element with a button's trait and responds to a double tap — otherwise the
  panel would be unreachable while browsing.
* **Reduce Motion is honoured** by every animation in the app.
* **A cover, not a spinner.** Quiet's own paper sits over the web view until the
  first page settles, then cross-fades, so a cold launch never shows a blank
  white rectangle. It lifts on failure too.
* **One haptic**, at the moment the long press takes, so the gesture feels like
  a control rather than a guess.
* **No permission prompts at all**, and no networking of Quiet's own.

## What is verified

Every push that touches this folder builds the app and runs its tests on a
macOS runner with a real Xcode and a real simulator. The current state:

```
** BUILD SUCCEEDED **
Executed 57 tests, with 0 failures
```

No errors and no warnings in Quiet's own sources. The workflow is
[`.github/workflows/quiet.yml`](../../.github/workflows/quiet.yml); a red run
prints a digest naming the errors, the failed tests and the warnings, so
nobody has to read four thousand lines of module compilation to find out what
broke.

The tests cover the whole of `Core` and the session's state machine: every
branch of the limit rule, the day boundary across a daylight-saving change, a
rewound clock, and the property that makes it safe to reach settings from the
curtain — nothing there can give today's time back.

That suite earned its keep on its first real run. It caught two defects that
had survived several careful readings:

* **The app was unusable from its second launch.** A guard read
  `screen != .setup`, which looks like "setup is not finished" and is not: at
  launch the screen still holds its initial value, so the guard fired every
  time and nothing ever moved on to the feed. A returning user would have seen
  the onboarding question forever.
* **The day boundary was wrong twice a year.** It was computed by adding four
  hours to midnight, which lands on 05:00 on the morning the clocks go
  forward — and it moved the boundary without moving the day's identity, so
  the two disagreed about which day it was.

Two things still need a person and a device, because no test can stand in for
them:

* that Instagram serves the full mobile site to the user agent in
  `UserAgent.mobileSafari(systemVersion:)`, and
* that the selectors in `trim.css` still match. They are the part of this app
  with a shelf life.

## The trade

Quiet runs on Instagram's mobile site, so pages load a beat slower than the
official app and some things are missing: posting, most of the camera, and
anything Instagram ships only in its own client. Reels sent to you in a DM will
not open. There is no search page, because search is where Explore lives — the
panel has a box that goes straight to a username instead.

If you want every feature Instagram ships, keep using Instagram. This is for
seeing what your friends posted and then putting the phone down.

Longer versions of all of this: [decisions](../docs/decisions.md),
[trade-offs](../docs/trade-offs.md), and
[what the App Store and Instagram's terms have to say](../docs/store-and-legal.md).

---

Quiet is not affiliated with or endorsed by Instagram or Meta.
