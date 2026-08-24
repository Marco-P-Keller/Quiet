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

async function page(html, url, head) {
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
  win.document.elementsFromPoint = function () {
    return Array.prototype.slice.call(win.document.querySelectorAll("[data-at-top]"));
  };
  // Every frame the script asks for, taken immediately, so a test can say
  // "and then the page rewrote itself" and see the result on the next line.
  const frames = [];
  win.requestAnimationFrame = (fn) => frames.push(fn);
  win.drain = () => { while (frames.length) frames.shift()(); };
  // The script asks Instagram who is signed in. There is nobody here to ask.
  win.fetch = () => new win.Promise(() => {});
  win.__quietTop = 59;
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
    `<div data-name="composer" style="position: fixed" data-box="0,760,390,60">
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

  process.exit(failures ? 1 : 0);
})();
