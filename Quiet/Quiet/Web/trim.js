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
 *   4. Put the header on the feed into the arrangement Instagram's own app
 *      uses: the plus on the left, the title in the middle, the heart on the
 *      right. The controls stay the site's own, so what they do and how they
 *      behave are unchanged — only where they sit.
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
    if (row.getAttribute("data-quiet-hidden") !== "nav") {
      row.setAttribute("data-quiet-hidden", "nav");
    }
    takeUpTheFloor(row);
    faceFromRow(row);
    sendIcons(row);
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
        var canvas = document.createElement("canvas");
        canvas.width = 72;
        canvas.height = 72;
        var ink = canvas.getContext("2d");
        if (!ink) { sent[key] = false; return; }
        ink.drawImage(picture, 0, 0, 72, 72);
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
    var node = row.parentElement;
    var depth = 0;
    while (node && node !== document.documentElement && depth < 8) {
      if (node.getAttribute("data-quiet-floor") === null) {
        var padding = parseFloat(window.getComputedStyle(node).paddingBottom);
        if (!isNaN(padding) && padding >= 8) {
          node.setAttribute("data-quiet-floor", "");
        }
      }
      node = node.parentElement;
      depth += 1;
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
  window.__quietOpenProfile = function () {
    var row = navRow();
    if (!row) return false;

    var link = personIn(row);
    if (!link) return false;

    var href = link.getAttribute("href");
    location.assign(href);
    // The address it went to rather than a bare yes, so the app can say where
    // it sent somebody and a test can check it went to the right place without
    // implementing navigation.
    return href;
  };

  /**
   * Start the page below the clock, and let it scroll up behind it.
   *
   * The app gives the page the whole screen — see `InstagramWebView` for the
   * seven attempts at doing anything else — so without this the first post
   * would be drawn under the status bar at rest. A padding on the document
   * puts the first thing in the feed below it and lets everything scroll up
   * behind it, which is exactly what Instagram's own app does.
   *
   * Set as a custom property rather than a style, so the rule that uses it
   * lives in trim.css with every other rule, where it can be read.
   */
  function makeRoom() {
    var top = window.__quietTop;
    if (!top) return;
    document.documentElement.style.setProperty("--quiet-top", top + "px");
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
    if (!bar) return;
    liftPinned(bar);
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
      guardLocation();
      sayWhere();
      whoAmI();
      replaceNav();
      liftHeader();
      shapeHeader();
    });
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
