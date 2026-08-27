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
* Do not use Meta's marks, colours or glyphs anywhere in the UI. Quiet's own
  screens deliberately look nothing like Instagram, which helps here as well as
  aesthetically.

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
  declares one required-reason API: `ProcessInfo.systemUptime`, the clock the
  limit rests on, under `NSPrivacyAccessedAPICategorySystemBootTime` with
  reason `35F9.1` — measuring time between events inside the app. Without it
  the upload is rejected with ITMS-91053 and never reaches review.
* **Bundle identifier.** Ships as `com.example.quiet` and must be changed to a
  real one, registered in the developer portal, with an app record created in
  App Store Connect before anything can be uploaded against it.
* **Icon.** 1024×1024, opaque, no alpha channel — which is why
  `Tools/make-icon.py` writes 8-bit RGB rather than RGBA. An icon with alpha
  is rejected.
* **Export compliance.** `ITSAppUsesNonExemptEncryption` is `false` in
  `Info.plist`, so no question is asked on each upload.
* **Build numbers.** `CURRENT_PROJECT_VERSION` is 1 and never moves. App Store
  Connect refuses a second upload with a build number it has already seen, so
  any real pipeline has to increment it.

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
