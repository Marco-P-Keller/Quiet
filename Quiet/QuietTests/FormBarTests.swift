import WebKit
import XCTest
@testable import Quiet

/// That the bar really is gone, and that the page is still where it was.
///
/// Both halves matter, and the second half is the one that was learned the hard
/// way. The first attempt at `FormBar` answered `inputAccessoryView` with `nil`
/// and passed every test written for it — there was no bar, the property said
/// so — and it left the message box **behind the keyboard**, because WebKit
/// stops resizing the page for a keyboard whose responder offers no accessory
/// at all. A test suite that only asks "is the bar gone" is green for that.
///
/// So this file asks three things instead of one: that WebKit still puts a bar
/// up when nobody has interfered, that nothing bar-shaped is drawn anywhere in
/// the app once `FormBar` has run, and that the page still ends exactly where
/// the keyboard begins. The first is what keeps the other two honest the day
/// WebKit stops offering a bar; the third is the one that would have caught the
/// first attempt.
@MainActor
final class FormBarTests: XCTestCase {
    /// Kept for the length of a test: a field only holds the keyboard while the
    /// view it is in is in a window, and the window is key.
    private var windows: [UIWindow] = []
    private var webViews: [WKWebView] = []

    /// What UIKit said the keyboard's frame was, which includes its accessory.
    private var keyboard: CGRect = .zero
    private var listener: NSObjectProtocol?

    override func tearDown() {
        webViews.forEach { $0.endEditing(true) }
        webViews = []
        windows.forEach { $0.isHidden = true }
        windows = []
        if let listener { NotificationCenter.default.removeObserver(listener) }
        listener = nil
        super.tearDown()
    }

    // MARK: - The view the fix reaches for

    func testTheViewThatOwnsTheBarIsWhereTheAppLooksForIt() {
        XCTAssertNotNil(
            FormBar.owner(of: WKWebView(frame: .zero)),
            """
            No WKContentView in the web view's scroll view. WebKit has renamed \
            or moved it, and FormBar now takes nothing away from anything.
            """
        )
    }

    /// And that it is there before a page is, which is what lets the app do
    /// this once where the view is built rather than watch for it.
    func testItIsThereBeforeAnyPageIs() {
        let webView = WKWebView(frame: .zero)
        XCTAssertNil(webView.url)
        XCTAssertTrue(FormBar.take(from: webView))
    }

    /// Saying it twice does not make a subclass of a subclass.
    func testAskingTwiceIsFree() throws {
        let webView = WKWebView(frame: .zero)
        XCTAssertTrue(FormBar.take(from: webView))
        let once = try XCTUnwrap(FormBar.owner(of: webView)).classForCoder

        XCTAssertTrue(FormBar.take(from: webView))
        let twice = try XCTUnwrap(FormBar.owner(of: webView)).classForCoder

        XCTAssertTrue(once === twice, "A second pass made a second class.")
    }

    // MARK: - The bar, on the screen

    /// Plain WebKit, so that the test below is measuring a bar that was there.
    ///
    /// Asked of the whole app rather than of the property, because the property
    /// is not what covers a send button. The bar is a real view and it is in
    /// this process: `UITextEffectsWindow > UIKeyboardItemContainerView >
    /// WKFormAccessoryView`, which is where this finds it.
    func testWebKitDrawsABarWhenNobodyHasInterfered() throws {
        let plain = try stage(quietened: false).webView
        let bars = barsOnScreen()

        XCTAssertEqual(
            bars.count, 1,
            """
            WebKit put no form bar on the screen for a focused field. Either it \
            arrives some other way now, or nothing is focused — and either way \
            the test below is measuring the absence of something absent.
            """
        )
        XCTAssertGreaterThan(try XCTUnwrap(bars.first).height, 0)
        XCTAssertNotNil(FormBar.owner(of: plain)?.inputAccessoryView)
    }

    /// The whole of the fix, said the way somebody looking at the phone says it.
    func testNothingBarShapedIsDrawnAnywhere() throws {
        _ = try stage(quietened: true)
        XCTAssertEqual(
            barsOnScreen(), [],
            "A form bar is on the screen, on top of the message box."
        )
    }

