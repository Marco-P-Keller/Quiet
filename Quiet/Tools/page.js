/**
 * A page that is not Instagram's, with trim.js running on it.
 *
 *     npm install jsdom
 *
 * Shared by every tool here that asks a question about the trim pass, because
 * the alternative is two copies of a fixture harness drifting apart — and the
 * whole reason these exist is that a question about a document should be
 * answered by a document rather than by building the app, waiting for
 * TestFlight and looking at a photograph.
 *
 * jsdom lays nothing out. Every measurement the script takes is answered from
 * an attribute on the fixture instead, which is enough: the only geometry
 * trim.js asks about is how big a thing is and whether it spans the glass.
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");

/**
 * jsdom's own complaints, minus the ones that are not about the script.
 *
 * A page that calls `location.replace` gets a "Not implemented" from jsdom,
 * because jsdom navigates nowhere — which is not a failure, it is the point.
 * Every other error it raises is a real one thrown by trim.js and has to be
 * seen, so only that one phrase is dropped.
 */
function speaker() {
  const relay = new VirtualConsole();
  // An empty list means "forward none of them", so the one below is the only
  // handler jsdom's errors reach.
  relay.forwardTo(console, { jsdomErrors: [] });
  relay.on("jsdomError", (error) => {
    if (/Not implemented/.test(error.message || "")) return;
    console.error(error.stack || error.message || error);
  });
  return relay;
}

const TRIM = fs.readFileSync(
  path.join(__dirname, "..", "Quiet", "Web", "trim.js"),
  "utf8"
);

/** Boxes come from the fixture, because jsdom has no layout to ask. */
function installBoxes(win) {
  win.Element.prototype.getBoundingClientRect = function () {
    const spec = this.getAttribute && this.getAttribute("data-box");
    if (!spec) return { left: 0, top: 0, width: 0, height: 0, right: 0, bottom: 0 };
    const [x, y, w, h] = spec.split(",").map(Number);
    return { left: x, top: y, width: w, height: h, right: x + w, bottom: y + h };
  };
}

async function page(html, url, head) {
  const dom = new JSDOM(
    `<!doctype html><html><head>${head || ""}</head><body>${html}</body></html>`,
    { runScripts: "outside-only", url, virtualConsole: speaker() }
  );
  if (dom.window.document.readyState === "loading") {
    await new Promise((go) => dom.window.addEventListener("load", go));
  }
  const win = dom.window;
  installBoxes(win);
  // A phone, not a desktop browser. jsdom's window is a thousand points wide,
  // and rules that ask whether something spans the glass answer no to every
  // fixture at that size.
  Object.defineProperty(win, "innerWidth", { value: 390, configurable: true });
  Object.defineProperty(win, "innerHeight", { value: 844, configurable: true });

  // The one question trim.js asks of the screen rather than of the markup.
  // jsdom paints nothing, so the fixture says what is under the point: any
  // element carrying data-at-top, outermost last, as the browser answers.
  // The script probes both ends of the glass — the header at the top, the
  // banner along the bottom — so the half of the screen the point falls in
  // decides which mark answers.
  win.document.elementsFromPoint = function (x, y) {
    const mark = y > (win.innerHeight || 844) / 2 ? "[data-at-bottom]" : "[data-at-top]";
    return Array.prototype.slice.call(win.document.querySelectorAll(mark));
  };
  // jsdom paints nothing here either. The fixture says what is drawn at a
  // point by carrying data-at-top; the topmost of them answers, which is what
  // a browser hands back for `elementFromPoint`.
  win.document.elementFromPoint = function () {
    return win.document.querySelector("[data-at-top]");
  };
  // jsdom scrolls nothing, so what the script asks the page to scroll by is
  // recorded instead. Taking a block out above the top of the glass has to be
  // paid for in the same frame, and this is where the payment shows up.
  win.scrolledBy = [];
  win.scrollBy = (x, y) => win.scrolledBy.push(y);
  // What the script sends up to the app, kept so a test can read it.
  win.sent = [];
  win.webkit = { messageHandlers: { quiet: { postMessage: (m) => win.sent.push(m) } } };
  // Every frame the script asks for, taken immediately, so a test can say
  // "and then the page rewrote itself" and see the result on the next line.
  const frames = [];
  win.requestAnimationFrame = (fn) => frames.push(fn);
  win.drain = () => { while (frames.length) frames.shift()(); };
  // The script asks Instagram who is signed in. There is nobody here to ask.
  win.fetch = () => new win.Promise(() => {});
  win.__quietTop = 59;
  // The two sentences the app hands the page, so the end of a feed can be said
  // in whichever language the phone is in. The catalogue owns the real ones.
  win.__quietEnd = "That's everyone you follow.";
  win.__quietEndNote = "Instagram would go on with people you don't. Pull down at the top for new posts.";
  win.eval(TRIM);
  win.drain();
  return win;
}

/**
 * Somewhere to keep score.
 *
 * Deliberately not a test framework. There is one dependency in this folder
 * and it is the thing that provides a DOM; adding a runner to get a red word
 * and a green word would be a second one, and neither of them would say
 * anything these four lines do not.
 */
function scoreboard(title) {
  let failures = 0;

  function check(name, got, expected) {
    const ok = JSON.stringify(got) === JSON.stringify(expected);
    if (!ok) failures += 1;
    console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
    if (!ok) {
      console.log(`        got      ${JSON.stringify(got)}`);
      console.log(`        expected ${JSON.stringify(expected)}`);
    }
  }

  function done() {
    console.log(
      failures
        ? `\n${title}: ${failures} failed`
        : `\n${title}: all good`
    );
    process.exit(failures ? 1 : 0);
  }

  return { check, done };
}

module.exports = { page, installBoxes, scoreboard, TRIM };
