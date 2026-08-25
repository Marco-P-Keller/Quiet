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

## The row is a different shape on a phone with a home button

Instagram does not draw the same bar on every iPhone, and neither does iOS.

A phone with a home indicator reserves a strip along the bottom for the system,
so the row floats above it: a pill, inset from both edges, the page running
underneath and out to the bottom of the glass.

A phone with a home button reserves nothing there, and a floating pill on one
leaves a band of nothing beneath it — the exact fault this project spent a day
removing from the top of the screen. So on those phones the row *is* the bottom
edge: full width, flush, a hairline above it, no shadow, no shrinking as you
scroll, and no capsule behind the entry you are on. It marks its place the way
those bars always have, by filling the symbol.

The two are told apart by the only thing that actually distinguishes them —
whether the system reserves anything at the bottom. Not by screen size, and not
by a list of model names that goes stale every September.

The insets are read from the window when the screen is built rather than
defaulted and corrected on appear. A wrong first answer used to cost a few
points of padding; now it would draw the row in the wrong shape for a frame.

## The status bar height comes from the view that owns the pixels

The page has to be told how tall the status bar is — it starts the feed below
the clock with that number, and the rule that lifts Instagram's pinned bar off
the clock uses it too. The app has now got it wrong twice, from two directions.

Asking the window answers twenty points until something has been laid out. A
SwiftUI state that starts at twenty and is corrected on appear is corrected
after the scripts have been built out of it. Both were in place, both were
wrong, and the photograph shows the result: no padding at all and a wordmark
drawn through the battery.

So the number comes from `safeAreaInsetsDidChange` on the web view itself. That
is UIKit telling the view that owns those pixels what its own safe area is, at
the moment it knows, and it cannot be early. The value only ever moves upward
from a floor of twenty, so a source that has not woken up cannot walk a correct
answer back down to its own default.

## The floor under a bar that is no longer there

Instagram pads the bottom of the feed so its own fixed row cannot cover the last
post. Quiet hides that row, and `display: none` takes the row out of the layout
and leaves the padding — a band of nothing under Quiet's own row, where
Instagram runs its next photograph.

It was blamed on the app's content inset for three commits, and taking the inset
away did not move it. It was never the app's.

The ancestors of the row are asked what they are padded by, and enough of it is
taken up. Only ancestors, only the bottom, and only when there is enough of it
to be a reservation rather than a margin somebody chose.

## Your profile uses Instagram's own link

The app knows the signed-in name and can build the address from it. That is one
deduction too many for a button marked "your profile": a name read a moment too
early sends somebody to a stranger, or to a page that does not exist, and this
is the one button in Quiet where that is unforgivable.

The row Quiet hides carries the link Instagram itself uses, and it is hidden
rather than removed precisely so it still knows where it goes. The address built
from the name is the fallback, for pages that carry no such row.

The page answers with the address it went to rather than a bare yes — which is
also the only way the harness can check *where* somebody was sent, in a place
that implements no navigation.

## "Explore is off in Quiet."

That sentence, under a button marked "your profile", is the whole of a bug that
took four builds to corner — and it was one missing line.

Instagram's own row carries `/`, `/explore/`, `/reels/`, `/direct/inbox/` and
`/yourname/`, in that order. A username is letters, digits, dots and
underscores, one to thirty of them. So is "explore". The code took the first
link shaped like a username and found `explore` every single time, so the button
navigated to Explore and the app refused its own tap with its own rule.

The same loop read the signed-in name, so Quiet believed the name was "explore".
That is why no photograph ever arrived for the row: it was looking for an avatar
inside a link that has none.

There is now one rule for "which link in this row is a person", used by both
readers: the roots Instagram owns are excluded by name, a link carrying a
photograph is preferred over one that does not, and failing that the last match
wins rather than the first — because the row ends with you. Six reserved roots
are checked one at a time in the harness.

## The icons are Instagram's own, drawn by Instagram

Side by side with the real row, SF Symbols are unmistakably somebody else's
drawings: a different house, a differently tilted paper plane. Redrawing
Instagram's by hand would be both worse and a liberty.

So the glyphs are taken out of the row the app hides, rasterised by the page
onto a canvas and handed over as bytes — the same channel the profile picture
already travels down, so the app still asks nobody for anything.

They arrive with the state they are in rather than as one picture. Instagram
fills the entry you are standing on and outlines the rest, so a row read on the
feed gives a filled house and outlines for the others; walk to the inbox and the
other halves arrive. Both collect themselves as the app is used, and whichever
has not turned up falls back to the symbol Quiet drew.

Which entry is which is asked of the address, not of the label. `aria-label` is
translated — Startseite, Suchen, Nachrichten — and a Swiss phone and an American
one would disagree about which icon is which. An href does not change with the
language.

The clock has no counterpart, because it is the one thing in that row that is
Quiet's rather than Instagram's.

## The strip behind the clock, again

It came out once, on the reasoning that whatever the app takes off the top comes
back as a black band at the bottom. That was wrong twice over: the band at the
bottom was Instagram's own floor padding, and taking this away did not fix it —
while three separate attempts at persuading Instagram's pinned bar to sit below
the clock each came back in a photograph with the wordmark drawn through the
battery.

So it is back, and this time it is not a guess about somebody else's page.
Whatever Instagram does with its header, nothing is ever drawn across the time
and the battery, because the app owns those pixels. If the lift works, the
header sits just below the strip; if it does not, the header slides underneath
and out of sight. Neither of those is broken, and that is the point: it is the
only part of this that does not depend on being right about a stranger's
stylesheet.

## Said twice: the web view gets the whole glass

The photograph shows the page stopping thirty-four points above the bottom of
the screen — the home indicator, to the point — with the row floating over a
black band instead of over Instagram's next photograph. The same thirty-four
points explain the top, where the strip and the page happened to agree.

The stack already ignores the safe area. A `UIViewRepresentable` inside such a
stack is not reliably given the whole of it, and the fix is one line on the view
itself. Said twice, it holds. This had been diagnosed three other ways first —
a content inset, Instagram's floor padding, a viewport — and only the second of
those was a real fault.

## The heart belongs to the app now

Instagram's own header is behind the strip at every scroll position. That is the
right outcome: three attempts at persuading a bar it pins to the top of the
glass to sit lower each came back in a photograph with the wordmark through the
battery, and hidden means nothing is ever drawn across the clock.

But the heart went with it, and the heart was the one control in that bar that
is nowhere else in Quiet.

So the app draws it, in a row of its own beneath the strip. The row is always
there, so the page is always told the same number and the feed never jumps as
the app learns things. The heart appears in it once the page has said where it
goes — `/accounts/activity/`, read out of Instagram's own bar. Quiet guesses no
addresses.

## Ask the screen, not the markup

Four builds went into finding Instagram's header by something *in* it: a link to
the activity feed, a link home, a wordmark, a set of class names. On the real
site each of those found nothing at all — which is why the header never moved,
why the app's strip has been covering it, and why the row the app drew in its
place came back in a photograph as a hundred points of empty black. There was no
heart to take out of a bar nobody had found.

The heart is a button now, or the address changed, or the class names did. It
does not matter which. The mistake was the same every time: asking a question
about somebody else's markup, which is theirs and changes weekly.

So the question changed. What is painted four points from the top of the glass,
in the middle? The browser answers with the whole stack of elements under that
point. Whatever in it is pinned there — sticky or fixed, against the top, and
short enough to be a bar rather than the page — is the thing that would be drawn
across the clock, and it is moved to the bottom of the clock.

There is nothing about Instagram in that at all, which is the point. It holds on
the feed, on a profile, in the inbox, and on whatever they ship next Tuesday.
Once lifted the bar is no longer under that point, so it is never lifted twice;
a page that rewrites itself gets a new element and that one is lifted in turn.

