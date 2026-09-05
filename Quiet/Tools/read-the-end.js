/**
 * When Quiet says a feed has ended, and whether it was right.
 *
 *     npm install jsdom && node Tools/read-the-end.js
 *
 * The end of the feed is the only thing in trim.js that puts a *sentence* on
 * the page, which makes it the only one that can be wrong out loud. Every other
 * mistake in this file is a strip that stays a tenth of a second too long. This
 * one tells somebody they have read everything their friends posted, and if it
 * says that while the rest of the feed is still on its way then the app has
 * lied about the one thing it exists to be right about.
 *
 * So the question is never "does it say the end" — it is *when*, and against a
 * feed that arrives the way Instagram's does: a few posts, a gap while the next
 * page is fetched, and only then either more posts or the treadmill.
 */

"use strict";

const { page, scoreboard } = require("./page");

const { check, done } = scoreboard("The end");

/**
 * Long enough for the pass the script holds back.
 *
 * `page`'s own `settle` waits `STILL` and no more, which is the right wait for
 * a page that has gone quiet. A page that is still *arriving* is held to a
 * ceiling instead — a second — and every question in this file is about that
 * page. Waiting less would be reading the document before the script has
 * finished with it and calling the result a finding.
 */
async function quiet(win) {
  for (let i = 0; i < 8; i++) {
    win.drain();
    await new Promise((go) => setTimeout(go, 200));
  }
  win.drain();
}

const FEED = "https://www.instagram.com/";

/** A post somebody you follow made: an article with a photograph in it. */
function post(name, height) {
  return `<article data-name="${name}" data-box="0,0,390,${height || 600}">
    <img data-box="0,0,390,390">
    <p data-box="0,0,390,20">a caption</p>
  </article>`;
}

/**
 * What Instagram puts under the last post while it fetches the next page:
 * boxes with height and nothing drawn in them.
 */
function placeholder(height) {
  return `<div class="placeholder" data-box="0,0,390,${height}"></div>`;
}

/** Instagram's own spinner. Something, and the proof a feed is still coming. */
function spinner() {
  return `<div data-box="0,0,390,60"><svg data-box="0,0,32,32"></svg></div>`;
}

/** A suggested post, written as an article like any other, with its heading. */
function suggestion(height) {
  return `<article data-box="0,0,390,${height || 600}">
    <div data-box="0,0,390,20"><span data-box="0,0,200,20">Suggested for you</span></div>
    <img data-box="0,0,390,390">
  </article>`;
}

function feed(inner) {
  return `<main data-box="0,0,390,4000"><div id="list" data-box="0,0,390,4000">${inner}</div></main>`;
}

/** Whether the sentence is on the page, and what is above it. */
function saidTheEnd(win) {
  return !!win.document.getElementById("quiet-end");
}

/** The name of the last post above the sentence, so a move can be seen. */
function endsAfter(win) {
  const mark = win.document.getElementById("quiet-end");
  if (!mark) return null;
  let node = mark.previousElementSibling;
  while (node && !node.getAttribute("data-name")) node = node.previousElementSibling;
  return node ? node.getAttribute("data-name") : null;
}

async function main() {
  /* ── While the next page is still being fetched ──────────────────────── */

  /* The case the whole tool exists for. One post has been drawn, Instagram has
   * laid out the boxes it will put the next ones in, and nothing has arrived
   * in them yet. There is half a screen of nothing under the last post and it
   * is not the end of anything — it is the middle of a load. */
  const arriving = await page(
    feed(post("first") + placeholder(500)),
    FEED
  );
  await quiet(arriving);
  check(
    "a gap while the next page is fetched is not the end",
    saidTheEnd(arriving),
    false
  );

  /* The same gap with Instagram's spinner in it, which is the version the
   * script's own comment says it relies on. */
  const withSpinner = await page(
    feed(post("first") + placeholder(500) + spinner()),
    FEED
  );
  await quiet(withSpinner);
  check(
    "a spinner under the gap is not the end either",
    saidTheEnd(withSpinner),
    false
  );

  /* The whole of why the gap matters: what the feed does next. Instagram
   * answers, the posts land in those boxes, and a sentence saying there are no
   * more of them is sitting three screens above the ones that arrived. That is
   * the app lying about the one thing it is here to be right about, and it is
   * the photograph somebody sends back. */
  const thenItArrived = await page(
    feed(post("first") + placeholder(500)),
    FEED
  );
  await quiet(thenItArrived);
  const arrived = thenItArrived.document.querySelector(".placeholder");
  arrived.insertAdjacentHTML(
    "beforebegin",
    post("second") + post("third") + post("fourth")
  );
  arrived.remove();
  await quiet(thenItArrived);
  check(
    "and no sentence is left stranded above the posts that arrive",
    endsAfter(thenItArrived),
    null
  );

  /* ── A feed that really has run out ──────────────────────────────────── */

  /* Three posts, then the treadmill: suggestions Quiet has taken out, and
   * nothing else. This is what the sentence is for. */
  const ended = await page(
    feed(post("first") + post("second") + post("last") + suggestion() + suggestion()),
    FEED
  );
  await quiet(ended);
  check("two suggestions in a row is the end", saidTheEnd(ended), true);
  check("and it is said under the last post there is", endsAfter(ended), "last");

  /* The shape a height rule was once needed for, and the reason counting has
   * to look inside. Instagram reserves the box and renders the suggested post
   * into it, so what Quiet takes out is a child rather than the sibling — and
   * the box stays, with its height, holding nothing. Counted from the outside
   * only, two of these read as nought and the treadmill goes on for ever. */
  const boxed = await page(
    feed(
      post("first") +
        `<div class="reserved" data-box="0,0,390,600">${suggestion()}</div>` +
        `<div class="reserved" data-box="0,0,390,600">${suggestion()}</div>`
    ),
    FEED
  );
  await quiet(boxed);
  check(
    "a suggestion inside the box Instagram reserved for it still counts",
    saidTheEnd(boxed),
    true
  );

  /* And the app's own furniture is not evidence. The navigation row is taken
   * out with the same attribute, and it is not a post the site served in
   * answer to a request for more feed. */
  const furniture = await page(
    feed(
      post("first") +
        `<div data-quiet-hidden="nav" data-box="0,0,390,50"></div>` +
        `<div data-quiet-hidden="wordmark" data-box="0,0,390,40"></div>`
    ),
    FEED
  );
  await quiet(furniture);
  check(
    "what Quiet took out of its own chrome is not evidence of an end",
    saidTheEnd(furniture),
    false
  );

  /* ── One suggestion is not the treadmill ─────────────────────────────── */

  /* Instagram puts a single suggested post between two real ones. Said there,
   * the sentence would have somebody's photograph under it. */
  const oneOfThem = await page(
    feed(post("first") + suggestion() + placeholder(120)),
    FEED
  );
  await quiet(oneOfThem);
  check("one suggestion on its own is not the end", saidTheEnd(oneOfThem), false);

  /* ── Having said it, a post arrives ──────────────────────────────────── */

  const thenMore = await page(
    feed(post("first") + suggestion() + suggestion()),
    FEED
  );
  await quiet(thenMore);
  check("the end, said", saidTheEnd(thenMore), true);

  const list = thenMore.document.getElementById("list");
  list.insertAdjacentHTML("beforeend", post("late"));
  await quiet(thenMore);
  check("and moved below a post that arrives after it", endsAfter(thenMore), "late");

  done();
}

main();
