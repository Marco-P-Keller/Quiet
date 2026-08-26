# Working on Quiet

## Where the app ships from

**TestFlight builds from the `quiet` repository, branch `dev`.** That is the
only branch a build has ever come from, and it is where every change belongs.

    git push origin HEAD:dev

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

They hold the same app. Keep them in step: make the change in one, copy the
touched files to the other, and push both — the monorepo to its working branch,
the standalone repository to `dev`.

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