Six checks in the harness, on a stub that answers the same question the browser
does: a sticky bar and a fixed bar are moved, one merely at the top of the
document is left alone, a wrapper as tall as the page is not a bar, something
pinned further down is not over the clock, and the bar is found through whatever
the page has wrapped it in.

With that, the strip goes back to being exactly as tall as the status bar and
Instagram's own header sits directly beneath it — with its own wordmark, its own
plus and its own heart, in its own place. The app draws no header of its own,
which is the third time this project has arrived at that answer and the first
time it can be relied on.

## A size, not a request

Twice a photograph has shown the page stopping thirty-four points above the
bottom of the glass — the home indicator, to the point — with the row floating
over a black band instead of over Instagram's next photograph. Both times the
answer was to ask SwiftUI more politely to ignore the safe area, on the stack
and then on the view as well.

Ignoring the safe area is a request. A size is not. The web view is now given
the window's own bounds as a frame outright, inside a stack aligned to the top,
so it covers the glass whatever the layout system decides it would have
preferred. A zero is read as "no opinion" rather than as a size, so an early
answer never squashes it.

## And the page's own idea of what it owes the bottom

Two things put a black band down there besides the frame.

The padding Instagram reserves for the bar Quiet hides — now taken up wherever
it is, not only on the ancestors of a row that some pages do not have.

And `env(safe-area-inset-bottom)`, which reads zero until a page asks for
`viewport-fit=cover` — which Quiet asks for, on Instagram's behalf, so that the
rule keeping the header off the clock can see the notch. Switching it on for the
top switched on every rule that consults it at the bottom. That is a black band
this project turned on itself, three commits after complaining about one.

Both are refused now, on `html` and `body` and on anything found holding a floor
worth eight points or more.

## The bottom inset the page is never told about

`html` and `body` were the wrong place to refuse `env(safe-area-inset-bottom)`,
and the photograph after that build says so: the band is still there. A
stylesheet can only reach the elements it can name, and the ones consulting the
safe area at the bottom are Instagram's, several layers down, generated afresh
whenever the client feels like it. `env()` is not a property; there is nothing
to override.

So it is answered where it is asked. The view the page is drawn in reports the
notch at the top and nothing at the bottom — one override on `QuietWebView`, and
every rule anywhere on the page that reserves room for the home indicator
reserves nothing. WebKit reads the same number for its own layout, so a viewport
inset at the bottom goes with it.

The top is untouched, which is the whole reason `viewport-fit=cover` is on: the
rule that keeps Instagram's header off the clock still sees the notch, and still
takes the larger of that and the number the app hands over.

## Two and a half millimetres

The row sat twelve points above the bottom edge of the glass. It sits at
twenty-eight now — about two and a half millimetres higher on the phone, at
roughly a hundred and sixty points to the inch, which is what a photograph asked
for.

It still floats over the home indicator rather than clearing it. A row that
clears it leaves a band of page between the two that nobody can read and nothing
can cover, which is the thing this project keeps taking out.

The scroll indicator moves with it: the pill, the air beneath it and the
system's strip, so a scroll bar stops above the row instead of running beside
it. Only the indicator — the page itself is given all of the glass, as before.

## The band was never a gap

Four fixes went into the black band above the row, and every one of them read it
as a gap — the page stopping short of the bottom of the glass. A taller frame,
the floor padding taken up, `html` and `body` refused their bottom padding, the
bottom safe area zeroed at the view so no `env()` anywhere could reserve a
strip. The photograph after the fourth shows the band exactly where it was.

That is the answer, and it took four builds to hear it. A band that survives
everything done to the page's *size* is not a hole in the page. It is an
element, drawn over Instagram's own photograph, in Instagram's own background
colour: the bar its row hangs in.

`navRow` finds the smallest container holding the five links, because that is
what has to be measured, read for the signed-in name, and rasterised for its
icons. What carries the colour, the border and the forty-odd points of height is
a wrapper further out. Hiding the links empties the bar without taking the bar
away, and an empty bar is a black band.

So the wrapper goes too, found the way everything else in trim.js is found — by
asking the browser what it did. Pinned to the bottom of the glass, short enough
to be a bar rather than a page, and without the feed inside it. That last one is
the stop: it is the only question that matters when a walk up the tree reaches a
container nobody meant.

Four checks in the harness. The bar behind the row is hidden with it, a wrapper
merely in the flow is left alone and keeps its floor taken up, a wrapper with
`main` inside it is the page, and one as tall as the page is not a bar.

The four earlier fixes stay. None of them was wrong — a page that owns the whole
glass and reserves nothing at the bottom is what this app wants either way, and
each of them removes a band this one would have left behind.

## Another two millimetres

Twelve points to begin with, then twenty-eight, and forty-one now. The row
clears the home indicator instead of floating over it, which is only worth
having because the page finally runs the whole way down behind it: under the row
is Instagram's next photograph rather than a strip of its background.

## The last inch: stop arguing with the page about it

Four rounds went into the strip along the bottom of the screen. A content inset.
Instagram's floor padding. A `viewport-fit` this project switched on itself and
then had to refuse at the other end. A frame instead of a request. Each one
moved the band and none of them removed it, because every one of them was a
guess about what a stranger's stylesheet keeps clear down there.

So the arguing stops. `env(safe-area-inset-bottom)` is the page's own name for
"the strip at the bottom I must not draw in" — so the web view is made that much
taller than the glass, and whatever the page reserves lands off the screen
entirely. Whatever it is, and however it is spelled next week, it is no longer
on the phone.

Nothing real is lost. What falls off the bottom is space the page itself set
aside to be empty, and the scroll view is given the same amount as a bottom
inset so that a page which *does* end can still be scrolled all the way into
view — that inset lands in the overhang, where nobody can see it.

On a phone with a home button the system reserves nothing, this adds nothing,
and the frame is exactly the screen.

## Five screenshots, held up against the real thing

The app has been looked at beside Instagram's own, screen for screen, and the
differences written down. Most of what follows is one answer given six times:
where Quiet had invented something, it stops.

### The row is a bar again, and it is Instagram's shape

A pill, inset from both edges, floating over the page, shrinking while the page
moved and fading back in when it stopped. Every one of those is a decision
Instagram did not make. Held up beside the real app the pill is the first thing
anybody sees, and what it says is *this is not the app you think it is*.

So the row is what every bar along the bottom of an iPhone has been since the
first one: the full width of the glass, flush against the bottom edge, forty-nine
points tall, opaque, a hairline above it, the system's own strip beneath. It
does not move when the page does. There is no second shape for phones with a
home button any more, because there is nothing left to make a second shape of —
those reserve nothing at the bottom and the same bar simply meets the glass.

The capsule behind the entry you are standing on went with it. Instagram marks
where you are by filling the symbol and doing nothing else, which is also what
the other four bars on the phone do.

The order changed too. Home, search, the middle one, messages, you — Instagram's
own order, with the clock where Instagram puts the thing its app does rather
than the thing the site does.

### The inch below the glass comes off

The web view hung an inch below the bottom edge, so that whatever the page
reserved for the home indicator fell off the screen instead of showing as a
black band under a floating row. It worked, and it cost something that only a
photograph of a story could show: *everything* the page pins to the bottom of
the viewport was pinned an inch below the glass. A story's reply field. A
conversation's message box. Pushed half off the screen by the app, on the two
pages where they are the only thing that matters.

With the row standing on the bottom edge there is no band to hide — the row is
covering it — so the frame is the glass, exactly, and the page's own bottom
furniture lands where the page put it.

What replaces the trick is the ordinary thing: the scroll view is inset by the
height of the row, so the last post scrolls clear of the bar rather than living
behind it. Which is what a tab bar has always done to the view underneath it.

### No row on a story, and none inside a conversation

