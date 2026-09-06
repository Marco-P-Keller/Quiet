# Photographs a runner cannot take

Everything the `Screenshots` workflow puts on the App Store comes off a running
build: it launches the app on a Pro Max, photographs each screen at 1320 × 2868,
and `make-the-store-shots.py` puts a caption over it. That covers every screen
Quiet draws itself, which is the whole set.

It cannot cover one thing. A signed-in Instagram feed needs an Instagram
account, and no runner has one — a runner photographing `browsing` gets a login
page. So if a frame of the real feed is ever wanted in the listing, it has to
come off a real phone, and this is where it goes:

    Tools/store-shots/en/feed.png
    Tools/store-shots/de/feed.png

1320 × 2868, straight out of an iPhone Pro Max, dark appearance, no editing —
the status bar is cropped off by the composer, so leave it alone. Drop the file
in, push, and it becomes the first frame of the set with everything else moving
down one. Leave it out and the set is the five screens the app owns.

**It is deliberately left out.** The reasoning is in
[`docs/store-listing.md`](../../../docs/store-listing.md): what this app sells
is the limiter, and a listing made mostly of somebody else's product invites
guideline 5.2.1 before a reviewer has read a word. The absence of Reels is a
sentence, and it works as one.

Anything else dropped in here is picked up the same way — the composer looks in
`shots/store/` first and then here, so a photograph kept in the repository wins
nothing and loses nothing except when CI could not take it.
