# Shipping this

Engineering notes on what stands between Quiet and other people's phones. Not
legal advice, and worth checking against the current rules before acting on —
both Apple's and Meta's change.

## For your own phone: no obstacle

Build it in Xcode and run it on your device. A free Apple ID signs an app for
seven days; a paid developer account signs it for a year. Nothing in this
section applies to a build you run yourself.

This is the deployment Quiet was written for.

## For the App Store: three real problems

### 1. Guideline 4.2 — Minimum Functionality

An app whose main job is to show somebody else's website in a web view is the
textbook 4.2 rejection. Apple's own wording asks for "a persistent value" beyond
a repackaged web page.

Quiet has an argument here, and it is a decent one: the value is not the web
page, it is the enforcement — a limit that survives reinstallation, blocking
that works at the URL layer, an app whose entire point is what it *removes*.
That is a real product, and there are apps in the store built on the same idea.

It is still an argument you have to make to a reviewer, and reviewers differ.
Expect at least one rejection and a written appeal.

### 2. Guideline 5.2.2 — Third-Party Sites

> "…an app that displays a third-party service's content should have permission
> from that service."

This is the harder of the two. Framing decides a lot here. An app presented as
*"an Instagram client"* is asking to be measured against Instagram's rights. The
same binary presented as *a focused browser with content blocking, which happens
to open one site by default* is a category Apple has approved many times.

Concretely, that means:

* Do not use "Instagram" in the app name, the icon, the subtitle, or the
  keywords beyond a plain nominative reference in the description.
* Keep the disclaimer visible — it is already in the About section of the panel
  and at the bottom of the store description.
* Do not use Meta's marks or colours anywhere in the UI. Quiet's own screens
  deliberately look nothing like Instagram, which helps here as well as
  aesthetically. **The glyphs are the one deliberate exception**, and it is an
  exception rather than an oversight: the wordmark this app used to fetch and
  re-draw is gone, the row along the bottom still wears Instagram's own icons,
  and the argument for keeping them is written down under *what was deliberately
  kept* below. The submitted review notes neither claim otherwise nor raise it.

### 3. Meta's Terms of Use

Meta's terms prohibit accessing the service by unauthorised means and modifying
or interfering with how it is presented. Quiet injects CSS and JavaScript into
pages a signed-in user is viewing, which is what every content blocker and
reader mode does — but read strictly, it is on the wrong side of that sentence.

The practical risk is not a lawsuit. It is:

* **a takedown request**, which historically is how Meta has dealt with apps
  like this one; and
* **account risk for users**, which is speculative but not zero, and which
  anyone shipping this should say out loud rather than leave for people to
  discover.

Two things reduce the exposure, and both are already true of this code:

* Quiet has **no server and no scraping**. It runs in a web view, on the user's
  own logged-in session. Nothing is collected, and nothing is sent anywhere the
  developer can reach: the one optional sync writes a limit and a running total
  into the reader's *own* iCloud, which the developer has no access to.
* Quiet **does not touch authentication**. The login page is Instagram's, the
  injected script never reads a form field, and no credential passes through any
  code in this repository.

## What was taken out so that the three arguments above are true

Everything in this section was in the app and is not any more. It is written
down rather than merely deleted, because each one was there for a reason that is
still a good reason, and somebody will eventually want to put it back.

The test for every one of them was the same question: **is this a browser showing a page,
or a client of Instagram's?** A content blocker has a real defence — it does its
work in the open, on a page its reader asked for, in the reader's own session.
Every line below gave that defence away for something cosmetic.

### 1. Three requests to Instagram's private web API

`/api/v1/web/accounts/edit/web_form_data/` for the signed-in name,
`/api/v1/users/web_profile_info/` for a face, and
`/api/v1/web/search/topsearch/` for the people behind the search field. Each one
carried `X-IG-App-ID: 936619743392459` — the identifier Instagram's own web
client sends, and the only value those endpoints answer.

That they ran inside Instagram's page with the reader's own cookies is the
sentence that made them feel all right, and it is not the point. The point is
the header. An app that hand-writes Instagram's client identifier onto a request
to an endpoint Instagram does not publish is not showing a page, it is
impersonating a client — which is the conduct Meta's terms name in as many
words, and the one thing here no amount of the rest of this app being careful
would have excused.

**What it cost, and what was bought back.** Two of the three were replaced by
reading a page rather than asking an endpoint, which is what every reader mode
does and costs nothing anybody can see:

* The **signed-in name** comes off Instagram's own navigation bar — a link in a
  page the reader is already looking at, and already in the code as the
  fallback. `learnMe` in `trim.js`.