Instagram draws no bar in either place, and now neither does Quiet. Both put
something of their own along the bottom edge — a reply field, a message box —
and both are the reason the screen is open at all. A row of five drawn across
them is the app covering the one control the screen exists for, which is
exactly what the photograph of a story showed.

### The clock and the search are pages, not sheets

Both were sheets. A sheet takes the whole screen, and the row along the bottom
goes with it — so for as long as either was up, the app it belongs to was gone
and the only way back was a button in a corner saying "Done".

They are pages now, drawn between the clock and the row, with the row still
there and still saying which of the five you are standing on. You leave them the
way you leave anything else in a tab bar: by tapping somewhere else. Tapping
home while the settings are open goes back to the feed you were reading, at the
place you were reading it, rather than loading it again.

The curtain keeps its sheets, because there is no row down there to be part of.

### The wordmark stays on the left

The header on the feed was being rearranged into what was believed to be the
app's arrangement: the plus on the left, the title in the middle, the heart on
the right. The app does not centre its wordmark and never has. The website
already draws exactly what the app draws — the wordmark on the left, the two
controls together on the right — so the arrangement stops, and what is left of
it names the three so their order is guaranteed rather than inherited.

### The second thing pinned to the top of the glass

The lift that keeps a page's own header off the clock found the first pinned
element under a point and stopped — and gave up entirely the moment it met one
it had already moved. The inbox pins two things up there, one behind the other,
so the first was lifted and the search field below it stayed where it was: cut
in half by the status bar, in the photograph.

It now asks at three points across the width, and lifts everything it finds
rather than the first thing.

## Two shapes for the row, and a choice between them

The row was an island — a pill inset from both edges, floating over the page,
drawing itself in as the page moved — and then it was a bar, because held up
against Instagram screen for screen the island is the first thing anybody sees
and Instagram does not draw one.

Both are now in the app and the panel asks which. It is the only setting in
Quiet that changes how something looks rather than what it does, and it earns
its place the way a setting should: two answers were built, and neither turned
out to be wrong. The bar is the shape of the thing being shown. The island is
the nicer object.

It starts as the bar, because a first launch should look like what it is showing
rather than like an opinion about it.

The choice is kept in the ordinary place preferences live, not in the keychain
with the limit. The limit is in the keychain because it has to outlive the app
being deleted — that is the whole promise, and the About screen says so in as
many words. The shape of a row surviving a delete-and-reinstall would be a
surprise rather than a feature.

The scroll view is inset by whichever shape is standing there, so the end of a
page clears the row either way.

## The keyboard waits to be asked

Finding someone opened with the keyboard already up. It reads as helpful and it
is not: the screen arrives with half of it already covered, before anybody has
decided they want to type, and the way back out is now two taps instead of one.

The field is still the first thing on the page and still the obvious thing to
touch. It waits to be touched.

## Going somewhere presses Instagram's own link

The row used to load an address. Loading one throws the page away and builds it
again — a spinner, the feed from the top, the stories fetched a second time —
every time you come back from the inbox.

Instagram's own row does not do that. It hands the address to the client already
running in the page, which keeps its shell, its caches, and the place you had
scrolled to. The row Quiet hides is hidden rather than removed precisely so its
links can still be pressed, and now they are.

Asking for the page you are already standing on presses nothing and answers with
the address, because that is what Instagram does and because the row has said
where you are since the day it learned to.

Loading the address is still there, as the fallback: for pages that carry no
such row, and for the moment before the first one has loaded.

What this is not: four pages held open at once. That would be four web views,
four copies of Instagram's client, and four times the memory — and the phone
would start closing them behind your back. This is one page that stops being
rebuilt, which is most of the difference and none of the cost.

## The clock is drawn, not borrowed from a font

Four of the five icons in the row are Instagram's own, taken out of the page.
The fifth is Quiet's, and it was an SF Symbol — which beside them is a lighter
line, a different geometry and a different optical size. In a photograph of the
row it is the one thing that came from somewhere else, and that is exactly how
it read.

So it is drawn to their specification instead: a twenty-five point box, a two
point stroke, round ends, and filled solid when you are standing on it. The
hands are punched out of the filled disc rather than painted over it in the
background colour, so it is right on the bar and right on the island, where what
is behind it is a blur rather than a colour.

Ten past twelve, which is how every clock in every advertisement has been drawn
for a century, because it is the arrangement that still reads as a clock at
twenty-five points.

## The viewport itself is smaller, and the argument is over

Six mechanisms went into keeping Instagram's own bars off the status bar: a
content inset, a padding on the document, a rule that lifted whatever the page
had pinned, and three separate attempts at finding that element. Every one of
them worked on the feed. Every one of them left the inbox with its search field
cut in half by the clock.

The photograph finally says why. That field is not pinned and it is not in the
flow — it is positioned against the *viewport*, which is what a chat layout
does. A padding on the document cannot move it, because an absolutely positioned
element whose containing block is the viewport does not care what the document
is padded by. And a rule for sticky elements never sees it at all.

So the viewport is made smaller instead. The web view starts at the bottom of
the clock and ends at the bottom of the glass, and the page's world is that.
Everything in it is right by construction: what is fixed, what is sticky, what
is absolute, and what asks for a hundred per cent of the height. There is
nothing left to find and nothing left to lift.

The page is told the clock is zero points tall, because for the page it now is.
The padding rule and the lift are still there and both evaluate to nothing —
they are the right mechanism for anything the app ever does need the page to
know, and they are one commit from being deleted if it never does.

What this costs is the one thing Instagram's own app does that Quiet now cannot:
run content up behind the status bar. The app has drawn that strip in the page's
own colour for several builds, and it will keep drawing it.

## No scroll bars

Instagram's app shows none, and the page draws two kinds. The browser's own,
along the edge of the view, which fades. And one inside every container the site
gives its own scrolling to — the inbox list, a conversation — which does not
fade, and is a line down the side of the screen for as long as you are reading.

Both are off. The page's in trim.css, in both spellings, because the property
that turns them off has one name in WebKit and another everywhere else; and the
app's on the scroll view, because that one is drawn over the top of the other.

## The icons are Instagram's, and now they are sharp

They are rasterised from Instagram's own SVGs onto a canvas at ninety-six
points, for a glyph drawn at twenty-five on a screen with three device pixels to
the point. Seventy-two was under three of them, and every icon in the row was
very slightly soft — not wrong, and not the same as Instagram's, which are
vectors and are not soft at any size.

Beyond that there is nothing to make more exact. These are not approximations of
Instagram's drawings, they *are* Instagram's drawings, taken out of the page the
app is showing. Drawing a house and a paper plane by hand to look more like
theirs would be further from the original, not closer, and a liberty besides.

## Instagram has two wordmarks and both are theirs

The app draws the script one — the one everybody pictures. The website draws the
newer one, and Quiet shows the website, so Quiet shows that.

The obvious way to close the gap is to set the word in a script font and call it
done. That is the one thing this will not do. A wordmark set in somebody else's
typeface is not a wordmark, it is a forgery that holds up at arm's length and
falls apart at reading distance — and on an app that displays Instagram and says
in its own About screen that it is not Instagram, a home-made Instagram logo is
precisely the wrong place for invention. It would be less faithful than what is
already there, not more.

So the page looks for Instagram's own file instead. Their sign-in page has
carried the script one for years, and it is the same origin, so the page can
fetch it, read it out of the markup and put it where the other one was. Fetched
without credentials on purpose: a signed-in session is redirected off that page
before it can be read, and this wants the page a stranger sees. Instagram's
drawing either way — only the one from the other room of their own house.

It is a nicety, so it does not get to break anything:

- An inline drawing is preferred over a picture — no second request, it takes
  the colour of the bar it lands in, and it is sharp at any size.
