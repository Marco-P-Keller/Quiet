import SwiftUI
import UIKit
import XCTest
@testable import Quiet

/// The colour the page sends up for the band the clock stands on.
///
/// The band is the one thing on the screen with nothing behind it: if a
/// malformed message were allowed through, the time and the battery would sit
/// on whatever three broken numbers happen to mean. Every refusal below leaves
/// the band on the colour it already had, which is never the wrong answer.
final class ChromeTests: XCTestCase {
    private func colour(_ body: [String: Any]) -> Color? {
        Chrome.colour(in: body)
    }

    /// Compared as the numbers the band is actually drawn with, rather than as
    /// two `Color` values: what matters is the colour that reaches the screen.
    private func channels(_ colour: Color?) -> [CGFloat]? {
        guard let colour else { return nil }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(colour).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return [red, green, blue, alpha]
    }

    func testThreeChannelsBecomeThatColour() {
        let drawn = channels(colour(["red": 38, "green": 38, "blue": 38]))
        XCTAssertEqual(drawn?.count, 4)
        for (channel, expected) in zip(drawn ?? [], [38 / 255.0, 38 / 255.0, 38 / 255.0, 1]) {
            XCTAssertEqual(channel, expected, accuracy: 0.001)
        }
    }

    func testTheEndsOfTheRangeAreColoursToo() {
        XCTAssertNotNil(colour(["red": 0, "green": 0, "blue": 0]))
        XCTAssertNotNil(colour(["red": 255, "green": 255, "blue": 255]))
    }

    /// JavaScript has one number type and rounds nothing on its own. A page
    /// that hands over 249.6 means 249.6.
    func testAFractionalChannelIsStillAChannel() {
        XCTAssertNotNil(colour(["red": 249.6, "green": 250, "blue": 250.4]))
    }

    func testAMissingChannelIsRefused() {
        XCTAssertNil(colour(["red": 38, "green": 38]))
        XCTAssertNil(colour([:]))
    }

    func testAChannelThatIsNotANumberIsRefused() {
        XCTAssertNil(colour(["red": "38", "green": 38, "blue": 38]))
    }

    func testAChannelOutsideTheRangeIsRefused() {
        XCTAssertNil(colour(["red": -1, "green": 38, "blue": 38]))
        XCTAssertNil(colour(["red": 38, "green": 256, "blue": 38]))
    }

    func testAChannelThatIsNotFiniteIsRefused() {
        XCTAssertNil(colour(["red": Double.nan, "green": 38, "blue": 38]))
        XCTAssertNil(colour(["red": Double.infinity, "green": 38, "blue": 38]))
    }
}

/// What Quiet says it is when it asks Instagram for a page.
///
/// Written down as a test rather than as a comment because two documents make
/// claims about this string — `store/review-notes.txt`, which App Review reads,
/// and `docs/store-and-legal.md` — and a sentence handed to Apple that the
/// binary contradicts is the one failure on that page with no technical fix.
final class UserAgentTests: XCTestCase {
    private let said = UserAgent.mobileSafari(systemVersion: "18.1")

    /// The tokens Instagram's own sniffing looks for. Without them the site is
    /// within its rights to serve something thinner, and a thinner Instagram is
    /// the one thing this app cannot survive.
    func testItAsksTheWayAMobileBrowserAsks() {
        XCTAssertTrue(said.hasPrefix("Mozilla/5.0 (iPhone;"), said)
        XCTAssertTrue(said.contains("Mobile/15E148"), said)
        XCTAssertTrue(said.contains("Safari/604.1"), said)
    }

    /// The token that is not Safari's, and the whole of the difference between
    /// an in-app browser and a disguise. Last, which is where Chrome and
    /// Instagram's own browser both put theirs.
    func testItNamesTheAppAsking() {
        XCTAssertTrue(said.hasSuffix(" " + UserAgent.name), said)
        XCTAssertTrue(UserAgent.name.hasPrefix("Quiet/"), UserAgent.name)
    }

    /// The system's version, not a version this app made up — a string claiming
    /// an iOS nobody is running is the kind of detail that gets a client
    /// fingerprinted.
    func testItCarriesThePhonesOwnVersion() {
        XCTAssertTrue(said.contains("iPhone OS 18_1 like Mac OS X"), said)
        XCTAssertTrue(said.contains("Version/18.0"), said)
    }

    /// Nothing of Instagram's. The string says which browser engine is asking;
    /// it has never said which *client* is asking, and the header that did —
    /// `X-IG-App-ID` — is gone with the three requests that carried it.
    func testItClaimsToBeNobodysClient() {
        for borrowed in ["Instagram", "IG", "936619743392459"] {
            XCTAssertFalse(said.contains(borrowed), "\(borrowed) is in \(said)")
        }
    }
}

/// What the page says is waiting in the inbox.
///
/// The number goes on a red badge on the row, so the same rule as the band
/// above applies: a message that does not make sense is dropped, and the badge
/// stays as it was. A count Quiet made up is worse than a count that is a
/// moment old.
final class UnreadTests: XCTestCase {
    private func reading(_ body: [String: Any]) -> Unread? {
        Unread(message: body)
    }

    func testANumberIsThatNumber() {
        XCTAssertEqual(reading(["count": 3, "dot": false]), .count(3))
    }

    func testNothingWaitingIsNothing() {
        XCTAssertEqual(reading(["count": 0, "dot": false]), Unread.none)
        XCTAssertEqual(reading(["count": 0]), Unread.none)
    }

    func testASpotWithNoNumberIsADot() {
        XCTAssertEqual(reading(["count": 0, "dot": true]), .dot)
    }

    /// The page never sends both, but if it did, the number is the more exact
    /// thing.
    func testANumberOutranksADot() {
        XCTAssertEqual(reading(["count": 2, "dot": true]), .count(2))
    }

    func testWhatIsNotACountIsRefused() {
        XCTAssertNil(reading([:]))
        XCTAssertNil(reading(["count": "3"]))
        XCTAssertNil(reading(["count": -1]))
        XCTAssertNil(reading(["count": 2.5]))
        XCTAssertNil(reading(["count": 1000]))
        XCTAssertNil(reading(["count": Double.nan]))
    }

    func testTheEndOfTheRangeIsStillACount() {
        XCTAssertEqual(reading(["count": 999]), .count(999))
    }

    /// Instagram's badge stops at nine, and so does the one on the row.
    func testTheBadgeStopsCountingAtNine() {
        XCTAssertEqual(Unread.count(1).written, "1")
        XCTAssertEqual(Unread.count(9).written, "9")
        XCTAssertEqual(Unread.count(10).written, "9+")
        XCTAssertEqual(Unread.count(120).written, "9+")
    }

    func testOnlyANumberWritesAnything() {
        XCTAssertNil(Unread.dot.written)
        XCTAssertNil(Unread.none.written)
    }

    func testAnEmptyInboxIsNotWaiting() {
        XCTAssertFalse(Unread.none.isWaiting)
        XCTAssertTrue(Unread.dot.isWaiting)
        XCTAssertTrue(Unread.count(1).isWaiting)
    }
}
