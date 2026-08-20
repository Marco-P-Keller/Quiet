# Decisions

Every one of these was a fork in the road. They are written down because in six
months the reasons will be gone and only the code will be left.

---

## The day begins at 4 a.m., not at midnight

A midnight reset hands out a second daily allowance at 00:00 — the exact moment
self-control is thinnest and the exact moment a lot of scrolling happens. The
hours after midnight belong to the evening you are still awake in.

Four in the morning is late enough to be past almost everyone's evening and
early enough that a normal day starts with a full allowance.

## Asking for less is free; asking for more waits

The single most important decision in the app.

A symmetric limit — one you can move up or down whenever you like — is not a
limit, it is a suggestion with extra steps. But making *reductions* hard would
be user-hostile: the app should never stand between someone and a smaller
number.

So the rule is asymmetric:

* **Down: immediately, always, free.** It does not consume the weekly change.
* **Up: from tomorrow, once a week.**

Both halves of the "up" rule are load-bearing.

*Once a week* makes the decision rare enough to be deliberate. *From tomorrow*
makes it impossible to be made in the moment it would help — with the curtain
already down, five minutes from the end, at the point where the argument is not
with the app but with yourself.

Together they have a property worth stating plainly: **no change made anywhere
in the app can return time to the day you are already in.** That is what makes
it safe to put a way into settings on the curtain, which in turn is what stops
the curtain from being a trap you cannot get out of. One rule, two problems
solved.

## A reduction does not reset the weekly clock

The hole this closes: raise the limit on Monday, drop it on Tuesday, raise it
again on Wednesday. If reductions cleared `lastIncrease`, the weekly rule would
be one extra tap away from meaningless.

`LimitPolicyTests.testLoweringDoesNotClearAnEarlierIncrease` is that hole, nailed
shut.

## A queued increase can be revised downward

If you asked for 120 minutes yesterday and wake up thinking better of it, you
can change it to 45 before it takes effect without spending another week. It is
still asking for less. The cooldown keeps running from the original decision.

## Time is counted from uptime, not from the clock

Two independent time systems, on purpose:

* **How much you have used** comes from `ProcessInfo.systemUptime`, which no
  settings screen can change. Moving the date does not add minutes.
* **Which day it is, and when the week is up** comes from the wall clock, which
  *can* be changed — so it is wrapped in `MonotonicClock`, which never reports a
  time earlier than one it has already seen.

Turning the clock back therefore buys nothing: it freezes the calendar until the
real time catches up. Turning it *forward* cannot be detected without a server,
and Quiet has no server. That is a deliberate trade, written into the About
screen rather than hidden.

## The keychain, not UserDefaults

Keychain items outlive the app that wrote them. Delete Quiet, install it again,
and the limit and the cooldown are exactly where you left them.

This is the whole point — a limit you can clear by holding an icon and tapping
Delete is not a limit — and it is also the app's one genuinely surprising
behaviour. It is stated in setup, in plain words, on the screen where the limit
is chosen, before anything is committed. Surprising and disclosed is fine.
Surprising and discovered later is not.

## No visible countdown

A timer on screen turns every minute into something to watch, and watching the
clock is its own kind of compulsion. Quiet says two things and then stops: at
five minutes and at one minute, once each per day. The remaining time is in the
panel, for the moments you actually want to know.

## No notifications, no permissions, no analytics

The app asks for nothing. No push permission, no photo access, no location, and
no analytics of any kind. An app about attention should not be sending push
notifications, and an app that tells you it has no tracking should be able to
prove it by having no networking code at all.

## Everything Quiet adds to the page is added *to* the page

There were three attempts at this and the first two were wrong in the same way:
they had the app draw something over somebody else's screen.

First a long press on the status bar. It worked, and it was a trick you had to
be told about — so most people would never have it. Then a faint dot in a corner
the app kept for itself: always visible, which was the point, and always
*there*, floating over the feed on every screen including all the ones where
nobody was looking for it.

The answer was to stop drawing. The trim script puts two things into the page
itself, in the two places Instagram left empty:

* **A full stop beside Instagram's settings**, on your own profile and nowhere
  else. Settings belong where settings already are.
* **The search, back in the slot Instagram's own search used to occupy.** Its
  search tab is the front door to Explore, so it stays shut; this one opens
  Quiet's, which returns people and nothing else.

Both are found by **where they are on the screen** rather than by what they are
called: a control in the top-left corner, and the home button in the bar along
the bottom. Names are translated and class names are generated afresh every
week; a corner is a corner. The first version looked for a link to
`/accounts/edit/` and found the *Edit profile* button halfway down the page,
which is exactly the kind of near-miss a selector gives you and a corner does
not.

Drawn by the page, they inherit Instagram's own sizing, spacing and colour, and
they scroll away with the bars they belong to. The labels come from the app, so
they are announced in the reader's own language.

The long press is gone. An app used every day should not need a trick, and once
the visible doors exist the trick is one more thing to explain.

