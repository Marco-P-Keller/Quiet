# The fields that are set once

Everything here is a switch or a line typed one time, in App Store Connect,
and not per language. Where a choice is arguable, the argument is in
[`docs/store-listing.md`](../docs/store-listing.md) and
[`docs/aso.md`](../docs/aso.md) rather than repeated here.

## App information

| Field | Value |
| --- | --- |
| Bundle ID | `com.connexa.quiet` |
| Primary language | English (U.S.) |
| Primary category | **Productivity** |
| Secondary category | **Health & Fitness** |
| Content rights | Contains third-party content — **no**. Quiet displays a website in a web view; it does not ship anybody's content. |
| Age rating | **17+** (see below) |
| Copyright | `2026 Connexa GmbH` |
| Version | `1.0` — the build number comes from the workflow's run number and never needs typing |

**Not Photo & Video.** It was set to that once, and it was doing harm: it put
the app beside photo editors, where the people browsing want something else,
and it filed it on the shelf where Instagram-adjacent tools live — which is the
association the review notes exist to argue against.

## URLs

| Field | Value |
| --- | --- |
| Privacy Policy URL | `https://marco-p-keller.github.io/Quiet/privacy.html` |
| Support URL | `https://connexa-gmbh.ch/support` |
| Marketing URL | `https://marco-p-keller.github.io/Quiet/` |

The support URL is the publisher's and the privacy URL is the app's, and the
split is deliberate: `connexa-gmbh.ch/datenschutz` is a *website* policy that
covers server logs, a contact form and cookies, and says nothing about the
keychain or the four permission strings. A reviewer who follows a privacy link
and finds a cookie notice has found a listing that does not match its binary.

## Age rating

Answer the questionnaire this way. What comes out is 17+, and that is correct.

* **User-generated content: yes, unrestricted.** Everything on the screen is
  Instagram's, which is exactly that.
* **Unrestricted web access: no.** The web view is confined to Instagram's own
  domains and the Meta domains a sign-in passes through. Everything else is
  handed to Safari, and Instagram's own "open the app" link is refused. This is
  enforced by URL rules in `ContentRules`, not by hiding buttons.
* Everything else: none.

## App privacy

**Data Not Collected.** Answer "No" to the first question and there is nothing
further to fill in.

Quiet has no networking of its own, no identifiers, no SDKs and no server to
send anything to. The Instagram session lives in the app's web storage exactly
as it would in Safari, which is Meta's collection, disclosed in Meta's own
listing. The optional iCloud sync does not change the answer: data in a user's
private key-value store, which the developer cannot read and never receives, is
not data the developer collects.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `false` in `Info.plist`, so App Store
Connect stops asking at every upload.

## Price

**Not decided anywhere in this repository, and it is the one field here that is
a business decision rather than a fact about the app.** Nothing in Quiet takes
money, asks for an account, or has a paywall in it, and the description promises
no server of ours — so Free with no in-app purchases is what the app currently
is. If it is to be paid, that is a build change as well as a field.

## App Review Information

* **Sign-in required: yes.** Add a demo Instagram account. A reviewer who
  cannot sign in sees a login page and nothing else, and "it looked like a
  website" is the one review this app cannot afford.
* **Notes:** paste [`review-notes.txt`](review-notes.txt).
* Contact: a name, a phone number and an address that is read the same day.

## Featured Content → Nominations

Free, and for this app realistically the largest single source of installs
available — larger than any keyword decision anywhere in this folder. The
reasoning and the evidence to put in it are in
[`docs/aso.md`](../docs/aso.md#editorial).
