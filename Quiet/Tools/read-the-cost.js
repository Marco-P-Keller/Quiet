/**
 * What the trim pass costs a page that is still arriving.
 *
 *     node Tools/read-the-cost.js
 *
 * The other two tools here ask whether the pass is *right*. This one asks what
 * it costs, because the answer was a surprise and a surprise that nothing was
 * watching comes back.
 *
 * The complaint it was written for: "the stories load straight away, only the
 * feed takes for ever." Both are drawn by the same client on the same thread,
 * so the difference is not the network — it is what else that thread was doing
 * by the time the feed's turn came.
 *
 * The pass had two speeds and they were about a thumb: while the page is under
 * one, only what must be immediate runs. A page that is *loading* is exactly as
 * busy and was running everything, on every frame Instagram's client mutated
 * the document — which during a mount is all of them.
 *
 * What is counted is the calls that make a browser lay the whole page out again
 * before it can answer: a box, a computed style, a hit test. jsdom answers all
 * three from an attribute in microseconds, so the number here is not a
 * millisecond count and does not pretend to be. It is how many times a frame
 * the pass says "stop what you are doing and tell me where this is", which is
 * the thing that was starving the render.
 *
 * Measured before the ration and after:
 *
 *     a page arriving, before   68.0 a frame
 *     a page arriving, after     2.3 a frame
 *     under a thumb              0.6 a frame
 *
 * The check below is a ceiling rather than an equality. The exact number moves
 * whenever a fixture does; a return to sixty is the regression.
 */

"use strict";

const { page, subframe, scoreboard } = require("./page.js");

const { check, done } = scoreboard("The cost");

const FEED = "https://www.instagram.com/";

/** A frame's worth of Instagram's client mounting a feed. */
const FRAMES = 60;

/** What a phone gives a frame. */
const BUDGET = 16;

function fixture() {
  const posts = [];
  for (let i = 0; i < 8; i++) {
    posts.push(`
      <article data-box="0,${i * 600},390,560">
        <a href="/someone${i}/"><img></a>
        <div>a caption</div>
      </article>`);
  }
  return `
    <main>${posts.join("")}</main>
    <nav data-at-bottom data-box="0,760,390,60">
      <a href="/"></a><a href="/explore/"></a><a href="/direct/inbox/"></a>
    </nav>`;
}

/** Count every call that forces a browser to lay the page out again. */
function watch(win) {
  const seen = { boxes: 0, styles: 0, points: 0 };
  const box = win.Element.prototype.getBoundingClientRect;
  win.Element.prototype.getBoundingClientRect = function () {
    seen.boxes += 1;
    return box.call(this);
  };
  const style = win.getComputedStyle.bind(win);
  win.getComputedStyle = function (node) {
    seen.styles += 1;
    return style(node);
  };
  const many = win.document.elementsFromPoint;
  win.document.elementsFromPoint = function (x, y) {
    seen.points += 1;
    return many.call(this, x, y);
  };
  const one = win.document.elementFromPoint;
  win.document.elementFromPoint = function () {
    seen.points += 1;
    return one.call(this);
  };
  seen.total = () => seen.boxes + seen.styles + seen.points;
  return seen;
}

const rest = (ms) => new Promise((go) => setTimeout(go, ms));

/**
 * A second of a page arriving, at a phone's frame rate.
 *
 * The frame rate is the whole point: the ration is in milliseconds, so a loop
 * that runs sixty frames as fast as it can is measuring a sixteenth of a second
 * and reporting it as one.
 */
async function loading(scrolling) {
  const win = await page(fixture(), FEED);
  const seen = watch(win);
  const feed = win.document.querySelector("main");

  for (let i = 0; i < FRAMES; i++) {
    const post = win.document.createElement("article");
    post.setAttribute("data-box", `0,${5000 + i * 600},390,560`);
    post.innerHTML = "<a href='/x/'><img></a>";
    feed.appendChild(post);
    if (scrolling) win.dispatchEvent(new win.Event("scroll"));
    await rest(BUDGET);
    win.drain();
  }
  return seen.total() / FRAMES;
}

/**
 * The same pass, in an advertisement's frame.
 *
 * trim.js is injected into every frame on purpose, so that an embedded player
 * never gets to appear first. Everything below the immediate half, though, is a
 * question about the app's own chrome — the header, the row, the colour behind
 * the clock, the end of the feed, who is signed in — and `receive` in
 * InstagramWebView.swift drops every answer to those that arrives from a
 * subframe. An advertisement in a feed is a subframe, and it was being asked
 * all of it, on every frame, so that the app could throw the answers away.
 */
async function inAFrame() {
  const win = await subframe(fixture(), FEED);
  // From the install onwards rather than from here. Most of what the full pass
  // says, it says once and then only when the answer changes — so clearing the
  // list first and mutating the page would be measuring that, and would pass
  // with the guard taken out.
  await win.settle();
  return win.sent.map((m) => m.kind);
}

(async () => {
  const arriving = await loading(false);
  const underAThumb = await loading(true);
  const fromAFrame = await inAFrame();

  console.log(`  a page arriving   ${arriving.toFixed(1)} a frame`);
  console.log(`  under a thumb     ${underAThumb.toFixed(1)} a frame`);
  console.log("");

  /* Sixty a frame is what it was. Ten is far above where the ration puts it and
   * far below any way back to running the whole pass on every mutation. */
  check("a loading page is not swept on every frame", arriving < 10, true);
  check("and a page under a thumb still is not", underAThumb < 10, true);

  /* Only the two the immediate half can say. Nothing about the app's chrome —
   * no colour, no tally, no sheet, no bare page — because nobody would listen
   * to any of it. */
  check(
    "a subframe says only what the immediate half says",
    fromAFrame.filter((kind) => kind !== "where" && kind !== "refused"),
    []
  );

  done();
})();
