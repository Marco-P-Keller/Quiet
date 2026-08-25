/**
 * What trim.js makes of Instagram's header, checked against a page that is not
 * Instagram's.
 *
 *     npm install jsdom && node Tools/read-the-header.js
 *
 * The header has cost this project more commits than everything else in it put
 * together, and every one of them was settled by building the app, waiting for
 * TestFlight and looking at a photograph. That is a long way to go to find out
 * that a selector matched nothing.
 *
 * So the finding is separated from the arranging. Which three controls trim.js
 * picks out of a bar is a question about a document, and a document can be
 * written here — the arrangement itself is four rules of CSS and belongs to the
 * browser. What these check is the part that has actually gone wrong: an
 * element found, or not found, or found twice.
 *
 * jsdom lays nothing out, so `getBoundingClientRect` is answered from a
 * `data-box` attribute on the fixture. That is enough: the only geometry the
 * script asks about is how big a control is.
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { JSDOM } = require("jsdom");

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

/**
 * @param row how much of the bottom of the glass the app's row stands on, which
 *   is what a sheet is given room to stand clear of. Eighty-nine points is the
 *   flush bar on a phone with a home indicator: forty-nine and thirty-four,
 *   rounded. Zero is a story or a conversation, where there is no row.
 * @param lift how much of the bottom of the glass the app has already taken
 *   away for a sheet. Zero everywhere except under one, and the number that
 *   lets the script tell "the room has not been made yet" from "the room has
 *   been made and the row is standing on the app's own paint".
 */
