import Foundation
import WebKit

/// The two files Quiet injects into every Instagram page, and the machinery to
/// get them there.
///
/// Both are real `.css` and `.js` files in the bundle rather than strings buried
/// in Swift, because they are the part of the app most likely to need a change
/// when Instagram moves something, and they should be editable by someone who
/// opens the project and reads.
enum WebScripts {
    /// The name the page uses to talk back to the app.
    static let messageHandler = "quiet"

    /// The identifier Instagram's own web client sends with its requests.
    /// Without it the newer endpoints answer 403 and no explanation.
    static let appID = "936619743392459"

    struct Payload {
        var scripts: [WKUserScript]
        /// Resources that could not be found. Never empty in a broken build, and
        /// never ignored: a missing trim file means Reels quietly reappear, which
        /// is the one failure this app must not have.
        var missing: [String]
    }

    /// - Parameter top: the height of the status bar, in points.
    ///
    ///   The page is given the whole screen, so the first thing in the document
    ///   would otherwise be drawn under the clock. Instagram's own app solves
    ///   this by starting its content below the status bar and letting it
    ///   scroll up behind it, and that is a property of the *page*, not of the
    ///   view it is drawn in — which is why it is handed over as a number here
    ///   rather than taken out of the web view as an inset. An inset shortens
    ///   what the page is given; this does not.
    ///
    /// - Parameter row: how much of the bottom of the glass Quiet's own row
    ///   stands on, in points.
    ///
    ///   Nothing is asked of the document with it. The page runs on beneath the
    ///   row, which is where Instagram's next photograph belongs, and the only
    ///   thing that cannot run on beneath it is a sheet: a sheet is pinned to
    ///   the bottom edge of the glass, so the buttons on it come up under the
    ///   row. The page is the only place that can be fixed, because a sheet is
    ///   the page's, and this is the number it needs to do it. Two shapes of
    ///   row, two heights, and nothing at all on the screens that own the
    ///   bottom edge — so it is handed over rather than written down. See
    ///   `saySheet` in trim.js.
    ///
    /// - Parameter lift: how much of the bottom of the glass the app has
    ///   already taken away for a sheet, in points.
    ///
    ///   Zero everywhere except under a sheet. It is the other half of the
    ///   number above: while the strip is gone the row is standing on the app's
    ///   own paint rather than on the page, and the page's answer to "is
    ///   anything on this sheet still under the row" has to be asked about
    ///   what is left of the row over the page. Without it the answer is the
    ///   same before and after the room is made — the sheet and the floor it is
    ///   measured against both rise by exactly the same amount — and the row
    ///   would stand down for as long as a sheet was open. See `rowOverThePage`
    ///   in trim.js.
    static func load(
        from bundle: Bundle = .main,
        top: CGFloat,
        row: CGFloat,
        lift: CGFloat = 0
    ) -> Payload {
        var scripts: [WKUserScript] = []
        var missing: [String] = []

        if let css = text(named: "trim", extension: "css", in: bundle) {
            scripts.append(userScript(source: styleInjector(css: css)))
        } else {
            missing.append("trim.css")
        }

        // The four numbers the page needs from the app, injected before the
        // trim runs so that all of them are there before its first paint.
        //
        // A fifth used to be here: the name of Quiet's own settings, for a mark
        // the script drew beside Instagram's on your own profile. That door is
        // in the row along the bottom now, on every page rather than on one, so
        // the string it was announced under has nothing left to label.
        scripts.append(userScript(source: """
        window.__quietAppID = \(quoted(WebScripts.appID));
        window.__quietTop = \(Int(top.rounded()));
        window.__quietRow = \(Int(row.rounded()));
        window.__quietLift = \(Int(lift.rounded()));
        """))

        if let js = text(named: "trim", extension: "js", in: bundle) {
            scripts.append(userScript(source: js))
        } else {
            missing.append("trim.js")
        }

        #if DEBUG
        // A sheet that is not Instagram's, for a machine to photograph.
        //
        // Eight rounds of this were settled by building, uploading, installing
        // and looking, and every one came back with the same picture — which is
        // what a chain of seven mechanisms looks like when any link in it fails,
        // and says nothing about which link. A sheet the shape of Instagram's,
        // put on the real page by a rehearsal, turns twenty minutes and somebody
        // else's eyes into nine minutes and a number.
        if Rehearsal.showsASheet {
            scripts.append(rehearsedSheet())
        }
        #endif

        assert(missing.isEmpty, "Quiet is missing \(missing.joined(separator: ", ")) from its bundle.")
        return Payload(scripts: scripts, missing: missing)
    }

