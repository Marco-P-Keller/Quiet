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
