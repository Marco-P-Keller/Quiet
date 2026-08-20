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

* **A clock in the navigation bar**, at the end, and a second one on your own
  profile beside Instagram's settings. Settings belong both where settings
  already are and somewhere reachable from wherever you happen to be.
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

All of them are drawn as line icons at Instagram's own weight, size and colour,
because the bars they sit in are a set and anything outside it reads as a fault
rather than as a control.

Quiet's is a clock, and getting there took three tries and a renderer. A bare
dot at twenty-four points beside a gear looked like dust on the display. The
app's own full stop set inside a ring fixed that and read as a record button —
which only became obvious once the thing was drawn at size and looked at rather
than reasoned about. A clock is the drawing everybody already reads as time, and
Quiet is a limit on time; the mark that is the app's own identity can stay on
the icon, where it has a whole square to itself and nothing to be confused
with.

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

## The page keeps the whole screen and is told what is spoken for

Three attempts at the same half-inch of glass, and the first two are worth
writing down because they are both reasonable and both wrong.

Instagram lays its header against the top of whatever it is given, so it ended
up under the clock. **Making the web view shorter** fixed that, and on a real
phone detached the site's own header into the middle of the feed — a sticky
position is laid out against a viewport, and the viewport had moved out from
under a running page. **Asking the page to respect the safe area**, by adding
`viewport-fit=cover` to its viewport meta, did nothing whatsoever: the site's
stylesheet never consults `env()`, so there was nothing to tell.

A **content inset** changes neither the frame nor the viewport. WebKit positions
fixed elements against the unobscured rect, which is exactly what an inset
defines, and it is the same mechanism a browser uses to make room for its own
toolbars. The page keeps the whole screen and is told that the top belongs to
the status bar and the bottom to Quiet's own row.

## Quiet carries the navigation

The search and the clock belonged inside Instagram's navigation bar, and that is
where they twice failed to appear: a row built by somebody else, out of
generated class names, with no room for a fourth child. Both failures were
silent — the app came back looking finished, with no controls at all.

Then they had a row of Quiet's own and Instagram still had its, which is one bar
too many and reads as a mistake even when both work.

So Quiet carries all five: home, search, messages, profile, and the clock for
its own settings. Instagram's row is hidden — after the signed-in name has been
read out of it, which is the one thing only that row knows and the only way a
profile button can exist at all. It is hidden rather than removed, so the name
can be read again on the next page.

The row is found by what is *in* it rather than by where it sits: a link to `/`
and a link to `/direct/`. Both are addresses, so both survive translation, and
neither needs the row to be on screen — which matters, because a hidden element
has no geometry left to measure.

What this costs: the unread badge on messages. Instagram draws that number and
Quiet does not have it.

## No first-run hint

There was a sentence on the first launch saying where Quiet's settings live.
With a hidden gesture it was necessary. With two icons in a row that never
moves, it is one more thing to read — and it arrived before the page did, so
the first thing anybody saw was a bubble on an empty screen.

## Quiet does not draw the header

Five attempts went into leaving Instagram's own header where it was and
persuading it to stay clear of the clock: a shorter web view, which detached the
site's header into the middle of the feed; `viewport-fit=cover`, which did
nothing at all because the stylesheet never consults `env()`; a content inset;
lifting whatever the page had pinned; and an opaque band of the app's own behind
the status bar.

The sixth was to draw the header natively, the way Instagram's iOS app does. It
lasted one build. The photograph of it settled two things at once.

The first: there is no collision to solve. Instagram's header is not stuck to
the top of the glass at all — it scrolls away with the feed, exactly like the
app's. Every fix after the content inset was aimed at a problem that had already
been solved, which is also why the code hunting for a *pinned* header found
nothing to hide.

The second: with Instagram's header still there and Quiet's above it, the app
read as two headers stacked, three points apart. No amount of styling makes that
right.

So the app owns the strip behind the clock and nothing else. The header is
Instagram's own, which carries the controls, the badges and the behaviour, and
is by definition exactly like Instagram.

## The header was drawn through the clock, twice over

A photograph of the running app, with the wordmark, the plus and the heart
struck straight through the battery, and two faults behind it. Both had been
reasoned about at length and neither had been measured.

**The page was never told how tall the status bar is.** The scripts are built
once, in `makeUIView`, out of whatever the height was at that moment — which is
the twenty points the state starts at, because the window has not laid anything
out yet. The real number arrived a moment later and was handed over with
`evaluateJavaScript`, and that is the trap: the page it reached was the empty
one a web view starts on. Instagram's document committed afterwards, ran the
injected script again, and put the twenty points back.

So the number was never wrong for long. It was right on a document nobody ever
saw, and twenty points on the one everybody did — about seven points of
clearance for a fifty-nine point status bar. Every photograph of "the header is
under the clock" was a photograph of this.

It is now said three ways, because one way has already lost it: the scripts are
rebuilt around the real number so every future document is told before its first
paint, the document on screen is told again on every commit rather than once,
and `makeUIView` takes the larger of what the layout reports and what the window
knows rather than trusting the first pass.

**And the bar is pinned after all.** The note above this one says it is not, on
the strength of a photograph; the photograph showed a feed at rest, where a
sticky bar and a bar in the flow look exactly alike. Scrolled, they do not: the
feed slides underneath it and it stays on the clock.

A padding on the document cannot move it. `position: sticky` measures its offset
from the edge of the scrollport, and the scrollport does not care what the
document is padded by — so the padding moves every part of the page except the
one part drawn over the clock. The earlier search for a pinned bar reported
finding none, and that was the search's fault: it looked at six ancestors of one
link, and only at elements as wide as the window. What is pinned is a wrapper.

