import WebKit
import XCTest
@testable import Quiet

@MainActor
final class SignInTests: XCTestCase {
    /// The promise the sign-in screen makes in writing, pinned. A script added
    /// to this configuration — Quiet's or anybody's — is a sentence on the
    /// screen that has stopped being true.
    func testTheSignInPageCarriesNoScriptOfQuiets() {
        let configuration = SignInWebView.configuration()
        XCTAssertTrue(configuration.userContentController.userScripts.isEmpty)
    }

    /// And it shares the panes' store, or a sign-in here is a session nobody
    /// on the other side can read.
    func testTheSignInPageSharesThePanesStore() {
        XCTAssertTrue(SignInWebView.configuration().websiteDataStore.isPersistent)
        XCTAssertTrue(SignInWebView.configuration().websiteDataStore === WKWebsiteDataStore.default())
    }

    func testInstagramsOwnSignInPagesAreTakenOutOfThePanes() {
        for address in [
            "https://www.instagram.com/accounts/login/",
            "https://www.instagram.com/accounts/login/?next=%2Fdirect%2Finbox%2F",
            "https://www.instagram.com/accounts/login/two_factor/",
            "https://www.instagram.com/accounts/password/reset/",
            "https://www.instagram.com/challenge/",
            "https://accountscenter.instagram.com/password_and_security/",
        ] {
            XCTAssertTrue(SignIn.belongsHere(URL(string: address)!), address)
        }
    }

    /// A link to Facebook from a post is somebody following a link. It goes
    /// the way it always went, and never onto the sign-in screen.
    func testOrdinaryPagesAndFacebookStayWhereTheyWere() {
        for address in [
            "https://www.instagram.com/",
            "https://www.instagram.com/direct/inbox/",
            "https://www.instagram.com/someone/",
            "https://www.instagram.com/accounts/edit/",
            "https://www.facebook.com/someone",
            "https://example.com/accounts/login/",
        ] {
            XCTAssertFalse(SignIn.belongsHere(URL(string: address)!), address)
        }
        XCTAssertFalse(SignIn.belongsHere(nil))
    }

    func testTheSignInIsOverOnInstagramsPagesWithASession() {
        let feed = URL(string: "https://www.instagram.com/")!
        XCTAssertTrue(SignIn.isOver(at: feed, hasSession: true))
        XCTAssertTrue(SignIn.isOver(at: URL(string: "https://www.instagram.com/direct/inbox/")!, hasSession: true))
    }

    /// Either half alone is wrong: a cookie can be there halfway through
    /// two-factor, and a page of Instagram's can be its help pages.
    func testTheSignInIsNotOverOnEitherHalfAlone() {
        XCTAssertFalse(SignIn.isOver(at: URL(string: "https://www.instagram.com/accounts/login/two_factor/")!, hasSession: true))
        XCTAssertFalse(SignIn.isOver(at: URL(string: "https://www.instagram.com/accounts/onetap/")!, hasSession: true))
        XCTAssertFalse(SignIn.isOver(at: URL(string: "https://www.instagram.com/")!, hasSession: false))
        XCTAssertFalse(SignIn.isOver(at: URL(string: "https://example.com/")!, hasSession: true))
        XCTAssertFalse(SignIn.isOver(at: URL(string: "about:blank")!, hasSession: true))
        XCTAssertFalse(SignIn.isOver(at: nil, hasSession: true))
    }
}