    /// Replaced, rather than taken away — and the difference is the whole file.
    ///
    /// `nil` here is the version that hid the message box behind the keyboard.
    /// What ships is an accessory that exists and is nothing: WebKit goes on
    /// counting it, and it is zero points of it to count.
    func testTheBarIsReplacedRatherThanRemoved() throws {
        let webView = try stage(quietened: true).webView
        let offered = try XCTUnwrap(
            FormBar.owner(of: webView)?.inputAccessoryView,
            """
            The accessory is nil. WebKit will stop resizing the page for the \
            keyboard and the message box goes behind it — see this file's note.
            """
        )
        XCTAssertEqual(offered.frame.height, 0)
    }

    // MARK: - The page, still where it was

    /// The page gets back the bar's space, and not one point more.
    ///
    /// This is the assertion the first attempt failed, and the only one that
    /// could have caught it. That attempt answered `nil`, and WebKit stopped
    /// resizing the page for the keyboard at all: the same page that was given
    /// 481 points with the bar up was given **860** — the whole glass — and the
    /// box pinned to the bottom of it went down behind the keyboard with the
    /// sentence in it. Every other test in this file was green for that.
    ///
    /// So the two are measured side by side and the difference is named. What
    /// ships gives the page 549 where the bar gave it 481: 68 points back,
    /// which is the bar, and nothing else moved. `nil` gives it 379 back, which
    /// is the keyboard, and the keyboard is still there.
    ///
    /// Stated as a bound rather than an equality because the two ends of the
    /// page do not cost the same on every runner — a simulator with a hardware
    /// keyboard attached puts no keyboard up, only the bar, and the home
    /// indicator's own strip is inside one of the numbers and outside the
    /// other. The bound holds in both, and it is the wrong side of `nil` by a
    /// factor of five.
    func testThePageGetsBackTheBarAndNotTheKeyboard() throws {
        let plain = try stage(quietened: false)
        let bar = try XCTUnwrap(FormBar.owner(of: plain.webView)?.inputAccessoryView)
        let withTheBar = try height(of: plain.webView)

        // Not every WebKit resizes the page for a keyboard at all. iOS 26
        // does — 860 points at rest, 481 with the bar up — and iOS 18, on the
        // same harness and the same page, leaves it at 860 either way and
        // moves only the visual viewport. There is nothing on that runner for
        // an absent accessory to break, and an assertion made anyway would be
        // measuring which SDK the machine happens to have.
        try XCTSkipUnless(
            withTheBar < plain.atRest,
            "This WebKit does not resize the page for a keyboard."
        )

        let quiet = try stage(quietened: true)
        let withNothing = try height(of: quiet.webView)

        XCTAssertGreaterThan(
            withNothing, withTheBar,
            "The page did not get the bar's space back."
        )
        XCTAssertLessThanOrEqual(
            withNothing - withTheBar, bar.frame.height + 4,
            """
            The page grew by \(withNothing - withTheBar) points where the bar \
            was only \(bar.frame.height) high. WebKit has stopped resizing it \
            for the keyboard, which puts whatever is pinned to the bottom of \
            the page — the message box — behind the keyboard.
            """
        )
    }

    /// Still nothing on the next page.
    ///
    /// The question behind doing this where the web view is built rather than
    /// on every navigation: a view WebKit rebuilt between pages would be one
    /// the app had quietened exactly once, for a page nobody was reading yet.
    func testItIsStillNothingAfterTheNextPage() throws {
        let webView = try stage(quietened: true).webView
        load(into: webView)
        focusTheField(in: webView)

        XCTAssertEqual(barsOnScreen(), [])
    }

    // MARK: - A page with a box at the foot of it

    private static let glass = CGRect(x: 0, y: 0, width: 402, height: 874)

    /// Instagram's shape, in as few words as it can be said: one field, pinned
    /// to the bottom of the page, with the keyboard in it.
    /// A staged page: the view it is in, and how tall the page was before
    /// anything asked for a keyboard.
    private struct Staged {
        let webView: WKWebView
        /// `window.innerHeight` with nothing obscuring the page, which is what
        /// says whether this WebKit resizes for a keyboard at all.
        let atRest: CGFloat
    }

    private func stage(quietened: Bool) throws -> Staged {
        if let listener { NotificationCenter.default.removeObserver(listener) }
        listener = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
            MainActor.assumeIsolated {
                self?.keyboard = (end as? NSValue)?.cgRectValue ?? .zero
            }
        }

