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
open Quiet/Quiet.xcodeproj     # then set your team and bundle identifier, and Run
```

The bundle identifier is `com.connexa.quiet` and the team is `B97SQSQBMR`,
both already set in the project. Running on your own device needs nothing
further; running on somebody else's needs their team instead.

## TestFlight

`.github/workflows/testflight.yml` archives, signs and uploads. It runs only
when somebody presses the button — Actions → TestFlight → Run workflow — never
on a push, because an upload puts a build under a real developer account and
consumes a build number App Store Connect will not give back. The build number
comes from the run number, so it only ever goes up.

It needs three repository secrets, added under Settings → Secrets and
variables → Actions:

| Secret | Where it comes from |
| --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Users and Access → Integrations |
| `APP_STORE_CONNECT_KEY_ID` | the same page, next to the key |
| `APP_STORE_CONNECT_PRIVATE_KEY` | the contents of the downloaded `.p8`, whole file |

The key is downloadable exactly once, so keep a copy somewhere safe. It grants
access to the developer account, which is why it belongs in Actions secrets
and nowhere else — not in the repository, not in a chat.

Two things have to exist in App Store Connect first, and neither can be done
from CI: the bundle identifier registered in the developer portal, and an app
record created against it. After that the workflow signs itself — Xcode
creates the certificate and profile through the API key.

Uploading is not submitting. The build lands in TestFlight; review is a
separate, deliberate step, and
[what it will run into](docs/store-and-legal.md) is worth reading first.

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
* **The way into the panel is a button as well as a gesture.** On your own
  profile the trim script puts Quiet's mark beside Instagram's own settings, so
  the app draws nothing over anybody's feed. Everywhere else it is the long
  press, and the status-bar strip carries a labelled accessibility element
  because a gesture is invisible to a screen reader.
* **Reduce Motion is honoured** by every animation in the app.
* **A cover, not a spinner.** Quiet's own paper sits over the web view until the
  first page settles, then cross-fades, so a cold launch never shows a blank
  white rectangle. It lifts on failure too.
* **One haptic**, at the moment the long press takes, so the gesture feels like
  a control rather than a guess.
* **No permission prompts at all**, and no networking of Quiet's own.

## What is verified

Every push that touches this folder builds the app, runs its tests, launches
it on a simulator and photographs it. The current state:

```
** BUILD SUCCEEDED **
Executed 62 tests, with 0 failures        (rules, clock, ledger, session)
Executed 1 test,  with 0 failures         (setup → Instagram → relaunch)
```

No errors and no warnings in Quiet's own sources. The workflow is
[`.github/workflows/quiet.yml`](.github/workflows/quiet.yml); a red run
prints a digest naming the errors, the failed tests and the warnings, and a
screenshot of the app in whatever state it reached.

What the photographs actually settled, none of which a unit test could:

* **The app launches, and Instagram's real mobile site loads inside it.** The
  user agent is accepted; no "unsupported browser" wall.
* **The trim works.** The bottom navigation arrives with three entries — home,
  messages, profile. Search and Reels are gone from the page itself.
* **The limit outlives the app.** The UI test closes it, opens it again, and
  insists the setup question does not come back.

A review of the whole branch against `main` then turned up eleven more, none
of them in the rule engine and all of them in the glue: an unreachable
one-minute warning, a confirmation shown on a screen that renders none, a
`closest("section")` that could climb past `<main>` and blank the page, a day
that could not turn while the curtain sat open past four in the morning, and
seven others. They are in the history with their reasons.

A security pass over the same diff found one more, and only one. Any page
inside the web view could name a URL scheme, and the app handed every one of
them to iOS, which opens the matching app without asking anybody — the move
`instagram://` was already refused for, minus the name. Six schemes leave the
app now: a link, an address, a phone number, a message, the App Store.
Everything else is cancelled in silence. Nothing else in that pass rose to a
finding: the workflows never echo a secret and never interpolate their input
into a shell, the injected script escapes through `JSONSerialization`, the
handle field is charset-checked against a fixed host, and the keychain entry
is device-only, in no access group, and holds a number of minutes.

Four defects were found by running it, all of which had survived careful
reading:

* **The app was unusable from its second launch.** A guard read
  `screen != .setup`, which looks like "setup is not finished" and is not: at
  launch the screen still holds its initial value, so nothing ever moved on to
  the feed.
* **The day boundary was wrong twice a year.** Computed by adding four hours to
  midnight, which lands on 05:00 on the morning the clocks go forward.
* **The keychain was failing in silence.** Every status code was discarded, so
  a store that refused writes looked identical to one that worked — while the
  app's one promise quietly stopped being true.
* **Instagram's own page offers a way out.** A button that opens Instagram's
  app, which the URL rules were politely handing to the system.

One thing still needs a person with an account, because a data centre has no
Instagram login: whether the trim holds on a **signed-in** feed, where the
navigation has five entries and posts arrive with suggestions between them.
Everything above was checked logged out.

## The trade

Quiet runs on Instagram's mobile site, so pages load a beat slower than the
official app and some things are missing: posting, most of the camera, and
anything Instagram ships only in its own client. Reels sent to you in a DM will
not open. Instagram's search tab is where Explore
lives, so it is gone — the panel searches for people instead, and returns
people only.

If you want every feature Instagram ships, keep using Instagram. This is for
seeing what your friends posted and then putting the phone down.

Longer versions of all of this: [decisions](docs/decisions.md),
[trade-offs](docs/trade-offs.md), and
[what the App Store and Instagram's terms have to say](docs/store-and-legal.md).
What has not been answered yet, in the order it matters:
[what is left](docs/what-is-left.md). Everything the App Store asks for,
written out: [the listing](docs/store-listing.md).

---

Quiet is not affiliated with or endorsed by Instagram or Meta.
