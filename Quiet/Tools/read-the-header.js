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

const { page, scoreboard } = require("./page");

const { check, done } = scoreboard("The header");

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

  /* WebKit draws a focus ring around whatever is focused, and a click made by a
   * script reads to it as a keyboard press rather than a finger — so pressing
   * home from Quiet's row left the Instagram wordmark in a blue rectangle, and
   * the next thing a finger touched got one too. The row is the app's own
   * furniture; pressing it is a navigation, not a decision about where the
   * cursor goes. */
  const pressed = await rowPage();
  const home = pressed.document.querySelector('a[href="/"]');
  home.focus();
  pressed.__quietGo("messages");
  check(
    "a press lets go of the focus rather than leaving a ring behind",
    pressed.document.activeElement === home,
    false
  );

  /* And never takes the keyboard off somebody mid-word. */
  const typing = await page(
    `${BOTTOM}<input data-name="field">`,
    FEED
  );
  const field = typing.document.querySelector('[data-name="field"]');
  field.focus();
  typing.__quietGo("messages");
  check(
    "but it never takes the keyboard away from something being typed in",
    typing.document.activeElement === field,
    true
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

  /* ── The other account ───────────────────────────────────────────────── */

  /* Two taps on the profile entry open Instagram's own account switcher, and
   * the whole of the app's part in that is pressing a button on their page.
   * Which button is asked of the page by name rather than by place: the one
   * control on your own profile that says who you are. */
  const MINE = (header) => `
    <div data-name="nav">
      <a href="/">home</a>
      <a href="/direct/inbox/">messages</a>
      <a href="/marco/"><img src="face.jpg"></a>
    </div>
    <main><header>${header}</header></main>`;

  const MY_PROFILE = "https://www.instagram.com/marco/";

  /** The page, and how many times the switcher was pressed. */
  const askToSwitch = async (html, url) => {
    const win = await page(MINE(html), url || MY_PROFILE);
    let presses = 0;
    const control = win.document.querySelector('[data-name="switcher"]');
    if (control) control.addEventListener("click", () => { presses += 1; });
    const answer = win.__quietSwitchAccounts();
    return { answer, presses };
  };

  check(
    "your own name, on your own profile, is the way to the other account",
    await askToSwitch(
      `<div role="button" data-name="switcher" data-box="16,60,120,24">marco</div>`
    ),
    { answer: true, presses: 1 }
  );

  /* Your name is a link in half a dozen places on a profile and every one of
   * them is a navigation. The switcher is a button, because it opens a sheet
   * rather than going anywhere. */
  check(
    "a name inside a link is a navigation, not the switcher",
    await askToSwitch(
      `<a href="/marco/"><span role="button" data-name="switcher"
          data-box="16,60,120,24">marco</span></a>`
    ),
    { answer: false, presses: 0 }
  );

  /* Somebody else's page carries their name rather than yours, so the address
   * can only fail closed — and it does the failing rather than the button
   * hunt, because the app would rather press nothing at all than press
   * something it cannot name on a page it did not mean to be on. */
  check(
    "and nothing is pressed on a page that is not your own profile",
    await askToSwitch(
      `<div role="button" data-name="switcher" data-box="16,60,120,24">marco</div>`,
      "https://www.instagram.com/someone/"
    ),
    { answer: false, presses: 0 }
  );

  /* A header Instagram has rewritten, with nothing in it the app can name.
   * Declining is the answer: the app asks again for a moment, and a press it
   * cannot make is a sheet that does not open rather than a wrong one. */
  check(
    "a header with no such button declines rather than guessing",
    await askToSwitch(
      `<div role="button" data-name="other" data-box="16,60,120,24">Follow</div>`
    ),
    { answer: false, presses: 0 }
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

  /* ── Something modal, and nothing done about it ──────────────────────── */

  /* Instagram puts a sheet up for switching accounts, for sharing, and for the
   * menu behind the three dots, and Quiet's row is drawn straight across the
   * buttons on it. Eleven answers to that were written and every one of them
   * moved something of Instagram's — which meant every one had to recognise the
   * thing it was moving first, and that is the half that failed. It missed the
   * account switcher for eight rounds, because Instagram never says a sheet is
   * one; then it caught the inbox's list of conversations, because a list of
   * conversations has exactly the shape of a sheet, and moved that instead.
   *
   * So the moving is gone and only the question is left. The page says whether
   * something modal is covering the foot of the glass; the app fades its own
   * row out while it is. Nothing of Instagram's is marked, moved, padded or
   * hidden — which is what makes recognising a sheet affordable again. A wrong
   * answer costs a row that fades for a moment, not a page that comes back
   * broken.
   *
   * These check both halves: that the answer is right, and that nothing was
   * touched to arrive at it. */
  const sheetOf = (win) => win.sent.filter((m) => m.kind === "sheet").pop();
  const marks = (win, name) => {
    const node = win.document.querySelector(`[data-name="${name}"]`);
    return [
      node.getAttribute("data-quiet-sheet"),
      node.getAttribute("data-quiet-hidden"),
      node.style.transform || "",
      node.style.marginBottom || "",
      node.style.paddingBottom || ""
    ].join("|");
  };

  const PANEL = '<h2>Switch accounts</h2>' +
    '<button data-name="one">marco</button>' +
    '<button data-name="two">Log In to an Existing Account</button>';

  /* With nothing modal on screen, nothing is said. */
  const plainFeed = await page(`<main><article>a post</article></main>`, FEED);
  check("with nothing modal on screen, nothing is said", sheetOf(plainFeed), undefined);

  /* The account switcher: held against the bottom, the width of the glass,
   * full of things to press, and saying nothing anywhere about being modal.
   * This is the one that went unfound for eight rounds. */
  const switcher = await page(
    `<div data-name="switcher" data-at-bottom style="position: fixed"
          data-box="0,300,390,520">${PANEL}</div><main></main>`,
    FEED
  );
  check("a sheet that never said it was one is found by its shape", sheetOf(switcher), {
    kind: "sheet",
    up: true
  });
  check("and nothing on it is marked or moved", marks(switcher, "switcher"), "||||");

  /* Said outright, which Instagram is under no obligation to do. */
  const declared = await page(
    `<div data-name="declared" role="dialog" data-at-bottom style="position: fixed"
          data-box="0,300,390,520">${PANEL}</div><main></main>`,
    FEED
  );
  check("one that says it is one is believed", sheetOf(declared)?.up, true);

  /* The inbox, which is the photograph that started this: a list of
   * conversations reaches the bottom of the screen, spans the glass and is full
   * of things to press. Every test a sheet passes, it passes — except being in
   * front of the page. */
  const conversations = await page(
    `<main><div data-name="threads" data-at-bottom data-box="0,120,390,700">
       <a href="/direct/t/1/">marco</a>
       <a href="/direct/t/2/">anna</a>
     </div></main>`,
    "https://www.instagram.com/direct/inbox/"
  );
  check(
    "the inbox, which was moved for eleven builds, is not a sheet",
    sheetOf(conversations),
    undefined
  );
  check("and it is left entirely alone", marks(conversations, "threads"), "||||");

  /* The one that does not depend on Instagram's markup at all.
   *
   * A photograph of the real switcher came back with the pill still drawn
   * across it, so the shape test did not find it — and the honest reading is
   * that it never will reliably, because it turns on where the panel sits in
   * somebody else's tree. What is not theirs to change is what a modal *is*:
   * every one of them stops the page behind it from scrolling. */
  const locked = await page(
    `<main><article>a post</article></main>`,
    FEED,
    "<style>body { overflow: hidden }</style>"
  );
  check("a page that cannot scroll has something modal on it", sheetOf(locked)?.up, true);

  const pinned = await page(
    `<main><article>a post</article></main>`,
    FEED,
    "<style>body { position: fixed }</style>"
  );
  check("and so does one whose body has been pinned", sheetOf(pinned)?.up, true);

  /* Which cannot catch the inbox, and that is the whole point of choosing it:
   * a list of conversations scrolls, and a page that scrolls is not locked. */
  const scrollingInbox = await page(
    `<main><div data-name="threads" data-at-bottom data-box="0,120,390,700">
       <a href="/direct/t/1/">marco</a>
     </div></main>`,
    "https://www.instagram.com/direct/inbox/"
  );
  check("a page that still scrolls has not", sheetOf(scrollingInbox), undefined);

  /* A backdrop is as tall as the glass. The sheet is the thing inside it. */
  const backdrop = await page(
    `<div data-name="backdrop" data-at-bottom style="position: fixed"
          data-box="0,0,390,844"><button>x</button></div><main></main>`,
    FEED
  );
  check("the dimmed backdrop is not the sheet", sheetOf(backdrop), undefined);

  /* Something tucked into a corner is a menu or a toast, not a sheet. */
  const corner = await page(
    `<div data-name="corner" data-at-bottom style="position: fixed"
          data-box="200,500,180,300"><button>x</button></div><main></main>`,
    FEED
  );
  check("something that does not span the glass is not a sheet", sheetOf(corner), undefined);

  /* Instagram's own navigation row is full width and at the foot of the glass,
   * and it is taken out before the question is asked. */
  const ownRow = await page(
    `<div data-name="theirs" data-quiet-hidden="nav" data-at-bottom
          style="position: fixed" data-box="0,300,390,520"><a href="/">home</a></div>
     <main></main>`,
    FEED
  );
  check("what Quiet has already taken out is not a sheet", sheetOf(ownRow), undefined);

  /* And the fourth question, asked in the middle of the glass rather than at
   * the foot of it: is the page still the thing on the screen?
   *
   * The switcher can slip the other three — it says nothing about being modal,
   * its panel sits where Instagram chooses to put it, and whether the page
   * behind it is pinned is Instagram's business. What no sheet on the mobile
   * web skips is the dimmed sheet of nothing behind it, because that is what a
   * tap outside lands on. */
  const scrim = await page(
    `<main><article>a post</article></main>
     <div data-name="scrim" data-at-top style="position: fixed" data-box="0,0,390,844">
       <div data-name="panel" data-box="0,540,390,304">${PANEL}</div>
     </div>`,
    FEED
  );
  check("something drawn over the whole page is a sheet", sheetOf(scrim)?.up, true);
  check("and nothing of it is marked or moved either", marks(scrim, "panel"), "||||");

  /* The page showing through is the page, however big the thing at that point
   * happens to be. */
  const showing = await page(
    `<main><article data-name="post" data-at-top data-box="0,0,390,844">a post</article></main>`,
    FEED
  );
  check("the page itself is not something over the page", sheetOf(showing), undefined);

  /* The shell Instagram draws everything in is as big as the glass and is
   * often positioned. It holds the page rather than covering it. */
  const holding = await page(
    `<div data-name="shell" data-at-top style="position: fixed" data-box="0,0,390,844">
       <main><article>a post</article></main>
     </div>`,
    FEED
  );
  check("nor is the shell the page is drawn in", sheetOf(holding), undefined);

  /* A toast, a cookie bar, a tooltip: over the page and nowhere near all of
   * it. */
  const toast = await page(
    `<div data-name="toast" data-at-top style="position: fixed" data-box="20,60,350,80">
       <button>Undo</button>
     </div><main></main>`,
    FEED
  );
  check("something over part of it is not", sheetOf(toast), undefined);

  /* And a wrapper the size of the glass that is laid out rather than drawn on
   * top — which is what a page whose content lives outside `main` looks like,
   * and the one shape this could have taken the row away from for good. */
  const outside = await page(
    `<div data-name="elsewhere" data-at-top data-box="0,0,390,844">
       <article>a post</article>
     </div><main></main>`,
    FEED
  );
  check("and neither is a page that simply fills the glass", sheetOf(outside), undefined);

  /* ── Two speeds ──────────────────────────────────────────────────────── */

  /* Instagram's feed is a virtualised list: it rewrites the document
   * continuously while a thumb is moving, and every one of those rewrites used
   * to run the whole pass inside an animation frame — several calls of which
   * read computed styles and boxes, which forces layout. That is a stutter with
   * a cause.
   *
   * So the pass has two speeds, and the line between them is what these check:
   * anything whose job is that something never appears stays immediate, and
   * everything else waits for the hand to come off the glass. */
  const rest = (ms) => new Promise((done) => setTimeout(done, ms));

  /* Wait for the pass to have happened rather than for a number of
   * milliseconds to have gone by.
   *
   * The checks below used a flat 260 against a settle of 140, which is nearly
   * twice the room needed and was still red one run in five: several of these
   * fixtures are alive at once, each with its own chain of timers, and a
   * `setTimeout` under that is a request rather than a promise. A check that
   * goes red at random teaches everybody to ignore red, which is worse than
   * not having it.
   *
   * The assertion is unchanged — this only stops it being an assertion about
   * *when*. */
  const until = async (holds, ms = 2000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline && !holds()) await rest(20);
    return holds();
  };

  const hiddenIn = (win, name) =>
    win.document.querySelector(`[data-name="${name}"]`).getAttribute("data-quiet-hidden");

  const flick = await page(`<main></main>`, FEED);
  flick.dispatchEvent(new flick.Event("scroll"));

  /* A suggestion block arriving mid-flick. Two frames of a reel is two frames
   * of a reel, so this one cannot wait. */
  const suggested = flick.document.createElement("div");
  suggested.setAttribute("data-name", "block");
  suggested.innerHTML = "<h2>Suggested for you</h2><a href=\"/someone/\">someone</a>";
  flick.document.querySelector("main").appendChild(suggested);
  /* A turn of the loop first: jsdom hands mutation records to the observer as a
   * microtask, so the pass has not been asked for yet on the line above. */
  await rest(0);
  flick.drain();
  check(
    "what must never appear is still taken out mid-flick",
    flick.document.querySelector('[data-name="block"]').getAttribute("data-quiet-hidden"),
    "suggestion"
  );

  /* And the rest waits rather than being lost. */
  const waiting = await page(`<main></main>`, FEED);
  waiting.dispatchEvent(new waiting.Event("scroll"));
  const late = waiting.document.createElement("div");
  late.setAttribute("data-at-bottom", "");
  late.setAttribute("style", "position: fixed");
  late.setAttribute("data-box", "0,300,390,520");
  late.innerHTML = "<h2>Switch accounts</h2><button>marco</button>";
  waiting.document.body.appendChild(late);
  await rest(0);
  waiting.drain();
  check("the sheet question is not asked mid-flick", sheetOf(waiting), undefined);

  await until(() => sheetOf(waiting)?.up === true);
  check("and is asked once the hand comes off the glass", sheetOf(waiting)?.up, true);

  /* Only what the page just added, rather than the whole feed. The observer is
   * handed the exact list of what changed; sweeping every span in the feed
   * sixty times a second to find it again was the largest cost in the frame.
   * A block nested inside an arrival still has to be found. */
  const nested = await page(`<main></main>`, FEED);
  nested.dispatchEvent(new nested.Event("scroll"));
  const buried = nested.document.createElement("div");
  buried.innerHTML =
    '<div><div data-name="deep"><h2>Suggested for you</h2></div></div>';
  nested.document.querySelector("main").appendChild(buried);
  await rest(0);
  nested.drain();
  check(
    "a block buried inside what arrived is found too",
    nested.document.querySelector('[data-name="deep"]').getAttribute("data-quiet-hidden"),
    "suggestion"
  );

  /* ── Nothing moves under a thumb ─────────────────────────────────────── */

  /* WebKit anchors a scroll to nothing. Take a block out above the top of the
   * glass and everything below slides up by exactly its height — under the
   * thumb, in the middle of a flick, which is the feed jumping.
   *
   * Nothing up there can be seen, so it waits; and when the hand comes off it
   * is taken out and the scroll is moved by what the page lost, in the same
   * frame, so that nothing moves on screen at all. */
  const above = await page(`<main></main>`, FEED);
  above.dispatchEvent(new above.Event("scroll"));
  const passed = above.document.createElement("div");
  passed.setAttribute("data-name", "passed");
  passed.setAttribute("data-box", "0,-300,390,200");
  passed.innerHTML = "<h2>Suggested for you</h2>";
  above.document.querySelector("main").appendChild(passed);
  await rest(0);
  above.drain();
  check(
    "a block above the glass is left alone while the page is moving",
    above.document.querySelector('[data-name="passed"]').getAttribute("data-quiet-hidden"),
    null
  );
  check("and nothing has been scrolled", above.scrolledBy, []);

  await until(() => hiddenIn(above, "passed") === "suggestion");
  check("once the hand is off the glass it goes", hiddenIn(above, "passed"), "suggestion");
  check("and the page is moved by exactly what it lost", above.scrolledBy, [-200]);

  /* And the case the phone actually reported: an advertisement, half of it
   * above the top of the glass. Instagram's list unmounts and mounts these
   * while a thumb is moving, so this happens over and over — and every time it
   * did, the page slid by the part that was above the fold. */
  const half = await page(`<main></main>`, FEED);
  half.dispatchEvent(new half.Event("scroll"));
  const straddling = half.document.createElement("div");
  straddling.setAttribute("data-name", "straddling");
  straddling.setAttribute("data-box", "0,-80,390,300");
  straddling.innerHTML = "<h2>Suggested for you</h2>";
  half.document.querySelector("main").appendChild(straddling);
  await rest(0);
  half.drain();
  check(
    "one straddling the top of the glass waits too",
    half.document.querySelector('[data-name="straddling"]').getAttribute("data-quiet-hidden"),
    null
  );
  await until(() => hiddenIn(half, "straddling") === "suggestion");
  check("and then goes", hiddenIn(half, "straddling"), "suggestion");
  check("paid for by the part that was above the fold, and no more",
        half.scrolledBy, [-80]);

  /* ── Never a hole where the feed was ─────────────────────────────────── */

  /* `closest` climbs as far as the document, so a `<section>` wrapping half of
   * somebody's afternoon is exactly as easy to reach as the post the heading
   * belongs to. One span reading "Reels" inside one of those took the rest of
   * the feed with it — which is the black nothing that comes back when you
   * scroll far enough down. */
  const huge = await page(
    `<main><section data-name="lots" data-box="0,100,390,1400">
       <h2>Suggested for you</h2>
     </section></main>`,
    FEED
  );
  check(
    "a block taller than the glass and a half is not a suggestion block",
    huge.document.querySelector('[data-name="lots"]').getAttribute("data-quiet-hidden"),
    null
  );

  const withPosts = await page(
    `<main><section data-name="around" data-box="0,100,390,600">
       <h2>Suggested for you</h2>
       <article>somebody's photograph</article>
     </section></main>`,
    FEED
  );
  check(
    "and neither is one with a post inside it",
    withPosts.document.querySelector('[data-name="around"]').getAttribute("data-quiet-hidden"),
    null
  );

  /* The card itself still goes, which is the whole point of the pass. */
  const card = await page(
    `<main><div data-name="card" data-box="0,100,390,420">
       <h2>Suggested for you</h2>
     </div></main>`,
    FEED
  );
  check(
    "a block the size of a card still does",
    card.document.querySelector('[data-name="card"]').getAttribute("data-quiet-hidden"),
    "suggestion"
  );

  /* ── The door stops at a post too ────────────────────────────────────── */

  /* An advertisement is a post whose button goes to the App Store. Taking that
   * button out takes a piece of the post out — and Instagram mounts and
   * unmounts that post while a thumb is moving, which is a feed going up and
   * down. The tap is still refused; that is `ContentRules`, and it does not
   * care what was drawn. */
  const insideAPost = await page(
    `<main><article data-box="0,0,390,600">
       <img data-box="0,0,390,400">
       <a data-name="cta" href="https://apps.apple.com/app/id1" data-box="0,420,390,44">
         Install
       </a>
     </article></main>`,
    FEED
  );
  check("a door inside somebody's post is left where it is",
        hiddenIn(insideAPost, "cta"), null);

  /* And outside one it goes, exactly as before. */
  const loose = await page(
    `<main></main>
     <a data-name="cta" href="https://apps.apple.com/app/id1"
        data-box="0,700,390,44">Get the app</a>`,
    FEED
  );
  check("and one that is not in a post still goes",
        hiddenIn(loose, "cta"), "upsell");

  /* ── Where the feed ends ─────────────────────────────────────────────── */

  /* Instagram's feed does not end: after the people you follow it goes on with
   * people you did not choose, and Quiet takes every one of those out. What was
   * left was a black nothing you could scroll through for ever — "no feed any
   * more, just black", which is the app working exactly as designed with no
   * place to stop. */
  const theEndMark = (win) => win.document.getElementById("quiet-end");

  const endedFeed = await page(
    `<main><div>
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="tail" data-box="0,600,390,500"></div>
     </div></main>`,
    FEED
  );
  check("half a screen below the last post with nothing in it is the end",
        theEndMark(endedFeed) !== null, true);
  check("and that half screen is left exactly where it is",
        hiddenIn(endedFeed, "tail"), null);
  check("and Quiet says so, in the app's words",
        theEndMark(endedFeed)?.firstChild.textContent,
        "That's everyone you follow.");

  /* The shape a person actually reported, and the one the first version of
   * this could not see: nothing black, the feed simply stops. What is under
   * the last post has been taken out, and something taken out has no height at
   * all — so there is no void to measure. The evidence is not a height. It is
   * that Instagram answered and Quiet emptied the answer. */
  const stopped = await page(
    `<main><div>
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="theirs" data-box="0,600,390,0">
         <h2>Suggested for you</h2>
       </div>
       <div data-name="andTheirs" data-box="0,600,390,0">
         <h2>Suggested posts</h2>
       </div>
     </div></main>`,
    FEED
  );
  check("a suggestion taken out is the whole of the evidence",
        hiddenIn(stopped, "theirs"), "suggestion");
  check("so the feed that simply stops is an end too",
        theEndMark(stopped)?.firstChild.textContent,
        "That's everyone you follow.");

  /* One is not enough to say it. A suggestion between two posts looks exactly
   * the same while more are still on their way, and a line reading "that is
   * everyone you follow" over somebody's photographs is the app lying about
   * the one thing it exists to be right about. */
  const justOne = await page(
    `<main><div>
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="theirs" data-box="0,600,390,0">
         <h2>Suggested for you</h2>
       </div>
     </div></main>`,
    FEED
  );
  check("one of theirs is not the end", theEndMark(justOne), null);

  /* Two in a row, with nothing of anybody's between them, is the section
   * Instagram fills the rest of the day with. That is when it is said — and
   * *only* said. */
  const twoOfTheirs = await page(
    `<main><div><div data-name="list" style="padding-bottom: 40px" data-box="0,0,390,900">
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="one" data-box="0,600,390,0"><h2>Suggested for you</h2></div>
       <div data-name="two" data-box="0,600,390,0"><h2>Suggested posts</h2></div>
       <div data-name="asks" data-box="0,600,390,4"></div>
       <div data-name="air" data-box="0,604,390,240"></div>
     </div></div></main>`,
    FEED
  );
  check("two of theirs in a row is", theEndMark(twoOfTheirs) !== null, true);

  /* And nothing below it is touched. A version of this took the tail away as
   * well, and the photograph that came back had a spinner still turning under
   * the sentence and a page that could no longer be scrolled: Instagram was
   * not finished, and the app had shut the door on it. */
  check("and what asks for more is left where it is",
        hiddenIn(twoOfTheirs, "asks"), null);
  check("and so is the air below", hiddenIn(twoOfTheirs, "air"), null);
  check("and the list keeps its own floor",
        twoOfTheirs.document
          .querySelector('[data-name="list"]').hasAttribute("data-quiet-floor"),
        false);

  /* And the line follows the last post rather than being said and left behind.
   * A feed that has run out can be answered a minute later, and a line reading
   * "that is everyone you follow" with two of their photographs under it would
   * be the app lying about the one thing it is here to be right about. */
  const answered = await page(
    `<main><div data-name="list">
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="theirs" data-box="0,600,390,0">
         <h2>Suggested for you</h2>
       </div>
       <div data-name="andTheirs" data-box="0,600,390,0">
         <h2>Suggested posts</h2>
       </div>
     </div></main>`,
    FEED
  );
  const fresh = answered.document.createElement("article");
  fresh.setAttribute("data-name", "fresh");
  fresh.setAttribute("data-box", "0,700,390,600");
  fresh.innerHTML = '<img data-box="0,700,390,400">';
  answered.document.querySelector('[data-name="list"]').appendChild(fresh);
  await rest(0);
  answered.drain();
  await until(() =>
    theEndMark(answered)?.previousElementSibling?.getAttribute("data-name") === "fresh");
  check("a post arriving after the end moves the end below it",
        theEndMark(answered)?.previousElementSibling?.getAttribute("data-name"),
        "fresh");

  /* A feed that is still arriving has a spinner in it, and a spinner is
   * something. This is the check that keeps the end of the feed from being
   * declared in the middle of it. */
  const stillLoading = await page(
    `<main><div>
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="tail" data-box="0,600,390,500">
         <svg data-box="170,780,40,40"></svg>
       </div>
     </div></main>`,
    FEED
  );
  check("a spinner below the last post is not the end",
        hiddenIn(stillLoading, "tail"), null);
  check("and nothing is said", theEndMark(stillLoading), null);

  /* Said once. The pass runs on every rewrite of the document, and a sentence
   * that arrived on each of them would be a wall of them. */
  const saidOnce = await page(
    `<main><div>
       <article data-box="0,0,390,600"><img data-box="0,0,390,400"></article>
       <div data-name="tail" data-box="0,600,390,500"></div>
     </div></main>`,
    FEED
  );
  saidOnce.document.querySelector("main").appendChild(saidOnce.document.createElement("p"));
  await rest(0);
  saidOnce.drain();
  await until(() => saidOnce.document.querySelectorAll("#quiet-end").length > 0);
  check("and said once, however many times the page is rewritten",
        saidOnce.document.querySelectorAll("#quiet-end").length, 1);

  /* And never on a page with no posts on it, which is every page that is not
   * the feed and the feed itself while it is still empty. */
  const noPostsYet = await page(`<main><div data-box="0,0,390,900"></div></main>`, FEED);
  check("a page with no posts on it has no end to announce", theEndMark(noPostsYet), null);

  /* ── The door, out of the frame path ─────────────────────────────────── */

  /* `takeDownTheStrip` asks the browser what is drawn at twelve points on the
   * glass, and each of those is a hit test that forces a layout. Twelve, sixty
   * times a second, for as long as anybody is scrolling. Two nets hold under
   * it from the first paint — the stylesheet and the URL rules — so it can
   * wait for the hand to come off. */
  const door = await page(`<main></main>`, FEED);
  door.dispatchEvent(new door.Event("scroll"));
  const bar = door.document.createElement("div");
  bar.setAttribute("data-name", "bar");
  bar.setAttribute("data-at-bottom", "");
  bar.setAttribute("style", "position: fixed");
  bar.setAttribute("data-box", "0,760,390,60");
  bar.innerHTML = "<button>Open</button>";
  door.document.body.appendChild(bar);
  await rest(0);
  door.drain();
  check(
    "the strip is not hunted for mid-flick",
    door.document.querySelector('[data-name="bar"]').getAttribute("data-quiet-hidden"),
    null
  );
  await until(() => hiddenIn(door, "bar") === "upsell");
  check("and is taken down once the hand comes off the glass", hiddenIn(door, "bar"), "upsell");

  /* A block in front of somebody is taken out at once and paid for by nobody:
   * removing it moves what is *below* it, which is not what they are reading. */
  const ahead = await page(`<main></main>`, FEED);
  ahead.dispatchEvent(new ahead.Event("scroll"));
  const coming = ahead.document.createElement("div");
  coming.setAttribute("data-name", "coming");
  coming.setAttribute("data-box", "0,600,390,200");
  coming.innerHTML = "<h2>Suggested for you</h2>";
  ahead.document.querySelector("main").appendChild(coming);
  await rest(0);
  ahead.drain();
  check(
    "one still on its way up is taken out mid-flick",
    ahead.document.querySelector('[data-name="coming"]').getAttribute("data-quiet-hidden"),
    "suggestion"
  );
  check("and the scroll is left alone", ahead.scrolledBy, []);

  /* ── Somebody mid-sentence ───────────────────────────────────────────── */

  /* The app is meant to be strict and not rude. Taking half a message away when
   * the day ends is rude, so the curtain waits twenty seconds — once. What the
   * app does with this is capped in `QuietSession`; the page's only job is to
   * say when a message is being typed, and a keyboard is not a fact the app can
   * see for itself. */
  const typingOf = (win) => win.sent.filter((m) => m.kind === "typing").pop();

  const midSentence = await page(
    `<main><textarea data-name="box"></textarea></main>`,
    "https://www.instagram.com/direct/t/1/"
  );
  check("nothing is said until somebody types", typingOf(midSentence), undefined);

  midSentence.document.querySelector('[data-name="box"]').dispatchEvent(
    new midSentence.Event("focusin", { bubbles: true })
  );
  check("a field taking the keyboard says so", typingOf(midSentence)?.on, true);

  /* An ordinary button taking the focus is not somebody typing. */
  const tapped = await page(
    `<main><button data-name="like">Like</button></main>`,
    FEED
  );
  tapped.document.querySelector('[data-name="like"]').dispatchEvent(
    new tapped.Event("focusin", { bubbles: true })
  );
  check("a button taking the focus is not", typingOf(tapped), undefined);

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

  /* ── Whether there is anything on the page at all ────────────────────── */

  /* `hasLoaded` answers a question about a request, and Instagram is a shell:
   * the request finishes, and what is on the glass for the next second or two
   * is a black rectangle with nothing in it. The app keeps its own cover over
   * that, and this is what tells it when to take the cover off. */
  const bareOf = (win) => win.sent.filter((m) => m.kind === "bare").pop();

  const bareShell = await page(`<main></main>`, FEED);
  check("a page with nothing drawn on it says so", bareOf(bareShell)?.on, true);

  const painting = await page(
    `<main><img data-name="photo" data-box="0,100,390,390"></main>`,
    FEED
  );
  check("and one with a photograph on it says the opposite", bareOf(painting)?.on, false);

  /* An element in the document that nobody can see is not a page. This is the
   * case that matters: Instagram's own row is hidden rather than removed, so
   * its five glyphs are still there on a page that has painted nothing else. */
  const hiddenRow = await page(
    `<nav data-name="row" data-box="0,800,390,44">
       <a href="/" data-name="home"><svg data-box="0,800,24,24"></svg></a>
       <a href="/direct/inbox/" data-name="messages"><svg data-box="40,800,24,24"></svg></a>
       <a href="/someone/" data-name="me"><svg data-box="80,800,24,24"></svg></a>
     </nav>
     <main></main>`,
    FEED
  );
  check("the row Quiet has taken away does not count as a page", bareOf(hiddenRow)?.on, true);

  /* And an element with no box at all, whoever hid it. */
  const invisible = await page(`<main><p data-name="nothing"></p></main>`, FEED);
  check("nor does anything else with no box", bareOf(invisible)?.on, true);

  /* Said once, and only on the way up. Instagram empties its own main element
   * on every client-side move between pages, and a cover that answered that
   * would flash over the screen every time somebody opened a profile. */
  const emptiedAgain = await page(
    `<main><img data-name="photo" data-box="0,100,390,390"></main>`,
    FEED
  );
  emptiedAgain.document.querySelector("main").innerHTML = "";
  emptiedAgain.drain();
  check(
    "a page that empties itself after painting does not bring the cover back",
    emptiedAgain.sent.filter((m) => m.kind === "bare").map((m) => m.on),
    [false]
  );

  /* The observer runs on every mutation, and an answer that has not changed
   * must not be sent again. */
  const stillEmpty = await page(`<main></main>`, FEED);
  stillEmpty.document.querySelector("main").appendChild(
    stillEmpty.document.createElement("div")
  );
  stillEmpty.drain();
  check(
    "and the same answer is not said twice",
    stillEmpty.sent.filter((m) => m.kind === "bare").length,
    1
  );

  /* ── A header that gets out of the way ───────────────────────────────── */

  /* jsdom lays nothing out and scrolls nothing, so the page is scrolled by
   * saying where it is and telling it so — which is exactly what a browser
   * does, and is all the listener reads. */
  const awayOf = (win) => win.document.documentElement.hasAttribute("data-quiet-away");

  const scrollTo = (win, y) => {
    Object.defineProperty(win, "scrollY", { value: y, configurable: true });
    win.dispatchEvent(new win.Event("scroll"));
    return awayOf(win);
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

  /* And nor is eight points, which is what it used to take. The header slid
   * out over a fifth of a second on the first eight points of any downward
   * movement, slid back on the next eight up, and did it again while somebody
   * was reading. Going away now asks for forty points in one direction; the
   * nudges add up, and a change of direction starts the tally again. */
  const calm = await page(GROUPED, FEED);
  scrollTo(calm, 300);
  scrollTo(calm, 280);
  check("a nudge back up brings it straight back", awayOf(calm), false);
  check("three small nudges down are not a decision", [
    scrollTo(calm, 292), scrollTo(calm, 304), scrollTo(calm, 316),
  ], [false, false, false]);
  check("the fourth is", scrollTo(calm, 328), true);

  /* Which only holds because the tally is a direction rather than a total: a
   * page wobbling under a thumb never accumulates forty of anything. */
  const wobble = await page(GROUPED, FEED);
  scrollTo(wobble, 300);
  scrollTo(wobble, 280);
  check("a page wobbling under a thumb sends nothing away", [
    scrollTo(wobble, 300), scrollTo(wobble, 280),
    scrollTo(wobble, 300), scrollTo(wobble, 280),
  ], [false, false, false, false]);

  /* Every other page's top bar is that page's own: the name on a profile, the
   * search in the inbox, the back arrow in a conversation. A back arrow that
   * slides away while you read is one you go hunting for. */
  const elsewhere = await page(GROUPED, "https://www.instagram.com/marco/");
  check(
    "on a page that is not the feed it stays where it is",
    scrollTo(elsewhere, 500),
    false
  );

  done();
})();