So trim.js asks the browser — `getComputedStyle`, from the bar upward — and
whatever is pinned within a point of the top gets `top: var(--quiet-clock)`
instead. Once lifted it stays lifted, because a lifted bar no longer answers the
question that found it and would otherwise drop back on the next frame.

`--quiet-clock` is the larger of the app's number and `env(safe-area-inset-top)`,
which needs `viewport-fit=cover` on the viewport meta. That was tried once and
written off as doing nothing whatsoever, on the grounds that Instagram's
stylesheet never consults `env()`. True, and beside the point: the stylesheet
that needs to consult it is ours. The two are kept together because they fail in
opposite directions — the app's number can be stale, and WebKit's is zero on a
phone with no notch.

## The header is rearranged, not rebuilt

What the paragraph above left standing was a real difference, and it is the one
anybody holding both apps sees first. Instagram's app puts the plus on the left,
the title in the middle and the heart on the right. Instagram's website puts the
title on the left and both icons on the right. Same three controls, different
places.

The seventh attempt would have been to draw those three natively and wire them
to the page. It is the obvious move and it is wrong twice over: the plus opens a
picker that no address reaches, and a control drawn by the app cannot carry the
badge Instagram draws on the one it replaced. It also fails the way all six
before it failed — by needing to be right about a document nobody here can see.

So the three are left exactly where they are in the document and moved only in
the layout. `trim.js` finds them — the heart by its address, the wordmark by
its, the plus as the control written next to the heart — marks each with an
attribute, and four rules in `trim.css` put the plus first, the heart last, and
the title in the middle of the bar rather than in the middle of what is left
over. The wrappers in between are given `display: contents`, which stops them
generating a box so that all three become items of the bar itself.

Three properties come out of that, and they are the whole argument:

* **It works and behaves exactly like Instagram**, because it *is* Instagram —
  its plus, its chevron, its heart, its badges, its modals, and a bar that
  scrolls away with the feed because it always did.
* **Nothing is moved in the document.** Instagram's client owns that tree and
  rebuilds it whenever it likes; a node this script had moved would be a node it
  puts back. Where a box is laid out is the browser's business and survives
  every rebuild.
* **Unsure means untouched.** If any of the three cannot be found, or two of
  them turn out to be the same piece of the bar, the header is left precisely as
  Instagram drew it. A header nobody rearranged is a great deal better than one
  rearranged on a guess.

What this costs: the title still says whatever Instagram's website says, which
today is the wordmark rather than the app's "For you". That word belongs to the
control underneath it, and the control is the site's own — putting a different
word on somebody else's button is how you end up with a header that lies about
where it goes.

The finding is now testable without a device. `Tools/read-the-header.js` writes
the bar as a document and asks trim.js what it makes of it, which caught a fault
no photograph would have shown for a week: the plus was being picked out as the
control furthest to the right, and on the second pass — after the stylesheet had
moved it to the left — that was the chevron. The two would have swapped places
sixty times a second.

The lift is checked there too, and separately, because the two are different
questions. Rearranging is a nicety and gives up the moment it is unsure. A
header drawn through the clock is the app looking broken, and has to be put
right even on a page whose bar is a shape nothing here recognises.

## The row marks where you are

A row of five outlines, none of them filled, is a toolbar. Instagram's is not:
the symbol you are standing on is solid, and a lighter capsule sits behind it.
That one difference is most of what makes it read as a place.

So Quiet's does the same, for all five — including the two screens that are the
app's own, the clock and the search, which are marked while they are open.

It costs a piece of state the app had just thrown away: the address on screen.
Instagram's client changes it without loading anything, so the navigation
delegate never hears about it and the row would go on marking the page you were
on three taps ago. The trimming script says where the page went; that is the
only reason it says anything about addresses at all.

What this costs: the unread badges. Instagram draws a red dot on messages and on
your own face, and Quiet does not have those numbers — they are drawn by the row
that gets hidden, and no address carries them.

The row also sits low now, over the home indicator, where Instagram's sits. The
page runs on beneath it to the bottom edge of the glass. A row that floats above
a page that stops underneath it is the worst of both.

## The page gets the whole screen

Seven attempts went into the half-inch of glass above the feed. A shorter web
view, a `viewport-fit`, a content inset, lifting whatever the page had pinned, a
native header, an opaque band behind the status bar. Every one of them took
something away from the page so the clock would stay legible.

A photograph with two circles drawn on it showed what they all had in common:
whatever is taken off the top comes back as a black strip along the bottom,
above the row, exactly where Instagram runs its next photograph. The two
complaints — "the black bar at the top" and "there must be content under the
navigation bar" — were one fault seen from both ends.

So nothing is taken. The web view owns every pixel, the page fills it, and
content runs behind the status bar and beneath the row the way it does in
Instagram's own app.

What keeps the clock legible is a padding on the document, not an inset on the
view: the first thing in the feed starts below the status bar and scrolls up
behind it. The height is handed to the page by the app, because only the app
knows how tall this phone's status bar is — twice, in fact, since the first
injection happens before the real number is known and the page is told again on
the page as soon as it is.

The scroll indicator is the one thing that still respects the app's furniture. A
scroll bar running under the row reads as a fault.

## The row answers the finger

Two things every tab bar on iOS has done since there were tab bars, Instagram's
included, and neither of which Quiet's row did.

A tap on the entry you are already standing on takes you to the top of it,
rather than loading the page you are already looking at all over again.

And every tap gives a tick under the thumb — light, and from a generator that is
kept alive and told to get ready, because an impact asked for cold arrives late
enough to feel like it belongs to a different tap.

Neither is visible in a screenshot. Both are most of what "it doesn't feel the
same" means when somebody says it about a row of icons that already looks right.
