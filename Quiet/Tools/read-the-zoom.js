/**
 * What two fingers on a photograph do.
 *
 *     node Tools/read-the-zoom.js
 *
 * The gesture Instagram's own app has and its website does not: pinch a
 * picture in a post and it lifts off the feed, follows your fingers, and
 * springs back when you let go.
 *
 * It is asked of a document rather than of a phone because the part that can
 * be wrong here is not the arithmetic — it is *what it decides to lift*. A
 * gesture that lifts the face beside somebody's name, or a picture in a
 * suggestion Quiet has already taken out, or the whole post instead of the
 * photograph in it, is a gesture that has to be found on a phone by somebody
 * pinching the wrong thing. Every one of those is a fixture below.
 *
 * jsdom lays nothing out, so the boxes come from `data-box` and the answer to
 * "what is under this point" comes from `data-at-top`, exactly as they do for
 * the other tools here. See `Tools/page.js`.
 */

"use strict";

const { page, scoreboard } = require("./page.js");

const { check, done } = scoreboard("The zoom");

const FEED = "https://www.instagram.com/";

/** A picture, at a place, in a post. */
const post = (inside) => `<main><article data-box="0,100,390,500">${inside}</article></main>`;

/** The one the point is standing on. */
const PHOTO =
  '<img data-at-top data-name="photo" src="p.jpg" data-box="0,160,390,390">';

/** Two fingers, said the way a browser says them. */
function fingers(win, ...points) {
  return points.map(([x, y]) => ({ clientX: x, clientY: y }));
}

function touch(win, kind, touches) {
  const event = new win.Event(kind, { bubbles: true, cancelable: true });
  Object.defineProperty(event, "touches", { value: touches });
  win.document.dispatchEvent(event);
  win.drain();
  return event;
}

const copyOf = (win) => win.document.getElementById("quiet-zoom-photo");
const shadeOf = (win) => win.document.getElementById("quiet-zoom");
const liftedIn = (win) =>
  Array.from(win.document.querySelectorAll("[data-quiet-lifted]")).map((n) =>
    n.getAttribute("data-name")
  );

/** A pinch, from its two fingers landing to whatever they do next. */
function pinch(win, from, to) {
  touch(win, "touchstart", fingers(win, ...from));
  if (to) touch(win, "touchmove", fingers(win, ...to));
}

