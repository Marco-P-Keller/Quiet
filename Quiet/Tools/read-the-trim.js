/**
 * The part of trim.js the app's promise actually rests on.
 *
 *     npm install jsdom && node Tools/read-the-trim.js
 *
 * The header had a tool of its own because the header had cost the most
 * commits. These are the checks nobody wrote, and they cover the things that
 * fail *silently* — which is worse than failing loudly, because an entrance
 * that quietly reappears looks exactly like an app that is working.
 *
 * Four questions:
 *
 *   1. Does a tap that would open Reels or Explore get refused, and does a
 *      profile whose name merely starts with those letters get left alone?
 *   2. Does a block Instagram inserted get hidden — and, far more important,
 *      does an ordinary post survive? A reel that gets through is a bug. A gap
 *      where a friend's photograph used to be is a betrayal.
 *   3. Does every phrase in the list actually match something? The list is
 *      twenty-odd hand-written strings in a dozen languages and a typo in any
 *      one of them is invisible from Swift, from CI and from the phone.
 *   4. Does the script notice when Instagram's own client changes the page
 *      without loading anything?
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { page, scoreboard, TRIM } = require("./page");

const { check, done } = scoreboard("The trim");

/* ── The stylesheet stops at the edge of a post ─────────────────────────── */

/* The feed jumped up and down where there were advertisements, and none of the
 * work in the script could have stopped it: it was the stylesheet.
 *
 * An advertisement is the one post that carries these addresses inside it —
 * its media is a reel, its button goes to the App Store. Hiding a link inside a
 * post does not remove an entrance, it removes a piece of the post; the height
 * goes with it and the page below slides up. A stylesheet cannot wait for the
 * hand to come off the glass and cannot pay a scroll back, so it must not
 * change a layout somebody is looking at at all.
 *
 * Read as text rather than through a DOM on purpose. jsdom's support for
 * Level 4 selectors is not the question — what the file says is. */
