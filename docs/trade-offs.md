# What you're trading

Everything Quiet cannot do, in one place, so nobody has to find out by using it.

## Because it runs on the mobile site

Quiet is Instagram's mobile web client in a web view. That gets you the feed,
stories, DMs, profiles, notifications, likes, comments and search-by-username.
It does not get you:

* **Posting.** No camera, no story composer, no editing tools.
* **Speed.** Pages load a beat slower than the native app, always.
* **Anything Instagram ships only in its own client**, which changes without
  notice and always will.
* **Push notifications.** Quiet cannot tell you that a message arrived, and no
  amount of engineering changes that: only Instagram knows, and Instagram pushes
  to its own app. Anything else — a server, CloudKit, Firebase, all of them land
  in the same place — means something somewhere else logged in as you, which is
  the one thing this app is built never to be.
  This is worth naming as the cost it is: with no notifications, "have I got a
  message" is a question that can only be answered by opening the app, which is
  a reason to open it more often, not less.
  What exists instead is an appointment, and it answers a different question. A
  single reminder a day, at an hour you choose, saying only that the window is
  open — and none at all on a day you have already been. It cannot tell you
  whether anything happened. It can take away the reason to keep finding out.

## Because of what Quiet removes on purpose

* **Reels are gone completely** — the tab, the feed, the reels tab on a profile,
  and reels sent to you in a DM. A friend's link will say "Reels are off in
  Quiet." rather than open.
* **Explore is gone**, and with it hashtag pages and the account directory.
* **There is no search page.** Finding someone searches Instagram for people
  and nothing else, and remembers the last eight profiles you opened so the
  three or four you actually visit are one tap away. What is gone with the page
  is Explore behind it: no hashtags, no places, no grid of strangers.

## Because Instagram would rather you used Instagram

* **Its pages carry a button that opens Instagram's own app.** Quiet refuses
  it — `instagram://` links are turned down with "Quiet is your Instagram
  here." It is the only link a person deliberately taps that the app declines,
  and it is declined because handing it over would undo the whole thing in one
  tap.
* **Nothing stops anyone opening the real app from the home screen.** Quiet is
  a self-imposed rule, not a lock on the phone.

## Because it is a web view and not a native client

* **The trim files have a shelf life.** `ContentRules` matches on URLs and will
  keep working, and a content rule list compiled into WebKit enforces the same
  addresses a second time, below anything Quiet's own code can be asked about.
  `trim.css` and `trim.js` match on `href`, on ARIA attributes and on wording,
  which is as stable as the DOM gets — but Instagram can still rename or
  restructure, and when they do, the tidying stops until somebody updates a
  selector. That is the maintenance cost of this whole approach and there is no
  version of it without one.

  What there is now is a witness. The trim pass counts what it finds, and an app
  that has opened five pages without once finding Instagram's own navigation
  says so in the panel. It cannot mend anything. It turns "somebody eventually
  notices while scrolling" into a sentence.
* **Suggested posts are recognised by their wording**, in twenty-four
  languages, and only when somebody has asked for them to be taken out — they
  are shown by default. In a language not on the list they will still appear
  when asked for; adding one is a line. The comparison is accent-blind and ignores how the spaces and capitals
  arrive, which is what makes a list of hand-written phrases survive contact
  with a real page.
* **Instagram can serve a different page to a web view than to Safari.** Quiet
  presents a Safari user agent so it gets the real mobile site. If Instagram
  changes what it serves, that is a thing to fix, not a thing that fails
  gracefully.
* **Logging in with Facebook leaves Instagram's domain.** Meta's login domains
  are allowed to open inside the app, because bouncing them to Safari would
  break signing in.

## Because there is no server

* **A clock moved forward is caught, as long as the app has been online.**
  This used to be the open half of the clock. Every page Instagram serves comes
  back with a `Date` header on it, and paired with the device's uptime that is
  enough to know what time it is whatever the phone says. Turning the clock
  *back* was always handled: time freezes until the real clock catches up.

  What is left of the hole: on a phone that has never reached the network since
  it was last restarted, nobody has vouched for anything, and the device is
  believed. That is the honest answer rather than a good one — but an app that
  shows a website has not been much use in that state anyway.
* **Changing the time zone is not a way through**, though it used to be. The
  local date moves a whole day in either direction the moment a zone changes,
  and a different date was being read as a day that had passed. The day now
  keeps the ending it was given when it began: the day you are in is as long as
  it was born to be, and the next one starts at 4 a.m. wherever you have
  landed.
* **Syncing is off until you ask for it, and it does not need a server.** A
  second device used to be a second allowance — two phones with a thirty-minute
  limit are an hour, which is the rule walked around by owning an iPad. The
  limit, the wait and today's total can now follow you through your own iCloud.
  What that costs is honesty about the merge: two devices *can* disagree, and
  what happens then is written down in `Carried.merge` rather than left to
  whichever spoke last. Less time never waits; more time does. The one door it
  cannot close is two devices, both offline, both queuing an increase in the
  same week — and even that buys the smaller of the two, which is no more than
  asking once.
* **There is no backup.** The state lives in this phone's keychain. Restoring an
  encrypted iPhone backup carries it over; anything else starts fresh.

## Because it is a phone app and only that

* **Portrait only, iPhone only.** Instagram's mobile site is a phone layout, and
  the app is built around a top edge that stays where it is. There is no iPad
  build and no landscape.
* **No widget, no Shortcuts, no Siri.** "How much have I got left" can only be
  answered by opening the app — which, as with notifications above, is a reason
  to open it. Both are possible and neither is built.
* **English and German only.** Every sentence in the app is in both, checked on
  every push. A third language is a person per language rather than a script:
  the app is mostly its sentences, and a machine translation nobody reads would
  make it worse in four languages rather than available in four.

## Because iOS is iOS

* **"The app closes" means the app ends, not that iOS quits it.** The curtain is
  a full screen with nothing on it. Quiet cannot force-quit itself, and no
  App Store app can — see [decisions.md](decisions.md).
* **Nothing stops you opening instagram.com in Safari.** Quiet is a self-imposed
  rule, not a lock on the phone. That would require Apple's Family Controls
  entitlement, which is a different project.

## Deliberately not built

Some of these were tempting. All of them were the wrong answer.

* **A "just five more minutes" button.** The reason the app exists.
* **Streaks, weekly reports, screen-time graphs.** A record of how much you
  scrolled is one more thing to check.
* **A visible countdown.** Turns every minute into something to watch.
* **A grace period at the end of a session.** Every limit that can be argued
  with gets argued with.
* **Passcode-locked settings.** The weekly rule already does the work, without
  another thing to forget.
