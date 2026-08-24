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
    ///   `giveTheSheetRoom` in trim.js.
    static func load(from bundle: Bundle = .main, top: CGFloat, row: CGFloat) -> Payload {
        var scripts: [WKUserScript] = []
        var missing: [String] = []

        if let css = text(named: "trim", extension: "css", in: bundle) {
            scripts.append(userScript(source: styleInjector(css: css)))
        } else {
            missing.append("trim.css")
        }

        // The three numbers the page needs from the app, injected before the
        // trim runs so that all of them are there before its first paint.
        //
        // A fourth used to be here: the name of Quiet's own settings, for a mark
        // the script drew beside Instagram's on your own profile. That door is
        // in the row along the bottom now, on every page rather than on one, so
        // the string it was announced under has nothing left to label.
        scripts.append(userScript(source: """
        window.__quietAppID = \(quoted(WebScripts.appID));
        window.__quietTop = \(Int(top.rounded()));
        window.__quietRow = \(Int(row.rounded()));
        """))

        if let js = text(named: "trim", extension: "js", in: bundle) {
            scripts.append(userScript(source: js))
        } else {
            missing.append("trim.js")
        }

        assert(missing.isEmpty, "Quiet is missing \(missing.joined(separator: ", ")) from its bundle.")
        return Payload(scripts: scripts, missing: missing)
    }

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
