import XCTest
@testable import Quiet

/// Whether the app can tell that it has stopped working.
///
/// The one hole this whole approach has. The address rules keep working
/// whatever Instagram does; everything else recognises Instagram by its shape,
/// and the day the shape changes the recognising stops finding anything —
/// without throwing, without logging, with the app still looking perfectly
/// healthy. These are the rules that turn that into a sentence.
final class HealthTests: XCTestCase {
    func testSilenceMeansNothingUntilEnoughPagesHaveGoneBy() {
        // A login screen carries no navigation. Nor does a story, nor an open
        // conversation. One page proves nothing and neither do four.
        for pages in 0..<Health.patience {
            XCTAssertFalse(
                Health(pages: pages, nav: 0).hasLostTheShape,
                "\(pages) pages is not evidence of anything"
            )
        }
    }

    func testEnoughPagesWithNothingFoundIsEvidence() {
        XCTAssertTrue(Health(pages: Health.patience, nav: 0).hasLostTheShape)
        XCTAssertTrue(Health(pages: 40, nav: 0).hasLostTheShape)
    }

    /// One row found is the shape still being there. Somebody who spends a
    /// morning in stories and conversations should not be told Instagram has
    /// been redesigned.
    func testFindingItEvenOnceIsEnough() {
        XCTAssertFalse(Health(pages: 40, nav: 1).hasLostTheShape)
    }

    // MARK: - Reading what the page said

    func testATallyIsReadOutOfTheMessage() {
        let reading = Health(message: [
            "pages": 7, "nav": 6, "headers": 2, "hidden": 13,
        ])
        XCTAssertEqual(reading, Health(pages: 7, nav: 6, headers: 2, hidden: 13))
    }

    /// The script runs in a page Instagram also runs code in. Nothing that
    /// arrives from there is trusted to be the shape it claims.
    func testNonsenseIsNotATally() {
        let refused: [[String: Any]] = [
            [:],
            ["pages": 3],
            ["pages": "seven", "nav": 1, "headers": 0, "hidden": 0],
            ["pages": -1, "nav": 0, "headers": 0, "hidden": 0],
            // A tally only climbs, and pages are counted before what is on
            // them. More rows than pages is not a reading of anything.
            ["pages": 2, "nav": 5, "headers": 0, "hidden": 0],
            ["pages": 2, "nav": 1, "headers": 9, "hidden": 0],
        ]
        for body in refused {
            XCTAssertNil(Health(message: body), "\(body)")
        }
    }
}