## Search is for people, and it lives in the panel

On Instagram's mobile site, search and Explore are the same tab: tapping search
shows the discovery grid. Blocking the grid means blocking the way to look
someone up, and hiding the grid with DOM heuristics while leaving the field
working would be fragile in exactly the way the rest of the app avoids. So the
tab is blocked outright.

The first answer to what that costs was a box in the panel that went straight to
`instagram.com/<handle>/`. It was robust — no selectors, nothing to break — and
it was wrong, which the first hour of real use said plainly: it takes a username
you already know, spelled exactly, and nobody knows how their friends spell
themselves.

So the panel does the searching. It asks Instagram the same question Instagram's
own search asks, from inside Instagram's own page, with the page's own cookies —
so it is the site's real answer, and Quiet still makes no request of its own.
What comes back is filtered to people and cut to six. No hashtags, no places, no
posts, no grid: the objection was never to searching, it was to everything a
search *page* carries with it.

It is the one part of the app that depends on an endpoint nobody promised to
keep, so it fails in a way that says so — "Search is not answering" rather than
"nobody by that name" — and typing an exact name still goes straight there.

## Hashtag links are left visible but refused

`/explore/tags/…` is blocked like the rest of Explore, but the links are *not*
hidden in captions. Deleting them would edit what a friend actually wrote.
Tapping one says "Explore is off in Quiet."

A hole in a sentence is a bigger lie than a refused tap.

## Refused taps say so

Silence reads as a broken app. An apology reads as an accident. Neither is true,
so the app states what it did — one sentence, three seconds, nothing to dismiss.

## Autoplay is off

`mediaTypesRequiringUserActionForPlayback = .all`. Video plays when you ask it
to. It is the smallest of the hooks and among the easiest to remove.

## Links off Instagram open in Safari

A bio link opens in the system browser, not in Quiet. Two reasons: the app
should not quietly become a general-purpose browser, and leaving the app stops
the timer — reading an article someone linked is not Instagram time.

## The curtain does not force-quit the app

The description of Quiet says "the app closes". It does not, technically:
iOS gives no supported way for an app to terminate itself, `exit(0)` is grounds
for App Review rejection, and to a person it looks exactly like a crash.

What it does instead is end: a full screen with one sentence, the time it opens
again, and nothing to press. That is closing, in every sense that matters to the
person holding the phone.

The one way to make the *icon itself* stop working is Apple's Family Controls
and Device Activity framework, which can shield an app system-wide. It needs an
entitlement granted by Apple on request. If Quiet is ever more than a personal
project, that is the upgrade path — see
[store-and-legal.md](store-and-legal.md).

## Quiet's own screens look nothing like Instagram

Warm paper, a serif, wide margins, one thing to read at a time. The contrast is
the point: when the curtain comes down, it should feel like leaving a room, not
like a modal in the same app.

## One type scale, tied to the system's

Every size in the app is a system text style — `.largeTitle` through `.caption`,
with the serif applied on top of the big ones. Nothing is set in fixed points.

Fixed sizes look correct exactly once: on the machine they were chosen on. A
person who has turned text up two notches, which is a great many people, gets an
app that either crops or lies about how much it can show. Four of the screens
were rebuilt around scroll views with the action pinned to the bottom edge so
that they still work at the largest settings rather than merely surviving them.

## A cover over the web view, not a spinner

A cold launch used to show the white rectangle of a web view that has not
painted, then Instagram arriving in pieces. Quiet now holds its own paper over
the top until the first page settles, and cross-fades.

Not a spinner: a spinner says "we are busy", and this is a third of a second on
a good connection. Paper says "the app has started", which is the true thing.
The cover lifts on failure as well as on success — otherwise someone offline
would be left looking at a blank page with no way to know why.

## The long press answers with a haptic

A long press that does nothing until a sheet appears is indistinguishable from
a long press that did not work. One soft tap at the moment the gesture takes is
what every long press on iOS does, and it is the difference between a control
and a guess.

## The hidden gesture is taught three times, not once

A gesture explained exactly once, on the busiest screen of the first run, is a
gesture most people will not have a week later. Quiet points it out on the first
launch of each of the first three days and then stops.

This cost nothing to store. The fourth thing the app remembers used to be a
boolean — *is setup done* — and is now the day setup finished, which answers the
same question and this one too.

## VoiceOver can reach everything a finger can

The status-bar strip is an accessibility element with a button's trait, labelled
and hinted, and it responds to a double tap without any holding. Without that,
the panel would have been unreachable while browsing for anyone using VoiceOver
— an invisible gesture is invisible in both senses.

Animations check `accessibilityReduceMotion` before running.

## Errors appear where the question was asked

"Find someone" used to answer a bad username with the app's floating notice —
which renders on the browsing screen, underneath the very panel the person was
typing into. The answer was invisible. It is now a line under the field, in
place of the explanation that normally sits there.

