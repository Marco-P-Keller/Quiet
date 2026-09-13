import UIKit
import WebKit
import XCTest
@testable import Quiet

/// That a page stops where the keyboard starts.
///
/// This is the conversation header that went away the moment somebody answered
/// a message, and the reason it is answered here rather than in the stylesheet.
/// An iOS keyboard does not shorten the box a page is laid out against: it
/// leaves that box the height of the glass and slides the visible part down
/// inside it, so everything at the top of the page goes above the screen.
/// Measured on a page built the way a conversation is:
///
///                                visualViewport.offsetTop   the bar's own top
///     no keyboard                              0                     62
///     keyboard up                            249                   −187
///     keyboard up, the view shortened          0                     62
///
/// The first attempt at this added that 249 to the `top` of whatever trim.js
/// had found pinned to the glass. It was measured, it worked on the page it was
/// measured on, and it did nothing whatsoever on the real site — a `top` is
/// only worth something to an element that is `fixed` or `sticky`, and a
/// conversation's bar is the first row of an app shell, which is neither. So
/// the thing that is shortened is the view, which has an opinion about nobody's
/// markup.
@MainActor
final class PaneRoomTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    /// The glass, a container filling it, and a field standing in the container
    /// the way a page's own field does.
    private func stage() throws -> (PaneContainer, UITextField) {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.windowLevel = .normal + 1

        let container = PaneContainer()
        container.frame = window.bounds
        window.addSubview(container)

        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 402, height: 44))
        container.addSubview(field)
        window.makeKeyAndVisible()
        self.window = window
        return (container, field)
    }

    /// A keyboard, said the way UIKit says it: a frame in the screen's space.
    private func keyboard(topAt top: CGFloat, for container: PaneContainer) {
        let glass = container.bounds
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(
                    x: 0, y: top, width: glass.width, height: glass.height - top
                )),
                UIResponder.keyboardAnimationDurationUserInfoKey: 0.0,
            ]
        )
        container.layoutIfNeeded()
    }

    func testAPageFillsTheContainerWhenNothingIsInTheWay() throws {
        let (container, _) = try stage()
        container.layoutIfNeeded()
        XCTAssertEqual(container.subviews.first?.frame, container.bounds)
    }

    /// The whole of the fix.
    func testAPageStopsWhereTheKeyboardStarts() throws {
        let (container, field) = try stage()
        field.becomeFirstResponder()

        keyboard(topAt: 529, for: container)

        XCTAssertEqual(
            container.subviews.first?.frame.height, 529,
            """
            The page is still the height of the glass with a keyboard over it. \
            WebKit will slide it up to reveal the field, and everything at the \
            top of the page — a conversation's header — goes with it.
            """
        )
    }

    /// And gets it back.
    func testTheRoomComesBackWhenTheKeyboardGoes() throws {
        let (container, field) = try stage()
        field.becomeFirstResponder()
        keyboard(topAt: 529, for: container)
        XCTAssertEqual(container.subviews.first?.frame.height, 529)

        // Which is how UIKit says a keyboard is leaving: a frame below the
        // bottom of the screen. The field has already resigned by then.
        field.resignFirstResponder()
        keyboard(topAt: container.bounds.maxY, for: container)

        XCTAssertEqual(container.subviews.first?.frame, container.bounds)
    }

    /// A keyboard belonging to one of Quiet's own screens leaves the page
    /// alone.
    ///
    /// The app has fields of its own — the one that finds somebody — and they
    /// are drawn over the page rather than in it. Shortening a page nobody can
    /// see is a relayout of Instagram for nothing, and hands the feed back at a
    /// different place than it was left at.
    func testAKeyboardThatIsNotThePagesChangesNothing() throws {
        let (container, _) = try stage()

        // Standing in the window beside the container, the way one of Quiet's
        // own screens does.
        let mine = UITextField(frame: CGRect(x: 0, y: 0, width: 402, height: 44))
        window?.addSubview(mine)
        mine.becomeFirstResponder()

        keyboard(topAt: 529, for: container)

        XCTAssertEqual(container.subviews.first?.frame, container.bounds)
    }

    /// The page the app actually puts in there, rather than a stand-in.
    func testAWebViewIsGivenTheSameRoom() throws {
        let (container, _) = try stage()
        container.subviews.forEach { $0.removeFromSuperview() }

        let webView = WKWebView(frame: .zero)
        container.addSubview(webView)
        let field = UITextField(frame: .zero)
        container.addSubview(field)
        field.becomeFirstResponder()

        keyboard(topAt: 529, for: container)

        XCTAssertEqual(webView.frame.height, 529)
    }
}
