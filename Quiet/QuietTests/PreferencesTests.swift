import XCTest
@testable import Quiet

/// The one preference in the app, and the two things that can go wrong with a
/// preference: it does not come back, or it comes back as something nobody
/// chose.
@MainActor
final class PreferencesTests: XCTestCase {
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

    /// A first launch should look like the thing the app is showing rather than
    /// like an opinion about it.
    func testItStartsAsInstagramsOwnShape() {
        XCTAssertEqual(Preferences(defaults: defaults).row, .bar)
    }

    func testAChoiceOutlivesTheObjectThatMadeIt() {
        let first = Preferences(defaults: defaults)
        first.row = .island

        XCTAssertEqual(Preferences(defaults: defaults).row, .island)
    }

    /// Written once, not on every read, and not when the answer has not changed
    /// — a `didSet` that fires on an assignment of the same value would write to
    /// the disk every time a view happened to set it.
    func testChoosingWhatIsAlreadyChosenChangesNothing() {
        let preferences = Preferences(defaults: defaults)
        preferences.row = .island
        preferences.row = .island

        XCTAssertEqual(Preferences(defaults: defaults).row, .island)
    }

    /// A value nobody recognises is not a shape. It should read as the default
    /// rather than crash or leave the row undrawn.
    func testSomethingUnrecognisableReadsAsTheDefault() {
        defaults.set("hovercraft", forKey: "quiet.row.shape")

        XCTAssertEqual(Preferences(defaults: defaults).row, .bar)
    }

    /// Both shapes are offered, and each has something to put on a button.
    func testBothShapesAreOfferedAndNamed() {
        XCTAssertEqual(RowShape.allCases.count, 2)
        for shape in RowShape.allCases {
            XCTAssertFalse(shape.name.isEmpty, "\(shape) must have a name")
        }
    }
}
