import XCTest
@testable import Quiet

/// The preferences, and the two things that can go wrong with a preference: it
/// does not come back, or it comes back as something nobody chose.
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

    // MARK: - What the app says on the way down

    /// On unless it has been turned off, which is not what `bool(forKey:)`
    /// answers for a key nobody has written. Asking it that way would have
    /// shipped an app that says nothing until somebody finds the switch and
    /// turns it on — silently, and looking exactly like a working app.
    func testTheAppSpeaksUntilItIsToldNotTo() {
        XCTAssertTrue(Preferences(defaults: defaults, hardware: .iPhone15).saysWhatIsLeft)
    }

    func testSilenceIsRememberedAndSoIsChangingYourMind() {
        let first = Preferences(defaults: defaults, hardware: .iPhone15)
        first.saysWhatIsLeft = false
        XCTAssertFalse(
            Preferences(defaults: defaults, hardware: .iPhone15).saysWhatIsLeft
        )

        first.saysWhatIsLeft = true
        XCTAssertTrue(
            Preferences(defaults: defaults, hardware: .iPhone15).saysWhatIsLeft
        )
    }

    // MARK: - What is in the feed

    /// The default that is the whole of the decision, pinned where it lives.
    ///
    /// Quiet used to take every one of Instagram's suggested posts out, always,
    /// and nobody had chosen that — it was the app editing somebody's feed on
    /// their behalf, which is the thing it objects to when the site does it.
    /// They are shown now, and there is a switch for anybody who would rather
    /// not have them.
    ///
    /// The tools in `Tools/` cannot ask this question. They test the script,
    /// and the script is handed the answer; this is where the answer is
    /// decided. It is also `object(forKey:)` rather than `bool(forKey:)` for
    /// the same reason as the notices above, and getting that wrong here would
    /// ship an app that hides them until somebody finds the switch — silently,
    /// and looking exactly like a working app.
    func testSuggestedPostsAreShownUntilSomebodySaysOtherwise() {
        XCTAssertTrue(Preferences(defaults: defaults, hardware: .iPhone15).showsSuggestions)
    }

    func testHidingThemIsRememberedAndSoIsChangingYourMind() {
        let first = Preferences(defaults: defaults, hardware: .iPhone15)
        first.showsSuggestions = false
        XCTAssertFalse(
            Preferences(defaults: defaults, hardware: .iPhone15).showsSuggestions
        )

        first.showsSuggestions = true
        XCTAssertTrue(
            Preferences(defaults: defaults, hardware: .iPhone15).showsSuggestions
        )
    }

    /// And that the answer actually reaches the page, which is the half of this
    /// that a preference test usually forgets. A setting nothing is told about
    /// is a switch that does nothing.
    func testThePageIsToldWhichWayTheSwitchIs() {
        let shown = WebScripts.load(top: 59, showsSuggestions: true)
            .scripts.map(\.source).joined(separator: "\n")
        XCTAssertTrue(shown.contains("window.__quietShowsSuggestions = true"))

        let hidden = WebScripts.load(top: 59, showsSuggestions: false)
            .scripts.map(\.source).joined(separator: "\n")
        XCTAssertTrue(hidden.contains("window.__quietShowsSuggestions = false"))
    }
}

private extension Hardware {
    static let iPhone14Pro = Hardware(model: "iPhone15,2", systemMajorVersion: 26)
    static let iPhone15 = Hardware(model: "iPhone15,4", systemMajorVersion: 26)
}
