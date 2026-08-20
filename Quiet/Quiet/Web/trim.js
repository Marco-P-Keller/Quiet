/*
 * Quiet's trim pass.
 *
 * Runs at document start on every Instagram page. Three jobs, in order of how
 * much they matter:
 *
 *   1. Refuse taps that would open Reels or Explore, and tell the app so it can
 *      say why. Silence would read as a broken page.
 *   2. Hide suggestion blocks, which carry no address of their own and can only
 *      be recognised by their wording.
 *   3. Put back the two things Quiet needs the page to carry: its own mark
 *      beside Instagram's settings on your profile, and a search in the slot
 *      Instagram's own search used to occupy. Both are found by where they sit
 *      on the screen rather than by what they are called, because a corner does
 *      not change with the language or with next week's class names.
 *   4. Keep all of it up as the page rewrites itself, because Instagram's web
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

  /* ── The page's own frame ────────────────────────────────────────────── */

  /**
   * Ask the page to lay itself out around the notch.
   *
   * Without `viewport-fit=cover`, WebKit reports every `env(safe-area-inset-*)`
   * as zero, so a site that has taken the trouble to avoid the status bar has
   * no way to know it is there — and Instagram's header renders underneath the
   * clock. Adding the one word lets the site's own rules do the work.
   *
   * The alternative, which this replaces, was for the app to make the web view
   * shorter. That worked on a simulator and, on a real phone, detached
   * Instagram's header and left it floating in the middle of the feed: sticky
   * positions are laid out against a viewport, and moving the viewport under a
   * running page is not something to do lightly.
   */
  function fitViewport() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) return;
    var content = meta.getAttribute("content") || "";
    if (content.indexOf("viewport-fit") !== -1) return;
    meta.setAttribute("content", content + ", viewport-fit=cover");
  }

  /* ── What Quiet puts back ────────────────────────────────────────────── */

  var MARK_ID = "quiet-mark";
  var SEARCH_ID = "quiet-search";
  var CLOCK_ID = "quiet-clock";
  var OURS = { "quiet-mark": true, "quiet-search": true, "quiet-clock": true };

  /**
   * Is this the signed-in person's own profile?
   *
   * Asked by where a link goes rather than by what it says: /accounts/edit/ is
   * a URL, and a URL is the same in every language while "Edit profile" is not.
   * It only exists on your own profile, which is the question.
   */
  function isOwnProfile() {
    return !!document.querySelector('a[href*="/accounts/edit"]');
  }

  /**
   * The control nearest a corner of the screen.
   *
   * Instagram's own settings and its navigation are found by where they *are*,
   * not by what they are called or which generated class they carry this week.
   * Both of those change; a settings control in the top-left corner and a
   * navigation bar along the bottom have not changed in the life of the site.
   */
  function controls() {
    return document.querySelectorAll('a[href], button, [role="button"], [role="link"]');
  }

  function controlNear(test) {
    var candidates = controls();
    for (var i = 0; i < candidates.length; i++) {
      var element = candidates[i];
      if (OURS[element.id]) continue;
      var box = element.getBoundingClientRect();
      if (box.width < 16 || box.height < 16 || box.width > 120) continue;
      if (test(box)) return element;
    }
    return null;
  }

  /**
   * The navigation bar along the bottom, and the controls in it.
   *
   * Found as the element with the most tappable children sitting on the bottom
   * edge — which is what a navigation bar *is*, and is true of it in every
   * language and under every generated class name. An earlier version looked
   * for a single control near the bottom-left and rejected it for being too
   * wide: the items in that bar are stretched to a third of the screen each, so
   * the one measurement I used to recognise a button is the one thing they are
   * not.
   */
  function bottomRow() {
    var candidates = controls();
    var rows = [];
    for (var i = 0; i < candidates.length; i++) {
      var element = candidates[i];
      if (OURS[element.id] || !element.parentElement) continue;
      var box = element.getBoundingClientRect();
      if (box.width < 20 || box.height < 20) continue;
      if (window.innerHeight - box.bottom > 130) continue;
      if (box.top < window.innerHeight * 0.7) continue;

      var row = null;
      for (var j = 0; j < rows.length; j++) {
        if (rows[j].parent === element.parentElement) row = rows[j];
      }
      if (!row) {
        row = { parent: element.parentElement, items: [] };
        rows.push(row);
      }
      row.items.push(element);
    }

    var best = null;
    for (var k = 0; k < rows.length; k++) {
      if (rows[k].items.length < 2) continue;
      if (!best || rows[k].items.length > best.items.length) best = rows[k];
    }
    if (best) {
      best.items.sort(function (a, b) {
        return a.getBoundingClientRect().left - b.getBoundingClientRect().left;
      });
    }
    return best;
  }

  /**
   * An icon in Instagram's own hand.
   *
   * The bar these sit in is a set of line drawings: one weight, one size, one
   * colour, inherited from whatever the page is wearing. Anything that does not
   * match that reads as a fault rather than as a control — which is what a bare
   * dot did, next to a gear.
   */
  function icon(shapes) {
    return (
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true" ' +
      'stroke="currentColor" stroke-width="1.6" stroke-linecap="round">' +
      shapes +
      "</svg>"
    );
  }

  function button(id, label, shapes, extra, onPress) {
    var element = document.createElement("button");
    element.id = id;
    element.type = "button";
    element.setAttribute("aria-label", label);
    // `all: unset` first, so none of Instagram's own button styling comes with
    // it, and nothing of ours leaks the other way. The icon inside is 24, which
    // is what everything else in these bars is.
    element.style.cssText =
      "all: unset; display: inline-flex; align-items: center; justify-content: center;" +
      "height: 44px; cursor: pointer; color: inherit; opacity: 0.85;" + extra;
    element.innerHTML = icon(shapes);
    element.addEventListener("click", function (event) {
      event.preventDefault();
      event.stopPropagation();
      onPress();
    });
    return element;
  }

  /**
   * Quiet's mark: a full stop set inside a ring.
   *
   * The icon is the app's own sentence — *that's all for today* — drawn at the
   * weight of the icons it stands among, so it reads as one of them rather than
   * as something that has gone wrong on the screen. A bare dot did not: at this
   * size, beside a gear, it looked like dust on the display.
   *
   * The numbers were drawn and looked at rather than guessed. The ring started
   * a point wider and the stop a third larger, which read as a record button;
   * matching the ring to the magnifying glass beside it, and shrinking the stop
   * inside it, turns it back into punctuation.
   */
  /**
   * A clock. Quiet is a limit on time, and a clock is the one drawing everybody
   * already reads as time — which beats a mark that has to be learned, however
   * much the full stop is the app's own.
   */
  var CLOCK_SHAPES =
    '<circle cx="12" cy="12" r="7.6"/>' +
    '<line x1="12" y1="12" x2="12" y2="7.6"/>' +
    '<line x1="12" y1="12" x2="15.6" y2="12"/>';

  var GLASS_SHAPES =
    '<circle cx="10.75" cy="10.75" r="7"/>' +
    '<line x1="15.9" y1="15.9" x2="20.5" y2="20.5"/>';

  /**
   * The two things Quiet puts into the navigation bar.
   *
   * The search Instagram took away, back in the slot its own search occupied —
   * that tab is the front door to Explore, so it stays shut, and this one opens
   * Quiet's, which returns people and nothing else. And the clock, at the end,
   * because settings belong somewhere you can always reach rather than on one
   * page you have to navigate to first.
   *
   * Both are given `flex: 1` so they share the bar the way its own items do
   * instead of squeezing them.
   */
  var toldBar = null;

  function placeBar() {
    var row = bottomRow();

    // Instagram drops its navigation on some screens — messages is the one
    // people notice. The app puts the two controls somewhere else on those
    // pages, and can only do that if it is told.
    var present = !!row;
    if (present !== toldBar) {
      toldBar = present;
      post({ kind: "bar", present: present });
    }

    if (document.getElementById(SEARCH_ID) && document.getElementById(CLOCK_ID)) return;
    if (!row) return;
    var share = "flex: 1 1 0; min-width: 44px;";

    if (!document.getElementById(SEARCH_ID)) {
      var glass = button(
        SEARCH_ID,
        window.__quietSearchLabel || "Find someone",
        GLASS_SHAPES,
        share,
        function () {
          post({ kind: "search" });
        }
      );
      row.items[0].insertAdjacentElement("afterend", glass);
    }

    if (!document.getElementById(CLOCK_ID)) {
      var clock = button(
        CLOCK_ID,
        window.__quietSettingsLabel || "Quiet settings",
        CLOCK_SHAPES,
        share,
        function () {
          post({ kind: "settings" });
        }
      );
      row.parent.appendChild(clock);
    }
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
      fitViewport();
      var main = document.querySelector("main");
      if (main) trimSuggestions(main);
      guardLocation();
      placeMark();
      placeBar();
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