- Anything that could run is taken out of it first. It is Instagram's markup
  from Instagram's origin and it is still going straight into the page, so it
  goes in as a drawing and nothing else.
- The original is not hidden until the replacement has been measured and found
  to have a size. One that draws nothing takes itself out again, gives the
  original back, and is never tried a second time.
- If the sign-in page has stopped carrying it, nothing happens at all.

Five checks in the harness, including the two that matter: the one that draws
nothing puts itself away, and a page with nothing remembered is left exactly as
Instagram drew it.

## The door back into the app does not get drawn

Instagram's page offers a bar along the bottom that opens Instagram in
Instagram. `instagram://` has been the one link a person deliberately presses
that Quiet declines, since the first photograph of the running app — and the app
says why when they press it.

That is not enough. A door you are told is locked every time you reach for it is
still a door in the room, and this one is a strip across the bottom of the page
with a bright blue sentence in the middle of it. It is precisely what the app
was built to remove.

Matched on the address, never on the words: "Use the app" is "App verwenden" on
one phone and something else on the next, and a rule written against a sentence
works in one language.

The whole strip goes, not just the link — hiding the link alone leaves an empty
bar with a cross in it, which is worse than leaving it there. The strip is found
by shape and only by shape: placed against the viewport, the width of the glass,
and short.

The thing that must never be hidden is a conversation's message box, which is
pinned to the bottom in exactly the same way. The only difference worth trusting
is that a composer has no link out of the site in it, so the search starts from
the link and never from the shape. Four doors and one composer are checked in
the harness, and a door with no bar around it goes on its own.

## The header gets out of the way

Pinned to the top of the glass, Instagram's header is a permanent inch of
wordmark over every photograph anybody scrolls past.

Instagram's own app slides it away as you go down and brings it back the moment
you go up. That is neither taking it out nor leaving it: it is there when you
want it and gone while you are reading, which is the whole point of a header
that moves.

Watched in the page rather than in the app. The app already knows which way a
thumb is going — it draws its own row smaller with it — but a message from one
to the other is a frame of lag on something the eye is following, and the page
has the number already.

A transform rather than a height or a display, so it costs no layout and the
feed does not jump as it goes. The element it moves is the one already found as
pinned to the top of the glass, so this knows nothing about Instagram's markup
that was not already known.

Only on the feed. Every other page's top bar is that page's own — the name on a
profile, the search in the inbox, the back arrow in a conversation — and a back
arrow that slides away while you read is one you go hunting for.

Two numbers, both chosen to be felt rather than noticed: it stays put for the
first sixty-four points, because there is nothing worth reading yet, and it
ignores movement under eight, because a fingertip resting on the glass is not a
decision.

## The door carries no address

The photograph that came back had the strip still along the bottom, which
settles what it is made of: there is no address anywhere in it. The tap is
handled in Instagram's own script, so the markup is a `div` with a sentence in
it, and nothing written as a selector over `href` can ever match. The sentence
above — that the search starts from the link and never from the shape — was the
second guess in a row, and it was wrong.

So it is found the way the header is found: by asking the screen. Twelve points
along the bottom of the glass, and then a decision made entirely on shape —
held against the viewport, spanning the glass, short, low down, a few words at
most, and something to press.

Each of those questions spares something real. Nothing to type in, because a
composer is the one thing down there that must never go and every composer has
a field. A few words at most, because a consent notice is also a strip along
the bottom, and refusing to let somebody answer one would be worse than the
banner. Something to press, because an empty strip is a spacer, and hiding a
spacer moves the page for nothing.

And not in a conversation at all. That bar is what you went there for, and a
message request puts its two answers in the same place. Nowhere else on the
site does that space belong to anybody but Quiet.

The link rules stay as they are. They hold from the first paint, before a frame
has been asked for, and they are what refuses a door that is not a strip at
all.

## The row is right in its first frame

Quiet draws its row with Instagram's own glyphs, read out of Instagram's own
navigation once a page has loaded. Honest, and about a second slow: for that
second the row wore the symbols Quiet falls back to, and then all of them
changed at once. The app looked like it was correcting itself in front of you.

The fix is not to draw them faster. A house and a paper plane are the same this
morning as they were last night, and an app that has seen them once has no
business asking again before it can show anything. So they are kept, along with
the signed-in name and the face — which is the same defect: the last entry in
the row used to appear a second after the other four.

Kept in `UserDefaults` rather than the keychain, deliberately. The keychain
holds the one thing that must outlive a reinstall, and putting a cache of
pictures beside it would be putting a convenience where a promise lives.
Losing all of it costs a second, once.

A remembered glyph is replaced the first time Instagram sends its own in a
given run, and not again. Without the first half, an icon Instagram redrew
would be one Quiet showed the old version of for ever; without the second, a
page that rewrites its navigation forty times would decode forty pictures.

## The second and a half the app opens with

An app that opens straight onto Instagram is an app you are inside before you
have decided to be. So there is a pause: one sentence on Quiet's own paper,
and then it goes.

It is not a progress indicator and does not pretend to be one. Nothing waits on
it — the web view loads behind it, so the time is spent rather than wasted. It
is not a logo screen either. There is a sentence to read, and somebody who
reads it has had the thought the whole app exists to prompt.

The system's own launch screen is now painted in the same paper, so nothing
flashes between the two. It carries no words of its own: a launch screen is laid
out by a different system, knows nothing about the reader's text size, and would
have to be written twice to say the same thing.

Held still, and only for a machine, under a rehearsal scene — it is the one
screen in Quiet that is gone before anybody could photograph it. The one UI test
that drives the app from an empty install skips it outright: a machine has no
eyes to read a sentence with, only a first tap that would go nowhere.

## Asking for stars, once

This is the only thing in Quiet that interrupts somebody for the app's benefit
rather than theirs, so it gets one shot and has to earn it.

Five minutes of the app actually in front of somebody. Not five minutes since it
was installed, because an app can sit unopened for a week. Not one long sitting
either: Quiet is built to be used in short ones, and a rule that only fired in a
long sitting would fire for the people using the app worst. So it is counted
across launches, against the same monotonic clock the limit uses, and a jump the
size of a night of standby is dropped rather than believed.

Once, ever. iOS caps the prompt at three a year on its own, and a rule that
leaned on somebody else's cap is a rule that would ask every day if the cap were
lifted.

The sheet is the system's, through SwiftUI's own `requestReview`. Everything
about it belongs to iOS: the stars, the wording, and the fact that it can be
dismissed without answering. An app that drew its own could nag, and could imply
a rating had been left when none had. Nothing can tell whether it appeared,
which is why the question is marked as put when it is asked rather than when a
star is pressed — asking twice because the first went quietly nowhere is the
exact behaviour this is avoiding.

And never over the curtain. The end of the day is the one moment in Quiet that
is meant to be felt, and a five-star sheet on top of it would be the app asking
to be praised for the thing it just took away.

## The declaration that was missing

`UserDefaults` is a required-reason API, and Quiet has been using it since the
row preference shipped without saying so in the privacy manifest. That is the
sort of omission that is invisible right up until an upload comes back as
ITMS-91053. Reason CA92.1 covers it exactly: written and read by this app alone,
no app group, no sharing of any kind.

## Higher, not taller

"Two millimetres higher" was read as height and given as height, and it was the
wrong reading of the same word. A taller pill with the same gap beneath it does
not sit higher — it crowds the bottom edge harder, which is exactly how it came
back.

So the island is the size it was, and the thirteen points went under it instead.
The scroll inset is unchanged either way: it was the pill plus air twice over,
and it is now the pill plus the lift plus the air, which comes to the same
number. Nothing about how far the page can be scrolled moved.

## A number instead of an argument

Two millimetres of gap under the floating row cost four rounds of build, upload,
install and look — and two of those rounds went entirely on which build was on
the phone. That is not a question anybody should be answering by eye.

