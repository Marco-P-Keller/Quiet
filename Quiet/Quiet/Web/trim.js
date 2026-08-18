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
 *   3. Keep doing both as the page rewrites itself, because Instagram's web
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

  function tell(surface) {
    try {
      window.webkit.messageHandlers.quiet.postMessage({
        kind: "refused",
        surface: surface,
      });
    } catch (error) {
      /* The app is not listening. Refusing the tap still worked. */
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

  var inspected = new WeakSet();

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
      if (inspected.has(element)) continue;
      inspected.add(element);

      var text = (element.textContent || "").trim().toLowerCase();
      if (!text || text.length > 40 || !labelSet[text]) continue;
      if (isCaption(element)) continue;

      var block =
        element.closest("article") ||
        element.closest("section") ||
        element.parentElement;
      if (block && block !== root) {
        block.setAttribute("data-quiet-hidden", "suggestion");
      }
    }
  }

  /* ── 3. Keep up with the page ─────────────────────────────────────────── */

  var pending = false;

  function schedule() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(function () {
      pending = false;
      var main = document.querySelector("main");
      if (main) trimSuggestions(main);
      guardLocation();
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
