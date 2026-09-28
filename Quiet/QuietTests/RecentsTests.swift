import XCTest
import UIKit
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

    // MARK: - Their faces

    /// A square of one colour, at whatever size the test needs it.
    private func portrait(_ side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { context in
                UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
    }

    /// Opening somebody out of the search results is the one moment their
    /// picture is already in the app's hand. Letting it go there is asking
    /// Instagram for it a second time.
    func testAFaceArrivesWithTheName() {
        Remembered.remember(visit: "ada", face: portrait(320), defaults: defaults)
        XCTAssertNotNil(Remembered.visitFaces(defaults: defaults)["ada"])
    }

    /// And typing a name and pressing return is the moment it is not, so the
    /// answer has to be allowed to turn up afterwards.
    func testAFaceCanArriveAfterTheName() {
        Remembered.remember(visit: "ada", defaults: defaults)
        XCTAssertNil(Remembered.visitFaces(defaults: defaults)["ada"])

        Remembered.remember(face: portrait(320), for: "ada", defaults: defaults)
        XCTAssertNotNil(Remembered.visitFaces(defaults: defaults)["ada"])
    }

    /// A late answer about somebody who has since been pushed off the list does
    /// not put them back, and does not leave their face behind either.
    func testAFaceForSomebodyNotOnTheListIsRefused() {
        Remembered.remember(face: portrait(320), for: "grace", defaults: defaults)
        XCTAssertTrue(Remembered.visitFaces(defaults: defaults).isEmpty)
    }

    /// Without this the faces are the one thing here that *is* a history:
    /// everybody this phone has ever opened, kept as a photograph, long after
    /// the name was gone.
    func testAFaceDoesNotOutliveTheName() {
        Remembered.remember(visit: "ada", face: portrait(320), defaults: defaults)
        for index in 0..<8 {
            Remembered.remember(visit: "person\(index)", defaults: defaults)
        }

        XCTAssertFalse(Remembered.visits(defaults: defaults).contains("ada"))
        XCTAssertNil(Remembered.visitFaces(defaults: defaults)["ada"])
    }

    /// Instagram's own profile picture can be three hundred kilobytes and the
    /// list draws it at thirty-two points. Eight of those kept whole is two
    /// megabytes of somebody else's photographs read on every launch.
    func testAFaceIsCutDownToTheSizeItIsDrawnAt() throws {
        Remembered.remember(visit: "ada", face: portrait(640), defaults: defaults)

        let kept = try XCTUnwrap(Remembered.visitFaces(defaults: defaults)["ada"])
        XCTAssertEqual(kept.size, CGSize(width: 96, height: 96))
    }

    func testEmptyingTheListTakesTheFacesWithIt() {
        Remembered.remember(visit: "ada", face: portrait(320), defaults: defaults)
        Remembered.forgetVisits(defaults: defaults)
        XCTAssertTrue(Remembered.visitFaces(defaults: defaults).isEmpty)
    }

    // MARK: - What the field narrows to

    /// The search field used to ask `/api/v1/web/search/topsearch/` who matched
    /// what was being typed, with Instagram's own web client identifier in a
    /// header. What stands there now is this list, narrowed — so this is the
    /// half of the screen that has to carry the weight, and it is worth asking
    /// rather than assuming.

    private let list = ["ada", "grace", "edsger", "adaline"]

    func testAnEmptyFieldNarrowsToEverybody() {
        XCTAssertEqual(SearchView.narrowing("", among: list), list)
        XCTAssertEqual(SearchView.narrowing("   ", among: list), list)
    }

    /// Anywhere in the name rather than at the front of it. People think of
    /// each other by whichever part of a handle is the name.
    ///
    /// The typed letters follow as a row of their own, as they always do — it
    /// is the one row that is in the same place every time, which is what makes
    /// it usable at all. `dsg` is a handle somebody could hold.
    func testItMatchesInsideAName() {
        XCTAssertEqual(SearchView.narrowing("dsg", among: list), ["edsger", "dsg"])
    }

    /// The typed name comes last, not first. Three letters are far more often
    /// somebody you already open than a stranger, and a row that jumps to the
    /// top on every keystroke is a row you tap by accident.
    func testTheTypedNameComesAfterThePeopleYouOpen() {
        XCTAssertEqual(SearchView.narrowing("ada", among: list), ["ada", "adaline"])
        XCTAssertEqual(
            SearchView.narrowing("alan", among: list),
            ["alan"],
            "A name nobody on this phone has opened is still openable."
        )
    }

    /// An `@` and a pasted profile link are the same person as the bare name —
    /// the same question `ContentRules` answers about every other address here.
    func testANameIsANameHoweverItIsTyped() {
        for typed in ["@grace", "instagram.com/grace/", "https://www.instagram.com/grace/"] {
            XCTAssertEqual(
                SearchView.narrowing(typed, among: list), ["grace"],
                "\(typed) is grace"
            )
        }
    }

    /// Nothing is offered for something that could not be a handle, because
    /// nothing could be opened with it either. A field with rubbish in it shows
    /// whoever it happens to match and no row promising a profile.
    func testSomethingThatIsNotAHandleOffersNoRow() {
        XCTAssertEqual(SearchView.narrowing("two words", among: list), [])
        XCTAssertEqual(SearchView.narrowing("#hashtag", among: list), [])
    }

    /// Typed in capitals, matched in lower case: handles have no capitals and
    /// a keyboard that autocapitalised one should not empty the list.
    func testCapitalsDoNotHideAnybody() {
        XCTAssertEqual(SearchView.narrowing("Grace", among: list), ["grace"])
    }
}