async function page(html, url, head, row, lift) {
  const dom = new JSDOM(
    `<!doctype html><html><head>${head || ""}</head><body>${html}</body></html>`,
    { runScripts: "outside-only", url }
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
  win.__quietRow = row === undefined ? 89 : row;
  win.__quietLift = lift === undefined ? 0 : lift;
  win.eval(TRIM);
  win.drain();
  return win;
}

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

/** Which fixture element ended up in which of the three places. */
function slots(win) {
  const doc = win.document;
  const named = (selector) => {
    const element = doc.querySelector(selector);
    return element ? element.getAttribute("data-name") : null;
  };
  return {
    create: named('[data-quiet-slot="create"]'),
    title: named('[data-quiet-slot="title"]'),
    activity: named('[data-quiet-slot="activity"]'),
    bar: named("[data-quiet-header]"),
    flattened: [...doc.querySelectorAll("[data-quiet-flatten]")]
      .map((e) => e.getAttribute("data-name"))
      .sort(),
  };
}

const FEED = "https://www.instagram.com/";

/* The shape the page has today: the wordmark and its chevron at one end, the
 * plus and the heart sharing a group at the other. */
const GROUPED = `
  <div data-name="bar">
    <div data-name="titlegroup">
      <a href="/" data-name="wordmark" data-box="8,10,100,24">Instagram</a>
      <button data-name="chevron" data-box="112,10,20,24">v</button>
    </div>
    <div data-name="icongroup">
      <button data-name="plus" data-box="300,10,24,24">+</button>
      <a href="/accounts/activity/" data-name="heart" data-box="340,10,24,24">h</a>
    </div>
  </div>
  <main></main>`;

(async () => {
  check(
    "the plus comes out of the group it shares with the heart",
    slots(await page(GROUPED, FEED)),
    {
      create: "plus",
      title: "titlegroup",
      activity: "heart",
      bar: "bar",
      flattened: ["icongroup"],
    }
  );

  check(
    "four controls written flat need nothing flattened",
    slots(
      await page(
        `<div data-name="bar">
           <a href="/" data-name="wordmark" data-box="8,10,100,24">Instagram</a>
           <button data-name="chevron" data-box="112,10,20,24">v</button>
           <button data-name="plus" data-box="300,10,24,24">+</button>
           <a href="/accounts/activity/" data-name="heart" data-box="340,10,24,24">h</a>
         </div><main></main>`,
        FEED
      )
    ),
    {
      create: "plus",
      title: "wordmark",
      activity: "heart",
      bar: "bar",
      flattened: [],
    }
  );

  // The whole safety property, in one case: unsure means untouched. A header
  // nobody rearranged is a great deal better than one rearranged on a guess.
  check(
    "a bar with no plus in it is left exactly as Instagram drew it",
    slots(
      await page(
        `<div data-name="bar">
           <a href="/" data-name="wordmark" data-box="8,10,100,24">Instagram</a>
           <a href="/accounts/activity/" data-name="heart" data-box="340,10,24,24">h</a>
         </div><main></main>`,
        FEED
      )
    ),
    { create: null, title: null, activity: null, bar: null, flattened: [] }
  );

  check(
    "a profile's own top bar is not the feed's and is left alone",
    slots(await page(GROUPED, "https://www.instagram.com/someone/")),
    { create: null, title: null, activity: null, bar: null, flattened: [] }
  );

  /* The one that matters most, and the one that caught a real fault.
   *
   * This runs again on every frame the page rewrites itself — which is most of
   * them — and by the second frame the stylesheet has already moved the plus to
   * the left-hand end and carried the chevron into the middle. A first version
   * picked the plus out by asking which control sat furthest to the right, and
   * on the second pass that was the chevron. The two of them would have swapped
   * places for ever, sixty times a second. */
  const win = await page(GROUPED, FEED);
  const before = slots(win);

  const box = (name, spec) =>
    win.document.querySelector(`[data-name="${name}"]`).setAttribute("data-box", spec);
  box("plus", "8,10,24,24");
  box("wordmark", "120,10,100,24");
  box("chevron", "224,10,20,24");
  win.document.querySelector("main").appendChild(win.document.createElement("div"));
  await new Promise((go) => setTimeout(go, 0));
  win.drain();

  check("the three keep their places once the arrangement has moved them", slots(win), before);

  /* The collision itself, which is a different question from the arrangement
   * and has to be answered even when the arrangement gives up.
   *
   * A pinned bar measures its offset from the edge of the scrollport, and the
   * scrollport does not care what the document is padded by — so the padding
   * that starts the feed below the status bar moves every part of the page
   * except the one part drawn over the clock. */
  const PINNED = `
    <div data-name="pinnedwrapper" style="position: sticky; top: 0px;">
      <div data-name="bar">
        <div data-name="titlegroup">
          <a href="/" data-name="wordmark" data-box="8,10,100,24">Instagram</a>
        </div>
        <div data-name="icongroup">
          <button data-name="plus" data-box="300,10,24,24">+</button>
          <a href="/accounts/activity/" data-name="heart" data-box="340,10,24,24">h</a>
        </div>
      </div>
    </div>
    <main></main>`;

  const lifted = (win) => {
    const element = win.document.querySelector("[data-quiet-pinned]");
    return element ? element.getAttribute("data-name") : null;
  };

  check(
    "a sticky wrapper above the bar is what gets lifted off the clock",
    lifted(await page(PINNED, FEED)),
    "pinnedwrapper"
  );

  check(
    "a bar in the ordinary flow is left where the document put it",
    lifted(await page(GROUPED, FEED)),
    null
  );

  /* Once lifted it reads as pinned at the clock's height rather than at
   * nothing. A version that re-derived this every frame would stop recognising
   * it and drop it straight back. */
  const sticky = await page(PINNED, FEED);
  const wrapper = sticky.document.querySelector('[data-name="pinnedwrapper"]');
  wrapper.style.top = "59px"; // what the stylesheet has now done to it
  sticky.document.querySelector("main").appendChild(sticky.document.createElement("div"));
  await new Promise((go) => setTimeout(go, 0));
  sticky.drain();
  check("what has been lifted stays lifted", lifted(sticky), "pinnedwrapper");

  // The viewport has to admit there is a notch before env() answers anything.
  const viewport = await page(
    `<div data-name="bar"></div><main></main>`,
    FEED,
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
  );
  check(
    "the viewport is told to cover the glass, so trim.css can ask about it",
    /viewport-fit=cover/.test(
      viewport.document.querySelector('meta[name="viewport"]').getAttribute("content")
    ),
    true
  );

  /* ── The row along the bottom, and what the page kept clear for it ────── */

  /* Instagram pads the bottom of the feed so a fixed bar cannot cover the last
   * post. Quiet hides that bar, and the padding stays behind as a black band
   * under Quiet's own row. It was blamed on the app's content inset for three
   * commits; taking the inset away did not move it. */
  /* Instagram's own order, which is the whole of the profile bug: `/explore/`
   * is letters, one to thirty of them, and so is a username. A search for the
   * first thing shaped like a username finds explore every time — and the app
   * then refused its own button with "Explore is off in Quiet." */
  const BOTTOM = `
    <div data-name="floor" style="padding-bottom: 48px">
      <div data-name="nav">
        <a href="/">home</a>
        <a href="/explore/">search</a>
        <a href="/reels/">reels</a>
        <a href="/direct/inbox/">messages</a>
        <a href="/marco/"><img src="face.jpg"></a>
      </div>
    </div>
    <main></main>`;

  const bottom = await page(BOTTOM, FEED);
  check(
    "Instagram's own row is hidden",
    bottom.document.querySelector('[data-name="nav"]').getAttribute("data-quiet-hidden"),
    "nav"
  );
  check(
    "and the floor it was standing on is taken up with it",
    bottom.document.querySelector('[data-name="floor"]').hasAttribute("data-quiet-floor"),
    true
  );

  /* And the bar the row was standing *in*, which is the black band in the
   * photograph. Four fixes read that band as a gap — the page stopping short of
   * the bottom of the glass — and answered it four times over: a taller frame,
   * the floor padding taken up, `html` and `body` refused their bottom padding,
   * the bottom safe area zeroed at the view. It survived all four, because it
   * was never a gap. `navRow` hides the five links; what carries the colour and
   * the height is the wrapper they hang in. */
  const shell = await page(
    `<div data-name="shell" style="position: fixed; bottom: 0px" data-box="0,803,393,49">
       <div data-name="nav">
         <a href="/">home</a>
         <a href="/direct/inbox/">messages</a>
         <a href="/marco/"><img src="face.jpg"></a>
       </div>
     </div>
     <main></main>`,
    FEED
  );
  check(
    "the bar drawn behind the row is hidden with it",
    shell.document.querySelector('[data-name="shell"]').getAttribute("data-quiet-hidden"),
    "nav"
  );

  /* A wrapper in the flow is padding, not a bar. Its floor is taken up — that
   * is the check above — and it keeps everything else it was drawing. */
  check(
    "something merely in the flow is not a bar and is left where it is",
    bottom.document.querySelector('[data-name="floor"]').hasAttribute("data-quiet-hidden"),
    false
  );

  /* The stop that matters. Everything else about a container can look like a
   * bar; a container with the feed inside it is the page. */
  const holdsTheFeed = await page(
    `<div data-name="shell" style="position: fixed; bottom: 0px" data-box="0,803,393,49">
       <div data-name="nav">
         <a href="/">home</a>
         <a href="/direct/inbox/">messages</a>
       </div>
       <main></main>
     </div>`,
    FEED
  );
  check(
    "a wrapper with the feed inside it is not a bar",
    holdsTheFeed.document.querySelector('[data-name="shell"]').hasAttribute("data-quiet-hidden"),
    false
  );

  const tall = await page(
    `<div data-name="shell" style="position: fixed; bottom: 0px" data-box="0,0,393,852">
       <div data-name="nav">
         <a href="/">home</a>
         <a href="/direct/inbox/">messages</a>
       </div>
     </div>
     <main></main>`,
    FEED
  );
  check(
    "nor is one as tall as the page",
    tall.document.querySelector('[data-name="shell"]').hasAttribute("data-quiet-hidden"),
    false
  );

  /* The button marked "your profile" uses Instagram's own link rather than an
   * address built from a name the app may have read a moment too early. */
  // It answers with the address it went to rather than a bare yes, which is
  // the only way to check *where* somebody was sent in a place that implements
  // no navigation.
  check(
    "your profile goes where Instagram's own link goes",
    bottom.__quietOpenProfile(),
    "/marco/"
  );

  check(
    "and the name it reads out of the row is a person, not a place",
    bottom.__quietMe,
    "marco"
  );

  /* A page with no such row has nothing to click, and says so rather than
   * guessing — the app falls back to the address it built from the name. */
  const bare = await page(`<main></main>`, FEED);
  check("with no row to read, it declines", bare.__quietOpenProfile(), false);

  /* Every reserved root, one at a time, in the place the profile link sits.
   * None of them is a person, and a row of nothing but Instagram's own
   * addresses must answer no rather than pick one. */
  for (const root of ["explore", "reels", "direct", "accounts", "stories", "p"]) {
    const only = await page(
      `<div data-name="nav">
         <a href="/">home</a>
         <a href="/direct/inbox/">messages</a>
         <a href="/${root}/">not a person</a>
       </div><main></main>`,
      FEED
    );
    check(`/${root}/ is not somebody's profile`, only.__quietOpenProfile(), false);
  }

  /* ── What is drawn at the top of the glass ───────────────────────────── */

  /* Four builds went into finding Instagram's header by something *in* it — a
   * link to the activity feed, a link home, a wordmark — and on the real site
   * it found nothing every time. This asks the browser what is painted at the
   * top instead, which is a question about the screen rather than about
   * somebody else's markup. */
  const atTop = (html) =>
    page(html, FEED).then((win) => {
      const found = win.document.querySelector("[data-quiet-pinned]");
      return found ? found.getAttribute("data-name") : null;
    });

  check(
    "whatever is pinned to the top of the glass is moved off the clock",
    await atTop(`
      <div data-name="sticky" data-at-top style="position: sticky; top: 0px"
           data-box="0,0,390,46">bar</div>
      <main></main>`),
    "sticky"
  );

  check(
    "and a fixed one is the same thing by another name",
    await atTop(`
      <div data-name="fixed" data-at-top style="position: fixed; top: 0px"
           data-box="0,0,390,46">bar</div>
      <main></main>`),
    "fixed"
  );

  check(
    "something merely at the top of the document is left where it is",
    await atTop(`
      <div data-name="flowing" data-at-top data-box="0,0,390,46">bar</div>
      <main></main>`),
    null
  );

  check(
    "a wrapper as tall as the page is not a bar and is not moved",
    await atTop(`
      <div data-name="whole" data-at-top style="position: sticky; top: 0px"
           data-box="0,0,390,800">everything</div>
      <main></main>`),
    null
  );

  check(
    "nor is something pinned further down the screen",
    await atTop(`
      <div data-name="lower" data-at-top style="position: sticky; top: 120px"
           data-box="0,120,390,46">bar</div>
      <main></main>`),
    null
  );

  /* The bar is found through whatever the page has wrapped it in: the browser
   * answers with the whole stack under the point, and only one of them is
   * pinned. */
  check(
    "the pinned one is picked out of the stack under the point",
    await atTop(`
      <div data-name="outer" data-at-top data-box="0,0,390,900">
        <div data-name="pinned" data-at-top style="position: sticky; top: 0px"
             data-box="0,0,390,46">bar</div>
      </div>
      <main></main>`),
    "pinned"
  );

  /* The reservation is there whether or not there is a row to walk up from.
   * On a page where Instagram draws no bottom bar, the padding it keeps for one
   * is still a black band under a row that floats. */
  const floored = await page(
    `<main data-name="feed" style="padding-bottom: 60px"></main>`,
    FEED
  );
  check(
    "the feed's own floor is taken up with no row in sight",
    floored.document.querySelector('[data-name="feed"]').hasAttribute("data-quiet-floor"),
    true
  );

  const unfloored = await page(`<main data-name="feed"></main>`, FEED);
  check(
    "and a page that reserved nothing is left alone",
    unfloored.document.querySelector('[data-name="feed"]').hasAttribute("data-quiet-floor"),
    false
  );

  /* ── Going somewhere through Instagram's own row ─────────────────────── */

  /* Each of the three presses the link the site already has, so the client in
   * the page keeps its shell and the place you had scrolled to, rather than the
   * app loading an address and throwing all of it away. */
  const rowPage = () => page(BOTTOM, FEED);

  for (const [kind, expected] of [
    ["home", "/"],
    ["messages", "/direct/inbox/"],
    ["profile", "/marco/"],
  ]) {
    const win = await rowPage();
    check(`${kind} goes to ${expected}`, win.__quietGo(kind), expected);
  }

  check(
    "and a destination nobody has heard of is declined",
    (await rowPage()).__quietGo("reels"),
    false
  );

  /* Standing on the feed already, home answers with the address rather than
   * pressing anything: the row has marked where you are since the day it
   * learned to, and going nowhere is what Instagram does too. */
  check(
    "asking for the page you are standing on presses nothing",
    (await rowPage()).__quietGo("home"),
    "/"
  );

  check(
    "with no row to press, every destination declines",
    ["home", "messages", "profile"].map((kind) => bare.__quietGo(kind)),
    [false, false, false]
  );

  /* ── The other wordmark ──────────────────────────────────────────────── */

  /* Instagram has two, and both are theirs: the script one in the app, the
   * newer one on the website. This puts theirs where theirs was — it never
   * sets the word in a substitute typeface, which would be a forgery rather
   * than a wordmark. */
  const WORDMARKED = `
    <div data-name="bar">
      <a href="/" data-name="wordmark" data-box="8,10,100,24">
        <svg data-name="theirs" aria-label="Instagram"></svg>
      </a>
      <button data-name="plus" data-box="300,10,24,24">+</button>
      <a href="/accounts/activity/" data-name="heart" data-box="340,10,24,24">h</a>
    </div>
    <main></main>`;

  /** Another frame, after the page has rewritten itself. */
  const again = async (win) => {
    win.document.querySelector("main").appendChild(win.document.createElement("div"));
    await new Promise((go) => setTimeout(go, 0));
    win.drain();
  };

  const dressed = await page(WORDMARKED, FEED);
  dressed.localStorage.setItem(
    "quiet.wordmark",
    'svg <svg aria-label="Instagram" viewBox="0 0 100 30"><path d="M0 0h10v10H0z"/></svg>'
  );
  await again(dressed);

  const mine = dressed.document.querySelector("[data-quiet-wordmark]");
  check("the remembered wordmark is put where the other one was", !!mine, true);

  /* Nothing is hidden until the replacement has been measured and found to
   * have a size. A header with no wordmark at all is worse than one with the
   * other wordmark, and this is a nicety — it does not get to break anything. */
  check(
    "and Instagram's own is still showing until it has been measured",
    dressed.document.querySelector('[data-name="theirs"]').getAttribute("data-quiet-hidden"),
    null
  );

  mine.setAttribute("data-box", "8,10,100,29");
  await again(dressed);
  check(
    "once it measures something, theirs steps aside",
    [
      dressed.document.querySelector("[data-quiet-wordmark]").getAttribute("data-quiet-wordmark"),
      dressed.document.querySelector('[data-name="theirs"]').getAttribute("data-quiet-hidden"),
    ],
    ["kept", "wordmark"]
  );

  /* One that draws nothing takes itself out again, gives back the original,
   * and is not tried a second time. */
  const empty = await page(WORDMARKED, FEED);
  empty.localStorage.setItem("quiet.wordmark", "svg <svg aria-label=\"Instagram\"></svg>");
  await again(empty);
  await again(empty);
  check(
    "one that draws nothing puts itself away and gives theirs back",
    [
      empty.document.querySelector("[data-quiet-wordmark]"),
      empty.document.querySelector('[data-name="theirs"]').getAttribute("data-quiet-hidden"),
      empty.localStorage.getItem("quiet.wordmark"),
    ],
    [null, null, null]
  );

  /* With nothing remembered, the header is exactly as Instagram drew it. */
  const plain = await page(WORDMARKED, FEED);
  await again(plain);
  check(
    "with nothing remembered, the header is left alone",
    [
      plain.document.querySelector("[data-quiet-wordmark]"),
      plain.document.querySelector('[data-name="theirs"]').getAttribute("data-quiet-hidden"),
    ],
    [null, null]
  );

  /* ── The door back into the app ──────────────────────────────────────── */

  /* Instagram's page offers a bar along the bottom that opens Instagram in
   * Instagram. The app already refuses the tap and says why, but a door you are
   * told is locked every time you reach for it is still a door in the room. */
  const banner = (href) => `
    <div data-name="banner" style="position: fixed" data-box="0,760,390,60">
      <a href="${href}" data-name="door" data-box="120,775,150,30">Use the app</a>
      <button data-name="cross" data-box="350,775,24,24">x</button>
    </div>
    <main></main>`;

  for (const [what, href] of [
    ["the app itself", "instagram://user?username=marco"],
    ["a story in the app", "instagram-stories://share"],
    ["the App Store", "https://apps.apple.com/app/instagram/id389801252"],
    ["the upsell", "/_n/mobile_app_upsell/?next=/"],
  ]) {
    const win = await page(banner(href), FEED);
    check(
      `a bar offering ${what} is taken down whole`,
      [
        win.document.querySelector('[data-name="banner"]').getAttribute("data-quiet-hidden"),
        win.document.querySelector('[data-name="cross"]').closest("[data-quiet-hidden]") !== null,
      ],
      ["upsell", true]
    );
  }

  /* The thing that must never be hidden. A conversation pins its message box to
   * the bottom of the viewport in exactly the same way, and the only difference
   * — the only one worth trusting — is that a composer has no link out of the
   * site in it. */
  const composer = await page(
    `<div data-name="composer" data-at-bottom style="position: fixed" data-box="0,760,390,60">
       <input data-name="field" data-box="10,770,300,40">
       <button data-name="send" data-box="330,770,40,40">send</button>
     </div>
     <main></main>`,
    FEED
  );
  check(
    "a conversation's message box is pinned the same way and left alone",
    composer.document.querySelector('[data-name="composer"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* The photograph that came back showed the strip still there, which settles
   * what it is made of: no address anywhere in it, so nothing written over
   * `href` can match. Found by what is drawn along the bottom of the glass
   * instead — the same question the header is found by. */
  const strip = (inside, box, position) => `
    <div data-name="strip" data-at-bottom
         style="position: ${position || "fixed"}"
         data-box="${box || "0,760,390,60"}">
      ${inside}
    </div>
    <main></main>`;

  const SENTENCE = '<div data-name="say" role="button">Use the app</div>' +
    '<button data-name="cross">x</button>';

  const wordless = await page(strip(SENTENCE), FEED);
  check(
    "a strip along the bottom with no link in it goes anyway",
    wordless.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    "upsell"
  );

  /* A consent notice is also a strip along the bottom, and refusing to let
   * somebody answer one would be worse than the banner. */
  const notice = await page(
    strip(
      "<p>We use cookies and similar technologies to give you a better " +
      "experience, and to show you relevant advertising.</p>" +
      '<button data-name="allow">Allow all</button>'
    ),
    FEED
  );
  check(
    "a paragraph of consent along the bottom is left alone",
    notice.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* A sheet is not a banner. */
  const sheet = await page(strip(SENTENCE, "0,300,390,520"), FEED);
  check(
    "a sheet half the height of the screen is left alone",
    sheet.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* Something that spans less than the glass is part of the page. */
  const narrow = await page(strip(SENTENCE, "40,760,300,60"), FEED);
  check(
    "something narrower than the glass is part of the page",
    narrow.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* Nothing to press is somebody's spacer, and hiding a spacer moves the page
   * for no reason at all. */
  const spacer = await page(strip("<span>&nbsp;</span>"), FEED);
  check(
    "a strip with nothing to press in it is a spacer and stays",
    spacer.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* The page's own content passes under that point on every scroll. */
  const flowing = await page(
    strip(SENTENCE, "0,760,390,60", "static"),
    FEED
  );
  check(
    "content merely passing under the point is not a strip",
    flowing.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* In a conversation the bar along the bottom is what you came for, and a
   * message request puts its two answers in the same place. */
  const inbox = await page(strip(SENTENCE), "https://www.instagram.com/direct/t/17/");
  check(
    "in a conversation the bottom of the screen is left entirely alone",
    inbox.document.querySelector('[data-name="strip"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* A door with no bar around it is still a door. */
  const alone = await page(
    `<main><a href="instagram://app" data-name="door">Open</a></main>`,
    FEED
  );
  check(
    "and a door with no bar around it goes on its own",
    alone.document.querySelector('[data-name="door"]').getAttribute("data-quiet-hidden"),
    "upsell"
  );

  /* ── Sheets ──────────────────────────────────────────────────────────── */

  /* Instagram puts a sheet up for switching accounts, for sharing, and for the
   * menu behind the three dots. It slides over its own tab bar; Quiet's row is
   * the app's furniture and stayed put, drawn across the buttons on it.
   *
   * Seven answers to that were written and every one of them tried to move
   * something of Instagram's. Seven photographs came back identical. This file
   * moves nothing now: it answers whether there is a sheet, whether anything on
   * it is under the row, and what colour it is — and the app, which owns the
   * viewport, makes the web view shorter. Everything anchored to the bottom of
   * a viewport rises with it, and no stylesheet can refuse that.
   *
   * So what is checked here is the answer, not the moving. */
  const sheetOf = (win) => win.sent.filter((m) => m.kind === "sheet").pop();
  const liftOf = (win) => {
    const moved = win.document.querySelector("[data-quiet-sheet]");
    return moved ? moved.style.getPropertyValue("--quiet-lift") : null;
  };


  const nothingModal = await page(`<main></main>`, FEED);
  check("with nothing modal on screen, nothing is said", sheetOf(nothingModal), undefined);

  /* Said outright in the markup, which is the answer when it is there. Three
   * spellings, and Instagram is obliged to use none of them. */
  const HIGH = 'data-box="0,500,390,344" style="position: fixed; background-color: rgb(38, 38, 38)"';

  for (const [what, markup] of [
    ["a sheet", `<div role="dialog" data-name="sheet" ${HIGH}>x</div>`],
    ["one that only says it is modal", `<div aria-modal="true" data-name="sheet" ${HIGH}>x</div>`],
    ["the element the platform has for it", `<dialog open data-name="sheet" ${HIGH}>x</dialog>`],
  ]) {
    const win = await page(`${markup}<main></main>`, FEED);
    check(`${what} is one`, sheetOf(win), {
      kind: "sheet", up: true, clear: true, red: 38, green: 38, blue: 38,
    });
  }

  /* A dialog in the tree with no box has been dismissed and not yet removed, or
   * built ahead of being needed. Neither is a sheet. */
  const notDrawn = await page(`<div role="dialog">x</div><main></main>`, FEED);
  check("one that is in the tree but not drawn is not one", sheetOf(notDrawn), undefined);

  /* And the one that was never asked, for seven rounds: a sheet that says
   * nothing at all. Found by what is drawn along the bottom of the glass. */
  const shape = (box, position, mark) => `
    <div data-name="sheet" ${mark === undefined ? "data-at-bottom" : mark}
         style="position: ${position || "fixed"}; background-color: rgb(38, 38, 38)"
         data-box="${box || "0,500,390,344"}">x</div>
    <main></main>`;

  const nameless = await page(shape(), FEED);
  check("a sheet that never said it was one is found by its shape", sheetOf(nameless), {
    kind: "sheet", up: true, clear: true, red: 38, green: 38, blue: 38,
  });

  /* Not everything held against the bottom is a sheet. */
  for (const [what, box, position] of [
    ["a bar is too short to be one", "0,795,390,49", "fixed"],
    ["a backdrop is too tall to be one", "0,0,390,844", "fixed"],
    ["a card does not span the glass", "60,500,270,344", "fixed"],
    ["and what is laid out in the page is part of the page", "0,500,390,344", "static"],
  ]) {
    const win = await page(shape(box, position), FEED);
    check(what, sheetOf(win), undefined);
  }

  /* Instagram's own floor reaches the bottom and spans the glass, and is
   * already taken out. It must never be mistaken for a sheet. */
  const floor = await page(
    `<div data-name="sheet" data-at-bottom data-quiet-floor=""
          style="position: fixed" data-box="0,500,390,344">x</div><main></main>`,
    FEED
  );
  check("Instagram's own floor is never one", sheetOf(floor), undefined);

  /* On a story and in a conversation the app draws no row, so there is nothing
   * for a sheet to be in the way of and nothing to take off the glass. */
  const noRow = await page(shape(), FEED, undefined, 0);
  check("with no row on the screen, a shape is not chased", sheetOf(noRow), undefined);

  /* What colour it is, so the strip of glass the app takes away underneath the
   * sheet is painted in the sheet's own colour rather than showing as a band of
   * something else. Climbed for, because a see-through layer hands back a
   * colour that is never drawn anywhere. */
  const seeThrough = await page(
    `<div data-name="outer" style="position: fixed; background-color: rgb(38, 38, 38)"
          data-box="0,500,390,344">
       <div data-name="sheet" data-at-bottom
            style="background-color: rgba(255, 255, 255, 0.2)"
            data-box="0,500,390,344">x</div>
     </div><main></main>`,
    FEED
  );
  check(
    "a see-through layer is climbed past for the colour",
    (({ red, green, blue }) => [red, green, blue])(sheetOf(seeThrough)),
    [38, 38, 38]
  );

  /* The last resort. The app cannot move what it cannot find, so it is told
   * whether anything on the sheet is still under the row — and when something
   * is, the row stands down and the press goes through it. */
  const under = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>
       <button data-box="16,790,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("a button under the row is reported", sheetOf(under).clear, false);

  const above = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>
       <button data-box="16,690,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("and one above it is not", sheetOf(above).clear, true);

  const below = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>
       <button data-box="16,900,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("what is off the glass entirely is not in the way", sheetOf(below).clear, true);

  /* And it has to come back, or the glass stays short for a sheet that has
   * gone. */
  const dismissed = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>x</div><main></main>`,
    FEED
  );
  dismissed.document.querySelector('[data-name="sheet"]').remove();
  await new Promise((go) => setTimeout(go, 0));
  dismissed.drain();
  check(
    "and the glass is given back when the sheet goes",
    dismissed.sent.filter((m) => m.kind === "sheet").map((m) => m.up),
    [true, false]
  );

  /* The observer runs on every mutation. Saying it again on every one of them
   * would take the glass away and give it back on every frame the page
   * rewrites itself. */
  const stays = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>x</div><main></main>`,
    FEED
  );
  stays.document.querySelector("main").appendChild(stays.document.createElement("div"));
  stays.drain();
  check(
    "a sheet that is still there is not announced twice",
    stays.sent.filter((m) => m.kind === "sheet").length,
    1
  );

  /* ── Sheets, and the three ways of missing one ───────────────────────── */

  /* A sheet arrives by sliding, and a slide is not a mutation. The observer
   * hears the panel go into the document while the panel is still below the
   * bottom edge, and nothing in the document changes while it travels — so the
   * question was asked once, at the one moment the honest answer is no, and
   * never asked again. That is the whole of the eighth photograph, and it is
   * why the seven before it all came back the same: every one of them changed
   * what the app does about a sheet, and none of them changed whether the app
   * ever heard about one. */
  const sliding = await page(
    `<div data-name="sheet" data-at-bottom
          style="position: fixed; background-color: rgb(38, 38, 38)"
          data-box="0,844,390,190">x</div><main></main>`,
    FEED
  );
  check("a sheet still below the edge is not one yet", sheetOf(sliding), undefined);

  sliding.document
    .querySelector('[data-name="sheet"]')
    .setAttribute("data-box", "0,654,390,190");
  await new Promise((go) => setTimeout(go, 300));
  check(
    "and is found when it lands, with nothing having changed in the document",
    sheetOf(sliding) && sheetOf(sliding).up,
    true
  );

  /* Two points of tolerance at the foot is a measurement, not a tolerance: it
   * asks a panel that can end on a rounded corner or a hairline of its own to
   * land on an exact pixel. */
  const shortOfTheEdge = await page(shape("0,634,390,180"), FEED);
  check(
    "a sheet that stops a little short of the edge is still one",
    shortOfTheEdge.sent.filter((m) => m.kind === "sheet").length && sheetOf(shortOfTheEdge).up,
    true
  );

  const wellShortOfIt = await page(shape("0,554,390,180"), FEED);
  check("and one that stops well short of it is not", sheetOf(wellShortOfIt), undefined);

  /* The walk for what is holding the panel against the glass used to stop after
   * eight steps, which is a guess about the depth of somebody else's tree.
   * Instagram's is deeper than that almost everywhere, and the fixed element is
   * the backdrop rather than the panel. */
  const deep = await page(
    `<div style="position: fixed" data-box="0,0,390,844">
       <div><div><div><div><div><div><div><div><div>
         <div data-name="sheet" data-at-bottom
              style="background-color: rgb(38, 38, 38)"
              data-box="0,654,390,190">x</div>
       </div></div></div></div></div></div></div></div></div>
     <main></main>`,
    FEED
  );
  check(
    "a panel a long way below the backdrop holding it is still held over the page",
    sheetOf(deep) && sheetOf(deep).up,
    true
  );

  /* ── And the question the photograph itself asks ─────────────────────── */

  /* Every test above is an inference about how Instagram builds a sheet, and an
   * inference about somebody else's markup is true until they change it. This
   * one is about the screen: is there anything a person would press drawn
   * underneath Quiet's row? It knows nothing about sheets and needs nothing of
   * Instagram's markup to be true. */
  const menu = await page(
    `<div data-name="menu" data-at-bottom
          style="position: fixed; background-color: rgb(38, 38, 38)"
          data-box="60,600,270,220">
       <button data-at-bottom data-box="70,780,250,44">Log in to an Existing Account</button>
     </div><main></main>`,
    FEED
  );
  check(
    "a menu that does not span the glass, with a button under the row, is in the way",
    [sheetOf(menu).up, sheetOf(menu).clear],
    [true, false]
  );

  /* The page's own content runs on beneath the row on purpose — that is where
   * Instagram's next photograph goes. What scrolls is not held over anything. */
  const running = await page(
    `<main><a data-at-bottom href="/marco/" data-box="16,780,358,44">marco</a></main>`,
    FEED
  );
  check("what the page runs on under the row is not one", sheetOf(running), undefined);

  /* A sheet, a menu and a dialog all span most of the glass. A stray fixed pill
   * does not, and taking a strip of glass away for one would be the app moving
   * the whole page for a button. */
  const pill = await page(
    `<div data-at-bottom style="position: fixed" data-box="120,780,150,44">
       <button data-at-bottom data-box="120,780,150,44">New posts</button>
     </div><main></main>`,
    FEED
  );
  check("a pill too narrow to be a sheet is left alone", sheetOf(pill), undefined);

  /* And what comes back is the panel rather than the dimmed backdrop around it.
   * The backdrop is the whole screen and has no colour worth painting a strip
   * of glass in — the strip is there so the sheet still reaches the bottom edge
   * and only its contents have moved. */
  const behindABackdrop = await page(
    `<div style="position: fixed; background-color: rgb(0, 0, 0)"
          data-box="0,0,390,844">
       <div data-name="panel" data-at-bottom
            style="background-color: rgb(38, 38, 38)" data-box="0,560,390,220">
         <button data-at-bottom data-box="16,720,358,44">Log In</button>
       </div>
     </div><main></main>`,
    FEED
  );
  check(
    "and it is the panel that is found, not the backdrop behind it",
    (({ up, clear, red, green, blue }) => [up, clear, red, green, blue])(
      sheetOf(behindABackdrop)
    ),
    [true, false, 38, 38, 38]
  );

  /* ── And what the room being made does to the answer ─────────────────── */

  /* The app takes a strip of glass off the bottom, and the sheet rises with it
   * — and so does the floor it is measured against, because both are anchored
   * to the same viewport. So the row has to be asked about what is left of it
   * over the page, or "is anything still underneath" answers the same before
   * and after the room is made, and the row stands down for as long as the
   * sheet is open. A row you cannot leave a sheet by is not a row. */
  const roomMade = await page(
    `<div role="dialog" data-name="sheet" ${HIGH}>
       <button data-box="16,790,358,44">Log In</button>
     </div><main></main>`,
    FEED,
    undefined,
    89,
    128
  );
  check(
    "with the room already made, nothing is under the row any more",
    sheetOf(roomMade).clear,
    true
  );

  /* And the sheet itself is held on to while it is on screen. The act of
   * answering changes the screen the next answer is read off: once the strip
   * is gone the row is standing on the app's own paint, the test that found
   * the sheet by what was drawn under the row finds nothing, and without this
   * the glass would come back and the sheet would drop onto the row again,
   * once per frame, for as long as it was open. */
  const foundThenLifted = await page(
    `<div data-name="sheet" data-at-bottom
          style="position: fixed; background-color: rgb(38, 38, 38)"
          data-box="0,654,390,190">
       <button data-at-bottom data-box="16,790,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check(
    "a nameless sheet with a button under the row stands the row down",
    [sheetOf(foundThenLifted).up, sheetOf(foundThenLifted).clear],
    [true, false]
  );

  foundThenLifted.__quietLift = 128;
  foundThenLifted.document
    .querySelector("main")
    .appendChild(foundThenLifted.document.createElement("div"));
  await new Promise((go) => setTimeout(go, 0));
  foundThenLifted.drain();
  check(
    "and the sheet is not lost, nor the row, the moment the room is made",
    [sheetOf(foundThenLifted).up, sheetOf(foundThenLifted).clear],
    [true, true]
  );

  /* The inbox, which is the case that made this necessary. Its list of
   * conversations spans the glass, starts under the header, reaches the bottom
   * edge, and sits inside something held against the screen — every test a
   * sheet passes, it passes. A photograph of it moved a hundred and twenty-eight
   * points up, with the inbox's own header piled on top of itself, is what this
   * check is made of.
   *
   * A sheet is put in front of the page, and the page is what is inside `main`.
   */
  const theInbox = await page(
    `<main>
       <div data-name="list" data-at-bottom
            style="position: fixed; background-color: rgb(0, 0, 0)"
            data-box="0,120,390,724">conversations</div>
     </main>`,
    FEED
  );
  check("the inbox's own list is not a sheet", sheetOf(theInbox), undefined);

  /* But one that says outright that it is modal is believed, wherever it is.
   *
   * The asymmetry is the point. Saying "I am modal" is a statement of intent
   * that only a sheet makes; being the shape of a sheet is a guess, and the
   * inbox shows what the guess costs when it is wrong. So the guess is refused
   * inside the page's own content and the statement is not. */
  const saysSoInMain = await page(
    `<main>
       <div role="dialog" data-name="sheet"
            style="position: fixed; background-color: rgb(38, 38, 38)"
            data-box="0,500,390,344">x</div>
     </main>`,
    FEED
  );
  check("but one that says so is believed wherever it is", sheetOf(saysSoInMain), {
    kind: "sheet", up: true, clear: true, red: 38, green: 38, blue: 38,
  });

  /* ── Moving the sheet ────────────────────────────────────────────────── */

  /* A photograph settled which mechanism is right, and it took shrinking the
   * viewport to get one: with the glass a hundred and twenty-eight points
   * shorter, Instagram's sheet did not rise — it was cut, straight through "Log
   * In to an Existing Account". A sheet clipped by a shorter viewport is a
   * sheet that is not anchored to the bottom of one, and nothing done to the
   * viewport will ever move it. */
  const HELD = 'style="position: fixed; background-color: rgb(38, 38, 38)"';

  const sheetGoesUp = await page(
    `<div role="dialog" data-name="sheet" ${HELD} data-box="0,500,390,344">x</div><main></main>`,
    FEED
  );
  check("a sheet is moved two centimetres up", liftOf(sheetGoesUp), "128px");

  /* Placed by a number worked out when it opened rather than anchored to the
   * bottom — which is the shape the photograph turned out to be, and the one a
   * shorter viewport cuts instead of moving. A transform does not care. */
  const sheetPlacedByANumber = await page(
    `<div role="dialog" data-name="sheet"
          style="position: fixed; top: 500px; background-color: rgb(38, 38, 38)"
          data-box="0,500,390,344">x</div><main></main>`,
    FEED
  );
  check("one placed by a number is moved just the same", liftOf(sheetPlacedByANumber), "128px");

  /* Once moved it is a hundred and twenty-eight points clear of the bottom
   * edge and would fail the test that chose it. Letting it go would drop it
   * back, find it again, and flicker for as long as it was open. */
  const sheetKeptWhenMoved = await page(
    `<div data-name="sheet" data-at-bottom ${HELD} data-box="0,500,390,344">x</div><main></main>`,
    FEED
  );
  sheetKeptWhenMoved.document
    .querySelector('[data-name="sheet"]')
    .setAttribute("data-box", "0,372,390,344");
  sheetKeptWhenMoved.document.querySelector("main").appendChild(sheetKeptWhenMoved.document.createElement("div"));
  await new Promise((go) => setTimeout(go, 0));
  sheetKeptWhenMoved.drain();
  check("and it is not let go once it has moved", liftOf(sheetKeptWhenMoved), "128px");

  /* And it is put back when the sheet goes, or the next page inherits a
   * transform belonging to a sheet nobody can see. */
  const sheetPutBack = await page(
    `<div role="dialog" data-name="sheet" ${HELD} data-box="0,500,390,344">x</div><main></main>`,
    FEED
  );
  sheetPutBack.document.querySelector('[data-name="sheet"]').remove();
  await new Promise((go) => setTimeout(go, 0));
  sheetPutBack.drain();
  check("and put back when the sheet goes", liftOf(sheetPutBack), null);

  /* The strip the app paints underneath has to be the sheet's colour. The
   * thing found is as often the backdrop as the panel, a backdrop is
   * see-through by design, and climbing up from one lands on the page — which
   * a photograph showed exactly: the strip in the page's near-black instead of
   * the sheet's grey. */
  const colourThroughBackdrop = await page(
    `<div role="dialog" data-name="sheet" data-box="0,0,390,844"
          style="position: fixed; background-color: rgba(0, 0, 0, 0.6)">
       <div data-name="panel" data-box="0,500,390,344"
            style="background-color: rgb(38, 38, 38)">x</div>
     </div><main></main>`,
    FEED
  );
  check(
    "the colour is read down into the panel, not up to the page",
    (({ red, green, blue }) => [red, green, blue])(sheetOf(colourThroughBackdrop)),
    [38, 38, 38]
  );

  /* ── The colour the clock stands on ──────────────────────────────────── */

  /* The app owns the pixels the time and the battery sit on, so something has
   * to decide what colour they are. The answer is: whatever Instagram is
   * drawing there, so that there is no seam. */
  const chromeOf = (win) => win.sent.filter((m) => m.kind === "chrome").pop();

  const top = (inside) =>
    `<div data-name="page" data-at-top style="background-color: rgb(13, 16, 21)">
       ${inside || ""}
     </div>
     <main></main>`;

  const painted = await page(top(), FEED);
  check(
    "the band takes the colour drawn at the top of the page",
    (({ red, green, blue }) => [red, green, blue])(chromeOf(painted)),
    [13, 16, 21]
  );

  /* Instagram's header is often translucent. A colour that is half see-through
   * over something else is not a colour the app can paint a solid band in, and
   * guessing what is behind it is how a band ends up nearly right on one page
   * and wrong on the next. */
  const throughIt = await page(
    `<div data-name="page" style="background-color: rgb(13, 16, 21)">
       <div data-name="bar" data-at-top style="background-color: rgba(255, 255, 255, 0.3)"></div>
     </div>
     <main></main>`,
    FEED
  );
  check(
    "a see-through bar is climbed past to the colour behind it",
    (({ red, green, blue }) => [red, green, blue])(chromeOf(throughIt)),
    [13, 16, 21]
  );

  /* A page in the light draws a light one, and nothing here has an opinion
   * about which. */
  const daylight = await page(
    `<div data-name="page" data-at-top style="background-color: rgb(255, 255, 255)"></div>
     <main></main>`,
    FEED
  );
  check(
    "and in the light it is the light one, with no opinion of ours",
    (({ red, green, blue }) => [red, green, blue])(chromeOf(daylight)),
    [255, 255, 255]
  );

  /* Nothing painted yet. Better to leave the app's own colour up than to send
   * a guess it will paint a band in. */
  const blank = await page(`<main></main>`, FEED);
  check(
    "a page that has painted nothing says nothing",
    chromeOf(blank),
    undefined
  );

  /* The observer runs on every mutation. A colour that has not changed must
   * not be sent again, or the band animates on every frame the page rewrites
   * itself. */
  const twice = await page(top(), FEED);
  twice.document.querySelector("main").appendChild(
    twice.document.createElement("div")
  );
  twice.drain();
  check(
    "the same colour is not said twice",
    twice.sent.filter((m) => m.kind === "chrome").length,
    1
  );

  /* ── A header that gets out of the way ───────────────────────────────── */

  /* jsdom lays nothing out and scrolls nothing, so the page is scrolled by
   * saying where it is and telling it so — which is exactly what a browser
   * does, and is all the listener reads. */
  const scrollTo = (win, y) => {
    Object.defineProperty(win, "scrollY", { value: y, configurable: true });
    win.dispatchEvent(new win.Event("scroll"));
    return win.document.documentElement.hasAttribute("data-quiet-away");
  };

  const feed = await page(GROUPED, FEED);
  check("at the top of the feed the header is there", scrollTo(feed, 0), false);
  check("a little way down it is still there", scrollTo(feed, 40), false);
  check("further down it gets out of the way", scrollTo(feed, 300), true);
  check("and on the way back up it returns", scrollTo(feed, 200), false);
  check("at the very top it is certainly there", scrollTo(feed, 0), false);

  /* A fingertip resting on the glass is not a decision. */
  check("a movement too small to mean anything changes nothing", [
    scrollTo(feed, 400), scrollTo(feed, 403),
  ], [true, true]);

  /* Every other page's top bar is that page's own: the name on a profile, the
   * search in the inbox, the back arrow in a conversation. A back arrow that
   * slides away while you read is one you go hunting for. */
  const elsewhere = await page(GROUPED, "https://www.instagram.com/marco/");
  check(
    "on a page that is not the feed it stays where it is",
    scrollTo(elsewhere, 500),
    false
  );

  process.exit(failures ? 1 : 0);
})();