(async () => {
  /* ── What it lifts ──────────────────────────────────────────────────────── */

  const feed = await page(post(PHOTO), FEED);
  pinch(feed, [[180, 330], [220, 370]]);
  check("two fingers on a photograph lift a copy of it", !!copyOf(feed), true);
  check("the original stands aside while the copy is up", liftedIn(feed), ["photo"]);
  check("and the page behind it is shaded", !!shadeOf(feed), true);

  /* The copy starts exactly where the photograph is, or the lift is a jump. */
  check("the copy starts where the photograph is", {
    left: copyOf(feed).style.left,
    top: copyOf(feed).style.top,
    width: copyOf(feed).style.width,
    height: copyOf(feed).style.height,
  }, { left: "0px", top: "160px", width: "390px", height: "390px" });

  /* It is a copy of what the page already had, so it arrives in the frame it
   * is asked for rather than over the air. */
  /* The same picture, at the address the page resolved it to — which is the
   * one already fetched and decoded, so the copy costs no network at all. */
  check("and it is the picture the page already fetched",
    /\/p\.jpg$/.test(copyOf(feed).src), true);

  /* ── What it leaves alone ───────────────────────────────────────────────── */

  /* The face beside the name is an `img` in a post too. */
  const faces = await page(
    post('<img data-at-top data-name="face" src="f.jpg" data-box="8,108,32,32">'),
    FEED
  );
  pinch(faces, [[16, 116], [32, 132]]);
  check("a face beside a name is not a photograph", !!copyOf(faces), false);

  /* And nothing outside a post is one either — the wordmark, an icon in the
   * header, a picture in something Quiet has already taken out. */
  const loose = await page(
    '<img data-at-top data-name="banner" src="b.jpg" data-box="0,0,390,390">',
    FEED
  );
  pinch(loose, [[180, 180], [220, 220]]);
  check("a picture outside a post is left alone", !!copyOf(loose), false);

  /* One finger is a scroll, a tap, or a double tap that likes something. It is
   * never this. */
  const oneFinger = await page(post(PHOTO), FEED);
  touch(oneFinger, "touchstart", fingers(oneFinger, [180, 330]));
  check("one finger is not a pinch", !!copyOf(oneFinger), false);
  check("and nothing of the page's has been touched", liftedIn(oneFinger), []);

  /* ── What it does while you hold it ─────────────────────────────────────── */

  const held = await page(post(PHOTO), FEED);
  /* Fingers 40 apart, then 80: twice the size. */
  pinch(held, [[180, 330], [220, 330]], [[160, 330], [240, 330]]);
  check("fingers twice as far apart make it twice the size",
    /scale\(2\)/.test(copyOf(held).style.transform), true);

  /* And it goes where the hand goes. */
  touch(held, "touchmove", fingers(held, [190, 360], [270, 360]));
  check("and it follows the middle of them",
    /translate\(30px, 30px\)/.test(copyOf(held).style.transform), true);

  /* Far enough is far enough. A feed photograph past about four times the size
   * is not a photograph any more, it is its own pixels. */
  touch(held, "touchmove", fingers(held, [0, 330], [390, 330]));
  check("it stops somewhere sensible",
    /scale\(4\)/.test(copyOf(held).style.transform), true);

  /* Pushed together rather than apart, it does not shrink into the page. */
  touch(held, "touchmove", fingers(held, [195, 330], [205, 330]));
  check("and never smaller than it was",
    /scale\(1\)/.test(copyOf(held).style.transform), true);

  /* ── What it does when you let go ───────────────────────────────────────── */

  const released = await page(post(PHOTO), FEED);
  pinch(released, [[180, 330], [220, 330]], [[140, 330], [260, 330]]);
  touch(released, "touchend", []);
  released.drain();

  check("letting go starts it home", copyOf(released).style.transform, "");
  check("and it is told to animate on the way",
    copyOf(released).hasAttribute("data-quiet-falling"), true);
  check("the shade starts fading with it", shadeOf(released).hasAttribute("data-on"), false);

  await new Promise((go) => setTimeout(go, 400));
  check("and then both of them are gone", [!!copyOf(released), !!shadeOf(released)], [false, false]);
  check("and the photograph has itself back", liftedIn(released), []);

  /* The way home is read when you let go, not remembered from when you
   * started. A feed that scrolled under the gesture would otherwise put the
   * photograph back where it used to be, which is somewhere it is not. */
  const moved = await page(post(PHOTO), FEED);
  pinch(moved, [[180, 330], [220, 330]], [[140, 330], [260, 330]]);
  moved.document
    .querySelector('[data-name="photo"]')
    .setAttribute("data-box", "0,20,390,390");
  touch(moved, "touchend", []);
  moved.drain();
  check("a page that moved underneath is answered by where it moved to",
    copyOf(moved).style.top, "20px");

  /* A third finger lifting is not the end of a pinch. */
  const third = await page(post(PHOTO), FEED);
  pinch(third, [[180, 330], [220, 330]]);
  touch(third, "touchend", fingers(third, [180, 330], [220, 330]));
  check("a third finger lifting does not end it", !!copyOf(third), true);

  /* ── What it must never do ──────────────────────────────────────────────── */

  /* A photograph that left the page mid-gesture — a feed rebuilt under a
   * thumb, which this one does — must not leave a copy standing over the page
   * for ever, and must not throw on the way out. */
  const vanished = await page(post(PHOTO), FEED);
  pinch(vanished, [[180, 330], [220, 330]]);
  const picture = vanished.document.querySelector('[data-name="photo"]');
  picture.parentNode.removeChild(picture);
  touch(vanished, "touchend", []);
  vanished.drain();
  await new Promise((go) => setTimeout(go, 400));
  check("a photograph taken off the page still puts the copy away",
    [!!copyOf(vanished), !!shadeOf(vanished)], [false, false]);

  done();
})();
