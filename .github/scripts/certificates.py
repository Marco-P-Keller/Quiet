"""Certificates, borrowed and given back.

Xcode cannot reuse a signing certificate whose private key it does not have,
and a fresh runner never has one. So every upload asks App Store Connect for a
new certificate, Apple allows two of the development kind, and by the third run
the account is full — which is exactly how two uploads failed with

    Choose a certificate to revoke. Your account has reached the maximum
    number of certificates.

while the app itself was fine. The archive needs a development certificate; the
second error line in that failure says so, and it is easy to misread as a
distribution problem.

Two jobs, one for either end of a run:

    return   Revoke whatever this run created. Only certificates created after
             the moment the run started signing are touched, which by
             construction is only the ones this run caused to exist. Nothing
             that was on the account beforehand can match.

    reclaim  Revoke the oldest development certificate, to make room. Asked for
             by hand, per run, because it destroys something — and offered at
             all because the person who owns this account has a phone and no
             Mac, and revoking from a phone is a long afternoon.

Revoking affects nothing already on the App Store or in TestFlight: Apple
re-signs what it distributes. It only stops that certificate signing anything
new, and nothing else holds its private key.
"""

import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

ROOT = "https://api.appstoreconnect.apple.com"

# The development kinds, whichever name Apple is using this year.
DEVELOPMENT = "DEVELOPMENT"


def token():
    now = int(time.time())
    with open(os.environ["KEY_PATH"]) as key:
        secret = key.read()
    return jwt.encode(
        {
            "iss": os.environ["ISSUER"],
            "iat": now,
            "exp": now + 600,
            "aud": "appstoreconnect-v1",
        },
        secret,
        algorithm="ES256",
        headers={"kid": os.environ["KEY_ID"], "typ": "JWT"},
    )


def call(bearer, method, path):
    request = urllib.request.Request(ROOT + path, method=method)
    request.add_header("Authorization", "Bearer " + bearer)
    with urllib.request.urlopen(request, timeout=30) as answer:
        body = answer.read()
    return json.loads(body) if body else {}


def made(stamp):
    """When a certificate was created, in seconds.

    Apple sends "2026-08-20T07:53:20.000+0000" and has sent a trailing Z in the
    past. Anything this cannot read counts as ancient, because the only safe
    mistake here is to leave a certificate alone.
    """
    text = (stamp or "").replace("Z", "+0000")
    for shape in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return int(datetime.datetime.strptime(text, shape).timestamp())
        except ValueError:
            continue
    return 0


def name(certificate):
    attributes = certificate.get("attributes", {})
    return attributes.get("name") or attributes.get("certificateType") or "?"


def certificates(bearer):
    return call(bearer, "GET", "/v1/certificates?limit=200").get("data", [])


def revoke(bearer, certificate):
    try:
        call(bearer, "DELETE", "/v1/certificates/" + certificate["id"])
        print("Revoked:", name(certificate))
        return True
    except urllib.error.HTTPError as error:
        print("Could not revoke", name(certificate), "-", error.code)
        return False


def give_back(bearer):
    since = int(os.environ.get("SIGNING_SINCE") or 0)
    if not since:
        print("No start time recorded; leaving the account alone.")
        return

    given = 0
    for certificate in certificates(bearer):
        if made(certificate.get("attributes", {}).get("createdDate")) < since:
            continue
        if revoke(bearer, certificate):
            given += 1
    print("Gave back", given, "certificate(s) this run created.")


def reclaim(bearer):
    found = [
        certificate
        for certificate in certificates(bearer)
        if DEVELOPMENT in (certificate.get("attributes", {}).get("certificateType") or "")
    ]
    if not found:
        print("No development certificates on the account; nothing to reclaim.")
        return

    found.sort(key=lambda one: made(one.get("attributes", {}).get("createdDate")))
    print("Development certificates held:", len(found))
    revoke(bearer, found[0])


def main():
    job = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        bearer = token()
    except Exception as error:  # a key that will not load is not worth a red run
        print("Could not build a token:", error)
        return

    try:
        {"return": give_back, "reclaim": reclaim}[job](bearer)
    except KeyError:
        print("Nothing to do:", job or "(no job named)")
    except urllib.error.HTTPError as error:
        print("App Store Connect said", error.code)
    except urllib.error.URLError as error:
        print("Could not reach App Store Connect:", error.reason)


if __name__ == "__main__":
    main()
