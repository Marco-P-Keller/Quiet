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

    /// A first launch on a phone that cannot wear the island should look like
    /// the thing the app is showing rather than like an opinion about it.
    func testItStartsAsInstagramsOwnShapeOnAnOlderPhone() {
        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone14Pro).row, .bar)
    }

    /// And on a phone that can, it opens as the shape the app was asked for
    /// first, without anybody having to find the panel.
    func testItStartsAsTheIslandOnANewPhone() {
        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone15).row, .island)
    }

    func testAChoiceOutlivesTheObjectThatMadeIt() {
        let first = Preferences(defaults: defaults, hardware: .iPhone14Pro)
        first.row = .island

        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone14Pro).row, .island)
    }

    /// The hardware only decides where nobody has. Choosing the bar on a phone
    /// that would have opened with the island has to stick, or the choice is
    /// not a choice.
    func testTheHardwareDoesNotOverruleAChoice() {
        let first = Preferences(defaults: defaults, hardware: .iPhone15)
        first.row = .bar

        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone15).row, .bar)
    }

    /// Written once, not on every read, and not when the answer has not changed
    /// — a `didSet` that fires on an assignment of the same value would write to
    /// the disk every time a view happened to set it.
    func testChoosingWhatIsAlreadyChosenChangesNothing() {
        let preferences = Preferences(defaults: defaults, hardware: .iPhone14Pro)
        preferences.row = .island
        preferences.row = .island

        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone14Pro).row, .island)
    }

    /// A value nobody recognises is not a shape. It should read as the default
    /// rather than crash or leave the row undrawn.
    func testSomethingUnrecognisableReadsAsTheDefault() {
        defaults.set("hovercraft", forKey: "quiet.row.shape")

        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone14Pro).row, .bar)
        XCTAssertEqual(Preferences(defaults: defaults, hardware: .iPhone15).row, .island)
    }

    /// Both shapes are offered, and each has something to put on a button.
    func testBothShapesAreOfferedAndNamed() {
        XCTAssertEqual(RowShape.allCases.count, 2)
        for shape in RowShape.allCases {
            XCTAssertFalse(shape.name.isEmpty, "\(shape) must have a name")
        }
    }
}

private extension Hardware {
    static let iPhone14Pro = Hardware(model: "iPhone15,2", systemMajorVersion: 26)
    static let iPhone15 = Hardware(model: "iPhone15,4", systemMajorVersion: 26)
}
