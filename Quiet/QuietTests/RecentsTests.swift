import XCTest
@testable import Quiet

/// The three or four people somebody actually opens the app to see.
///
/// Instagram's search tab is the front door to Explore, which is why it is
/// gone. What a person wanted from it was *who is my friend on here*, and for
/// most people that is the same short list every time — so it answers before a
/// letter is typed. Deliberately not a history: no dates, no order of interest,
/// no count, nothing to feel anything about.
final class RecentsTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "quiet.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAFreshPhoneHasNobodyOnIt() {
        XCTAssertEqual(Remembered.visits(defaults: defaults), [])
    }

    func testTheMostRecentIsFirst() {
        for name in ["ada", "grace", "edsger"] {
            Remembered.remember(visit: name, defaults: defaults)
        }
        XCTAssertEqual(Remembered.visits(defaults: defaults), ["edsger", "grace", "ada"])
    }

    /// Moved to the front rather than added again. Without this, somebody's own
    /// three people are pushed off the end by one afternoon of looking at
    /// strangers, and the list is useless exactly when it is needed.
    func testOpeningSomebodyAgainMovesThemUp() {
        for name in ["ada", "grace", "edsger"] {
            Remembered.remember(visit: name, defaults: defaults)
        }
        Remembered.remember(visit: "ada", defaults: defaults)

        XCTAssertEqual(Remembered.visits(defaults: defaults), ["ada", "edsger", "grace"])
    }

    func testItStaysShort() {
        for index in 0..<30 {
            Remembered.remember(visit: "person\(index)", defaults: defaults)
        }
        let kept = Remembered.visits(defaults: defaults)
        XCTAssertEqual(kept.count, 8)
        XCTAssertEqual(kept.first, "person29")
    }

    /// The same person, written the four ways people write them. What is
    /// remembered is the name the app will use, not the name that was typed.
    func testANameIsANameHoweverItArrives() throws {
        for typed in ["Ada", "@ada", "instagram.com/ada/", "https://www.instagram.com/ada/"] {
            let url = try XCTUnwrap(ContentRules.profile(forHandle: typed), typed)
            XCTAssertEqual(ContentRules.pathComponents(of: url).first, "ada", typed)
        }
    }

    func testEmptyNamesAreNotRemembered() {
        Remembered.remember(visit: "", defaults: defaults)
        XCTAssertEqual(Remembered.visits(defaults: defaults), [])
    }

    func testTheListCanBeEmptied() {
        Remembered.remember(visit: "ada", defaults: defaults)
        Remembered.forgetVisits(defaults: defaults)
        XCTAssertEqual(Remembered.visits(defaults: defaults), [])
    }
}