        // Whichever scene this app has, preferring the active one.
        //
        // Deliberately not *only* the active one. Run on its own this suite
        // finds the host app foreground-active; run after three hundred other
        // tests it finds the same scene reporting something else, and five
        // tests that had been measuring WebKit started reporting on the mood
        // of the test runner instead. The window is made key either way, which
        // is what a field needs to take a keyboard.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(
            scenes.first { $0.activationState == .foregroundActive } ?? scenes.first,
            "This app has no window scene, so nothing here can hold a keyboard."
        )
        let webView = WKWebView(frame: scene.screen.bounds)
        if quietened { XCTAssertTrue(FormBar.take(from: webView)) }
        webViews.append(webView)

        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        // Above whatever the host app has up, so that this is what is on the
        // glass and the keyboard belongs to the field below.
        window.windowLevel = .normal + 1
        window.addSubview(webView)
        window.makeKeyAndVisible()
        windows.append(window)

        load(into: webView)
        let atRest = try height(of: webView)
        focusTheField(in: webView)
        return Staged(webView: webView, atRest: atRest)
    }

    private func load(into webView: WKWebView) {
        let finished = expectation(description: "the page finished")
        let watcher = Finished { finished.fulfill() }
        webView.navigationDelegate = watcher
        webView.loadHTMLString(
            """
            <html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
              body { margin:0; background:#0d0e10; color:#fff; font:17px -apple-system;
                     padding:60px 16px 0 }
              .said { background:#262628; border-radius:20px; padding:10px 14px;
                      max-width:70%; margin:6px 0 }
              #box { position:fixed; left:10px; right:10px; bottom:8px; height:44px;
                     border:1px solid #3a3a3c; border-radius:22px; display:flex;
                     align-items:center; padding:0 16px }
              #message { flex:1; background:transparent; border:0; color:#fff;
                         font:17px -apple-system; outline:none }
            </style></head><body>
              <div class="said">a conversation, and something said in it</div>
              <div id="box"><input id="message"></div>
            </body></html>
            """,
            baseURL: nil
        )
        wait(for: [finished], timeout: 30)
        webView.navigationDelegate = nil
    }

    /// Asked of the page rather than of the app, because it is the page's field
    /// and a focus WebKit granted is the only one that brings a keyboard.
    ///
    /// Then waited for, because the keyboard arrives a turn or two of the run
    /// loop later and a first responder asked too early answers honestly that
    /// it is not one. Then waited for again: the frame UIKit reports is the one
    /// it is animating to, and the page is resized as it lands.
    private func focusTheField(in webView: WKWebView) {
        webView.evaluateJavaScript("document.getElementById('message').focus()")
        let owner = FormBar.owner(of: webView)
        let arrived = expectation(description: "the keyboard arrived")
        poll(until: { owner?.isFirstResponder == true }, then: arrived)
        wait(for: [arrived], timeout: 15)
        settle(for: 1.5)
    }

    private func height(of webView: WKWebView) throws -> CGFloat {
        var answer: CGFloat?
        let read = expectation(description: "the page answered")
        webView.evaluateJavaScript("window.innerHeight") { value, _ in
            answer = (value as? NSNumber).map { CGFloat($0.doubleValue) }
            read.fulfill()
        }
        wait(for: [read], timeout: 10)
        return try XCTUnwrap(answer)
    }

    /// Every form bar anywhere in this app's windows, by frame.
    ///
    /// Named for what WebKit calls it rather than for "accessory", which also
    /// matches the text cursor's own furniture — `_UICursorAccessoryHostView`
    /// lives inside the page and is nobody's business here.
    private func barsOnScreen() -> [CGRect] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .flatMap(bars(in:))
    }

    private func bars(in view: UIView) -> [CGRect] {
        var found: [CGRect] = []
        if NSStringFromClass(type(of: view)).contains("FormAccessory") {
            found.append(view.convert(view.bounds, to: nil))
        }
        return found + view.subviews.flatMap(bars(in:))
    }

    private func poll(
        until condition: @escaping @MainActor () -> Bool,
        then fulfilled: XCTestExpectation,
        by deadline: Date = .now + 12
    ) {
        if condition() || Date.now > deadline {
            fulfilled.fulfill()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.poll(until: condition, then: fulfilled, by: deadline)
        }
    }

    private func settle(for seconds: TimeInterval) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        wait(for: [settled], timeout: seconds + 10)
    }
}

/// A navigation delegate that says when the page is up, and nothing else.
private final class Finished: NSObject, WKNavigationDelegate {
    private let done: () -> Void
    init(done: @escaping () -> Void) { self.done = done }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done() }
}
