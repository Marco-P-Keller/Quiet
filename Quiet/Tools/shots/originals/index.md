# The originals

Untouched captures from a real phone, kept exactly as the phone wrote them.
Nothing here is uploaded anywhere; `../source` holds the prepared versions and
`../out` holds the finished slides. This folder exists so that the next person
to re-cut a slide has the frame to re-cut it *from*, and so that any retouching
can be checked against what was actually on the screen.

They were nearly lost twice over. `Quiet/.gitignore` carried an unanchored
`shots/`, meant for the directory CI writes into — and it also matched
`Tools/shots`, so the source photographs and the finished listing were never in
the repository at all. That is now `/shots/`. A file that was never added does
not show up as missing, which is why this went unnoticed.

| file | taken | what is on it | where it goes |
| --- | --- | --- | --- |
| `feed-reels-gap.png` | 19:00 | The home feed. Instagram's own header, one post, and the row along the bottom with the Reels slot standing empty. | `source/feed.png`, byte for byte → **slide 1** |
| `feed-post-open.png` | 18:59 | The same post, scrolled far enough that the like and comment counts, the caption and the date are on screen — and the empty slot still is. | retouched → `source/feed-open.png` → **slide 5** |
| `panel-spent-dark.png` | 22:57 | The panel with the day spent, and a raise already queued: **Daily limit 20 minutes** over **45 minutes from tomorrow**. | `source/en/panel-tomorrow.png` → **slide 3** |
| `feed-reels-gap-badged.png` | 18:59 | The same frame as `feed-reels-gap`, one minute earlier, with a follow-request badge over the header. | not used |
| `post-detail.png` | 18:58 | A single post's own page. | not used |
| `curtain-on-a-phone.png` | 22:56 | The end of the day, on a real phone. | not used |
| `opening-on-a-phone.png` | 14:52 | The opening screen, on a real phone, from TestFlight. | not used |

## Why three of them are not used

**`post-detail.png`** carries two typos in the caption — "onyl" for "only", and
"Safe you loved one" for "Save your loved one". A listing screenshot is read at
full size by somebody deciding whether the developer is careful, and that is a
poor place to publish a typo. Re-shoot it after the caption is fixed and it
becomes a usable slide.

**`curtain-on-a-phone.png`** and **`opening-on-a-phone.png`** show the same two
screens the simulator already gives us at `source/en/curtain.png` and
`source/en/opening.png` — at 1320 × 2868, which is the native size the slide is
built at. These are 1179 × 2556 and would be scaled. They are kept because a
photograph of the shipping build on real glass is worth having, not because
anything needs them.

**`feed-reels-gap-badged.png`** is the worse twin of `feed-reels-gap.png`. It is
kept because it is *why* the retouch below could be honest.

## The one retouch

`feed-post-open.png` carries a red follow-request badge, with a soft shadow,
sitting over the header — across the heart icon and across the post row's `…`
button. It had to go: a notification badge in an advertisement is somebody
else's account asking to be let in.

It was not painted out. `feed-reels-gap.png` is the same screen, one minute
apart, at the same scroll offset for the header and 365 px apart for the feed
beneath it — and the two agree **pixel for pixel** everywhere the badge is not.
So the badge was replaced with that capture's own pixels, in two bands split at
y = 355, which is plain white in both:

    header band   y < 355   ← feed-reels-gap.png, same coordinates
    the post row  y ≥ 355   ← feed-reels-gap.png, shifted up by 365

The patched rectangle is `(900, 170) – (1179, 480)`; the badge and its shadow
measure `(945, 206) – (1146, 430)`, so it is covered with room to spare. Both
numbers were measured, not guessed — the first attempt used a box that stopped
inside the shadow and left a faint rectangle where the shadow's outer half
survived, and a smaller box that erased the `…` button and did not put it back.
An over-retouched screenshot looks faked, which costs more than the artefact it
removes.

Afterwards the only red left above the fold is the heart's own notification dot,
which is genuine app state and is in the shipping slide 1 as well.

To redo it, or to check it:

    from PIL import Image
    b = Image.open("feed-post-open.png").convert("RGB")
    c = Image.open("feed-reels-gap.png").convert("RGB")
    donor = Image.new("RGB", b.size, (255, 255, 255))
    donor.paste(c.crop((0, 0, c.width, 355)), (0, 0))
    donor.paste(c.crop((0, 355 + 365, c.width, c.height)), (0, 355))
    b.paste(donor.crop((900, 170, 1179, 480)), (900, 170))

## The rule

The same one that is at the foot of `Tools/make-shots.py`, and it is the reason
this folder is worth keeping rather than the reason it is awkward to:

> If a person who is not you can be recognised in it, it does not go in the
> listing.

Every frame here is the developer's own account, the developer's own post, and
the developer's own phone. The three profile pictures in a "Liked by …" row are
the thing to watch for on the next re-shoot; none of these frames has one,
because the feed was scrolled past it before the shutter.