The general rule this came from: an answer belongs on the surface that asked the
question, not on the one behind it.

## The tests were run, not just written

The project spent a while in the state where the reasoning was sound, the code
read well, and nothing had ever been compiled. Building it on a macOS runner
was the difference between an argument and a fact, and it cost one afternoon.

It found two defects that several careful readings had not. One of them —
a guard on `screen != .setup` that never let the app leave onboarding — would
have made the app unusable from its second launch. It is four words long and
it looks correct.

The lesson is not "write more tests". The suite already existed and already
described the right behaviour. The lesson is that a test nobody has run is a
document, and a document cannot fail.

## The keychain is not allowed to fail quietly

`KeychainStore` used to ignore every status code the Security framework
returns — `_ = SecItemAdd(...)`. It looked tidy. What it actually bought was
the worst failure this app can have: a store that declines writes and says
nothing turns "your limit outlives the app" into every launch a clean slate,
while the app goes on looking perfectly healthy.

It took photographing the running app to notice. The screenshot after the UI
test showed the setup question again, seconds after the test had answered it.
With the status codes recorded, the device log said it in one line:

    Quiet: keychain update failed with -34018 (A required entitlement isn't present.)

That turned out to be the build, not the app: CI had been passing
`CODE_SIGNING_ALLOWED=NO` to avoid needing a development team, and an unsigned
build carries no `application-identifier` entitlement, without which iOS
refuses the keychain outright. The override is gone; a simulator destination
signs ad-hoc without a team.

Two things stay from it. The store now records refusals and the app says so in
the one red banner it owns, alongside the warning for missing trim files —
both are failures silent enough to go unnoticed, and neither is allowed to be
discovered by accident. And the UI test now closes the app, opens it again,
and insists that setup does not come back, so the promise is checked rather
than assumed.

## A day keeps the ending it was given when it began

The day turns at 4 a.m. wherever you are, which quietly makes the time zone part
of the rule — and a time zone is two taps in Settings, with no clock change for
the monotonic guard to notice.

The local date moves a whole day in either direction the instant a zone changes.
The app was reading a date that was merely *different* as a day that had
*passed*, so both directions handed out a fresh allowance: fly east, get twenty
minutes; fly back, get twenty more; or skip the flight and use Settings.

The ending is now decided when a day begins and does not move. The day you are
in is as long as it was born to be, and the next one starts at 4 a.m. wherever
you have landed. One honest turnover and the app has fully adopted the new zone,
which is the behaviour somebody who has actually emigrated wants.

## The curtain answers in the hand

The long press already won this argument: a control that does nothing visible
feels broken, and one soft tap at the moment it takes is what makes it read as a
control rather than a guess.

A screen replacing itself mid-scroll has the same problem in a larger form. One
soft tap — the softest iOS has, not a notification tone, since nothing has gone
wrong and nothing has been achieved — and only on the transition from reading to
spent. Opening the app onto a day that was already gone stays silent: a phone
that buzzes at you for something you did yesterday has misunderstood the app.

## The app speaks German as carefully as it speaks English

Quiet is almost entirely a piece of writing. Sixty-odd sentences, each one
argued over, are the whole interface — so shipping them in a language its reader
does not think in would throw away most of what the app is.

Both languages live in one catalogue. The trap was never the sentences in `Text`,
which SwiftUI translates on its own; it was the ones the app *builds* — the
button that says "Ask for 30 minutes a day", the notice that says "Two minutes
left." A `Text` of a `String` variable is verbatim by design, so those would have
shipped in English inside a German app, looking for all the world like a
finished translation. Every one is now looked up explicitly.

## A debug-only way to stand on any screen

The curtain is the moment the whole app turns on, and reaching it honestly costs
the shortest limit the app allows: five minutes of watching a simulator. So
nobody ever looked at it, and it went to the App Store listing unexamined.

`Rehearsal` writes the state a named scene needs — an empty install, a spent day,
the panel open — through the same store the app writes to, and then gets out of
the way. It is wrapped in `#if DEBUG` in its entirety: none of it exists in a
build anybody can install, and it holds no opinion about how the app behaves,
which is the only thing that makes a rehearsal worth trusting.

## Quiet opens on the login form, not on instagram.com

Signed out, `instagram.com` serves a page whose largest element is a purple
button that opens Instagram's own app, with "Log In" underneath it in small
grey letters. That is the one door out this app exists to close, offered before
you have even signed in — and it was the first thing a new user saw.

Quiet opens at `/accounts/login/`, which is the form a person came to use. A
signed-in session is sent straight on to the feed.

## The page starts below the status bar

The web view used to run under the status bar, because the strip that opens the
panel wants to sit against the glass. The page does not know it is inside an
app: it lays its header against the top of whatever it is given, so Instagram's
own logo ended up under the clock.

The page now begins below the status bar, and the band above it is painted in
the page's own background colour so the seam does not show. The bottom still
runs to the edge, which is where the page's own navigation belongs.
