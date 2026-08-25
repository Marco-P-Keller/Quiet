/*
 * Quiet's trim pass.
 *
 * Runs at document start on every Instagram page. Five jobs, in order of how
 * much they matter:
 *
 *   1. Refuse taps that would open Reels or Explore, and tell the app so it can
 *      say why. Silence would read as a broken page.
 *   2. Hide suggestion blocks, which carry no address of their own and can only
 *      be recognised by their wording.
 *   3. Take out Instagram's navigation bar, having first read the signed-in
 *      name out of it, because Quiet carries all five entries in a row of its
 *      own that no stylesheet of Instagram's can reach.
 *   4. Name the three controls in the header on the feed — the wordmark, the
 *      plus and the heart — so that the order they are laid out in is
 *      guaranteed rather than inherited. Which is the order the site already
 *      uses, and the order the app uses: the wordmark on the left, the two
 *      icons together on the right. Nothing is moved.
 *   5. Keep all of it up as the page rewrites itself, because Instagram's web
 *      client replaces the feed without ever loading a new page.
 *
 * It never reads form fields, and never touches the login page's inputs. Your
 * password is between you and Instagram; this file has no business near it.
 */

(function () {
  "use strict";

  if (window.__quietTrimInstalled) return;
  window.__quietTrimInstalled = true;

  /** Path roots Quiet does not open. Mirrors ContentRules.blockedRoots. */
  var BLOCKED = /^\/(reels?|explore|directory)(\/|$)/;
  var SUGGESTED_ACCOUNTS = /^\/accounts\/suggested(\/|$)/;

  /**
   * Headings that mark a block Instagram inserted rather than one your friends
   * posted. Matched exactly, after trimming, so that a caption which merely
   * mentions the words is left alone.
   */
  var SUGGESTION_LABELS = [
    "suggested for you",
    "suggested posts",
    "suggested accounts",
    "suggested reels",
    "suggested threads",
    "reels",
    "discover people",
    "vorgeschlagene beiträge",
    "vorschläge für dich",
    "vorgeschlagen für dich",
    "sugerencias para ti",
    "publicaciones sugeridas",
    "suggestions pour vous",
    "publications suggérées",
    "suggerimenti per te",
    "post suggeriti",
    "sugestões para você",
    "publicações sugeridas",
    "voorgesteld voor jou",
    "förslag för dig",
  ];

  var labelSet = Object.create(null);
  for (var i = 0; i < SUGGESTION_LABELS.length; i++) {
    labelSet[SUGGESTION_LABELS[i]] = true;
  }

  /** The Reels tab on a profile: /someone/reels/. */
  var PROFILE_REELS = /^\/[^/]+\/reels(\/|$)/;

  function surfaceFor(path) {
    var match = BLOCKED.exec(path);
    if (match) return match[1].indexOf("reel") === 0 ? "reels" : "explore";
    if (SUGGESTED_ACCOUNTS.test(path)) return "explore";
    if (PROFILE_REELS.test(path)) return "reels";
    return null;
  }

  function post(message) {
    try {
      window.webkit.messageHandlers.quiet.postMessage(message);
    } catch (error) {
      /* The app is not listening. Whatever we just did still happened. */
    }
  }

  function tell(surface) {
    post({ kind: "refused", surface: surface });
  }

  /* ── Instagram's own navigation ───────────────────────────────────────── */

  /**
   * The row along the bottom, found by its shape rather than by its place.
   *
   * A hidden element has no geometry, and this row is hidden the moment it is
   * found — so measuring it works exactly once and then never again, which is
   * why the profile name kept going missing. Structure survives hiding: the
   * messages link is in it, a link to "/" is in it, and it is small. The depth
   * limit is what stops the walk from reaching a container holding half the
   * page, which is the mistake two earlier versions made.
   */
  function navRow() {
    var directs = document.querySelectorAll('a[href^="/direct/"]');
    for (var i = 0; i < directs.length; i++) {
      var node = directs[i].parentElement;
      var depth = 0;
      while (node && node !== document.body && depth < 6) {
        if (node.querySelector('a[href="/"]') &&
            node.querySelectorAll("a[href]").length <= 12) {
          return node;
        }
        node = node.parentElement;
        depth += 1;
      }
    }
    return null;
  }

  var asked = false;

  /**
   * Who is signed in — asked, not deduced.
   *
   * Two versions of this read the name off a link in the page, and both got it
   * wrong: the first found the wordmark at the top of the feed, which is also a
   * link to "/", and walked up to a container holding half the document; the
   * second was right in principle and still handed somebody a stranger's
   * profile under a button marked "your profile".
   *
   * This is the request Instagram's own settings page makes, run inside
   * Instagram's page with Instagram's own cookies. It returns the signed-in
   * name and nothing else. There is nothing left to guess at.
   */
  function whoAmI() {
    if (asked || window.__quietMe) return;
    asked = true;
    fetch("/api/v1/web/accounts/edit/web_form_data/", {
      credentials: "same-origin",
      headers: { "X-IG-App-ID": window.__quietAppID || "" }
    })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (data) {
        var name = data && data.form_data && data.form_data.username;
        if (!name) return;
        window.__quietMe = name;
        var form = data.form_data || {};
        announce(name, form.profile_pic_url || form.profile_pic_url_hd || null);
      })
      .catch(function () {
        // Signed out, or the endpoint moved. The row keeps its four entries.
        asked = false;
      });
  }

  /**
   * The roots Instagram owns.
   *
   * A username is letters, digits, dots and underscores, one to thirty of them
   * — and so is "explore". Instagram's own row carries `/`, `/explore/`,
   * `/reels/`, `/direct/inbox/` and `/yourname/`, in that order, and a search
   * for the first thing shaped like a username finds `explore` every time.
   *
   * That one missing line is the whole of two bugs that took four builds to
   * corner: a button marked "your profile" that answered "Explore is off in
   * Quiet", and a signed-in name that was the word explore, which is why no
   * photograph ever arrived to go in the row.
   */
  var NOT_PEOPLE = {
    explore: true, reels: true, reel: true, direct: true, accounts: true,
    stories: true, p: true, tv: true, s: true, about: true, legal: true,
    developer: true, help: true, privacy: true, terms: true, api: true,
    challenge: true, emails: true, session: true, web: true, graphql: true
  };

  /**
   * The one link in this row that leads to a person.
   *
   * Instagram's profile entry is the one carrying a photograph, so a link with
   * an image in it is taken over one without. Failing that, the last match
   * rather than the first: the row ends with you.
   */
  function personIn(row) {
    var links = row.querySelectorAll('a[href^="/"]');
    var fallback = null;

    for (var i = 0; i < links.length; i++) {
      var link = links[i];
      var match = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(link.getAttribute("href") || "");
      if (!match || NOT_PEOPLE[match[1].toLowerCase()]) continue;
      if (link.querySelector("img")) return link;
      fallback = link;
    }
    return fallback;
  }

  /**
   * The name off the navigation bar, kept only as a second chance for the day
   * the request above stops answering.
   */
  function learnMe(row) {
    // Only ever from inside the bar. A profile link in the feed belongs to
    // whoever posted, and sending somebody to a stranger's profile under a
    // button marked "your profile" is worse than having no button.
    var link = personIn(row);
    if (!link) return;

    var name = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(link.getAttribute("href"))[1];
    if (window.__quietMe === name) return;
    window.__quietMe = name;

    var picture = link.querySelector("img");
    announce(name, picture ? picture.getAttribute("src") : null);
  }

  /**
   * Tell the app who is signed in, with their face if it can be had.
   *
   * Instagram's own row ends in a photograph rather than an outline of a
   * person, and so does Quiet's. The bytes are fetched by the page, as
   * everything else here is, so the app still asks nobody for anything.
   */
  function announce(username, source) {
    if (!source) {
      post({ kind: "me", username: username });
      return;
    }
    fetch(source, { credentials: "omit" })
      .then(function (response) { return response.ok ? response.arrayBuffer() : null; })
      .then(function (buffer) {
        if (!buffer || buffer.byteLength > 300000) {
          post({ kind: "me", username: username });
          return;
        }
        var bytes = new Uint8Array(buffer);
        var binary = "";
        for (var i = 0; i < bytes.length; i++) {
          binary += String.fromCharCode(bytes[i]);
        }
        window.__quietFace = true;
        post({ kind: "me", username: username, picture: btoa(binary) });
      })
      .catch(function () {
        // A face that will not come is not a reason to lose the button.
        post({ kind: "me", username: username });
      });
  }

  /**
   * Quiet's row carries all five entries, so Instagram's is one bar too many.
   *
   * Hidden rather than removed: the name is read out of it on every page, and
   * `display: none` leaves the addresses in the document where they can still
   * be read.
   */
  function replaceNav() {
    var row = navRow();
    if (!row) return;
    if (!window.__quietMe) learnMe(row);
    // Before the row goes: what is drawn behind it still has a size, and a
    // hidden element has none.
    hideNavShell(row);
    if (row.getAttribute("data-quiet-hidden") !== "nav") {
      row.setAttribute("data-quiet-hidden", "nav");
    }
    takeUpTheFloor(row);
    faceFromRow(row);
    sendIcons(row);
  }

  /**
   * The bar Instagram draws *behind* its row, which is the black band in the
   * photograph.
   *
   * This is the thing four separate fixes went looking for in the wrong place.
   * The band was read as a gap — the page stopping short of the bottom of the
   * glass — and answered four times over: a taller frame, the floor padding
   * taken up, `html` and `body` refused their bottom padding, and finally the
   * bottom safe area zeroed at the view so that no `env()` anywhere could
   * reserve a strip. The band survived all four, which is the answer: it is not
   * a gap at all. It is an element, drawn over Instagram's own photograph, in
   * Instagram's own background colour.
   *
   * `navRow` finds the smallest container holding the five links, because that
   * is what has to be measured and read. What carries the bar's colour, its
   * border and its height is a wrapper further out — pinned to the bottom of
   * the glass, spanning it, forty or fifty points tall. Hiding the links inside
   * it empties the bar without taking the bar away.
   *
   * So the wrapper goes too. Found the way everything else here is found: by
   * asking the browser what it did, rather than by matching a class name.
   * Pinned to the bottom, short enough to be a bar rather than a page, and
   * without the feed inside it — that last one is the stop that keeps a walk up
   * the tree from reaching a container holding the whole document, which is the
   * mistake this file has made twice before.
   */
  function hideNavShell(row) {
    var node = row.parentElement;
    var depth = 0;

    while (node && node !== document.body &&
           node !== document.documentElement && depth < 6) {
      if (node.getAttribute("data-quiet-hidden") !== null) return;
      if (isBottomBar(node)) {
        node.setAttribute("data-quiet-hidden", "nav");
        return;
      }
      node = node.parentElement;
      depth += 1;
    }
  }

  /**
   * Whether this is the bar itself rather than something it happens to be in.
   *
   * Four questions, and a no to any of them leaves the element alone. It has to
   * be taken out of the flow and pinned to the bottom of the glass, because
   * that is what a bottom bar is and what a wrapper in the feed is not. It has
   * to be short: a bar is forty or fifty points and the page is nine hundred.
   * And the feed must not be inside it, which is the only question that matters
   * when the other three are answered by a container nobody meant.
   */
  function isBottomBar(node) {
    var style = window.getComputedStyle(node);
    if (style.position !== "fixed" && style.position !== "sticky") return false;

    // `auto` parses to nothing, and something merely floating in the page is
    // not pinned to the bottom of anything.
    var bottom = parseFloat(style.bottom);
    if (isNaN(bottom) || bottom > 1) return false;

    if (node.querySelector("main")) return false;

    var box = node.getBoundingClientRect();
    return box.height <= 140;
  }

  /* ── Instagram's own icons ────────────────────────────────────────────── */

  /**
   * Which entry in Instagram's row leads where.
   *
   * Asked of the address rather than of the label. `aria-label` is translated —
   * "Startseite", "Suchen", "Nachrichten" — and a Swiss phone and an American
   * one would disagree about which icon is which. An href does not change with
   * the language.
   */
  var ENTRIES = [
    { name: "home", test: function (href) { return href === "/"; } },
    { name: "search", test: function (href) { return href.indexOf("/explore") === 0; } },
    { name: "messages", test: function (href) { return href.indexOf("/direct") === 0; } }
  ];

  /** What has already been sent, so the same picture is not drawn twice. */
  var sent = {};

  /**
   * Hand the app Instagram's own icons, drawn by Instagram.
   *
   * Quiet's row stood in SF Symbols for a while, and side by side with the real
   * thing they are unmistakably somebody else's drawings: a different house, a
   * differently tilted paper plane. Redrawing Instagram's by hand would be
   * both worse and a liberty.
   *
   * These are the actual glyphs, taken out of the row the app hides, rasterised
   * by the page onto a canvas and handed over as bytes — the same channel your
   * profile picture already travels down, so the app still asks nobody for
   * anything.
   *
   * Sent with the state they are in rather than as one picture. Instagram fills
   * the entry you are standing on and outlines the rest, so a row photographed
   * on the feed gives a filled house and four outlines. Walk to the inbox and
   * the outlined house and the filled paper plane arrive. Both halves collect
   * themselves as you use the app, and whichever has not arrived falls back to
   * the symbol Quiet drew.
   */
  function sendIcons(row) {
    var here = location.pathname;

    for (var i = 0; i < ENTRIES.length; i++) {
      var entry = ENTRIES[i];
      var link = null;
      var links = row.querySelectorAll('a[href^="/"]');
      for (var j = 0; j < links.length; j++) {
        if (entry.test(links[j].getAttribute("href") || "")) { link = links[j]; break; }
      }
      if (!link) continue;

      var on = entry.test(here);
      var key = entry.name + (on ? ".on" : ".off");
      if (sent[key]) continue;

      var glyph = link.querySelector("svg");
      if (!glyph) continue;

      sent[key] = true;
      draw(glyph, key);
    }
  }

  /**
   * One SVG, rasterised.
   *
   * Through a data URL rather than through the DOM, because an image built from
   * a data URL carries no other origin with it and leaves the canvas readable.
   * Anything that goes wrong here — no canvas, a glyph that will not parse —
   * gives back the key so it can be tried again, and the row keeps the symbol
   * it already has.
   */
  function draw(glyph, key) {
    var text;
    try {
      var copy = glyph.cloneNode(true);
      copy.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      // Instagram sizes its glyphs with attributes and its stylesheet both, and
      // a stylesheet does not travel inside a data URL.
      copy.setAttribute("width", "24");
      copy.setAttribute("height", "24");
      if (!copy.getAttribute("viewBox")) copy.setAttribute("viewBox", "0 0 24 24");
      text = new XMLSerializer().serializeToString(copy);
    } catch (error) {
      sent[key] = false;
      return;
    }

    var picture = new Image();
    picture.onload = function () {
      try {
        // Ninety-six, for a glyph drawn at twenty-five points on a screen
        // with three device pixels to the point. Seventy-two was under three
        // of them and every icon in the row was very slightly soft — not
        // wrong, and not the same as Instagram's, which are vectors.
        var canvas = document.createElement("canvas");
        canvas.width = 96;
        canvas.height = 96;
        var ink = canvas.getContext("2d");
        if (!ink) { sent[key] = false; return; }
        ink.drawImage(picture, 0, 0, 96, 96);
        post({ kind: "icon", entry: key, picture: canvas.toDataURL("image/png").split(",")[1] });
      } catch (error) {
        sent[key] = false;
      }
    };
    picture.onerror = function () { sent[key] = false; };
    picture.src = "data:image/svg+xml;base64," +
      btoa(unescape(encodeURIComponent(text)));
  }

  var lastFaceTry = 0;

  /**
   * Second chance at your own face.
   *
   * The photograph comes from Instagram's settings endpoint, fetched by the
   * page — and a fetch to a content delivery network can be refused for
   * reasons that have nothing to do with being signed in, which leaves the row
   * ending in an outline of a person instead of a face. The row Quiet hides has
   * the same photograph already loaded in it.
   *
   * Tried again rather than once, because the row is rebuilt as the page moves
   * and the image may not have arrived the first time. Every five seconds at
   * most: this is a fallback, not a poll.
   */
  function faceFromRow(row) {
    if (!window.__quietMe || window.__quietFace) return;

    var now = Date.now();
    if (now - lastFaceTry < 5000) return;
    lastFaceTry = now;

    var picture = row.querySelector("img[src]");
    if (picture) announce(window.__quietMe, picture.getAttribute("src"));
  }

  /**
   * Take back the space Instagram reserved for the bar that is no longer there.
   *
   * Hiding the row with `display: none` takes the row out of the layout and
   * leaves behind whatever the page had padded *around* it — a floor of forty
   * or fifty points at the bottom of the feed, kept clear so a fixed bar would
   * not cover the last post. With the bar gone that floor is a black band under
   * Quiet's own row, where Instagram runs its next photograph.
   *
   * It was blamed on the content inset for three commits. Taking the inset away
   * did not move it, which is the answer: it was never the app's.
   *
   * Only ancestors of the row, only their bottom padding, and only when there
   * is enough of it to be the reservation rather than a margin somebody chose.
   */
  function takeUpTheFloor(row) {
    // The feed's own container, whether or not it is an ancestor of the row.
    // On the pages where Instagram draws no bottom bar there is no row to walk
    // up from, and the reservation is there all the same.
    var main = document.querySelector("main");
    if (main) {
      markFloor(main);
      markFloor(main.parentElement);
      markFloor(main.firstElementChild);
    }

    var node = row.parentElement;
    var depth = 0;
    while (node && node !== document.documentElement && depth < 8) {
      markFloor(node);
      node = node.parentElement;
      depth += 1;
    }
  }

  /** Enough bottom padding to be a reservation rather than a choice. */
  function markFloor(node) {
    if (!node || node.nodeType !== 1) return;
    if (node.getAttribute("data-quiet-floor") !== null) return;

    var style = window.getComputedStyle(node);
    var padding = parseFloat(style.paddingBottom);
    var margin = parseFloat(style.marginBottom);
    if ((!isNaN(padding) && padding >= 8) || (!isNaN(margin) && margin >= 8)) {
      node.setAttribute("data-quiet-floor", "");
    }
  }

  /**
   * Instagram's own way to your profile.
   *
   * The app knows the signed-in name and can build the address from it, and
   * that is one deduction too many for a button marked "your profile" — a name
   * read a moment too early sends somebody to a stranger, or to a page that
   * does not exist. The row Quiet hides carries the link Instagram itself uses.
   * It is hidden, not removed, so it still knows where it goes.
   */
  /** Where each of the three lives, asked of the address rather than the label. */
  var DESTINATIONS = {
    home: function (href) { return href === "/"; },
    messages: function (href) { return href.indexOf("/direct") === 0; }
  };

  /**
   * Go where Instagram's own row would go, by pressing Instagram's own link.
   *
   * The app used to load an address, which throws the page away and builds it
   * again: a spinner, a fresh feed from the top, and the stories reloaded, every
   * time you came back from the inbox. Instagram's own row does not do that —
   * it hands the address to the client already running in the page, which keeps
   * its shell, its caches and the place you had scrolled to.
   *
   * The row is hidden rather than removed precisely so it can still be pressed.
   *
   * It answers with the address it went to rather than a bare yes: the app can
   * fall back to loading that address when there is no row to press, and a test
   * can check *where* somebody was sent without implementing navigation.
   */
  window.__quietGo = function (kind) {
    var row = navRow();
    if (!row) return false;

    var link = null;
    if (kind === "profile") {
      link = personIn(row);
    } else {
      var test = DESTINATIONS[kind];
      if (!test) return false;
      var links = row.querySelectorAll('a[href^="/"]');
      for (var i = 0; i < links.length; i++) {
        if (test(links[i].getAttribute("href") || "")) { link = links[i]; break; }
      }
    }
    if (!link) return false;

    var href = link.getAttribute("href");
    // Already there. Pressing it again would be Instagram's own answer to that,
    // which is to go back to the top — and the row has said that itself since
    // the day it learned to mark where you are.
    if (location.pathname === href) return href;

    link.click();
    return href;
  };

  /** The name the app used before there were three of them. */
  window.__quietOpenProfile = function () {
    return window.__quietGo("profile");
  };

  /**
   * Start the page below the clock, and let it scroll up behind it — and say
   * how much of the bottom of the glass the app's own row stands on.
   *
   * The app gives the page the whole screen — see `InstagramWebView` for the
   * seven attempts at doing anything else — so without this the first post
   * would be drawn under the status bar at rest. A padding on the document
   * puts the first thing in the feed below it and lets everything scroll up
   * behind it, which is exactly what Instagram's own app does.
   *
   * The number at the other end is not spent on the document, which owes the
   * bottom of the screen nothing: the page runs on beneath the row, where
   * Instagram's next photograph belongs. It is there for the one thing that
   * cannot run on beneath it, which is a sheet — see `saySheet`.
   *
   * Both are set as custom properties rather than as styles, so the rules that
   * use them live in trim.css with every other rule, where they can be read.
   * The row is set even when it is nothing, because nothing is the truth on a
   * story and on a conversation, and a property left behind from the last
   * screen would hold a sheet off an edge the row is no longer standing on.
   */
  function makeRoom() {
    var style = document.documentElement.style;
    var top = window.__quietTop;
    if (top) style.setProperty("--quiet-top", top + "px");
    style.setProperty("--quiet-row", rowStands() + "px");
  }

  /**
   * Let the page see the notch, so that trim.css can ask about it.
   *
   * `viewport-fit=cover` was tried once and written off as doing nothing
   * whatsoever, on the grounds that Instagram's stylesheet never consults
   * `env()`. True, and beside the point: the stylesheet that needs to consult
   * it is ours. Without this the safe area is flat zero and `env()` in trim.css
   * answers nothing.
   *
   * It is worth having as well as the number the app hands over, not instead of
   * it, because the two fail in opposite directions. The app's number can be
   * stale — it has been, for six commits — and WebKit's cannot; WebKit's is
   * zero on anything without a notch, and the app's is not.
   */
  function coverTheGlass() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) return;
    var content = meta.getAttribute("content") || "";
    if (content.indexOf("viewport-fit") !== -1) return;
    meta.setAttribute("content", content + ", viewport-fit=cover");
  }

  /**
   * Push whatever is holding the header at the top of the glass down past the
   * clock.
   *
   * The padding that starts the document below the status bar cannot reach a
   * pinned element: `position: sticky` measures its offset from the edge of the
   * scrollport, and the scrollport does not care what the document is padded
   * by. So a bar with `top: 0` sits over the clock at every scroll position
   * except the very top, which is exactly the photograph — the wordmark, the
   * plus and the heart drawn straight through the battery.
   *
   * A previous version of this looked for that bar and reported finding none,
   * and the conclusion drawn was that Instagram does not pin its header. The
   * conclusion was wrong and the search was at fault: it only ever looked at
   * six ancestors of a link, and only at ones as wide as the window. What is
   * pinned here is a wrapper, and it is asked of the browser rather than of a
   * stylesheet, so the answer is true whatever Instagram changed this week.
   */
  function liftPinned(bar) {
    var node = bar;
    while (node && node !== document.body) {
      // Once lifted it reads as pinned at the clock's height rather than at
      // nothing, so the test below would stop recognising it and it would drop
      // back the next frame. What has been lifted stays lifted.
      if (node.getAttribute("data-quiet-pinned") !== null) return;

      var style = window.getComputedStyle(node);
      if (style.position === "sticky" || style.position === "fixed") {
        var top = parseFloat(style.top);
        // `auto` parses to nothing, and a sticky element with no top is not
        // pinned vertically to anything.
        if (!isNaN(top) && top < 1) {
          node.setAttribute("data-quiet-pinned", "");
          return;
        }
      }
      node = node.parentElement;
    }
  }

  var lastPath = null;

  /**
   * Tell the app where the page went.
   *
   * Instagram's client changes the address without loading anything, so the
   * app's own navigation delegate never hears about it — and the row along the
   * bottom would go on marking the page you were on three taps ago.
   */
  function sayWhere() {
    if (location.pathname === lastPath) return;
    lastPath = location.pathname;
    post({ kind: "where", path: lastPath });
  }

  /* ── Sheets ───────────────────────────────────────────────────────────── */

  /**
   * Instagram puts a sheet up for switching accounts, for sharing, and for the
   * menu behind the three dots. It slides over its own tab bar the way every
   * sheet on a phone does, and Quiet's row — which is the app's furniture, not
   * the page's — stayed exactly where it was, drawn across the buttons on it.
   *
   * Seven answers to that were written and every one of them tried to move
   * something of Instagram's: pad the panel, transform the panel, move the row,
   * make the row inert. Seven photographs came back identical. Whatever the
   * reason for each — and there is no way to read one off a photograph — the
   * shared property is that they all asked somebody else's stylesheet for
   * permission.
   *
   * This file no longer moves anything. Its whole job here is to answer two
   * questions and hand them to the app:
   *
   *   is there a sheet, and what colour is it?
   *
   * The app owns the viewport. It makes the web view shorter, every bottom-
   * anchored thing in the page rises by exactly that much because that is what
   * being anchored to the bottom of a viewport means, and there is no rule
   * anybody can write that refuses it. It is the same answer the status bar
   * needed, and it is in this file's own history: "So the viewport itself is
   * made smaller. Everything in it is right by construction."
   *
   * Which leaves the finding, and the finding is where the eighth photograph
   * came back the same as the other seven. Three things were wrong with it, and
   * every one of them says no to a sheet that is really there:
   *
   *   * **A sheet arrives by sliding, and a slide is not a mutation.** The
   *     observer hears the panel appear, and at the moment it appears the panel
   *     is still below the bottom edge of the glass. Nothing in the document
   *     changes while it travels up, so the question was asked once, at the one
   *     moment the honest answer is no, and never asked again. See `settle`.
   *   * **It had to reach the bottom edge to the pixel.** Two points of
   *     tolerance, against a panel that can end on a rounded corner or a
   *     hairline of its own. Forty now, which is still far less than the row.
   *   * **It had to be held over the page within eight steps.** Instagram's
   *     tree is deeper than eight almost everywhere, and the fixed element is
   *     the backdrop, not the panel. The walk goes to the body now.
   *
   * And a third way of finding one is asked underneath the other two, which is
   * the question the photograph itself asks: *is anything a person would press
   * drawn under Quiet's row?* See `theSheetUnderTheRow`. It knows nothing about
   * sheets, needs nothing of Instagram's markup to be true, and is the one test
   * that cannot be wrong about the thing that is actually wrong.
   */

  var MODAL = '[role="dialog"], [aria-modal="true"], dialog[open]';

  var lastSheet = false;
  var lastClear = true;
  var lastTint = null;

  function saySheet() {
    var sheet = theSheet();
    var up = !!sheet;
    var clear = !up || everythingClearsTheRow(sheet);
    var tint = up ? colourOf(sheet) : null;
    var key = tint ? tint.join(",") : null;

    if (up === lastSheet && clear === lastClear && key === lastTint) return;
    lastSheet = up;
    lastClear = clear;
    lastTint = key;

    var message = { kind: "sheet", up: up, clear: clear };
    if (tint) {
      message.red = tint[0];
      message.green = tint[1];
      message.blue = tint[2];
    }
    post(message);
  }

  /**
   * The sheet the app is already holding the glass open for.
   *
   * Held on to rather than found again every time, because the act of answering
   * changes the screen the next answer is read off. The app takes a strip of
   * glass away underneath the sheet, so the row stops standing on the page at
   * all — and the test that found the sheet by what was drawn under the row
   * then finds nothing, and the glass would come back, and the sheet would drop
   * onto the row again, once per frame, for as long as it was open.
   *
   * So the answer is only worked out again once the sheet it was about has gone
   * off the screen.
   */
  var known = null;

  function theSheet() {
    if (known && stillDrawn(known)) return known;
    known =
      theSheetItSaysItIs() || theSheetByItsShape() || theSheetUnderTheRow();
    return known;
  }

  /** Still in the document, still drawn, and still on the glass. */
  function stillDrawn(node) {
    if (node.isConnected === false) return false;
    if (!document.documentElement.contains(node)) return false;
    var box = node.getBoundingClientRect();
    if (box.width <= 0 || box.height <= 0) return false;
    // Dismissed by sliding back down rather than by being taken out.
    return box.top < (window.innerHeight || 0);
  }

  /**
   * The sheet by what it says it is.
   *
   * The markup first, because when Instagram does say a thing is modal that is
   * the answer and there is nothing to work out. Nothing obliges it to, though,
   * and when it does not, the symptom is identical to every other way this can
   * fail — which is how seven rounds went by without the question being asked.
   */
  function theSheetItSaysItIs() {
    var modals = document.querySelectorAll(MODAL);
    for (var i = 0; i < modals.length; i++) {
      var box = modals[i].getBoundingClientRect();
      if (box.width > 0 && box.height > 0) return modals[i];
    }
    return null;
  }

  /**
   * A sheet that never said it was one, found the way the header and the upsell
   * strip are: by asking what is actually drawn along the bottom of the glass.
   *
   * The tests are what makes something a sheet rather than part of a page. It
   * reaches the bottom edge; it spans nearly the whole width; it is tall enough
   * to be a sheet and shorter than the screen, because a backdrop is as tall as
   * the glass; and it is held over the page rather than laid out in it.
   *
   * Nothing of Instagram's own is picked up by mistake: its floor is taken out
   * and carries a mark saying so, a bar is too short, a card does not span the
   * glass — and on the screens that own their bottom edge, a story or a
   * conversation, the app draws no row and none of this runs.
   */
  var SHEET_SHORTEST = 100;

  /**
   * How far above the bottom edge a sheet may stop and still be a sheet.
   *
   * Two points, which is what this was, is a measurement rather than a
   * tolerance: it asks a panel that can end on a rounded corner, a hairline or
   * a home-indicator strip of its own to land on an exact pixel. Forty is
   * generous about the foot of a sheet and still less than half the row, so
   * nothing that stops short enough to clear the row is chased.
   */
  var SHEET_FOOT = 40;

  function theSheetByItsShape() {
    if (!document.elementsFromPoint) return null;

    var width = window.innerWidth || 0;
    var height = window.innerHeight || 0;
    if (!width || !height || rowStands() <= 0) return null;

    var columns = [
      Math.round(width / 2),
      Math.round(width * 0.2),
      Math.round(width * 0.8)
    ];
    var rows = [height - 2, height - 30, height - 60];

    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        var stack = document.elementsFromPoint(columns[c], rows[r]);
        if (!stack) continue;
        for (var i = 0; i < stack.length; i++) {
          if (looksLikeASheet(stack[i], width, height)) return stack[i];
        }
      }
    }
    return null;
  }

  function looksLikeASheet(node, width, height) {
    if (!ours(node)) return false;

    var box = node.getBoundingClientRect();
    if (box.width < width * 0.8) return false;
    if (box.bottom < height - SHEET_FOOT || box.bottom > height + 8) return false;
    if (box.height < SHEET_SHORTEST) return false;
    if (box.height > height - 8) return false;

    return heldOverThePage(node) !== null;
  }

  /** Anything the app has already dealt with, or drawn itself, is not a sheet. */
  function ours(node) {
    if (!node || !node.getAttribute) return false;
    if (node === document.body || node === document.documentElement) return false;
    if (node.getAttribute("data-quiet-floor") !== null) return false;
    if (node.getAttribute("data-quiet-hidden") !== null) return false;
    if (node.id && node.id.indexOf("quiet-") === 0) return false;
    return true;
  }

  /**
   * Held against the glass rather than laid out in the page — and which element
   * is doing the holding.
   *
   * The walk used to stop after eight steps, which is a guess about the depth of
   * somebody else's tree and was wrong about Instagram's: a sheet's panel is a
   * long way below the fixed backdrop that holds it, and eight steps never
   * reached it. It goes to the body now, which is the only end there is.
   *
   * The element doing the holding is handed back rather than a yes: it is the
   * panel itself when the panel is the fixed one, and the backdrop when it is
   * not, and one of the two callers wants to know which.
   */
  function heldOverThePage(node) {
    var steps = 0;
    while (node && node !== document.body && steps < 60) {
      if (window.getComputedStyle(node).position === "fixed") return node;
      node = node.parentElement;
      steps += 1;
    }
    return null;
  }

  /**
   * The question the photograph asks, asked directly: is there anything a
   * person would press drawn underneath Quiet's row?
   *
   * Every other test here is an inference about how Instagram builds a sheet,
   * and an inference about somebody else's markup is only ever true until they
   * change it. This one is about the screen. It probes the strip of glass the
   * row stands on, and if what is drawn there is something pressable held over
   * the page, then whatever that thing belongs to is in the way — whether or
   * not it is a sheet, whether or not it says so, and whatever shape it is.
   *
   * The page's own content is never picked up. What scrolls is not held over
   * anything, and content running on beneath the row is exactly what the row is
   * meant to have under it — that is where Instagram's next photograph goes.
   * The one further guard is width: a sheet, a menu and a dialog all span most
   * of the glass, and a stray fixed pill does not.
   */
  var OVERLAY_NARROWEST = 0.6;

  function theSheetUnderTheRow() {
    if (!document.elementsFromPoint) return null;

    var width = window.innerWidth || 0;
    var height = window.innerHeight || 0;
    var stands = rowOverThePage();
    if (!width || !height || stands <= 0) return null;

    var columns = [0.5, 0.15, 0.35, 0.65, 0.85].map(function (part) {
      return Math.round(width * part);
    });
    var rows = [
      height - 4,
      height - Math.round(stands / 2),
      height - stands + 4
    ];

    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        var stack = document.elementsFromPoint(columns[c], rows[r]);
        if (!stack) continue;
        for (var i = 0; i < stack.length; i++) {
          var control = pressableAt(stack[i]);
          if (!control) continue;
          var panel = panelAround(control, width, height);
          if (panel) return panel;
        }
      }
    }
    return null;
  }

  /**
   * What a control drawn under the row belongs to.
   *
   * The largest box around it that is still smaller than the glass, and only if
   * something on the way up is holding it there. Largest, because the sheet is
   * the thing the app has to paint a strip underneath and the button is not;
   * smaller than the glass, because the next box out is the dimmed backdrop,
   * which is the whole screen and has no colour worth sampling.
   */
  function panelAround(control, width, height) {
    var node = control;
    var panel = null;
    var held = false;
    var steps = 0;
    while (node && node !== document.body && steps < 60) {
      if (!ours(node)) return null;
      if (window.getComputedStyle(node).position === "fixed") held = true;
      var box = node.getBoundingClientRect();
      if (box.width >= width * OVERLAY_NARROWEST && box.height < height - 8) {
        panel = node;
      }
      node = node.parentElement;
      steps += 1;
    }
    return held ? panel : null;
  }

  /**
   * The control a point lands on: the element itself, or the button whose label
   * it is. A tap lands on the text inside a button as often as on the button.
   */
  function pressableAt(node) {
    var steps = 0;
    while (node && node !== document.body && steps < 8) {
      if (!ours(node)) return null;
      if (node.matches && node.matches(PRESSABLE)) return node;
      node = node.parentElement;
      steps += 1;
    }
    return null;
  }

  /**
   * What colour the sheet is, so the app can paint the strip of glass it takes
   * away underneath it.
   *
   * Without this the sheet would appear to stop short of the bottom edge with a
   * band of the app's own colour beneath it, which is not what a sheet looks
   * like. With it, the sheet reaches the edge exactly as before and only its
   * contents have moved up.
   *
   * Climbs until something is opaque, for the same reason the clock's band
   * does: a see-through layer hands back a colour that is never drawn anywhere.
   */
  function colourOf(sheet) {
    var node = sheet;
    var steps = 0;
    while (node && node !== document.body && steps < 6) {
      var colour = colourFrom(window.getComputedStyle(node).backgroundColor);
      if (colour) return colour;
      node = node.parentElement;
      steps += 1;
    }
    return null;
  }

  /** Anything on the sheet you could press, and whether it is above the row. */
  var PRESSABLE =
    'a, button, input, textarea, select, [role="button"], [role="link"], ' +
    '[role="menuitem"], [role="tab"], [contenteditable="true"], [tabindex]';

  /**
   * Measured rather than assumed.
   *
   * The app has one last resort — standing the row down so the press goes
   * through it — and this is what decides whether it is needed. A sheet whose
   * every control is above the row needs nothing further; one that still has a
   * button underneath gets the row out of the way of the tap even though it
   * cannot get it out of the way of the eye.
   *
   * Asked of what the row is still standing on rather than of how tall it is,
   * so that once the app has taken the glass away the answer becomes yes and
   * the row goes back to answering taps. A row that stayed inert for as long as
   * a sheet was open would be a row you could not leave a sheet by.
   */
  function everythingClearsTheRow(sheet) {
    var height = window.innerHeight || 0;
    var floor = height - rowOverThePage();
    var controls = sheet.querySelectorAll(PRESSABLE);
    for (var i = 0; i < controls.length; i++) {
      var box = controls[i].getBoundingClientRect();
      if (box.width <= 0 || box.height <= 0) continue;
      /* Only what is on the glass can be under the row. */
      if (box.top >= height) continue;
      if (box.bottom > floor + 1) return false;
    }
    return true;
  }

  /**
   * How much of the bottom of the glass Quiet's row stands on, in points.
   *
   * Handed over by the app, because the app is the only thing that knows: the
   * row is the app's own furniture, it has two shapes with two heights, and on
   * the screens that own the bottom edge there is no row at all and the answer
   * is zero. See `WebScripts.load(top:row:lift:)`.
   */
  function rowStands() {
    var points = window.__quietRow;
    return typeof points === "number" && points > 0 ? points : 0;
  }

  /**
   * And how much of that is still over the page.
   *
   * Once the app has taken a strip of glass off the bottom for a sheet, the
   * page's world ends above the row and the row is standing on the app's own
   * paint rather than on anything of Instagram's. Everything that asks whether
   * something is *under* the row has to ask about this number instead, or the
   * answer never changes no matter how much room is made — the sheet and the
   * floor it is measured against both rise by the same amount.
   */
  function rowOverThePage() {
    var taken = window.__quietLift;
    taken = typeof taken === "number" && taken > 0 ? taken : 0;
    return Math.max(0, rowStands() - taken);
  }

  /* ── The colour the clock stands on ───────────────────────────────────── */

  /**
   * The colour Instagram is drawing along the top of itself, sent up so the
   * app can paint the band behind the clock in the same one.
   *
   * The app owns the pixels the time and the battery sit on — the page's
   * viewport starts underneath them — so something has to decide what colour
   * they are, and the system's own page colour is not it: in the dark that is
   * pure black against Instagram's near-black, and the seam shows as a hard
   * line across the top of every screen.
   *
   * It was a grey for a while, a deliberate step off the page, on the argument
   * that a band wants an edge. Asked for plainly, the answer was the other one:
   * no seam at all. The clock should look like it is standing on the page
   * rather than on a shelf above it.
   *
   * So the colour is sampled from what is actually drawn at the top of the
   * page rather than named here. A hex typed into an app is a guess about
   * somebody else's design that goes stale without anyone noticing; a sample
   * follows Instagram from light to dark, from the feed to a story, and
   * through a redesign, with nothing here touched.
   */
  var CHROME_TOKENS = ["--ig-primary-background", "--ig-secondary-background"];

  var lastChrome = null;

  function sayChrome() {
    var colour = chromeColour();
    if (!colour) return;

    var key = colour.join(",");
    if (key === lastChrome) return;
    lastChrome = key;

    post({
      kind: "chrome",
      red: colour[0],
      green: colour[1],
      blue: colour[2],
    });
  }

  function chromeColour() {
    /* What is drawn, first: it is the thing the band has to match, and it is
     * true on a page whose palette is named nothing this knows. */
    var drawn = colourAtTop();
    if (drawn) return drawn;

    /* Nothing opaque to sample — a page mid-rewrite, or one that has painted
     * nothing yet. Then Instagram's palette, by name. */
    var root = window.getComputedStyle(document.documentElement);
    for (var i = 0; i < CHROME_TOKENS.length; i++) {
      var token = colourFrom(root.getPropertyValue(CHROME_TOKENS[i]));
      if (token) return token;
    }
    return null;
  }

  /**
   * Whatever is actually drawn at the top of the page.
   *
   * Asked of the page rather than of `body`, because on most of Instagram the
   * body is transparent and the colour belongs to a container several levels
   * in. Climbs until something is opaque: a translucent bar would otherwise
   * hand back a colour that is never drawn anywhere.
   */
  function colourAtTop() {
    var element = document.elementFromPoint(
      Math.max(1, Math.floor(window.innerWidth / 2)),
      1
    );
    while (element) {
      var colour = colourFrom(
        window.getComputedStyle(element).backgroundColor
      );
      if (colour) return colour;
      element = element.parentElement;
    }
    return colourFrom(
      window.getComputedStyle(document.documentElement).backgroundColor
    );
  }

  /**
   * "38, 38, 38", "rgb(38, 38, 38)" and "rgba(38, 38, 38, 1)" all mean the
   * same thing here. The bare triple is how Instagram writes its custom
   * properties, so that the page can say `rgba(var(--token), 0.6)`.
   *
   * Anything see-through is refused rather than flattened. A colour that is
   * half transparent over something else is not a colour the app can paint a
   * solid band in, and guessing what is behind it is how you end up with a
   * band that is nearly right on one page and wrong on the next.
   */
  function colourFrom(value) {
    if (!value) return null;

    var numbers = String(value).match(/-?[\d.]+/g);
    if (!numbers || numbers.length < 3) return null;
    if (numbers.length > 3 && parseFloat(numbers[3]) < 0.95) return null;

    var channels = [];
    for (var i = 0; i < 3; i++) {
      var channel = Math.round(parseFloat(numbers[i]));
      if (!isFinite(channel)) return null;
      channels.push(Math.min(255, Math.max(0, channel)));
    }
    return channels;
  }

  /* ── Instagram's header, in the arrangement its own app uses ──────────── */

  /**
   * The feed, and only the feed.
   *
   * Every other page's top bar is part of that page — the name on a profile,
   * the compose button in the inbox — and rearranging those would be
   * rearranging the page.
   */
  function isFeed() {
    var path = location.pathname;
    return path === "/" || path === "";
  }

  /** Where the heart goes. Two spellings, because one of them is older. */
  var ACTIVITY =
    'a[href^="/accounts/activity"], a[href^="/accounts/notifications"]';

  /**
   * The bar across the top of the feed, found by what is in it.
   *
   * Two things are always in it and nowhere near each other in the document:
   * the link to the activity feed, and the link home the wordmark sits in.
   * Both are addresses, so both survive translation and next week's generated
   * class names — the same reasoning that finds the navigation row.
   *
   * An earlier version went looking for a bar *pinned* to the top of the glass
   * and found nothing at all, which is the whole story of six commits: this bar
   * is not pinned, it is merely first, and it scrolls away with the feed
   * exactly as the app's does.
   */
  function headerBar() {
    if (!isFeed()) return null;

    var hearts = document.querySelectorAll(ACTIVITY);
    for (var i = 0; i < hearts.length; i++) {
      var node = hearts[i].parentElement;
      var depth = 0;
      while (node && node !== document.body && depth < 6) {
        if (node.getAttribute("data-quiet-hidden") === null &&
            node.querySelector('a[href="/"]') &&
            node.querySelectorAll("a[href]").length <= 8) {
          return node;
        }
        node = node.parentElement;
        depth += 1;
      }
    }
    return null;
  }

  /**
   * The plus.
   *
   * There is no address to match it on — on the web it opens a picker rather
   * than going anywhere — so it is taken as the control next to the heart in
   * the document. That is what tells it from the chevron beside the wordmark,
   * which is the only other control up there and sits at the far end.
   *
   * Next to it *in the document* rather than on the screen, which matters more
   * than it looks: this runs again on every frame the page rewrites itself, and
   * by then the plus has been moved to the left-hand end of the bar. Asking
   * where things are would find the chevron the second time round and swap the
   * two of them for ever. The order they are written in does not move.
   */
  function createControl(bar, mark, heart) {
    var candidates = bar.querySelectorAll(
      'a[href], button, [role="button"], [role="link"]'
    );
    var before = null;
    var after = null;
    for (var i = 0; i < candidates.length; i++) {
      var element = candidates[i];
      if (holds(element, mark) || holds(element, heart)) continue;
      var box = element.getBoundingClientRect();
      if (box.width < 16 || box.height < 16 || box.width > 80) continue;

      // DOCUMENT_POSITION_FOLLOWING: the heart comes after this one.
      if (element.compareDocumentPosition(heart) & 4) {
        before = element;
      } else if (!after) {
        after = element;
      }
    }
    // The last one written before the heart, which on every version of this
    // page so far is the plus. If the heart is written first, the first one
    // after it, for the same reason.
    return before || after;
  }

  /** Whether these two are the same element, or one is inside the other. */
  function holds(a, b) {
    return a === b || a.contains(b) || b.contains(a);
  }

  /**
   * The outermost wrapper around `element` that still leaves the others out.
   *
   * The three controls are what the app arranges, but they are rarely direct
   * children of the bar — the plus and the heart usually share a group. This
   * climbs as far as it can without swallowing one of the other two, so each of
   * the three ends up with a piece of the bar that is its own.
   */
  function outermost(bar, element, others) {
    var node = element;
    while (node.parentElement && node.parentElement !== bar &&
           bar.contains(node.parentElement)) {
      var parent = node.parentElement;
      for (var i = 0; i < others.length; i++) {
        if (others[i] && parent.contains(others[i])) return node;
      }
      node = parent;
    }
    return node;
  }

  /** Only when it would actually change. An attribute set every frame is a
   *  mutation every frame, and the observer above is watching. */
  function note(element, name, value) {
    if (element.getAttribute(name) !== value) element.setAttribute(name, value);
  }

  /**
   * Flatten the wrappers between the bar and one of the three, so that all
   * three are laid out by the bar itself.
   *
   * `display: contents` does this without moving anything: the wrapper stops
   * generating a box and its children become the bar's own flex items. Nothing
   * in the document changes places, which matters more here than anywhere else
   * in this file — Instagram's client owns this tree and rebuilds it whenever
   * it likes, and a node this script had moved would be a node it puts back.
   */
  function flatten(bar, slot) {
    var node = slot.parentElement;
    while (node && node !== bar && bar.contains(node)) {
      note(node, "data-quiet-flatten", "");
      node = node.parentElement;
    }
  }

  /**
   * Put the header in the app's arrangement: the plus on the left, the title in
   * the middle of the bar, the heart on the right.
   *
   * This is a change of arrangement and nothing else. The controls stay
   * Instagram's — its plus, its chevron, its heart, with its badges on them and
   * its modals behind them — so the header goes on working and behaving exactly
   * as the site's does, which is the only way it can also behave exactly as the
   * app's does.
   *
   * It gives up the moment it is unsure. If any of the three cannot be found,
   * or two of them turn out to be the same piece of the bar, the header is left
   * precisely as Instagram drew it. A header nobody rearranged is a great deal
   * better than one rearranged on a guess.
   */
  function shapeHeader() {
    var bar = headerBar();
    if (!bar) return;

    var heart = bar.querySelector(ACTIVITY);
    var mark = bar.querySelector('a[href="/"]');
    if (!heart || !mark) return;

    var plus = createControl(bar, mark, heart);
    if (!plus) return;

    var title = outermost(bar, mark, [heart, plus]);
    var left = outermost(bar, plus, [heart, title]);
    var right = outermost(bar, heart, [title, plus]);
    if (title === left || title === right || left === right) return;

    note(title, "data-quiet-slot", "title");
    note(left, "data-quiet-slot", "create");
    note(right, "data-quiet-slot", "activity");
    flatten(bar, title);
    flatten(bar, left);
    flatten(bar, right);

    note(bar, "data-quiet-header", "");
  }

  /* ── A header that gets out of the way ────────────────────────────────── */

  /**
   * Instagram's header does not sit there for ever, and neither does this one.
   *
   * Pinned to the top of the glass, it is a permanent inch of wordmark over
   * every photograph anybody scrolls past. Instagram's own app slides it away
   * as you go down and brings it back the moment you go up — which is not the
   * same as taking it out, and not the same as leaving it: it is there when you
   * want it and gone while you are reading.
   *
   * Watched here rather than in the app. The app already knows which way a
   * thumb is going — it draws its own row smaller with it — but a message from
   * one to the other is a frame of lag on something the eye is following, and
   * the page has the number already.
   *
   * Only on the feed. Every other page's top bar is that page's — the name on a
   * profile, the search in the inbox, the back arrow in a conversation — and a
   * back arrow that slides away while you read is a back arrow you go hunting
   * for.
   */

  var lastY = 0;
  var headerAway = false;

  /** Far enough down that there is something worth reading. */
  var CLEAR_OF_THE_TOP = 64;

  /** Enough movement to be a decision rather than a fingertip resting. */
  var DELIBERATE = 8;

  function watchTheHeader() {
    window.addEventListener("scroll", function () {
      var y = window.scrollY || document.documentElement.scrollTop || 0;
      var delta = y - lastY;
      if (Math.abs(delta) < DELIBERATE) return;
      lastY = y;

      showOrHideHeader(isFeed() && y > CLEAR_OF_THE_TOP && delta > 0);
    }, { passive: true });
  }

  function showOrHideHeader(away) {
    if (away === headerAway) return;
    headerAway = away;
    if (away) {
      document.documentElement.setAttribute("data-quiet-away", "");
    } else {
      document.documentElement.removeAttribute("data-quiet-away");
    }
  }

  /** Leaving the feed brings it back, wherever the last page was scrolled to. */
  function headerComesBack() {
    if (isFeed()) return;
    lastY = 0;
    showOrHideHeader(false);
  }

  /* ── The door back into the app ───────────────────────────────────────── */

  /**
   * Addresses that lead out of the website and into the app.
   *
   * Matched on the address rather than on the words. "Use the app" is
   * "App verwenden" on this phone and something else on the next one, and a
   * rule written against a sentence is a rule that works in one language.
   */
  var THE_DOOR =
    'a[href^="instagram://"], a[href^="instagram-stories://"], ' +
    'a[href^="itms-apps:"], a[href^="itms-appss:"], ' +
    'a[href*="apps.apple.com"], a[href*="itunes.apple.com"], ' +
    'a[href*="mobile_app_upsell"]';

  /**
   * Take down the banner that offers to open Instagram in Instagram.
   *
   * The app already refuses the tap — `instagram://` is the one link a person
   * deliberately presses that Quiet declines, and it says why. But a door you
   * are told is locked every time you reach for it is still a door in the room,
   * and this one is a bar across the bottom of the page with a bright blue
   * sentence in the middle of it.
   *
   * The whole bar goes, not just the link: hiding the link alone leaves an
   * empty strip with a cross in it, which is worse than leaving it alone.
   */
  function refuseTheDoor() {
    var doors = document.querySelectorAll(THE_DOOR);
    for (var i = 0; i < doors.length; i++) {
      var banner = bannerAround(doors[i]) || doors[i];
      note(banner, "data-quiet-hidden", "upsell");
    }
    takeDownTheStrip();
  }

  /* A banner is at most a sentence and a cross. */
  var A_FEW_WORDS = 48;
  /* Tall enough for two lines of it, short of anything that is a page. */
  var STRIP_TALLEST = 140;
  var STRIP_SHORTEST = 16;

  /**
   * The same banner, found when there is no link in it to find.
   *
   * The photograph that came back showed it still there, which means the strip
   * carries no address at all: the tap is handled in Instagram's own script and
   * the markup is a `div` with a sentence in it. Nothing written as a selector
   * over `href` can ever match that, and no amount of adding to the list would
   * have helped.
   *
   * So this asks the screen instead, the same way the header is found: what is
   * actually drawn along the bottom of the glass? Then it decides by shape,
   * and only by shape.
   *
   * Twelve points, because the strip does not sit at the very bottom — Quiet's
   * own row is drawn over that — and its exact height is Instagram's business.
   * A column at each side and one down the middle, at four heights.
   */
  function takeDownTheStrip() {
    if (!document.elementsFromPoint) return;
    // Not in a conversation. The bar along the bottom of one is the thing you
    // came there to use, and message requests put their two answers in the
    // same place. Nowhere else on the site is that space anybody's but ours.
    if (location.pathname.indexOf("/direct") === 0) return;

    var width = window.innerWidth || 390;
    var height = window.innerHeight || 844;
    var columns = [
      Math.round(width * 0.2),
      Math.round(width / 2),
      Math.round(width * 0.8)
    ];
    var rows = [height - 2, height - 28, height - 64, height - 110];

    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        var stack = document.elementsFromPoint(columns[c], rows[r]);
        if (!stack) continue;
        for (var i = 0; i < stack.length; i++) {
          if (isTheStrip(stack[i])) {
            note(stack[i], "data-quiet-hidden", "upsell");
          }
        }
      }
    }
  }

  /**
   * Is this one of the elements under that point the strip itself?
   *
   * Every question here is about the drawn thing rather than about the markup,
   * and each one is there to spare something real:
   *
   * - held against the viewport, spanning the glass, short, and low down —
   *   that is a banner rather than a paragraph of the page;
   * - nothing to type in — a composer is the one thing down there that must
   *   never go, and every composer has a field;
   * - a few words at most — a consent notice is also a strip along the bottom,
   *   and refusing to let somebody answer it would be worse than the banner;
   * - something to press — an empty strip is somebody's spacer, and hiding a
   *   spacer moves the page for no reason.
   */
  function isTheStrip(node) {
    if (!node || !node.getAttribute) return false;
    if (node === document.body || node === document.documentElement) return false;
    if (node.getAttribute("data-quiet-hidden") !== null) return false;
    if (node.id && node.id.indexOf("quiet-") === 0) return false;

    var style = window.getComputedStyle(node);
    if (style.position !== "fixed" &&
        style.position !== "sticky" &&
        style.position !== "absolute") return false;

    var width = window.innerWidth || 390;
    var height = window.innerHeight || 844;
    var box = node.getBoundingClientRect();
    if (box.width < width - 2) return false;
    if (box.height < STRIP_SHORTEST || box.height > STRIP_TALLEST) return false;
    if (box.bottom < height * 0.75) return false;

    if (node.querySelector('input, textarea, form, [contenteditable="true"]')) {
      return false;
    }
    var words = (node.textContent || "").replace(/\s+/g, " ").trim();
    if (words.length > A_FEW_WORDS) return false;
    if (!node.querySelector('a, button, [role="button"]')) return false;

    return true;
  }

  /**
   * The strip the door is set into.
   *
   * Found by shape and only by shape: pinned or placed against the viewport,
   * the width of the glass, and short. A message box is pinned to the bottom of
   * a conversation and is exactly the thing that must never be hidden — which
   * is why the search starts from a link that leads out of the site, and a
   * composer has none.
   */
  function bannerAround(door) {
    var node = door.parentElement;
    var depth = 0;
    while (node && node !== document.body && depth < 6) {
      var style = window.getComputedStyle(node);
      if (style.position === "fixed" ||
          style.position === "sticky" ||
          style.position === "absolute") {
        var box = node.getBoundingClientRect();
        if (box.width >= (window.innerWidth || 390) - 2 &&
            box.height > 0 && box.height <= 140) {
          return node;
        }
      }
      node = node.parentElement;
      depth += 1;
    }
    return null;
  }

  /* ── The other wordmark ───────────────────────────────────────────────── */

  /**
   * Instagram has two wordmarks and both are theirs.
   *
   * The app draws the script one — the one everybody pictures. The website
   * draws the newer one, and Quiet shows the website, so Quiet shows that.
   *
   * The obvious way to close the gap is to set the word in a script font and
   * call it done, and that is the one thing this will not do: a wordmark set in
   * somebody else's typeface is not a wordmark, it is a forgery that holds up
   * at arm's length and falls apart at reading distance. It would be *less*
   * faithful than what is there now, not more.
   *
   * So this looks for Instagram's own file instead. Their sign-in page has
   * historically carried the script one, and it is the same origin, so the page
   * can fetch it, read it out of the markup and put it where the other one was.
   * Instagram's drawing either way — only the one from the other room of their
   * own house.
   *
   * It may find nothing. Then nothing happens, which is the whole design of it.
   */

  var WORDMARK = "quiet.wordmark";

  function rememberedWordmark() {
    try {
      return window.localStorage.getItem(WORDMARK);
    } catch (error) {
      // A phone with storage turned off is a phone with the other wordmark.
      return null;
    }
  }

  /**
   * Ask the sign-in page for it, once.
   *
   * Without credentials on purpose: a signed-in session is redirected off that
   * page before it can be read, and this wants the page a stranger sees. It is
   * a request the page makes to the site it already is, which is the same
   * arrangement as everything else here.
   */
  function learnWordmark() {
    if (window.__quietWordmarkAsked || rememberedWordmark()) return;
    window.__quietWordmarkAsked = true;

    fetch("/accounts/login/", { credentials: "omit" })
      .then(function (answer) { return answer.ok ? answer.text() : null; })
      .then(function (html) {
        if (!html) return;
        var found = wordmarkIn(new DOMParser().parseFromString(html, "text/html"));
        if (!found) return;
        try { window.localStorage.setItem(WORDMARK, found); } catch (error) { return; }
        dressHeader();
      })
      .catch(function () {
        // Offline, or the page moved. Worth one more try on the next page.
        window.__quietWordmarkAsked = false;
      });
  }

  /**
   * The wordmark out of a document that is not the one on screen.
   *
   * An inline drawing is preferred over a picture: it needs no second request,
   * it takes the colour of the bar it lands in, and it is sharp at every size.
   * Anything that could run is taken out of it first — this is Instagram's own
   * markup from Instagram's own origin, and it is still going straight into the
   * page, so it goes in as a drawing and nothing else.
   */
  function wordmarkIn(doc) {
    var drawing = doc.querySelector('svg[aria-label="Instagram"]');
    if (drawing) {
      var copy = drawing.cloneNode(true);
      // A namespace-wildcard selector is legal CSS and not every engine parses
      // it, and a wordmark needs none of these anyway. If taking them out
      // leaves nothing to draw, the measurement below catches it.
      var risky = copy.querySelectorAll("script, foreignObject, a, use, image");
      for (var i = 0; i < risky.length; i++) risky[i].remove();
      strip(copy);
      return "svg " + copy.outerHTML;
    }

    var picture = doc.querySelector('img[alt="Instagram"]');
    var source = picture && picture.getAttribute("src");
    if (!source) return null;
    try {
      var address = new URL(source, location.origin);
      if (address.protocol !== "https:") return null;
      return "img " + address.href;
    } catch (error) {
      return null;
    }
  }

  /** Every `on…` handler, off every node, all the way down. */
  function strip(node) {
    var names = node.getAttributeNames ? node.getAttributeNames() : [];
    for (var i = 0; i < names.length; i++) {
      if (names[i].toLowerCase().indexOf("on") === 0) node.removeAttribute(names[i]);
    }
    var children = node.children || [];
    for (var c = 0; c < children.length; c++) strip(children[c]);
  }

  /**
   * Put it where the other one was.
   *
   * The original is never removed and never hidden until the replacement has
   * been measured and found to have a size. A header with no wordmark in it at
   * all would be a worse outcome than a header with the wrong one, and this is
   * a nicety — it does not get to break anything.
   */
  function dressHeader() {
    var remembered = rememberedWordmark();
    if (!remembered) return;

    var bar = headerBar();
    if (!bar) return;

    var home = bar.querySelector('a[href="/"]');
    if (!home) return;

    var mine = home.querySelector("[data-quiet-wordmark]");
    if (mine) {
      // Measured on the frame after it was made. Nothing, and it goes away
      // again and never comes back.
      if (mine.getAttribute("data-quiet-wordmark") === "new") {
        var box = mine.getBoundingClientRect();
        if (box.width < 8 || box.height < 4) {
          mine.remove();
          window.__quietWordmarkAsked = true;
          try { window.localStorage.removeItem(WORDMARK); } catch (error) {}
          showTheirs(home);
          return;
        }
        note(mine, "data-quiet-wordmark", "kept");
        hideTheirs(home);
      }
      return;
    }

    var holder = document.createElement("span");
    holder.setAttribute("data-quiet-wordmark", "new");
    holder.style.cssText =
      "display: inline-flex; align-items: center; height: 29px; color: inherit;";

    if (remembered.indexOf("svg ") === 0) {
      var drawing = new DOMParser()
        .parseFromString(remembered.slice(4), "image/svg+xml")
        .documentElement;
      if (!drawing || drawing.nodeName.toLowerCase() !== "svg") return;
      drawing.setAttribute("height", "29");
      drawing.removeAttribute("width");
      holder.appendChild(document.importNode(drawing, true));
    } else {
      var picture = document.createElement("img");
      picture.src = remembered.slice(4);
      picture.alt = "Instagram";
      picture.style.cssText = "height: 29px; width: auto; display: block;";
      holder.appendChild(picture);
    }

    home.appendChild(holder);
  }

  function hideTheirs(home) {
    var theirs = home.querySelectorAll("svg, img");
    for (var i = 0; i < theirs.length; i++) {
      if (theirs[i].closest("[data-quiet-wordmark]")) continue;
      note(theirs[i], "data-quiet-hidden", "wordmark");
    }
  }

  function showTheirs(home) {
    var theirs = home.querySelectorAll('[data-quiet-hidden="wordmark"]');
    for (var i = 0; i < theirs.length; i++) theirs[i].removeAttribute("data-quiet-hidden");
  }

  /**
   * The lift, which has to happen whether the arrangement did or not.
   *
   * Kept apart from `shapeHeader` on purpose. Rearranging is a nicety and gives
   * up the moment it is unsure; a header drawn through the clock is the app
   * looking broken, and that must be put right even on a page whose bar is a
   * shape nothing here recognises.
   */
  function liftHeader() {
    var bar = headerBar();
    if (bar) liftPinned(bar);
    liftWhateverIsUpThere();
  }

  /**
   * Ask the browser what is drawn at the top of the glass, and move it down.
   *
   * Every version of this before now went looking for Instagram's header by
   * something *in* it — a link to the activity feed, a link home, a wordmark.
   * The photographs say that search finds nothing on the real site: the header
   * never moved, the app's strip covered it, and the row the app drew in its
   * place stayed empty because there was no heart to take out of a bar nobody
   * had found. Four builds of that.
   *
   * The heart is a button, or the address changed, or the class names did.
   * Whichever it was, the mistake was the same each time: asking a question
   * about Instagram's markup, which is somebody else's and changes weekly.
   *
   * This asks a question about the screen. What is painted four points from the
   * top, in the middle? The browser answers with the stack of elements under
   * that point, outermost last. Whatever in it is pinned there — sticky or
   * fixed, against the top, and short enough to be a bar rather than the page —
   * is the thing that would otherwise be drawn across the clock. It is moved to
   * the bottom of the clock by trim.css.
   *
   * There is nothing here about Instagram at all, which is the point. It works
   * on the feed, on a profile, in the inbox, and on whatever they ship next
   * Tuesday.
   *
   * Once lifted it is no longer at that point, so it is not found again and not
   * lifted twice. A page that rewrites itself gets a new element, and that one
   * is lifted in its turn.
   */
  function liftWhateverIsUpThere() {
    if (!document.elementsFromPoint) return;

    var width = window.innerWidth || 390;
    // Three columns rather than one. A bar that spans the glass is found at any
    // of them; one that does not — the search field in the inbox sits in a
    // wrapper narrower than the page — is found at the one it covers. Cheap
    // enough to do on every frame the page rewrites itself.
    var columns = [
      Math.round(width * 0.2),
      Math.round(width / 2),
      Math.round(width * 0.8)
    ];

    for (var c = 0; c < columns.length; c++) {
      var stack = document.elementsFromPoint(columns[c], 4);
      if (!stack) continue;
      for (var i = 0; i < stack.length; i++) {
        liftIfPinnedToTheTop(stack[i]);
      }
    }
  }

  /**
   * One element out of the stack under a point, moved down if it is a bar
   * drawn over the clock.
   *
   * Every element at that point is asked, and every one that qualifies is
   * lifted. An earlier version stopped at the first — and, worse, gave up
   * entirely the moment it met something already lifted, which is how the
   * inbox ended up with its search field cut in half by the status bar: the
   * page pins two things up there, one behind the other, and only ever the
   * first of them was moved.
   *
   * Lifting something twice is not possible and not a problem: once it carries
   * the attribute it is left alone, and it has moved out from under the point
   * in any case.
   */
  function liftIfPinnedToTheTop(node) {
    if (!node || node === document.body || node === document.documentElement) return;
    if (!node.getAttribute || node.getAttribute("data-quiet-pinned") !== null) return;
    // Nothing of Quiet's is pinned to the top, but a control it added to
    // somebody else's bar must never be mistaken for the bar.
    if (node.id && node.id.indexOf("quiet-") === 0) return;

    var style = window.getComputedStyle(node);
    if (style.position !== "sticky" && style.position !== "fixed") return;

    var top = parseFloat(style.top);
    // `auto` parses to nothing, and something pinned to the bottom is not
    // what is over the clock.
    if (isNaN(top) || top > 1) return;

    var box = node.getBoundingClientRect();
    // A bar, not the page. Instagram's header is about forty-five points; a
    // wrapper as tall as the screen is not a header and must not be moved.
    if (box.height > 140 || box.height < 8) return;

    node.setAttribute("data-quiet-pinned", "");
  }

  /* ── 1. Taps ──────────────────────────────────────────────────────────── */

  document.addEventListener(
    "click",
    function (event) {
      var anchor = event.target && event.target.closest
        ? event.target.closest("a[href]")
        : null;
      if (!anchor) return;

      var destination;
      try {
        destination = new URL(anchor.getAttribute("href"), location.href);
      } catch (error) {
        return;
      }
      if (destination.host !== location.host) return;

      var surface = surfaceFor(destination.pathname.toLowerCase());
      if (!surface) return;

      event.preventDefault();
      event.stopPropagation();
      tell(surface);
    },
    true
  );

  /* ── 2. Suggestion blocks ─────────────────────────────────────────────── */

  /* What each element said the last time it was read, rather than merely that
   * it was read. Instagram's client recycles DOM nodes: an element inspected
   * while it held a caption can later hold "Suggested for you", and a set of
   * seen nodes would never look at it again. */
  var lastSeenText = new WeakMap();

  function isCaption(element) {
    /* Captions and comments live inside a link to their author or a heading of
     * their own. A suggestion header does not. */
    return !!element.closest("a");
  }

  function trimSuggestions(root) {
    var candidates = root.querySelectorAll(
      'span, h1, h2, h3, h4, div[role="heading"]'
    );
    for (var i = 0; i < candidates.length; i++) {
      var element = candidates[i];

      var text = (element.textContent || "").trim().toLowerCase();
      if (lastSeenText.get(element) === text) continue;
      lastSeenText.set(element, text);

      if (!text || text.length > 40 || !labelSet[text]) continue;
      if (isCaption(element)) continue;

      /* Only ever a block inside the feed. `closest` climbs as far as the
       * document, so without this it could reach a <section> wrapping the
       * whole page and hide everything — a blank app, from one matching
       * word. */
      var block = element.closest("article, section");
      if (!block || block === root || !root.contains(block)) {
        block = element.parentElement;
      }
      if (block && block !== root && root.contains(block)) {
        block.setAttribute("data-quiet-hidden", "suggestion");
      }
    }
  }

  /* ── 4. Keep up with the page ─────────────────────────────────────────── */

  var pending = false;

  function schedule() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(function () {
      pending = false;
      var main = document.querySelector("main");
      if (main) trimSuggestions(main);
      coverTheGlass();
      makeRoom();
      takeUpTheFloor(document.body);
      guardLocation();
      sayWhere();
      sayChrome();
      whoAmI();
      replaceNav();
      headerComesBack();
      refuseTheDoor();
      learnWordmark();
      dressHeader();
      liftHeader();
      shapeHeader();
      // Last, because one of the ways a sheet is found is by asking what is
      // drawn under the row, and everything Quiet takes out of the page is
      // drawn there until it has been taken out. Instagram's own navigation
      // row and its door back into the app are both full-width, both held
      // against the bottom of the glass and both full of things you could
      // press — which is to say, both indistinguishable from a sheet right up
      // until the two calls above mark them.
      saySheet();
      settle();
    });
  }

  /**
   * Ask about the sheet again for a moment, after everything else has been
   * asked once.
   *
   * A sheet arrives by sliding, and a slide is not a mutation. The observer
   * hears the panel go into the document, and at that moment the panel is
   * still below the bottom edge of the glass with a transform on it; nothing
   * in the document changes while it travels, so the pass above runs exactly
   * once, at the one moment the honest answer is that there is no sheet — and
   * is never run again until something else rewrites the page.
   *
   * That is the whole of what the eighth photograph showed, and it explains
   * the seven before it: every one of those changed what the app does about a
   * sheet, and none of them changed whether the app ever heard about one.
   *
   * So a change to the document is followed for a moment afterwards. Six looks
   * over two-thirds of a second, spaced further apart as they go, which
   * outlasts any sheet animation on the site and costs six calls of a function
   * that reads a handful of boxes. Only the sheet is asked about again: the
   * rest of the pass is about the document, and the document has not changed.
   */
  var SETTLE = [16, 50, 120, 240, 420, 650];

  var settling = false;

  function settle() {
    if (settling) return;
    settling = true;
    var step = 0;
    (function again() {
      if (step >= SETTLE.length) {
        settling = false;
        return;
      }
      var wait = SETTLE[step] - (step > 0 ? SETTLE[step - 1] : 0);
      step += 1;
      setTimeout(function () {
        saySheet();
        again();
      }, wait);
    })();
  }

  var lastRescue = 0;

  /**
   * Backstop for the case where Instagram's own router lands on a blocked path
   * without a page load. A real navigation home is heavy-handed, which is why
   * it is rate-limited: better a rare reload than a loop.
   */
  function guardLocation() {
    var surface = surfaceFor(location.pathname.toLowerCase());
    if (!surface) return;

    var now = Date.now();
    if (now - lastRescue < 3000) return;
    lastRescue = now;

    tell(surface);
    location.replace("/");
  }

  ["pushState", "replaceState"].forEach(function (name) {
    var original = history[name];
    history[name] = function () {
      var result = original.apply(this, arguments);
      schedule();
      return result;
    };
  });

  window.addEventListener("popstate", schedule);

  watchTheHeader();

  /* A change of scheme rewrites every colour in the page and touches nothing in
   * the document, so the observer below never hears about it and the band would
   * keep the colour of the scheme you left. */
  if (window.matchMedia) {
    var scheme = window.matchMedia("(prefers-color-scheme: dark)");
    if (scheme.addEventListener) {
      scheme.addEventListener("change", schedule);
    } else if (scheme.addListener) {
      scheme.addListener(schedule);
    }
  }

  new MutationObserver(schedule).observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule);
  } else {
    schedule();
  }
})();
