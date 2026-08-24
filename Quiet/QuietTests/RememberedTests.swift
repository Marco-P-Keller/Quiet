import XCTest
import UIKit
@testable import Quiet

/// What the row already knew last time.
///
/// The defect this exists to prevent is specific and was visible in a
/// photograph: for the first second of a launch the row wore Quiet's fallback
/// symbols, and then every one of them changed at once. The app looked like it
/// was correcting itself in front of the reader.
final class RememberedTests: XCTestCase {
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

    /// A one-point square, which is all any of this needs to be to prove the
    /// journey out to storage and back.
    private func square(_ white: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format)
            .image { context in
                UIColor(white: white, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }
        return image.pngData()!
    }

    func testAnEmptyInstallRemembersNothing() {
        XCTAssertTrue(Remembered.icons(defaults: defaults).isEmpty)
        XCTAssertNil(Remembered.me(defaults: defaults))
        XCTAssertNil(Remembered.myFace(defaults: defaults))
    }

    func testAGlyphComesBackAsATemplate() {
        Remembered.remember(icon: "home.on", data: square(0), defaults: defaults)
        let drawn = Remembered.icons(defaults: defaults)
        XCTAssertEqual(drawn.count, 1)
        // A template, or the row would carry Instagram's black into a light
        // appearance instead of taking the tint of everything beside it.
        XCTAssertEqual(drawn["home.on"]?.renderingMode, .alwaysTemplate)
    }

    func testEachEntryIsKeptSeparately() {
        Remembered.remember(icon: "home.on", data: square(0), defaults: defaults)
        Remembered.remember(icon: "messages.off", data: square(1), defaults: defaults)
        XCTAssertEqual(Set(Remembered.icons(defaults: defaults).keys), ["home.on", "messages.off"])
    }

    /// Instagram redraws its icons from time to time. A glyph that could only
    /// ever be written once would be one Quiet showed the old version of for
    /// ever.
    func testAGlyphCanBeReplaced() {
        let first = square(0)
        let second = square(1)
        Remembered.remember(icon: "home.on", data: first, defaults: defaults)
        Remembered.remember(icon: "home.on", data: second, defaults: defaults)
        let stored = defaults.dictionary(forKey: "quiet.glyphs") as? [String: Data]
        XCTAssertEqual(stored?["home.on"], second)
    }

    /// The page hands back whatever it finds. A photograph arriving where a
    /// glyph was expected is refused rather than kept.
    func testSomethingFarTooBigIsRefused() {
        Remembered.remember(
            icon: "home.on",
            data: Data(count: 200 * 1024),
            defaults: defaults
        )
        XCTAssertTrue(Remembered.icons(defaults: defaults).isEmpty)
    }

    func testTheNameAndTheFaceComeBack() {
        Remembered.remember(me: "marco", face: square(0.5), defaults: defaults)
        XCTAssertEqual(Remembered.me(defaults: defaults), "marco")
        XCTAssertNotNil(Remembered.myFace(defaults: defaults))
    }

    /// Signing in as somebody else must not leave the previous name in the row.
    func testANewNameReplacesTheOldOne() {
        Remembered.remember(me: "marco", face: nil, defaults: defaults)
        Remembered.remember(me: "someone", face: nil, defaults: defaults)
        XCTAssertEqual(Remembered.me(defaults: defaults), "someone")
    }

    /// A page that knows the name but has not fetched the picture yet must not
    /// take away the face that is already being drawn.
    func testANameWithNoFaceKeepsTheFaceThereIsAlready() {
        Remembered.remember(me: "marco", face: square(0.5), defaults: defaults)
        Remembered.remember(me: "marco", face: nil, defaults: defaults)
        XCTAssertNotNil(Remembered.myFace(defaults: defaults))
    }

    func testARehearsalCanForgetAllOfIt() {
        Remembered.remember(icon: "home.on", data: square(0), defaults: defaults)
        Remembered.remember(me: "marco", face: square(0.5), defaults: defaults)

        Remembered.forget(defaults: defaults)

        XCTAssertTrue(Remembered.icons(defaults: defaults).isEmpty)
        XCTAssertNil(Remembered.me(defaults: defaults))
        XCTAssertNil(Remembered.myFace(defaults: defaults))
    }
}
