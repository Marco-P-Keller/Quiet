import WebKit
import XCTest
@testable import Quiet

/// Where WebKit answers, rather than where the app believes it answers.
///
/// Three places in this app take a WebKit completion handler and step straight
/// into main-actor state inside it — `BlockList` twice, `WebSurface.signOut`
/// once — using `MainActor.assumeIsolated`. The alternative, hopping with a
/// `Task`, costs a turn of the run loop in each of them, and in `signOut` that
/// turn is one in which the panes on the glass still belong to somebody who has
/// just signed out.
///
/// `assumeIsolated` is not a hope. It is a trap: if the handler ever arrives
/// somewhere other than the main actor the app does not misbehave, it dies, and
/// it dies on a stranger's phone rather than here. Apple documents no queue for
/// either of these, so what the app relies on is behaviour — and behaviour that
/// is relied on and not measured is the kind that changes in an OS release
/// between one build and the next.
///
/// So it is measured. If a future WebKit answers on another thread, this file
/// goes red on the push that picks up that SDK, months before anybody's app
/// disappears mid-tap.
final class WebKitAnswersTests: XCTestCase {
    /// `WebSurface.signOut` rebuilds every pane in this handler.
    func testTheSessionIsForgottenOnTheMainThread() {
        let answered = expectation(description: "removeData answered")
        // The disk cache only, and `.distantPast` — which is to say the call
        // `clearCaches` already makes on purpose, rather than the one
        // `signOut` makes. Same method, same handler, nobody's session.
        //
        // The first draft asked for `.distantFuture` instead, reasoning that
        // data modified since a moment that has not arrived is no data and so
        // nothing would be deleted. It read well and it hung: on the CI
        // runner's runtime the handler was never called at all, and the test
        // this file exists to make trustworthy failed on its first run
        // somewhere that was not this machine. A cutoff no real caller passes
        // is a path no real caller exercises.
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeDiskCache],
            modifiedSince: .distantPast
        ) {
            XCTAssertTrue(
                Thread.isMainThread,
                """
                WKWebsiteDataStore answered off the main thread. \
                WebSurface.signOut assumes otherwise and would trap.
                """
            )
            answered.fulfill()
        }
        wait(for: [answered], timeout: 60)
    }

    /// `BlockList` adds a compiled rule list to a configuration in this one.
    func testTheBlockListIsLookedUpOnTheMainThread() {
        let answered = expectation(description: "lookUpContentRuleList answered")
        WKContentRuleListStore.default().lookUpContentRuleList(
            forIdentifier: "a name no list was ever compiled under"
        ) { _, _ in
            XCTAssertTrue(
                Thread.isMainThread,
                """
                WKContentRuleListStore answered off the main thread. \
                BlockList assumes otherwise and would trap.
                """
            )
            answered.fulfill()
        }
        wait(for: [answered], timeout: 60)
    }
}
