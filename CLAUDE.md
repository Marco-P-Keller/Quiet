# Working on Quiet

## Where the app ships from

**TestFlight builds from the `quiet` repository, branch `dev`.** That is the
only branch a build has ever come from, and it is where every change belongs.

    git push standalone quiet-dev:dev

Push there **always**, and do not push to `main` in either repository unless
somebody asks for it in as many words. A change that is not on `dev` is a change
the person testing it cannot see — which cost a whole afternoon once: three
TestFlight builds in a row came back "still not fixed" because the work had been
pushed to the monorepo's branches and never to the one being built.

## The two repositories

| | |
|---|---|
| `Marco-P-Keller/quiet` | where it ships from. `dev` is the branch. |
| `Marco-P-Keller/heartdistance-legal` | the monorepo, under `breakthrough/`. |

They hold the same app, and the app source is meant to be **identical**. Copying
"the touched files" is what broke a TestFlight archive: one half of a two-file
change went across, the other did not, and the missing half was a colour
constant nothing in the copied file could compile without. Both repositories
then held a different half of two different changes, and neither built.

So the check is the whole tree, not the diff you think you made:

    diff -rq breakthrough/Quiet <the other repo>/Quiet

It must print nothing but the two documented exceptions: `README.md`, which
lives at the standalone repository's root, and `Tools/read-the-site.py`, which
checks a `site/` directory only that repository has.

And the drift can run in either direction, so read what it prints rather than
assuming which side is newer. A file changed in the standalone repository and
nowhere else is not stale — it is work you are about to overwrite.

## Before asking for a TestFlight build

**Look at the CI run for the commit you are about to build.** The archive that
failed at 14:41 had a red `Quiet` run at 14:40 saying exactly why. Waiting nine
minutes for a build that cannot compile is nine minutes; asking somebody else to
wait for it is worse.

## Before pushing

There is no Swift compiler here; CI is the compiler. What *can* be run locally,
and should be, takes seconds:

    node Tools/read-the-header.js     # the trim pass, asked questions
    node Tools/read-the-trim.js
    python3 Tools/read-the-strings.py # every sentence, in both languages

## The one habit that matters

Measure, do not look. Every round settled by a photograph of a phone costs
twenty minutes and yields one bit; every round where something was measured
yields the next finding. The CI job photographs the row and the rehearsed sheet
and fails on a disagreement, and the digest names failing tests in the log.
Reach for those before reaching for a guess — and never tell somebody they are
on an old build without checking which commit the build came from.
