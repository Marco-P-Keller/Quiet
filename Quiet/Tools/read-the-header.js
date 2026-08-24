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
 */
async function page(html, url, head, row) {
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
   * the app's and stayed put, and was drawn straight through the buttons on it.
   *
   * A sheet has no address, so nothing about where you are can see one coming.
   * What it does have is an attribute saying it is modal — the same word in
   * every language, and one Instagram has to set for its own screen reader.
   *
   * Two answers moved the row and neither was right: a button that cannot be
   * seen cannot be pressed by anybody. So the sheet is given room to stand
   * clear of the row instead, and what the app is told is whether that worked.
   */
  const sheetOf = (win) => win.sent.filter((m) => m.kind === "sheet").pop();
  const paddedIn = (win) => {
    const panel = win.document.querySelector("[data-quiet-sheet]");
    return panel ? panel.getAttribute("data-name") : null;
  };

  /* A panel: pinned to the bottom edge, most of the width of the glass, and
   * shorter than it. The three things a bottom sheet has and a backdrop does
   * not. */
  const PANEL = 'style="position: fixed" data-box="0,400,390,444"';

  const noSheet = await page(`<main></main>`, FEED);
  check("with nothing modal on screen, nothing is said", sheetOf(noSheet), undefined);

  for (const [what, markup] of [
    ["a sheet", `<div role="dialog" data-name="panel" ${PANEL}>Switch accounts</div>`],
    ["one that only says it is modal", `<div aria-modal="true" data-name="panel" ${PANEL}>x</div>`],
    ["the element the platform has for it", `<dialog open data-name="panel" ${PANEL}>x</dialog>`],
  ]) {
    const win = await page(`${markup}<main></main>`, FEED);
    check(`${what} is one`, sheetOf(win), { kind: "sheet", up: true, clear: true });
    check(`${what} is given room to stand clear of the row`, paddedIn(win), "panel");
  }

  /* The dimmed sheet of glass over the page is not the thing to pad. Its
   * children measure their `bottom` against its padding box, so padding meant
   * to lift the sheet off the row would push it down behind it instead. */
  const backdrop = await page(
    `<div role="dialog" data-name="backdrop" style="position: fixed" data-box="0,0,390,844">
       <div data-name="panel" style="position: absolute" data-box="0,400,390,444">
         <button data-name="login" data-box="16,800,358,44">Log In to an Existing Account</button>
       </div>
     </div><main></main>`,
    FEED
  );
  check("the panel is padded rather than the backdrop around it", paddedIn(backdrop), "panel");

  /* And not something inside the panel that happens to end at the same edge.
   * Padding a button makes the button taller and moves nothing anywhere. */
  const button = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,400,390,444">
       <button data-name="login" data-box="0,780,390,64">Log In to an Existing Account</button>
     </div><main></main>`,
    FEED
  );
  check("nor the button at the foot of it", paddedIn(button), "panel");

  /* A sheet is as often built the other way about, with the box that is pinned
   * to the edge outside the element that says it is modal. Then the panel is a
   * step or two up rather than down, and a search that only ever descends finds
   * nothing at all. */
  /* The shape the photograph turned out to be, and the reason two builds went
   * past with the row still drawn over the button: a panel that is a plain box
   * inside a fixed backdrop, which is what a flex column with `margin-top:
   * auto` is. It was refused for not being positioned, no panel was found, and
   * the app fell back to standing the row down. Being positioned was never what
   * makes something a panel; it was there to keep the backdrop out, and the
   * backdrop is kept out by being as tall as the glass. */
  const unpositioned = await page(
    `<div role="dialog" data-name="backdrop" style="position: fixed" data-box="0,0,390,844">
       <div data-name="panel" data-box="0,500,390,344">
         <button data-name="login" data-box="16,780,358,44">Log In</button>
       </div>
     </div><main></main>`,
    FEED
  );
  check(
    "a panel that is not positioned at all is still the panel",
    paddedIn(unpositioned),
    "panel"
  );

  /* And the backdrop it sits in is never the one padded: it is as tall as the
   * glass, and padding it resolves its children's bottom against its own
   * padding box, which moves the sheet the wrong way. */
  check(
    "and the backdrop around it is left alone",
    unpositioned.document.querySelector('[data-name="backdrop"]').hasAttribute("data-quiet-sheet"),
    false
  );

  const inside = await page(
    `<div data-name="panel" style="position: fixed" data-box="0,400,390,444">
       <div role="dialog" data-name="dialog" data-box="0,400,390,444">
         <button data-name="login" data-box="16,780,358,44">Log In to an Existing Account</button>
       </div>
     </div><main></main>`,
    FEED
  );
  check("a dialog inside its panel finds the panel above it", paddedIn(inside), "panel");

  /* Upwards, but not as far as the document. A page padded at its foot is the
   * black band under the row that three rules in trim.css exist to take back. */
  const loose = await page(
    `<div data-name="page" style="position: absolute" data-box="0,0,390,844">
       <div role="dialog" data-name="dialog" data-box="100,400,190,444">x</div>
     </div><main></main>`,
    FEED
  );
  check("a dialog with no panel of its own pads nothing", paddedIn(loose), null);

  /* A sheet slides up. Arriving is a change to the document and is seen; the
   * travelling is a transition, which changes nothing in the document and is
   * seen by nothing. Measured on the frame it appeared, a sheet is half a
   * screen below where it lands — so the pass looks again a few times, and a
   * box still on its way is left alone until it gets there. */
  const arriving = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,700,390,444">x</div><main></main>`,
    FEED
  );
  check("a sheet still on its way up is not padded there", paddedIn(arriving), null);
  arriving.document
    .querySelector('[data-name="panel"]')
    .setAttribute("data-box", "0,400,390,444");
  // The looks are spaced to cover an animation. Long enough for the first.
  await new Promise((go) => setTimeout(go, 120));
  arriving.drain();
  check("and is padded once it has landed", paddedIn(arriving), "panel");
  check("with the app told the once", sheetOf(arriving), {
    kind: "sheet",
    up: true,
    clear: true,
  });

  /* Finding a panel and padding it is not the same as the sheet standing clear,
   * and the difference is what let two builds go past: a padding that moved
   * nothing reported success, so the app left the row answering taps and the
   * button stayed underneath it. The question is now asked of the one thing
   * that matters — is there a control on this sheet under the row — and it is
   * asked after the padding is on.
   *
   * jsdom lays nothing out, so the boxes here are what they say they are, which
   * is exactly the case being checked: a panel that was padded and did not
   * move. */
  const stillUnder = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,400,390,444">
       <button data-name="login" data-box="16,790,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("a panel is found and padded", paddedIn(stillUnder), "panel");
  check(
    "but a button still under the row is not standing clear",
    sheetOf(stillUnder).clear,
    false
  );

  /* The same sheet with its button above the row, which is what the padding
   * produces in a browser that lays out. */
  const moved = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,400,390,444">
       <button data-name="login" data-box="16,690,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("and once it is above the row, it is", sheetOf(moved).clear, true);

  /* Something scrolled out of the sheet, or below the fold of it, is not under
   * the row: only what is on the glass can be in the way. */
  const offscreen = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,400,390,444">
       <button data-name="login" data-box="16,900,358,44">Log In</button>
     </div><main></main>`,
    FEED
  );
  check("what is off the glass entirely is not in the way", sheetOf(offscreen).clear, true);

  /* A sheet that fills the glass has nowhere to be moved to. The app is told,
   * and the row stands down for that one the way it did for all of them. */
  const full = await page(
    `<div role="dialog" data-name="panel" style="position: fixed" data-box="0,0,390,844">x</div><main></main>`,
    FEED
  );
  check("one that fills the glass is left where it is", paddedIn(full), null);
  check("and the app is told the row is still in its way", sheetOf(full), {
    kind: "sheet",
    up: true,
    clear: false,
  });

  /* On a story and in a conversation the app draws no row, so there is nothing
   * for a sheet to stand clear of and nothing the padding would be. */
  const noRow = await page(
    `<div role="dialog" data-name="panel" ${PANEL}>x</div><main></main>`,
    FEED,
    undefined,
    0
  );
  check("with no row on the screen, nothing is padded", paddedIn(noRow), null);
  check("and the sheet has nothing to stand clear of", sheetOf(noRow), {
    kind: "sheet",
    up: true,
    clear: true,
  });

  /* A dialog in the tree with no box has been dismissed and not yet removed, or
   * built ahead of being needed. Neither is a sheet. */
  const notDrawn = await page(
    `<div role="dialog">nothing drawn</div><main></main>`,
    FEED
  );
  check("one that is in the tree but not drawn is not a sheet", sheetOf(notDrawn), undefined);

  /* And the room has to come off again, or the page is left padded for a sheet
   * that is no longer on it. */
  const dismissed = await page(
    `<div role="dialog" data-name="panel" ${PANEL}>x</div><main></main>`,
    FEED
  );
  dismissed.document.querySelector('[data-name="panel"]').remove();
  // The observer answers a mutation in a microtask, so the frame it asks for
  // does not exist yet on the line after the change. Let the queue run first.
  await new Promise((go) => setTimeout(go, 0));
  dismissed.drain();
  check(
    "and what was said about it comes back the other way when it goes",
    dismissed.sent.filter((m) => m.kind === "sheet").map((m) => m.up),
    [true, false]
  );

  /* The panel is chosen by being shorter than the glass, and the padding makes
   * it taller by the height of the row. Measured with the padding on, a panel
   * grows out of the test that chose it: it would be unchosen on the next frame
   * and chosen again on the one after, for as long as the sheet was open. */
  const grown = await page(
    `<div role="dialog" data-name="panel" ${PANEL}>x</div><main></main>`,
    FEED
  );
  // What the padding does to the box: the foot stays on the bottom edge of the
  // glass and the top of it comes up by the height of the row.
  grown.document
    .querySelector('[data-name="panel"]')
    .setAttribute("data-box", "0,311,390,533");
  grown.drain();
  check("the room it was given does not unchoose it", paddedIn(grown), "panel");
  check(
    "and nothing is said a second time",
    grown.sent.filter((m) => m.kind === "sheet").length,
    1
  );

  /* The observer runs on every mutation. Saying it again on every one of them
   * would animate the row on every frame the page rewrites itself. */
  const stays = await page(
    `<div role="dialog" data-name="panel" ${PANEL}>x</div><main></main>`,
    FEED
  );
  stays.document.querySelector("main").appendChild(stays.document.createElement("div"));
  stays.drain();
  check(
    "a sheet that is still there is not announced twice",
    stays.sent.filter((m) => m.kind === "sheet").length,
    1
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
