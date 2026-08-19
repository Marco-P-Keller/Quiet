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
* **Push notifications.** Quiet does not send any, by design, and the web client
  cannot.

## Because of what Quiet removes on purpose

* **Reels are gone completely** — the tab, the feed, the reels tab on a profile,
  and reels sent to you in a DM. A friend's link will say "Reels are off in
  Quiet." rather than open.
* **Explore is gone**, and with it hashtag pages and the account directory.
* **There is no search page.** The panel goes straight to a username you type.
  Fuzzy search, "people you may know" and searching by display name are gone
  with it.
* **Suggested posts and suggested accounts** are removed from the feed by
  matching their wording. `trim.js` carries the phrases for English, German,
  Spanish, French, Italian, Portuguese, Dutch and Swedish. In any other
  language they will still appear; adding one is a one-line change.

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
  keep working. `trim.css` matches on `href` and ARIA attributes, which is as
  stable as the DOM gets — but Instagram can still rename or restructure, and
  when they do, an entrance reappears until somebody updates a selector. That is
  the maintenance cost of this whole approach, and there is no version of it
  without one.
* **Instagram can serve a different page to a web view than to Safari.** Quiet
  presents a Safari user agent so it gets the real mobile site. If Instagram
  changes what it serves, that is a thing to fix, not a thing that fails
  gracefully.
* **Logging in with Facebook leaves Instagram's domain.** Meta's login domains
  are allowed to open inside the app, because bouncing them to Safari would
  break signing in.

## Because there is no server

* **A clock moved forward cannot be caught.** Setting the date to next week
  grants a new day, and there is no way to know without asking a server Quiet
  does not have. Turning the clock *back* is handled: time freezes until the
  real clock catches up.
* **Changing the time zone is not a way through**, though it used to be. The
  local date moves a whole day in either direction the moment a zone changes,
  and a different date was being read as a day that had passed. The day now
  keeps the ending it was given when it began: the day you are in is as long as
  it was born to be, and the next one starts at 4 a.m. wherever you have
  landed.
* **Nothing syncs.** A second device has its own limit and its own day.
* **There is no backup.** The state lives in this phone's keychain. Restoring an
  encrypted iPhone backup carries it over; anything else starts fresh.

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
