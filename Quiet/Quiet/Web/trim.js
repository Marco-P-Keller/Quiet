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
 *   3. Push whatever the page pins to the top of the screen below the clock.
 *   4. Take out Instagram's navigation bar, having first read the signed-in
 *      name out of it, because Quiet carries all five entries in a row of its
 *      own that no stylesheet of Instagram's can reach.
 *   5. Put Quiet's clock beside Instagram's own settings, on your profile.
 *      Found by where it sits on the screen rather than by what it is called,
 *      because a corner does not change with the language or with next week's
 *      generated class names. Everything else Quiet needs is in the app's own
 *      row along the bottom, where no stylesheet of Instagram's can reach it.
 *   6. Keep all of it up as the page rewrites itself, because Instagram's web
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

  /* ── The status bar ──────────────────────────────────────────────────── */

  /**
   * Push whatever the page pins to the top of the screen below the clock.
   *
   * The content inset holds the page down while it is at rest, and that is
   * where two earlier attempts stopped — which is why this looked fixed until
   * somebody scrolled. A sticky header does not live in the content: it pins
   * itself to the top of the viewport, and the viewport starts at the top of
   * the glass. So the moment the feed moved, Instagram's header climbed back
   * under the clock.
   *
   * The element is found by asking what is actually drawn at the very top of
   * the screen, rather than by guessing at markup — one call, no walking the
   * document — and only something as wide as the screen is treated as a bar.
   * Setting its `top` to the same inset makes the two agree: below the clock at
   * rest, below the clock while scrolling.
   */
  function liftPinned() {
    var inset = window.__quietTopInset || 0;
    if (!inset) return;

    var stack = document.elementsFromPoint(window.innerWidth / 2, 2);
    for (var i = 0; i < stack.length; i++) {
      var element = stack[i];
      if (element.hasAttribute("data-quiet-lifted")) return;
      var position = getComputedStyle(element).position;
      if (position !== "sticky" && position !== "fixed") continue;
      if (element.getBoundingClientRect().width < window.innerWidth * 0.6) continue;

      element.setAttribute("data-quiet-lifted", "");
      element.style.setProperty("top", inset + "px", "important");
      return;
    }
  }

  /**
   * The link nearest the top of the screen that goes where `matches` says.
   */
  function highest(matches) {
    var best = null;
    var bestTop = Infinity;
    var links = document.querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i++) {
      if (!matches(links[i].getAttribute("href") || "")) continue;
      var box = links[i].getBoundingClientRect();
      if (box.height === 0) continue;
      if (box.top < bestTop) {
        bestTop = box.top;
        best = links[i];
      }
    }
    return best;
  }

  /**
   * Take out the feed's own header.
   *
   * Three attempts to make Instagram's header sit below the clock, and it kept
   * climbing back the moment the page moved. The header holds a wordmark, a
   * button for posting — which this app cannot do anyway — and the activity
   * heart, which is a hook by construction. None of it is worth a fourth
   * attempt, and without it there is nothing pinned to the top of the screen at
   * all: the collision cannot happen again.
   *
   * Only the feed's. It is recognised by the wordmark, a link to "/" in a bar
   * as wide as the screen that the page has pinned there. A profile or a
   * conversation carries a back button and a title in its top bar and no link
   * home, so those are left alone.
   */
  function hideFeedHeader() {
    var wordmark = highest(function (href) { return href === "/"; });
    if (!wordmark) return;

    var node = wordmark;
    while (node && node !== document.body) {
      var box = node.getBoundingClientRect();
      var position = getComputedStyle(node).position;
      if (
        box.top < 90 &&
        box.width >= window.innerWidth * 0.9 &&
        box.height <= 160 &&
        (position === "sticky" || position === "fixed")
      ) {
        if (node.getAttribute("data-quiet-hidden") !== "header") {
          node.setAttribute("data-quiet-hidden", "header");
        }
        return;
      }
      node = node.parentElement;
    }
  }

  /* ── What Quiet puts back ────────────────────────────────────────────── */

  var MARK_ID = "quiet-mark";
  var OURS = { "quiet-mark": true };

  /* ── Instagram's own navigation ───────────────────────────────────────── */

  /**
   * The row along the bottom.
   *
   * Found by two links that are certainly in it — one to "/" and one to
   * "/direct/" — and then by taking, for each, the one *lowest on the screen*.
   * That last part is the whole of it: Instagram's wordmark at the top of the
   * feed is also a link to "/", and it comes first in the document. Walking up
   * from the wordmark to something that also contains the messages link lands
   * on a container holding most of the page, and everything downstream then
   * reads the wrong thing out of it.
   *
   * The guard below says the same thing a second way: a navigation bar has a
   * handful of links in it, not fifty.
   */
  function lowest(matches) {
    var best = null;
    var bestBottom = -Infinity;
    var links = document.querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i++) {
      if (!matches(links[i].getAttribute("href") || "")) continue;
      var box = links[i].getBoundingClientRect();
      if (box.height === 0) continue;
      if (box.bottom > bestBottom) {
        bestBottom = box.bottom;
        best = links[i];
      }
    }
    return best;
  }

  function navRow() {
    var home = lowest(function (href) { return href === "/"; });
    var direct = lowest(function (href) { return href.indexOf("/direct/") === 0; });
    if (!home || !direct) return null;

    var node = home.parentElement;
    while (node && node !== document.body && !node.contains(direct)) {
      node = node.parentElement;
    }
    if (!node || node === document.body) return null;
    // A bar, not a page.
    if (node.querySelectorAll("a[href]").length > 12) return null;
    return node;
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
        post({ kind: "me", username: name });
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
      var match = /^\/([A-Za-z0-9._]{1,30})\/?$/.exec(links[i].getAttribute("href") || "");
      if (!match) continue;
      if (window.__quietMe === match[1]) return;
      window.__quietMe = match[1];
      post({ kind: "me", username: match[1] });
      return;
    }
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
      whoAmI();
      hideFeedHeader();
      liftPinned();
      replaceNav();
      placeMark();
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
  // A header only climbs under the clock once the page moves, so the page
  // moving is exactly when to look. Cheap: `schedule` waits for a frame.
  window.addEventListener("scroll", schedule, { passive: true });

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