* The **faces in the recently-opened list** come off the profile pages
  themselves, at the moment somebody opens one. That list is of people this
  phone *opened*, and a profile somebody opened has that person's photograph at
  the top of it. `faceOnThisProfile` in `trim.js`, and it is the better source
  as well as the defensible one: no round trip, nothing asked about anybody who
  was never opened, and the picture is there before the list is next looked at.

**Only the third could not be bought back.** Live search needs an endpoint that
answers a typed string, and there is no such page. The field narrows the
recently-opened list as you type and offers the typed name itself as the last
row — which for the three or four people this screen exists for is the same
screen, answered instantly and with no request at all. A stranger who has never
been opened has to be typed exactly. `SearchView.narrowing`, measured in
`RecentsTests`.

### 2. The Instagram wordmark, fetched and re-drawn

The app draws the script wordmark; the website draws the newer one. A pass here
fetched `/accounts/login/` in the background, cut `svg[aria-label="Instagram"]`
out of the markup and drew that one in the header instead. Careful, and still
this app's code re-drawing somebody else's mark. The header shows whatever
Instagram drew there, untouched.

### 3. Two background requests for pages nobody asked to see

Both of the above fetched a whole second document on the way to the feed. With
them gone, a full trim pass makes **no network request at all** except for a
picture the page itself has already loaded: the reader's own face, and — on a
profile page, and only there — that person's. Both are `<img src>` values off
the document, fetched without credentials.

That is checked rather than asserted. `Tools/page.js` records every address the
script asks for; `read-the-header.js` fails if a full pass over a feed asks for
anything at all, and `read-the-trim.js` pins down *which* picture a profile page
gives up — a profile is mostly a grid of square photographs the same size as a
face, and one of somebody's own photographs filed under their name would be
worse than no photograph.

### 4. A private class name in the shipped binary

Not Meta's — Apple's. `FormBar` removes the floating capsule iOS 26 draws over
Instagram's send button, and to do it it has to reach the view that answers the
keyboard's questions for a page. It used to find that view by matching the class
name `WKContentView`, which is WebKit's private business and was sitting in the
binary as a string literal, in an app whose whole review argument is that it
takes no liberties.

It asks by conformance now: the view that answers for the page is the one that
is a `UITextInput`, which is a public protocol, is the thing that actually
matters about it, and is true of no other subview of a web view's scroll view.
Better on the merits as well as on the paperwork — a class WebKit renames
tomorrow still has to conform to that protocol in order to hold a keyboard at
all. Measured in `FormBarTests`, which finds the view and then checks that no
bar is drawn anywhere in the app.

### And what was deliberately kept