const CSS = fs
  .readFileSync(path.join(__dirname, "..", "Quiet", "Web", "trim.css"), "utf8")
  .replace(/\/\*[\s\S]*?\*\//g, "");

/* Only the ones that match by address. The two that do not are deliberate and
 * neither can move a page: `[data-quiet-hidden]` is set by the script, which
 * decides for itself when a thing may go and pays the scroll back when it
 * does, and a scrollbar is not a box in the flow. */
const byAddress = CSS
  .split("}")
  .filter((block) => /display:\s*none/.test(block))
  .flatMap((block) => block.split("{")[0].split(","))
  .map((one) => one.trim())
  .filter((one) => one.includes("[href") || one.includes(":has("));

check(
  "every rule that hides part of a page by its address stops at a post",
  byAddress.filter((one) => !/:not\(article /.test(one)),
  []
);

/* And there is more than a handful of them, or the check above passes on an
 * empty list and says nothing at all. */
check("and there are rules to say it about", byAddress.length > 10, true);

const FEED = "https://www.instagram.com/";

/**
 * The phrase list, read out of trim.js itself.
 *
 * Read rather than repeated, so that a phrase added tomorrow is covered
 * tomorrow. A copy here would be a list that agrees with the script on the day
 * it is written and never again.
 */
function labels() {
  const block = /var SUGGESTION_LABELS = \[([\s\S]*?)\];/.exec(TRIM);
  if (!block) throw new Error("SUGGESTION_LABELS is not where this expects it");
  return block[1]
    .split("\n")
    .map((line) => /"([^"]*)"/.exec(line))
    .filter(Boolean)
    .map((found) => found[1]);
}

/**
 * Let the page's own machinery run.
 *
 * A mutation reaches the observer on a microtask, and the observer is what
 * asks for the frame the trim pass runs in. Draining frames straight after an
 * edit drains an empty queue — which is not the script failing, it is the test
 * arriving before it.
 */
async function settle(win) {
  await new Promise((go) => setTimeout(go, 0));
  await win.settle();
}

/** Tap a link the way a thumb does, and say what the page made of it. */
function tap(win, selector) {
  const anchor = win.document.querySelector(selector);
  const event = new win.MouseEvent("click", { bubbles: true, cancelable: true });
  anchor.dispatchEvent(event);
  return {
    refused: event.defaultPrevented,
    said: win.sent.filter((m) => m.kind === "refused").map((m) => m.surface),
  };
}

(async () => {
  /* ── 1. Taps ─────────────────────────────────────────────────────────── */

  const doors = {
    "/reels/": "reels",
    "/reel/CxYz123/": "reels",
    "/explore/": "explore",
    "/explore/tags/sunset/": "explore",
    "/directory/profiles/": "explore",
    "/accounts/suggested/": "explore",
    "/someone/reels/": "reels",
    /* IGTV's old address, which Instagram kept alive as a redirect into the
     * same player. The script used to answer "explore" for this, because it
     * worked the surface out from whether the root began with "reel". */
    "/tv/CxYz123/": "reels",
  };

  for (const [href, surface] of Object.entries(doors)) {
    const win = await page(`<main><a href="${href}">go</a></main>`, FEED);
    check(`a tap on ${href} is refused as ${surface}`, tap(win, "a"), {
      refused: true,
      said: [surface],
    });
  }

  /* The bug on the other side, and the one that would be reported as "the app
   * cannot open my friend". Whole path components, never a prefix. */
  const spared = [
    "/reelstuff/",
    "/explorers/",
    "/tvtotal/",
    "/directorycorp/",
    "/someone/",
    "/someone/tagged/",
    "/p/CxYz123/",
    "/direct/inbox/",
  ];
  for (const href of spared) {
    const win = await page(`<main><a href="${href}">go</a></main>`, FEED);
    check(`a tap on ${href} is left alone`, tap(win, "a"), {
      refused: false,
      said: [],
    });
  }

  /* Somebody else's site, linked from a comment. Not this script's business:
   * the app decides that, by URL, in Swift. */
  const outside = await page(
    `<main><a href="https://example.com/reels/">go</a></main>`,
    FEED
  );
  check("a link to somebody else's site is not this script's business",
    tap(outside, "a"), { refused: false, said: [] });

  /* ── 2. Suggestion blocks ────────────────────────────────────────────── */

  const hidden = (win) =>
    [...win.document.querySelectorAll("[data-quiet-hidden]")]
      .map((e) => e.getAttribute("data-name"))
      .sort();

  const MIXED = `
    <main>
      <article data-name="friend">
        <a href="/someone/"><span>someone</span></a>
        <span>a photograph of a dog</span>
      </article>
      <article data-name="inserted">
        <span>Suggested for you</span>
        <a href="/stranger/"><span>stranger</span></a>
      </article>
      <article data-name="another-friend">
        <a href="/else/"><span>else</span></a>
        <span>a photograph of a lake</span>
      </article>
    </main>`;

  const mixed = await page(MIXED, FEED);
  check("the block Instagram inserted is hidden", hidden(mixed), ["inserted"]);
  check(
    "and both of the posts either side of it are untouched",
    [...mixed.document.querySelectorAll("article")]
      .filter((a) => !a.hasAttribute("data-quiet-hidden"))
      .map((a) => a.getAttribute("data-name")),
    ["friend", "another-friend"]
  );

  /* A caption that happens to say the words. The rule that separates the two
   * is that a heading of Instagram's is not inside a link and a caption is. */
  const caption = await page(
    `<main>
       <article data-name="post">
         <a href="/someone/"><span>Suggested for you</span></a>
       </article>
     </main>`,
    FEED
  );
  check("a caption that merely says the words survives", hidden(caption), []);

  /* Longer than a heading ever is. Without the length rule, a comment quoting
   * the phrase would take the post it is under with it. */
  const essay = await page(
    `<main>
       <article data-name="post">
         <span>suggested for you is a phrase i have grown to dislike, actually</span>
       </article>
     </main>`,
    FEED
  );
  check("a sentence that contains the phrase is not a heading", hidden(essay), []);

  /* Instagram's client recycles DOM nodes: an element inspected while it held
   * a caption can later hold a heading. A set of seen nodes would never look
   * at it twice, which is the bug the WeakMap of last-seen *text* fixes. */
  const recycled = await page(
    `<main><article data-name="post"><span>a photograph of a dog</span></article></main>`,
    FEED
  );
  check("nothing is hidden yet", hidden(recycled), []);
  recycled.document.querySelector("span").textContent = "Suggested for you";
  await settle(recycled);
  check(
    "a node that has been recycled into a heading is caught",
    hidden(recycled),
    ["post"]
  );

  /* ── 3. Every phrase in the list ─────────────────────────────────────── */

  const list = labels();
  check("the phrase list was found and is not empty", list.length > 0, true);

  const missed = [];
  for (const label of list) {
    const win = await page(
      `<main><article data-name="block"><span>${label}</span></article></main>`,
      FEED
    );
    if (hidden(win).length !== 1) missed.push(label);
  }
  check(`all ${list.length} phrases match something`, missed, []);

  /* And the same phrases as a person would type them, since the match is made
   * after lower-casing and trimming and both are easy to lose. */
  const shouted = [];
  for (const label of list) {
    const win = await page(
      `<main><article data-name="block"><span>  ${label.toUpperCase()}  </span></article></main>`,
      FEED
    );
    if (hidden(win).length !== 1) shouted.push(label);
  }
  check("case and stray spaces do not matter", shouted, []);

  /* The three ways a heading arrives written differently from the way it is
   * written in the list. Every one of these was a phrase that got through. */

  const spellings = {
    "a Turkish capital dotted I": [
      "Senin \u0130\u00e7in \u00d6nerilenler", true,
    ],
    "a non-breaking space between the words": [
      "Suggested\u00a0for\u00a0you", true,
    ],
    "an accent written as two code points": [
      "Vorschla\u0308ge fu\u0308r dich", true,
    ],
    "a line break inside the heading": [
      "Suggested\nfor you", true,
    ],
    /* And the other side of the same rule: a wider net that still catches
     * nothing it should not. */
    "an ordinary caption": ["a photograph of a dog", false],
  };

  for (const [name, [text, expected]] of Object.entries(spellings)) {
    const win = await page(
      `<main><article data-name="block"><span>${text}</span></article></main>`,
      FEED
    );
    check(`${name} is read as the phrase it is`, hidden(win).length === 1, expected);
  }

  /* ── 4. A page that changes without loading ──────────────────────────── */

  /* Instagram's client replaces the feed with a profile without a navigation
   * of any kind, and the app's row along the bottom learns where it is from
   * this message and nothing else. */
  const moving = await page(`<main></main>`, FEED);
  const where = () =>
    moving.sent.filter((m) => m.kind === "where").map((m) => m.path);

  check("the first page says where it is", where(), ["/"]);

  moving.history.pushState({}, "", "/someone/");
  moving.drain();
  check("and so does the next one", where(), ["/", "/someone/"]);

  /* The same address twice is not news. */
  moving.history.replaceState({}, "", "/someone/");
  moving.drain();
  check("the same address is not said twice", where(), ["/", "/someone/"]);

  /* Landing on a blocked path without a page load at all — the backstop for
   * the case where Instagram's own router gets there first. */
  const landed = await page(`<main></main>`, "https://www.instagram.com/explore/");
  check(
    "arriving on a blocked path is refused even with no tap to refuse",
    landed.sent.filter((m) => m.kind === "refused").map((m) => m.surface),
    ["explore"]
  );

  /* ── 5. Whether the script can tell that it has stopped working ──────── */

  /* The one hole this whole approach has: everything except the address rules
   * recognises Instagram by its shape, and the day the shape changes the
   * recognising stops finding anything — silently, with the app still looking
   * perfectly healthy. The tally is what turns that into a sentence. */

  const health = (win) => {
    const said = win.sent.filter((m) => m.kind === "health");
    return said.length ? said[said.length - 1] : null;
  };

  const A_ROW = `
    <nav data-name="row" data-box="0,800,390,44">
      <a href="/" data-name="home"></a>
      <a href="/direct/inbox/" data-name="messages"></a>
      <a href="/someone/" data-name="me"></a>
    </nav>
    <main></main>`;

  const withRow = await page(A_ROW, FEED);
  check(
    "a page where Instagram's row was found says so",
    (({ pages, nav }) => ({ pages, nav }))(health(withRow)),
    { pages: 1, nav: 1 }
  );

  const withoutRow = await page(`<main></main>`, FEED);
  check(
    "and a page where it was not found says that instead",
    (({ pages, nav }) => ({ pages, nav }))(health(withoutRow)),
    { pages: 1, nav: 0 }
  );

  /* What was hidden is counted once, not once per frame. The trim pass runs on
   * every mutation Instagram's client makes, and a tally that climbed with it
   * would say a great deal about how busy the client is and nothing at all
   * about whether anything was found. */
  const counted = await page(MIXED, FEED);
  check("a hidden block is counted", health(counted).hidden, 1);

  counted.document.querySelector("main").appendChild(
    counted.document.createElement("div")
  );
  await settle(counted);
  check(
    "and it is not counted again on the next pass",
    health(counted).hidden,
    1
  );

  /* Walking to another page starts the page's own answer over, so a row found
   * on the feed cannot vouch for a row on a profile. */
  const walked = await page(A_ROW, FEED);
  walked.history.pushState({}, "", "/someone/");
  await settle(walked);
  check(
    "each page is asked separately",
    (({ pages, nav }) => ({ pages, nav }))(health(walked)),
    { pages: 2, nav: 2 }
  );

  /* ── The suggestions, and whose choice they are ───────────────────────── */

  /* Instagram's suggested posts are *shown*. That is the app's default and it
   * was asked for in those words: all of them, with a switch in the panel for
   * anybody who would rather not have them.
   *
   * Which makes this the one rule in the file that runs both ways, and both
   * ways have to be checked. A setting that only ever tightens is a setting
   * nobody can undo, and the memo below is exactly the thing that would have
   * made undoing it impossible.
   *
   * The fixtures elsewhere in these tools leave the flag alone and are trimmed,
   * because what they are asking about is the trimming. Here it is set the way
   * the app sets it. See `dress` in page.js. */
  const BOTH = `
    <main data-box="0,0,390,3000"><div id="list" data-box="0,0,390,3000">
      <article data-name="mine" data-box="0,0,390,600"><img data-box="0,0,390,390"></article>
      <article data-name="theirs" data-box="0,0,390,600">
        <div data-box="0,0,390,20"><span data-box="0,0,200,20">Suggested for you</span></div>
        <img data-box="0,0,390,390">
      </article>
      <article data-name="alsoTheirs" data-box="0,0,390,600">
        <div data-box="0,0,390,20"><span data-box="0,0,200,20">Suggested posts</span></div>
        <img data-box="0,0,390,390">
      </article>
      <div data-name="reels" data-box="0,0,390,300"><h2>Reels</h2></div>
    </div></main>`;

  const why = (win, name) =>
    win.document
      .querySelector(`[data-name="${name}"]`)
      ?.getAttribute("data-quiet-hidden") ?? null;

  const shown = await page(BOTH, FEED, null, { __quietShowsSuggestions: true });
  await settle(shown);
  check("shown, a suggestion is left where it is", why(shown, "theirs"), null);
  check("and so is the next one", why(shown, "alsoTheirs"), null);

  /* Reels are not a suggestion, whatever the heading over them says. They are
   * refused by address in three other places in this app, and a carousel of
   * them arriving back in the feed under a switch about *suggestions* would be
   * one promise undone by a setting about another. */
  check("but a block of Reels still goes", why(shown, "reels"), "reels");

  /* And with them on the page the feed does not end, so nothing says it does.
   * The sentence is a claim that there is nothing below but people you did not
   * choose; below this there are exactly those people, visible. */
  check(
    "and nothing is said about the feed ending",
    !!shown.document.getElementById("quiet-end"),
    false
  );

  /* Asked for, they go — which is the behaviour every other fixture here gets. */
  const asked = await page(BOTH, FEED);
  await settle(asked);
  check("asked for, a suggestion goes", why(asked, "theirs"), "suggestion");
  check("and the end of the feed is said again", 
        !!asked.document.getElementById("quiet-end"), true);

  /* ── The switch, flicked while the page is open ───────────────────────── */

  /* Three pages are open at once and only one of them is on the glass, so the
   * flag arriving at document start covers none of the three. This is the
   * other half, and it has to work in both directions. */
  asked.__quietSuggestionsChanged(true);
  await settle(asked);
  check("flicked, they come back on the page already open", why(asked, "theirs"), null);
  check("and the sentence about the end goes with them",
        !!asked.document.getElementById("quiet-end"), false);

  /* Back the other way, which is the direction that was nearly impossible.
   * `lastSeenText` is what stops a heading being read on every frame, and a
   * heading remembered as read while they were shown would never be looked at
   * again once they were not. */
  asked.__quietSuggestionsChanged(false);
  await settle(asked);
  check("and off again, they go a second time", why(asked, "theirs"), "suggestion");
  check("with the post either side untouched throughout", why(asked, "mine"), null);

  done();
})();
