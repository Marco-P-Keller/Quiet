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
        // Nothing of anybody's is thrown away by this: `.distantFuture` selects
        // the data modified since a moment that has not arrived, which is none
        // of it. The handler still runs, on whichever thread WebKit picks, and
        // that is the whole of what is being asked.
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeDiskCache],
            modifiedSince: .distantFuture
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
        wait(for: [answered], timeout: 10)
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
        wait(for: [answered], timeout: 10)
    }
}