* **A user agent carrying Safari's tokens.** `Mozilla/5.0 (iPhone; …) …
  Safari/604.1 Quiet/1.0`. This was taken out once and has been **put back**,
  on 2026-09-28, with the app's own name appended to it.

  The reasoning that took it out was about Meta and was written as though it
  were about Apple, and those are not the same question.
  `WKWebView.customUserAgent` is a public Apple API provided for exactly this;
  no guideline speaks to what an app puts in that string, and App Review does
  not see it. What the honest string risks is the thing this app cannot
  survive: Instagram serves a stripped-down page to a client it does not
  recognise, and what it recognises is `Mobile` and `Safari`. An app whose whole
  purpose is a daily limit on **the real site** cannot trade the real site for a
  point of principle nobody at Apple is asking about.

  The last token is the difference between this and a disguise. Chrome appends
  `CriOS/…`, Instagram's own in-app browser appends `Instagram …`, and this
  appends `Quiet/1.0` — the platform norm, and a string that names the app
  asking. `UserAgentTests` holds all of it, because two documents make claims
  about this string and one of them goes to Apple.

  **This is the first line to give back if Meta objects.** It costs a possibly
  thinner page and nothing else. What must never come back with it are the three
  requests under 1 above: a user agent is a browser saying which engine it is,
  and `X-IG-App-ID` on an unpublished endpoint is an app saying it is Instagram's
  own client. The first is a convention; the second is the thing Meta's terms
  name outright.
* **Instagram's glyphs, in Quiet's own row.** The house, the paper plane and the
  magnifier are read out of the navigation bar Quiet hides, rasterised by the
  page and drawn in Quiet's own bottom row. This is the one item on the list
  above that was weighed and **kept**, on 2026-09-28, knowingly.

  The argument for taking it out is the honest one and it is above: it is
  another company's artwork inside this app's furniture, and the rule at the top
  of this page says not to. The argument for keeping it is that it is a
  different *kind* of exposure from everything else here — no endpoint, no
  impersonation, no header hand-written to obtain a reply that would otherwise
  be refused, and nothing shipped in the binary. It is a drawing on a page the
  reader is looking at, redrawn at the foot of the same screen.

  What it buys is the row. SF Symbols were tried and they are unmistakably
  somebody else's drawings — a different house, a differently tilted paper
  plane — beside a clock this app draws by hand to a two-point stroke. The whole
  store listing is photographed with this row in it.

  **If a reviewer raises it, take them out.** That is a stylesheet's worth of
  work and the app is unchanged in every other respect; it is not a position
  worth defending. The review notes say nothing about it — and nothing in them
  is untrue as a result: the sentence about trademarks is scoped to the app's
  name, icon and subtitle, all three of which carry none.
* **Advertising is not touched.** Every selector in `trim.css` carries
  `:not(article a)`, so nothing inside a post is hidden — and an advertisement
  is exactly a post whose media is a reel and whose button goes to the App
  Store. Quiet removes entrances, not revenue. This is the first thing to say in
  any correspondence with Meta.
* **Nothing goes near authentication.** The login page is Instagram's, the
  injected script never reads a form field, and no credential passes through any
  code in this repository.
* **Three pages are opened per cold start**, not one: the feed, and ten seconds
  later the inbox and the profile, one at a time, only when signed in. They are
  pages the reader is about to open, prepared the way every browser prepares a
  page it expects — a speculative load, not a crawl. Kept deliberately.

## The version with no argument to make

Apple's **Family Controls** and **Device Activity** frameworks can shield an app
system-wide: the real Instagram app, blocked at the OS level, on a schedule you
set. That is strictly better than anything a web view can do — it holds even
when you open Instagram directly.

It needs the Family Controls (Distribution) entitlement, which Apple grants on
request for apps genuinely in the screen-time category. Approval is not
automatic and the request takes time.

That version of Quiet is a different app: no web view, no trimming, no terms
problem, and none of the maintenance in `trim.css`. It also cannot give you a
feed with Reels removed — it can only give you no feed at all. Which of those
two products is the right one is a real question, and worth answering before
writing any more code.

## Before the first upload

Things App Store Connect checks mechanically, before any human sees the app.

* **Privacy manifest.** Present, at `Quiet/Resources/PrivacyInfo.xcprivacy`. It
  declares **two** required-reason APIs, and both are needed:
  `ProcessInfo.systemUptime`, the clock the limit rests on, under
  `NSPrivacyAccessedAPICategorySystemBootTime` with reason `35F9.1` —
  measuring time between events inside the app; and `UserDefaults`, where the
  preferences live, under `NSPrivacyAccessedAPICategoryUserDefaults` with
  reason `CA92.1` — written and read by this app alone, no app group.
  Either one missing and the upload is rejected with ITMS-91053, before any
  human sees it. The second was added after the first shipped without it, which
  is the way this particular hole is normally found.
* **Bundle identifier.** `com.connexa.quiet`, set in `project.yml` and in the
  checked-in project, with team `B97SQSQBMR`. It still needs an app record
  created against it in App Store Connect before anything can be uploaded —
  the TestFlight workflow says so in as many words if it is missing, rather
  than failing in xcodebuild's voice.
* **Icon.** 1024×1024, opaque, no alpha channel — which is why
  `Tools/make-icon.py` writes 8-bit RGB rather than RGBA. An icon with alpha
  is rejected. The one in the catalogue is 8-bit RGB and carries no `tRNS`
  chunk, which is the pair of facts that sentence actually means.
* **Export compliance.** `ITSAppUsesNonExemptEncryption` is `false` in
  `Info.plist`, so no question is asked on each upload.
* **Build numbers.** Not typed and not kept in the repository.
  `CURRENT_PROJECT_VERSION` reads 1 in the project and is overridden on the
  command line by the TestFlight workflow, which passes `github.run_number` —
  a number that only ever climbs. App Store Connect refuses a second upload
  with a build number it has already seen, and this is why it never gets one.
  `MARKETING_VERSION` is 1.0 and is the one a person sees.

## If it ships

The store listing needs, at minimum:

* the trade stated in the description, not buried — slower pages, no posting, no
  Reels even from DMs;
* the keychain behaviour stated, since a limit that survives deletion will
  otherwise arrive as a one-star surprise;
* the disclaimer: **Quiet is not affiliated with or endorsed by Instagram or
  Meta.**

`ITSAppUsesNonExemptEncryption` is already set to `false` in `Info.plist`, which
saves an export-compliance question on every upload.