So CI measures it. A rehearsal scene puts the row in its floating shape and
photographs it before the page arrives, so the island stands on a flat colour
with nothing underneath it, and a script reads the gap and the height off the
pixels. Both numbers are printed on every push.

It measures the drawn thing rather than the constant. Reading `islandLift` back
out of the source would prove only that the source says what it says.

Three details it took a wrong answer to get right. Dark, because the island
casts a black shadow and on a light background the shadow's own edge is what a
naive scan finds first. A column a quarter of the way across, because the middle
is where iOS draws the home indicator over the app and the indicator is the
brightest thing on the screen. And three rows of agreement before an edge is
believed, because a shadow fades in over about twenty points and one row of it
looks like a capsule.

The point of it is not this gap. It is that the next disagreement about a
distance is settled by reading a line in a log.

## Two millimetres higher again

Twelve points, then twenty-five, and thirty-eight now — thirteen points a time,
which is what two millimetres comes to on a phone at roughly a hundred and sixty
points to the inch.

The pill is the height it has always been. That was the lesson of the last
round: the word is "higher", and a taller pill with the same air beneath it does
not sit higher, it crowds the bottom edge harder. Only the gap moves.

The scroll inset moves with it, because it is the pill plus the lift plus the
air and always has been — so the end of a page still clears the row instead of
stopping behind it, and a scroll indicator still stops above it.

Nothing to argue about this time: the rehearsal shot goes through the measuring
script on every push, and the number in the log is the gap that was drawn.

## The row was never the problem

Four attempts at two millimetres: twelve points, then a taller pill, then
twenty-five, then thirty-eight. Each one was a guess at a number that had been
right since the second attempt, and each one was wrong for the same reason.

The opening screen was held in a `ZStack` wrapped around the whole app. That
put a container between the app and the window, and a container respects the
safe area. The browsing screen ignores the safe area on purpose and therefore
reports the height of the whole glass — so it was a view eight hundred and
seventy-four points tall being centred in a region seven hundred and eighty-one
points tall, and it hung twelve and a half points off the bottom of the screen.

Which is why nothing moved. The row went up by thirteen and the screen it
stands on went down by twelve and a half. On the phone the gap read 12.3 points
before the change and 12.3 points after it, and both readings were honest.

An overlay instead of a stack. An overlay is laid over the view and sized to
it; the view is proposed exactly what it was proposed before the opening screen
existed, which is the whole point of using one.

Two things this cost that were avoidable. The first is that the row's number
was raised three times to compensate for a bug somewhere else, and each raise
made the eventual fix look like a regression. The second is that two rounds
went on insisting the phone was running an older build — it was not, and the
arithmetic said so all along: twelve points of lift with no bug and twenty-five
points of lift with a twelve-and-a-half point bug draw the same picture.

So CI now checks the drawn gap against the number in the source and fails when
they disagree, rather than printing it and hoping. The measurement had already
caught this on its first honest run and been read as a fault in the
measurement.

## A grey band behind the clock, in Instagram's own grey

The strip the time and the battery stand on was drawn in the page's own colour,
which in the dark is pure black. On a black page that is not a band at all —
there is nothing to see, and the top of the screen has no edge.

It is one step off the page now. Which step was the only real question, and
there were two ways to answer it: write a hex into the app, or ask the page.

Asking the page won. A hex typed into an app is a guess about somebody else's
design, and it is wrong the morning after that design changes with nobody here
noticing — the app would go on painting last year's grey next to this year's
page. Instagram publishes its palette as custom properties on the root element,
so the band is painted in the colour the site itself puts on top of itself: its
search fields, its sheets. It follows the phone from light to dark because the
page does, and it survives a redesign because it was never a number here.

The fallback is arithmetic rather than a second guess: the colour actually drawn
at the top of the page, moved fifteen per cent towards white if it is dark and
four per cent towards black if it is light. Black lifted by fifteen per cent is
rgb(38, 38, 38), which is the grey the tokens give in the dark to the number —
so the fallback does not look like a fallback. Behind that, for a page that has
answered nothing at all, `secondarySystemBackground`: the system's own name for
one step off the page.

The message is refused unless all three channels are numbers inside the range a
channel has. A band with nothing behind it is the wrong place to find out what
three broken numbers mean, and a refusal leaves the colour that was already
there.

## No band behind the clock at all

The grey lasted one build. Asked for plainly, the answer to "what colour should
the strip behind the clock be" was: the same one as the header, so that there is
no strip.

The argument for a grey was that a band wants an edge — that the time and the
battery should stand on something rather than float in the same void the feed
runs in. Seen on a phone, that argument loses twice over. The system's black
against Instagram's near-black is already a hard line across the top of every
screen, which is what was being complained about; a grey replaces it with a
second line in a lighter colour. Nobody was asking for a shelf.

So the colour is sampled from what Instagram actually draws at the top of the
page — not the elevated surface it puts on top of itself, and not one step off
anything. What the app owns and what the page owns are the same colour, and the
seam is gone. It still follows the phone from light to dark, the app from the
feed to a story, and Instagram through a redesign, because it is a sample rather
than a hex typed in here.

A translucent bar is climbed past rather than flattened: half of white over
near-black is not a colour the app can paint a solid band in, and guessing what
is behind it is how a band ends up nearly right on one page and wrong on the
next. A page that has painted nothing says nothing, and the app keeps its own
colour up rather than being handed a guess. Five checks in the harness, which is
sixty-eight.

## A sheet owns the screen, so the sheet is given the room

Instagram puts a sheet up for switching accounts, for sharing, and for the menu
behind the three dots. It slides over its own tab bar, the way every sheet on a
phone does. Quiet's row is the app's rather than the page's, so it stayed
exactly where it was and was drawn straight through the buttons on the sheet: a
photograph of "Switch accounts" shows the row across "Log In to an Existing
Account".

A sheet is not a page. It has no address, and every rule Quiet had for "the
screens that own the bottom edge" is written in addresses, so none of them could
ever see one coming.

Found by what it is: the markup says outright that it is modal, in an attribute
that is the same word in every language and that Instagram has to set for its
own screen reader to work. No class names, no guessing at shapes. Only if it is
actually drawn — a dialog in the tree with no box has been dismissed and not yet
removed, or built ahead of being needed, and neither is a reason to do anything.

Two answers came before this one and both of them moved the row. First it was
taken away while a sheet was up, which reasons well — a modal is the only thing
you can be doing — and reads badly: the row is the one part of the screen that
is always in the same place, and a sheet is a thing you are half way through.
Then it stayed where it was and stopped answering taps, so every press went to
the sheet underneath.

The same photograph killed the second one. The row was never in the way because
it was answering taps. It was in the way because it was drawn across the one
button on the sheet, and a button nobody can see is a button nobody can press,
whoever is given the tap.

So nothing of the app moves and the sheet is given the room instead. The app
says how much of the bottom of the glass its row stands on — `--quiet-row`,
handed over beside the status bar height it already hands over — and the page
pads the panel of the sheet by exactly that. Every control on the sheet ends
above the row, and the panel's own colour runs on underneath it, which is what a
sheet looks like when something is standing in front of it.

Which box to pad is the whole of the work, and it is asked of the browser rather
than of Instagram's class names. A panel is positioned rather than in the flow,
because being pinned to an edge is what `position` is for; it reaches the bottom
edge of the glass and spans most of its width, because that is where a sheet on
a phone sits; and it is shorter than the glass, which is what tells it from the
dimmed backdrop around it. Shallowest first, so what is found is the box pinned
to the edge rather than a button inside it that ends at the same place — and a
few steps upwards as well, because a sheet is as often a pinned box with the
dialog inside it as the other way about.

