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
        announce(name, (data.form_data && data.form_data.profile_pic_url) || null);
      })
      .catch(function () {
        // Signed out, or the endpoint moved. The row keeps its four entries.
        asked = false;
      });
  }

  /**
   * The name off the navigation bar, kept only as a second chance for the day
   * the request above stops answering.
   */
  function learnMe(row) {
    // Only ever from inside the bar. A profile link in the feed belongs to
    // whoever posted, and sending somebody to a stranger's profile under a
    // button marked "your profile" is worse than having no button.
    var links = row.querySelectorAll('a[href^="/"]');
    for (var i = 0; i < links.length; i++) {
      var link = links[i];
      var match = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(link.getAttribute("href") || "");
      if (!match) continue;
      if (window.__quietMe === match[1]) return;
      window.__quietMe = match[1];

      var picture = link.querySelector("img");
      announce(match[1], picture ? picture.getAttribute("src") : null);
      return;
    }
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
  }

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
