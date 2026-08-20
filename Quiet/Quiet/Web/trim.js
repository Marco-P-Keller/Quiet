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

  /* ── What Quiet puts back ────────────────────────────────────────────── */

  var MARK_ID = "quiet-mark";
  var SEARCH_ID = "quiet-search";

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
  function controlNear(test) {
    var candidates = document.querySelectorAll('a[href], button, [role="button"], [role="link"]');
    for (var i = 0; i < candidates.length; i++) {
      var element = candidates[i];
      if (element.id === MARK_ID || element.id === SEARCH_ID) continue;
      var box = element.getBoundingClientRect();
      if (box.width < 16 || box.height < 16 || box.width > 120) continue;
      if (test(box)) return element;
    }
    return null;
  }

  function button(id, label, onPress) {
    var element = document.createElement("button");
    element.id = id;
    element.type = "button";
    element.setAttribute("aria-label", label);
    // `all: unset` first, so none of Instagram's own button styling comes with
    // it, and nothing of ours leaks the other way.
    element.style.cssText =
      "all: unset; display: inline-flex; align-items: center; justify-content: center;" +
      "cursor: pointer; vertical-align: middle; color: inherit;";
    element.addEventListener("click", function (event) {
      event.preventDefault();
      event.stopPropagation();
      onPress();
    });
    return element;
  }

  /**
   * A full stop — the same one on the app's icon — beside Instagram's settings,
   * on your own profile and nowhere else. Drawn by the page rather than by the
   * app so it sits at whatever size and spacing Instagram is using today, and
   * scrolls away with the header it belongs to.
   */
  function placeMark() {
    var existing = document.getElementById(MARK_ID);
    if (!isOwnProfile()) {
      if (existing) existing.remove();
      return;
    }
    if (existing && existing.isConnected) return;
    // Only while the header is actually at the top of the screen, or the
    // "top-left corner" is whatever happens to have scrolled into it.
    if (window.scrollY > 40) return;

    var settings = controlNear(function (box) {
      return box.top < 90 && box.left < 90;
    });
    if (!settings || !settings.parentElement) return;

    var mark = button(MARK_ID, window.__quietSettingsLabel || "Quiet settings", function () {
      post({ kind: "settings" });
    });
    mark.style.cssText += "width: 34px; height: 34px;";

    var dot = document.createElement("span");
    dot.style.cssText =
      "display: block; width: 6px; height: 6px; border-radius: 50%;" +
      "background: currentColor; opacity: 0.4;";
    mark.appendChild(dot);

    settings.insertAdjacentElement("afterend", mark);
  }

  /**
   * The search Instagram took away, put back where it was.
   *
   * Its own search tab is the front door to Explore, so it stays shut. This one
   * opens Quiet's, which returns people and nothing else. The slot is found by
   * the home button in the navigation bar, and the glass goes immediately after
   * it — which is exactly where Instagram's own search has always been.
   */
  function placeSearch() {
    var existing = document.getElementById(SEARCH_ID);
    if (existing && existing.isConnected) return;

    var home = controlNear(function (box) {
      return window.innerHeight - box.bottom < 120 && box.left < window.innerWidth / 4;
    });
    if (!home || !home.parentElement) return;

    var glass = button(SEARCH_ID, window.__quietSearchLabel || "Find someone", function () {
      post({ kind: "search" });
    });
    glass.style.cssText += "width: 44px; height: 44px;";
    glass.innerHTML =
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">' +
      '<circle cx="10.5" cy="10.5" r="7" stroke="currentColor" stroke-width="2"/>' +
      '<line x1="15.8" y1="15.8" x2="21" y2="21" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>' +
      "</svg>";

    home.insertAdjacentElement("afterend", glass);
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
      guardLocation();
      placeMark();
      placeSearch();
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