A padding rather than a lift, so the panel does not move: only what is on it
does. And never on a backdrop or on anything else as tall as the glass, where
the padding is at best useless and at worst backwards — a backdrop resolves its
children's `bottom: 0` against its own padding box, so padding meant to lift the
sheet off the row would push it down behind it instead.

Where the room could not be made — a sheet filling the whole glass, a shape the
page does not recognise — the page says so, and there the old answer still
holds: the row stands down and the press goes through to the sheet. Everywhere
else the row goes on answering taps, because it is beside the sheet now rather
than over it. That last-resort is why the app is still told there is a sheet at
all; the room itself is the page's work from end to end.

The inset under the page is left alone, as it was before: the page beneath the
sheet has not changed, and taking the row's height off it would scroll what you
were reading out from under the sheet while you were not looking at it. And the
row is live regardless the moment one of Quiet's own pages is open — the row is
the way out of those, and a sheet left open on the page behind is no reason to
take the way out away.

A sheet also slides, and a transition changes nothing in the document, so a pass
that only ever ran on a mutation would measure the panel half a screen below
where it lands and decide once, while it was moving, that there was nothing to
pad. It looks again three times, at sixty, two hundred and five hundred
milliseconds, and stops the moment a sheet has its room or goes away.

Twenty-three checks, which is ninety-one.

## The panel was being refused for the wrong reason

Three builds went past with the row still drawn across "Log In to an Existing
Account", and the third of them was supposed to have fixed it by padding the
sheet. It did not, and the photograph says why once the rule is read back
against it.

A panel had to be *positioned* to count. That was never what makes something a
panel — it was there to keep the backdrop out, and the backdrop is already kept
out by being as tall as the glass. Instagram's sheet is a plain box inside a
fixed backdrop, which is what a flex column with `margin-top: auto` is, so it was
refused, no panel was found, and the app fell back to standing the row down.
Which is the answer that had already been photographed twice.

The test is now geometry alone: as wide as most of the glass, reaching its
bottom, and shorter than it. Every candidate is inside the dialog or within four
steps of it, so there is nothing else down there to pick by mistake. Ancestors
are tried before descendants, because when the dialog and the box around it are
the same rectangle the outer one is the better answer: padding it cannot be
swallowed by an inner box with a height of its own.

The second half is worse and simpler. "Standing clear" was *assumed* from having
found a panel. So a padding that moved nothing reported success, the app left the
row live, and the button stayed underneath it — the app believed a thing it had
never checked. It is measured now: after the padding is on, every control on the
sheet is asked whether it is above the row, and only then is the sheet clear.

When it is not, the row stands down and the press goes through. That is the worse
of the two outcomes and it is never the wrong one — whatever shape a sheet turns
out to be, the button can be pressed.

Six checks, which is ninety-seven.

## Move the sheet, do not ask its layout to move it

Padding was tried twice, on a real phone, in two builds, and moved nothing both
times. Why is Instagram's business — a height of its own, a flex rule, an
overflow — and it does not matter, because the answer does not have to go
through layout at all.

A transform does not. Whatever the box is made of, it and everything inside it
are drawn higher, and the taps follow the drawing. There is nothing in anybody
else's stylesheet that can refuse it.

The padding stays and now has one job: the box grows by exactly what it moves, so
its own background still reaches the bottom edge of the glass and there is no
strip of dimmed page showing underneath the sheet.

Two centimetres, because that is what was asked for in the end. The row itself is
eighty-nine points — about one and four tenths of a centimetre — and three
attempts at "exactly clear of the row" produced three photographs of a button
under the row. A hundred and twenty-eight points is the row and a margin nobody
has to measure to believe.

Never so far that the top of the sheet leaves the glass. A sheet nearly as tall
as the screen has nowhere to go, and cutting its heading off to free its foot is
not a trade worth making, so the distance is whatever is left above it less forty
points — and nothing at all is written when that comes to nothing.

Five checks: how far it goes, a sheet with no room, one with a little, the box
around the dialog being the one moved, and the transform being taken off again
when the sheet goes. A hundred and two.

## The sheet never said it was a sheet

Five rounds went past on this — pad the panel, take the row away, leave it and
make it inert, measure whether the padding worked, move the sheet two
centimetres — and every one of them was gated on the same line: find something
in the markup that says it is modal.

Nothing obliges Instagram to say so. And when it does not, the symptom is
identical to the symptom of each of those five mechanisms failing: the row drawn
across the button, in every photograph, whatever had been changed. Five pictures
of the same thing, and the one thing they were all evidence of was the one thing
never looked at.

It is found by shape now, the way the header and the upsell strip are: what is
actually drawn along the bottom of the glass. It reaches the bottom edge, spans
nearly the whole width, is tall enough to be a sheet and shorter than the screen
— a backdrop is as tall as the glass — and it is held over the page rather than
laid out in it, which is what a sheet is.

Nothing of Instagram's own can be picked up by mistake. Its floor is already
taken out and carries a mark saying so; a bar is too short; a card does not span
the glass; and on the screens that own their bottom edge — a story, a
conversation — the row is nothing and none of this runs at all.

The lesson is the one this project keeps relearning and keeps having to pay for:
ask the screen, not the markup. Six checks, which is a hundred and eight.

## The app owns the viewport, so the app moves the sheet

Eight rounds of this. Pad the panel; refuse the panel for the wrong reason; take
the row away; leave the row and make it inert; measure whether the padding
worked; move the panel with a transform; find the sheet by shape instead of by
what it calls itself. Eight photographs came back and every one was the same
picture.

Which is the finding, and it took eight to see it. Seven different mechanisms do
not fail for seven different reasons that often. What they shared is that every
one of them tried to move something of Instagram's — and a photograph of a row
over a button says nothing at all about *which* link of that chain broke.

So the page stops moving things. Its whole job now is to answer two questions —
is there a sheet, and what colour is it — and hand them over.

The app owns the viewport. While a sheet is up it makes the web view a hundred
and twenty-eight points shorter, and everything anchored to the bottom of the
page rises by exactly that, because that is what being anchored to the bottom of
a viewport means. There is no rule anybody can write that refuses it.

This project already learned this, for the status bar, and the note is still in
`InstagramWebView`: six mechanisms went into keeping Instagram's own bars off the
clock, each worked on the feed and left the inbox broken, and the answer in the
end was to make the viewport smaller — everything in it right by construction.
The same lesson, the same shape of failure, eight rounds later.

The strip of glass taken away is painted in the sheet's own colour, sampled from
the page, so the sheet still reaches the bottom edge and only its contents have
moved.

And the thing that should have been built first: CI now puts a sheet on the real
page. A rehearsal draws one the shape of Instagram's — held against the bottom of
the glass, the width of it, saying nothing anywhere about being modal, which is
the case that went unasked for seven rounds — with a bright band at its foot, and
a script measures how far that band ends up from the bottom edge. Zero is the
bug. A hundred and twenty-eight is the fix. Nine minutes instead of twenty, and a
number instead of somebody else's eyes.

## The ninth photograph: nothing was ever asked after the sheet landed

The eighth round moved the answer into the app, where nothing of Instagram's can
refuse it, and the row was still drawn across "Log in to an Existing Account".

Which is the fourth time a photograph of that button has come back, and this
time the thing to look at was not the mechanism. Every one of the eight rounds
changed what the app *does* about a sheet. None of them changed whether the app
ever hears about one — and there is exactly one place where that is decided.

A sheet arrives by sliding. A slide is not a mutation. The observer hears the
panel go into the document, and at that moment the panel is still below the
bottom edge of the glass with a transform on it; nothing in the document changes
while it travels, so the question was asked once, at the one instant the honest
answer is *there is no sheet*, and never asked again until something else
rewrote the page. Every mechanism downstream of that was correct and unreachable.

