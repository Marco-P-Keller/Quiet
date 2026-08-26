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
  var BLOCKED = /^\/(reels?|tv|explore|directory)(\/|$)/;
  var SUGGESTED_ACCOUNTS = /^\/accounts\/suggested(\/|$)/;

  /** Which surface each of those roots belongs to. Mirrors the same table. */
  var ROOT_SURFACE = {
    reel: "reels",
    reels: "reels",
    /* IGTV's old address, kept alive as a redirect into the video player. */
    tv: "reels",
    explore: "explore",
    directory: "explore",
  };

  /**
   * Headings that mark a block Instagram inserted rather than one your friends
   * posted. Matched exactly, after trimming, so that a caption which merely
   * mentions the words is left alone.
   */
  var SUGGESTION_LABELS = [
    /* English */
    "suggested for you",
    "suggested posts",
    "suggested accounts",
    "suggested reels",
    "suggested threads",
    "reels",
    "discover people",
    /* German */
    "vorgeschlagene beiträge",
    "vorschläge für dich",
    "vorgeschlagen für dich",
    /* Spanish */
    "sugerencias para ti",
    "publicaciones sugeridas",
    /* French */
    "suggestions pour vous",
    "publications suggérées",
    /* Italian */
    "suggerimenti per te",
    "post suggeriti",
    /* Portuguese */
    "sugestões para você",
    "publicações sugeridas",
    /* Dutch */
    "voorgesteld voor jou",
    /* Swedish */
    "förslag för dig",
    /* Danish */
    "foreslået til dig",
    /* Norwegian */
    "foreslått for deg",
    /* Finnish */
    "ehdotuksia sinulle",
    /* Polish */
    "propozycje dla ciebie",
    "sugerowane posty",
    /* Czech */
    "návrhy pro vás",
    /* Romanian */
    "sugestii pentru tine",
    /* Hungarian */
    "javaslatok neked",
    /* Greek */
    "προτεινόμενα για εσένα",
    /* Turkish. The reason this file normalises before it compares: a capital
     * dotted I lower-cases to an i with a combining dot above, which is not
     * the letter anybody would write in a list like this one. */
    "senin için önerilenler",
    "sizin için önerilenler",
    "önerilen gönderiler",
    /* Russian */
    "рекомендации для вас",
    "рекомендуемые публикации",
    /* Ukrainian */
    "рекомендації для вас",
    /* Indonesian */
    "disarankan untuk anda",
    "postingan yang disarankan",
    /* Vietnamese */
    "gợi ý cho bạn",
    /* Arabic */
    "مقترح لك",
    "منشورات مقترحة",
    /* Hindi */
    "आपके लिए सुझाव",
    /* Thai */
    "แนะนำสำหรับคุณ",
    /* Japanese */
    "あなたへのおすすめ",
    "おすすめの投稿",
    /* Korean */
    "회원님을 위한 추천",
    /* Chinese, simplified and traditional */
    "为你推荐",
    "為你推薦",
  ];

  /**
   * One spelling of a phrase, so that two spellings of it match.
   *
   * The comparison used to be `trim().toLowerCase()`, which is right for
   * English and wrong in three different ways for everybody else:
   *
   *   * A Turkish capital dotted I lower-cases to an `i` followed by a
   *     combining dot above. Written the way a person writes it, no Turkish
   *     phrase in the list above could ever have matched a heading Instagram
   *     actually draws.
   *   * Instagram emits non-breaking spaces between words. `trim` removes them
   *     at the ends and nothing touches the ones in the middle, so a heading
   *     with one in it was a heading that got through.
   *   * An accent can be written more than one way in Unicode, and which one
   *     arrives is not something a page promises.
   *
   * Decomposing, dropping the combining marks and collapsing the whitespace
   * settles all three. It also makes the match accent-blind, which is a
   * slightly wider net than before — and the two guards that decide whether a
   * match may hide anything, that it is not inside a link and no longer than a
   * heading, are unchanged. The net is wider only where widening it is safe.
   */
  function normalise(text) {
    return (text || "")
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/\s+/g, " ")
      .trim()
      .toLowerCase();
  }

  var labelSet = Object.create(null);
  for (var i = 0; i < SUGGESTION_LABELS.length; i++) {
    labelSet[normalise(SUGGESTION_LABELS[i])] = true;
  }

  /** The Reels tab on a profile: /someone/reels/. */
  var PROFILE_REELS = /^\/[^/]+\/reels(\/|$)/;

  function surfaceFor(path) {
    var match = BLOCKED.exec(path);
    /* Looked up rather than worked out from the spelling. The old version
     * asked whether the root began with "reel" and called everything else
     * Explore, which was true for exactly as long as the table held four
     * entries — "tv" arrived and started announcing itself as Explore. */
    if (match) return ROOT_SURFACE[match[1]] || "explore";
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
    found("nav");
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
    letGo(link);
    return href;
  };

  /**
   * Let go of whatever the press left holding the focus.
   *
   * WebKit draws a focus ring around a focused element, and a click made by a
   * script reads to it as a keyboard one rather than a finger — so pressing
   * home from Quiet's row leaves the Instagram wordmark in a blue rectangle,
   * and the heuristic stays that way afterwards, so the next thing a *finger*
   * touches gets one too. Two photographs: the wordmark, and the name at the
   * top of a profile.
   *
   * The row is the app's own furniture. Pressing it is a navigation, not a
   * decision to put the cursor somewhere, and nothing about it should leave a
   * mark on the page.
   *
   * Three times, because a router that changes the screen puts the focus
   * somewhere of its own on the way. And never on something being typed in:
   * taking the keyboard away from somebody mid-word would be a far worse thing
   * than a blue rectangle.
   */
  function letGo(link) {
    var release = function () {
      if (link && link.blur) link.blur();
      var active = document.activeElement;
      if (!active || active === document.body) return;
      if (beingTypedIn(active)) return;
      if (active.blur) active.blur();
    };
    release();
    setTimeout(release, 0);
    setTimeout(release, 250);
  }

  function beingTypedIn(node) {
    var name = (node.tagName || "").toLowerCase();
    if (name === "input" || name === "textarea" || name === "select") return true;
    return node.getAttribute && node.getAttribute("contenteditable") === "true";
  }

  /* ── Somebody mid-sentence ────────────────────────────────────────────── */

  /**
   * Say when a message is being typed, and when it stops.
   *
   * For one thing only: the end of the day arriving while somebody is halfway
   * through a sentence takes the sentence with it. That is not strict, it is
   * rude — and the app can be strict without being rude. What the app does
   * with this is in `QuietSession`, and it is capped there.
   *
   * The page is the only place that knows. A keyboard is not a fact the app can
   * see, and the field being typed in belongs to Instagram.
   */
  var typing = false;

  function sayTyping(on) {
    if (on === typing) return;
    typing = on;
    post({ kind: "typing", on: on });
  }

  function watchForTyping() {
    document.addEventListener("focusin", function (event) {
      if (beingTypedIn(event.target)) sayTyping(true);
    }, true);
    document.addEventListener("focusout", function () {
      /* On the next turn, because moving between two fields blurs one before it
       * focuses the other, and a gap of one frame is not somebody stopping. */
      setTimeout(function () {
        var here = document.activeElement;
        sayTyping(!!here && beingTypedIn(here));
      }, 0);
    }, true);
  }

  /** The name the app used before there were three of them. */
  window.__quietOpenProfile = function () {
    return window.__quietGo("profile");
  };

  /**
   * Start the page below the clock, for the case where the app has handed it
   * a screen that begins at the top of the glass.
   *
   * It does not any more — the web view is given a frame that starts under the
   * clock and stops above the row, so the page's own world already begins in
   * the right place and the number arrives as zero. The rule stays because the
   * two are independent: the app decides how much of the glass the page gets,
   * this decides what the page does with a strip it has been given and does not
   * own, and a future where those differ should not need this written again.
   *
   * Set as a custom property rather than as a style, so the rule that uses it
   * lives in trim.css with every other rule, where it can be read.
   */
  function makeRoom() {
    var style = document.documentElement.style;
    var top = window.__quietTop;
    if (top) style.setProperty("--quiet-top", top + "px");
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
    // A new page: nothing has been found on it yet, and one more has gone by
    // for the tally to be read against.
    tally.pages += 1;
    here = { nav: false, header: false };
    post({ kind: "where", path: lastPath });
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
    found("header");

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
      // And the row, which is the safety valve on the whole sheet question. A
      // page that is scrolling is a page that is not locked, so if the app is
      // holding its row down for a modal that has since gone — because the
      // closing never showed up as a mutation, or because Instagram forgot to
      // unlock — the first flick of a thumb puts it back. The row is the only
      // way to Quiet's own settings, and it must never be possible to be
      // stranded without it.
      saySheet();
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

  /* ── Something modal, and nothing done about it ───────────────────────── */

  /**
   * Whether Instagram has a sheet up, said once and acted on by nobody here.
   *
   * Instagram puts one up for switching accounts, for sharing, and for the menu
   * behind the three dots. It covers the foot of the glass, which is where
   * Quiet's own row floats, and the row is drawn straight across the last
   * button on it.
   *
   * Eleven mechanisms went into fixing that and every one of them *moved
   * something of Instagram's* — pad the panel, transform it, give it a margin,
   * take the glass away underneath it. Each had to recognise the sheet before
   * it could touch it, and recognition failed in both directions: it missed the
   * account switcher for eight rounds, because Instagram never says a sheet is
   * one; then it caught the inbox and moved a list of conversations up over its
   * own header.
   *
   * This does none of that. Nothing here is marked, moved, padded, lifted or
   * hidden. The page answers one question and the app decides what to do about
   * its own furniture — which is what makes recognition affordable again. A
   * wrong answer now costs a row that fades for a moment. It used to cost a
   * page that came back broken.
   */
  var MODAL = '[role="dialog"], [aria-modal="true"], dialog[open]';

  /* Tall enough to be a sheet rather than a bar, and short enough to be a sheet
   * rather than the dimmed backdrop around one. */
  var SHEET_SHORTEST = 120;
  /* How far above the bottom edge a sheet may stop and still be one. */
  var SHEET_FOOT = 48;

  /* False rather than nothing, so a screen with no sheet on it says nothing at
   * all. The app starts from the same answer, and a message that only ever
   * confirms the obvious is a message worth not sending. */
  var lastSheet = false;

  function saySheet() {
    var up = !!theSheet();
    if (up === lastSheet) return;
    lastSheet = up;
    post({ kind: "sheet", up: up });
  }

  function theSheet() {
    return theSheetItSaysItIs() || theSheetByItsShape() || theLockedPage();
  }

  /**
   * The page itself, stopped — which is the most reliable of the three and the
   * only one that needs nothing of Instagram's markup to be true.
   *
   * A photograph of the real account switcher, on a build that had the two
   * tests above, came back with the pill still drawn through "Log in to an
   * Existing Account". So the shape test did not find it, and the honest
   * reading is that it never will reliably: it turns on where the panel sits in
   * somebody else's tree and what `position` they gave it, and both are theirs
   * to change on any Tuesday.
   *
   * What is not theirs to change is what a modal *is*. Every one of them stops
   * the page behind it from scrolling, because a background that scrolls under
   * a sheet is the oldest bug on the mobile web — so they set `overflow:
   * hidden`, or the iOS trick of pinning the body. That is a fact about the
   * document, in the document's own stylesheet, and it is exactly as true for a
   * sheet Instagram ships next month.
   *
   * It cannot catch the inbox, which is what the shape test caught: a list of
   * conversations scrolls, and a page that scrolls is not locked. Nothing in
   * trim.css sets `overflow` on either element, so the only hand that can have
   * written it is Instagram's.
   */
  function theLockedPage() {
    return scrollIsLocked() ? document.body : null;
  }

  function scrollIsLocked() {
    if (!document.body) return false;
    var body = window.getComputedStyle(document.body);
    /* Pinning the body is how the mobile web stops iOS scrolling a background,
     * and it is never done for any other reason. */
    if (body.position === "fixed") return true;
    if (body.overflow === "hidden" || body.overflowY === "hidden") return true;
    var root = window.getComputedStyle(document.documentElement);
    return root.overflow === "hidden" || root.overflowY === "hidden";
  }

  /** The easy half, and the one Instagram is under no obligation to give. */
  function theSheetItSaysItIs() {
    var modals = document.querySelectorAll(MODAL);
    for (var i = 0; i < modals.length; i += 1) {
      if (isSheet(modals[i], true)) return modals[i];
    }
    return null;
  }

  /**
   * The hard half: ask the screen what is drawn over the foot of the glass.
   *
   * Three columns rather than one, because a sheet is full width and something
   * of Instagram's own may be over the middle of it. Shallowest first, so what
   * is found is the panel rather than a button inside it that happens to end in
   * the same place.
   */
  function theSheetByItsShape() {
    if (!document.elementsFromPoint) return null;
    var width = window.innerWidth || 390;
    var height = window.innerHeight || 844;
    var columns = [
      Math.round(width * 0.2),
      Math.round(width / 2),
      Math.round(width * 0.8)
    ];
    for (var c = 0; c < columns.length; c += 1) {
      var stack = document.elementsFromPoint(columns[c], height - 8) || [];
      for (var i = stack.length - 1; i >= 0; i -= 1) {
        if (isSheet(stack[i], false)) return stack[i];
      }
    }
    return null;
  }

  /**
   * What makes something a sheet rather than a part of the page.
   *
   * `declared` relaxes the shape but never the two refusals below it: something
   * that says it is modal is believed about being modal, not about being
   * somewhere it is not.
   */
  function isSheet(node, declared) {
    if (!node || !node.getAttribute) return false;
    if (node === document.body || node === document.documentElement) return false;
    if (ours(node)) return false;
    /* Page content is never a sheet, however much it looks like one. A sheet is
     * put in *front* of the page, and the page is what is inside `main` — which
     * is exactly where the inbox keeps its list of conversations, the thing an
     * earlier version of this took for a sheet and moved. */
    if (insideThePage(node)) return false;

    var box = node.getBoundingClientRect();
    if (!box || box.width <= 0 || box.height <= 0) return false;

    var width = window.innerWidth || 390;
    var height = window.innerHeight || 844;
    /* A sheet spans the glass. A card, a toast and a menu tucked into a corner
     * do not. */
    if (box.width < width * 0.9) return false;
    if (box.bottom < height - SHEET_FOOT) return false;
    if (declared) return true;

    if (box.height < SHEET_SHORTEST) return false;
    /* As tall as the glass is the backdrop, not the sheet. */
    if (box.height > height - SHEET_FOOT) return false;
    var style = window.getComputedStyle(node);
    if (style.position !== "fixed" &&
        style.position !== "absolute" &&
        style.position !== "sticky") return false;
    /* Something to press. A sheet is a question; a spacer is not. */
    return !!node.querySelector('a, button, [role="button"], input');
  }

  /** Anything Quiet has drawn or already dealt with. */
  function ours(node) {
    if (node.id && node.id.indexOf("quiet-") === 0) return true;
    if (node.getAttribute("data-quiet-hidden") !== null) return true;
    if (node.getAttribute("data-quiet-floor") !== null) return true;
    return false;
  }

  function insideThePage(node) {
    var main = document.querySelector("main");
    return !!main && main.contains(node);
  }

  /**
   * Ask again for a moment, because a sheet arrives by sliding and a slide is
   * not a mutation.
   *
   * The observer hears the panel go into the document, and at that moment the
   * panel is still below the bottom edge with a transform on it; nothing in the
   * document changes while it travels. So the pass above runs exactly once, at
   * the one instant the honest answer is that there is no sheet. That was the
   * whole of the eighth photograph, and it explains the seven before it: every
   * one of them changed what the app *did* about a sheet, and none of them
   * changed whether the app ever heard about one.
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

  /* ── Whether any of this is still working ─────────────────────────────── */

  /**
   * A tally, so that the app can notice its own failure.
   *
   * This is the one hole the whole approach has. `ContentRules` matches on
   * addresses and will keep working; everything else here recognises Instagram
   * by its shape, and the day Instagram changes that shape the recognising
   * simply stops finding anything. Nothing throws. Nothing logs. The row along
   * the bottom falls back to Quiet's own symbols, the suggestion blocks come
   * back, and the app goes on looking exactly like an app that is working.
   *
   * So the script counts what it found. Not to fix anything — it cannot — but
   * so that "Instagram changed something and Quiet has not caught up" is a
   * sentence the app can say rather than a thing somebody has to notice while
   * scrolling a real feed.
   *
   * Counted per page rather than per frame. The trim pass runs on every
   * mutation, and a count of frames would say a great deal about how busy
   * Instagram's client is and nothing about whether anything was found.
   */
  var tally = { pages: 0, nav: 0, headers: 0, hidden: 0 };

  /** What has already been found on the page currently open. */
  var here = { nav: false, header: false };

  var lastTally = "";

  function found(what) {
    if (here[what]) return;
    here[what] = true;
    tally[what === "nav" ? "nav" : "headers"] += 1;
  }

  function sayHealth() {
    var line = [tally.pages, tally.nav, tally.headers, tally.hidden].join(":");
    if (line === lastTally) return;
    lastTally = line;
    post({
      kind: "health",
      pages: tally.pages,
      nav: tally.nav,
      headers: tally.headers,
      hidden: tally.hidden,
    });
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

      var text = normalise(element.textContent);
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
        if (block.getAttribute("data-quiet-hidden") !== "suggestion") {
          tally.hidden += 1;
        }
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
      sayHealth();
      // Last, because Instagram's own bottom navigation and its door back into
      // the app are both full-width things at the foot of the glass — which is
      // to say, both indistinguishable from a sheet right up until the calls
      // above mark them.
      saySheet();
      settle();
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

  watchForTyping();

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