    #if DEBUG
    /// Built to the shape the tests describe: held against the bottom of the
    /// glass, the width of it, tall enough to be a sheet and far short of the
    /// screen, and saying nothing anywhere about being modal — which is the case
    /// that went unasked for seven rounds.
    ///
    /// Its foot is a bright band on purpose. A photograph answers the only
    /// question that matters in one measurement: how far is the bottom of this
    /// sheet's content from the bottom of the screen?
    private static func rehearsedSheet() -> WKUserScript {
        WKUserScript(
            source: sheetSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    private static let sheetSource = """
    (function () {
      function put() {
        if (!document.body) return;
        if (document.getElementById("rehearsed-sheet")) return;
        var sheet = document.createElement("div");
        sheet.id = "rehearsed-sheet";
        sheet.setAttribute("style", [
          // Placed by a number worked out when it opened, not anchored to
          // the bottom — which is the shape Instagram's turned out to be, and
          // the one a shorter viewport cuts instead of moving. If the rehearsed
          // sheet were anchored, it would pass a test the real one fails.
          "position: fixed", "left: 0", "right: 0",
          "top: calc(100% - 260px)",
          "height: 260px", "background: rgb(38, 38, 38)",
          "border-radius: 14px 14px 0 0", "z-index: 2147483000",
          "display: flex", "flex-direction: column",
          "justify-content: flex-end"
        ].join(";"));
        var foot = document.createElement("button");
        foot.setAttribute("style", [
          "height: 24px", "margin: 0", "border: 0", "padding: 0",
          "width: 100%", "background: rgb(255, 0, 128)"
        ].join(";"));
        sheet.appendChild(foot);
        // A child anchored to the viewport, the way Instagram's sheet anchors
        // its heading — and the thing a transform quietly re-anchors, because
        // an element with a transform becomes the containing block for every
        // fixed thing inside it. A photograph of that came back with the
        // sheet's contents piled on top of each other. If this mark leaves the
        // top of the screen, the mechanism has done it again.
        var pinned = document.createElement("div");
        pinned.id = "rehearsed-pin";
        pinned.setAttribute("style", [
          "position: fixed", "top: 300px", "left: 0",
          "width: 40px", "height: 20px", "background: rgb(0, 255, 255)"
        ].join(";"));
        sheet.appendChild(pinned);
        document.body.appendChild(sheet);
      }
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", put);
      } else {
        put();
      }
      setTimeout(put, 1500);
      setTimeout(put, 4000);
    })();
    """
    #endif

    private static func userScript(source: String) -> WKUserScript {
        WKUserScript(
            source: source,
            // Before the page's own scripts run, in every frame, so an embedded
            // player never gets a chance to appear first.
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    private static func text(named name: String, extension ext: String, in bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text
    }

    /// Wraps the stylesheet in the smallest script that will attach it before the
    /// first paint.
    private static func styleInjector(css: String) -> String {
        """
        (function () {
          var style = document.createElement("style");
          style.setAttribute("data-quiet", "trim");
          style.textContent = \(quoted(css));
          (document.head || document.documentElement).appendChild(style);
        })();
        """
    }

    /// A JavaScript string literal for arbitrary text.
    private static func quoted(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed]),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }
}