It had been solved once. "It looks again three times, at sixty, two hundred and
five hundred milliseconds" is four entries above this one, written when the room
was still made by padding the panel — and it went out of the file with the
padding, because it lived in the same function. A rewrite that keeps the
mechanism and drops the trigger is the most expensive kind, because everything
that is left still reads correct.

So a change to the document is followed for a moment afterwards: six looks over
two-thirds of a second, spaced further apart as they go, outlasting any sheet
animation on the site and costing six calls of a function that reads a handful of
boxes. Only the sheet is asked about again — the rest of the pass is about the
document, and the document has not changed.

Two more of the same kind were in the finding, both of them a guess about
somebody else's markup written as if it were a measurement:

* A sheet had to reach the bottom edge to within **two points**, against a panel
  that can end on a rounded corner or a hairline of its own. Forty now, which is
  generous about the foot of a sheet and still less than half the row.
* What holds a panel against the glass had to be within **eight steps** of it.
  Instagram's tree is deeper than eight almost everywhere, and the fixed element
  is the backdrop rather than the panel. The walk goes to the body now.

And underneath both, a third way of finding one, which is the question the
photograph itself asks: **is anything a person would press drawn underneath
Quiet's row?** It probes the strip of glass the row stands on, and if what is
drawn there is something pressable held over the page, then whatever that thing
belongs to is in the way — whether or not it is a sheet, whether or not it says
so, and whatever shape it is. It knows nothing about how Instagram builds a
sheet, which is the only property that matters: every other test here is true
until somebody else's release, and this one is about the screen.

It is asked last in the pass, after Instagram's own navigation row and its door
back into the app have been marked. Both of those are full width, held against
the bottom of the glass and full of things you could press — which is to say,
both indistinguishable from a sheet until the moment they are taken out. The
page's own content is never picked up: what scrolls is not held over anything,
and content running on beneath the row is exactly what belongs under it.

Two things follow from the app being the one that moves.

The sheet is **held on to** while it is on screen. The act of answering changes
the screen the next answer is read off: once the strip of glass is gone the row
is no longer standing on the page, the test that found the sheet by what was
drawn under the row finds nothing, and without this the glass would come back
and the sheet would drop onto the row again, once per frame, for as long as it
was open.

And the row is told **how much of it is left over the page**. Both the sheet and
the floor its buttons are measured against are anchored to the same viewport, so
both rise by exactly the same amount, and "is anything still underneath" answers
the same before and after the room is made. Without the second number the row
stands down for as long as a sheet is open, and a row you cannot leave a sheet
by is not a row. `__quietLift` is the app saying what it gave.

Thirteen checks, which is ninety-eight in that file.

## Cut, not moved

The ninth answer shrank the viewport, and a photograph finally measured
something instead of showing the same picture again:

    0 – 25.9 pt    the app
    25.9 – 78.4    the island, 52.5 pt tall
    78.4 – 130.9   the app's strip
    130.9 –        the sheet

The glass ends a hundred and twenty-eight points up, to the point. The shrink
fired. And Instagram's sheet did not rise with it — it was cut, straight through
"Log In to an Existing Account".

Which answers the question the eight rounds before it could not. A sheet clipped
by a shorter viewport is a sheet that is not anchored to the bottom of one: it is
placed by a number somebody worked out when it opened, and nothing done to the
viewport will ever move it. Eight mechanisms failed on detection; the ninth
found it and then moved the wrong thing.

So the page keeps the whole glass and the sheet is moved in the page, by a
transform. A transform does not care what put the box where it is — a computed
top, a bottom, or Instagram's own translate — and `!important` in a stylesheet
outranks the inline style their animation leaves behind. Padding is wrong here
and was removed: on a sheet that *is* anchored to the bottom it moves the box
twice.

What a transform cannot do is fill the gap it opens underneath, so the app paints
a strip there in the sheet's own colour. That colour was being read by climbing
*up* from what was found — and what is found is as often the backdrop as the
panel, a backdrop is see-through by design, and climbing up from one lands on the
page. The same photograph shows it: the strip in the page's near-black instead of
the sheet's grey. It reads downwards now, for the widest opaque box inside.

And the rehearsed sheet in CI is no longer anchored to the bottom either. It was,
and it would have passed a test the real one fails.

One more thing the transform brings with it: once moved, the sheet is a hundred
and twenty-eight points clear of the bottom edge and fails the test that chose
it. Letting it go would drop it back, find it again, and flicker for as long as
it was open — so a sheet already moved is measured where it was.

Five checks, which is a hundred and three.

## A transform is a containing block

The tenth answer moved the sheet with a transform, and the photograph came back
with the sheet's own contents piled on top of each other: "Switch accounts" and
an account row drawn on the same line, the rest gone.

That is not a bug in the moving. It is what a transform is. An element with one
becomes the containing block for every `position: fixed` thing inside it, and
Instagram's sheet has fixed children that were anchored to the viewport. They
were suddenly anchored to a box a third of the way down the screen.

Margins instead. A margin moves a box and changes nothing about what anything
inside it is measured against. Both are set, because the sheet may be held by
either edge and only one of them can be answering: a box placed by `top` ignores
the bottom margin, one placed by `bottom` ignores the top, and either way it ends
up a hundred and twenty-eight points higher.

The rehearsed sheet in CI now carries a mark of its own that is anchored to the
viewport, three hundred points from the top, and the check fails if it moves.
That is this failure, reproduced: a mechanism that re-anchors what is inside the
sheet is caught in nine minutes rather than in a photograph.

Which is the pattern of this whole sequence, written down once more. Every round
that was settled by looking at a phone took twenty minutes and produced one bit
of information. Every round where something was measured produced the next
finding: the glass ends at 128 (so the shrink fired), the sheet was cut (so it is
not anchored to the bottom), the contents piled up (so the mechanism re-anchored
them). The checks are worth more than the fixes.

## The inbox is not a sheet

The same build that piled the account switcher on top of itself did it to the
inbox as well, and that one is the more useful photograph. Nothing modal was
open. The list of conversations had simply been taken for a sheet, moved up a
hundred and twenty-eight points, and — because the mechanism was a transform —
re-anchored the inbox's own fixed header on the way.

It passes every test a sheet passes. It spans the glass, it starts under the
header, it reaches the bottom edge, and it sits inside something held against
the screen. By shape it is a sheet, and shape is all that was being asked.

A sheet is put in *front* of the page, and the page is what is inside `main`.
Instagram builds its modals where every framework builds them, at the foot of
the body, outside the document's own content. So the shape test now refuses
anything inside `main`.

The declaration is still believed anywhere, and the asymmetry is deliberate.
Saying "I am modal" is a statement of intent that only a sheet makes; being the
shape of a sheet is a guess, and the inbox is what the guess costs when it is
wrong. The guess is refused inside the page's own content; the statement is not.

## No blue rectangles

Two photographs: the Instagram wordmark in a blue outline, and the name at the
top of a profile in another.

That is WebKit's focus ring, and Quiet put it there. The row along the bottom
navigates by pressing the link Instagram already has — which is the right way to
do it, because loading an address throws the page away — but a click made by a
script reads to WebKit as a keyboard press rather than a finger. So the pressed
link keeps the focus and gets a ring, and the heuristic stays that way
afterwards, which is why the next thing a *finger* touches gets one too.

The row is the app's own furniture. Pressing it is a navigation, not a decision
about where the cursor goes, and nothing about it should leave a mark on the
page. So the press lets go of the focus straight after — three times, because a
router that changes the screen puts the focus somewhere of its own on the way.

Never on something being typed in. Taking the keyboard away from somebody
mid-word would be a far worse thing than a blue rectangle, and it is the one
case checked twice.

Nothing was done to the ring itself. Suppressing outlines across the page would
have fixed the photograph and taken the focus ring away from anybody navigating
with a keyboard, who is the one person it is for.

## The row leaves the page

Twelve answers to one photograph: Instagram's account switcher comes up, and
Quiet's row is drawn across the buttons on it.

Eleven of them were mechanisms, and they shared a shape. Pad the panel.
Transform the panel. Give the panel a margin. Shrink the glass underneath it.
Take the row away while a sheet is up. Leave the row and stop it answering taps.
Every one of them moved something of Instagram's, and moving something of
Instagram's means recognising it first.

Recognition is the half that failed, and it failed in both directions. For eight
rounds it found nothing, because Instagram never says a sheet is one: no
`role="dialog"`, no `aria-modal`, nothing. So the search was rebuilt to work by
shape — held against the bottom edge, the width of the glass, shorter than it,
full of things to press — and the shape it then found was the inbox. A list of
conversations is held against the bottom edge, spans the glass, and is full of
things to press. It was moved a hundred and twenty-eight points up, over its own
header, and the photograph of that came back as "und das ist kaputt gegangen".

The mistake was not in any of the eleven. It was in the shape they share.

A sheet is anchored to the bottom of the viewport. That is what a sheet *is* —
not a class name, not a role, a position. So the row is put outside the
viewport: the web view is given a frame that starts under the clock and stops at
the top of the row, and the app paints the strip underneath in the page's own
colour. The bottom of the page's world is now the top of the row, and every
sheet Instagram will ever open — the account switcher, sharing, the menu behind
the three dots, and whatever it ships next month — lands above it. Nothing of
Instagram's is touched, recognised, or named.

It is the same answer the status bar already had, at the other end of the
screen, written up six sections above this one: *so the viewport itself is made
smaller. Everything in it is right by construction.* Both ends of the app now
say it, and the second one took eleven builds longer than the first because the
question wore a different hat.

What goes with it is the whole apparatus: the sheet detector and its three
strategies, the lift, the marking, the colour reading, the row standing down,
the strip painted in the sheet's own colour, `--quiet-row`, `--quiet-lift`, and
thirty-seven checks in the harness. Four checks replace them, and they check the
absence — that a sheet, a declared dialog and the inbox all come through
unmarked, unmoved and unhidden — because the mechanism they guard against is one
somebody would reasonably write again.

What it costs is real: the feed no longer runs behind the row. The band at the
bottom is the app's own paint rather than the next photograph. Instagram's own
app draws an opaque tab bar there, so it is not a difference anybody looks at
side by side and notices — and it is the price of a sheet that works on every
screen rather than on the ones a heuristic happened to recognise.

The measurement in CI stays and gets sharper. A rehearsed sheet is put on the
real page, held against the bottom of the viewport, and its foot is photographed
against the bottom edge of the screen. It used to have to agree with the number
the app moved sheets by; it now has to agree with the height of the row, summed
out of the three constants the row is built from rather than written down in the
workflow. It does: **eighty-nine points, to the point**, on the first run that
reached it. That is the number eleven mechanisms never produced.

Two things the same run said, both worth keeping.

The row itself had moved seven points up — twenty-five in the source, thirty-two
in the photograph — the moment the web view stopped being as tall as the screen.
Seven is exactly what the web view's box lost against the safe area. With no
child left the height of the glass, the stack worked its own height out from its
tallest child and came up short at the bottom. It is given the glass outright
now, which is the same sentence the web view two screens above it already
carried: ignoring the safe area is a request about edges, and a size is not a
request. Nobody would have caught seven points by eye, and the row has been
argued about four times.

And the mark pinned inside the rehearsed sheet, which is there to catch the
sheet becoming the containing block for what is fixed inside it, was briefly
moved to the bottom edge so that both numbers would be distances from the same
place. That was wrong twice over. Held by the bottom it lands in the same spot
whether it is re-anchored or not, since the sheet's bottom edge *is* the bottom
of the viewport — a check that cannot fail. And it made the check arithmetic in
CSS pixels, which are not points: a page that declares no viewport is laid out
at nine hundred and eighty and scaled to fit, so three hundred came back as a
hundred and twenty-three. It is held by the top again, and the question is now
whether the mark is on the screen above the foot at all — which is the same
answer at every scale, because re-anchoring sends it three hundred down from the
top of a sheet two hundred and sixty tall, which is off the bottom of the screen.

---

## Instagram's own answer is the clock

For a long time the trade-offs said a date moved *forward* could not be caught
without a server, and Quiet has no server. That was true about a server and
false about the answer.

Every page the app loads comes back carrying a `Date` header, put there by the
machine that served it. Nothing is asked of anybody, no request is made, and
nothing leaves the phone — it is one line of a response the app was already
reading. Paired with the device's uptime, which counts real elapsed time from
the last restart and which no settings screen can reach, it says what time it is
regardless of what the phone claims.

Ten minutes of tolerance, which is far more room than either a `Date` header or
a phone on automatic time needs, and three orders of magnitude short of the
thing being defended against.

It fixed the other direction too, which nothing else could. A clock pushed
forward and then pulled back used to poison the high-water mark for as long as
the jump was wide: the app froze, correctly by its own rule and uselessly for
the person holding it. An instant somebody else vouched for, sitting behind the
mark, is evidence the mark was made of a lie — and it is the one thing in the
app allowed to bring the mark down.

## The wait can be chosen, and choosing it obeys itself

A week is the rule this app was built around and it is also somebody's guess.
Refusing to let a reader be *stricter* would be the app standing between
somebody and a smaller number, which is the one thing it promises never to do.

So the wait is seven days, a fortnight or a month — under the same asymmetry as
everything else, which is the only way it can move at all. Longer takes effect
at once. Shorter is subject to the wait it is trying to shorten, and spends it.
Without that second half, shortening the wait would be the free move that
shortening the limit is, and the weekly rule would have a door in it: the
cooldown would be the single dial you could turn down at the exact moment it
started to bite.

Not offered during setup. First run asks two questions, and the reason it asks
only two is written above; a third would be a decision nobody has enough
information to make yet.

## There is a way out, and it opens slowly

The limit lives in the keychain because it has to outlive the app being deleted.
That is the promise. The consequence nobody had written down is that there was
no way out at all — the only exit was for somebody to know that a keychain
exists and to go and find it, which is not an exit, it is a trap with
documentation.

So there is a door, the same shape as every other door here. "Make Quiet forget
everything" takes effect after the wait currently in force, and can be called
off at any moment before then for nothing, because changing your mind about
being released is asking to be held to the rule.

The Instagram session is not part of it. Signing out has its own button and
always did; bundling the two would mean somebody asking to be released from a
rule was also, a week later and without being asked again, logged out.

## Time on Instagram includes reading messages

Never argued about in writing, which is why it is here.

Quiet counts every second the site is on screen, and a conversation is the site
being on screen. Two arguments were weighed. Messages are the part of Instagram
that is unambiguously *for* something, and charging for them makes the app
slightly worse at the thing nobody objects to. But an exemption for messages is
an exemption anybody can stand in: the inbox is one tap from the feed, and a
budget with a room in it that does not count is a budget with a room people
learn to sit in.

The panel is free and the search is free because neither of them is Instagram —
they are the app's own furniture, and time spent deciding how much time you want
is not time spent. A conversation is not furniture.

## The notices can be turned off; the limit cannot

The two warnings on the way down are a setting. It is worth being careful about
why that is not a hole.

A warning changes nothing about how much time there is. The limit is the limit
whether or not anybody is counted down to it, the curtain falls at the same
second either way, and turning them off buys not one minute — a test insists on
exactly that. The single argument this app refuses to have is about *how much*,
and this is not that argument.

What it buys, for a certain kind of reader, is not being told that five minutes
remain, since that sentence is precisely the thing that starts a last five
minutes.
