import XCTest
@testable import Quiet

/// The rule that decides which shape the row has before anybody chooses one.
///
/// It is worth a test of its own because it is arithmetic on a string, and
/// because the one place the arithmetic is surprising — an iPhone 14 Pro
/// calling itself `iPhone15,2` — is exactly the boundary it has to get right.
final class HardwareTests: XCTestCase {
    private func hardware(_ model: String, iOS version: Int = 26) -> Hardware {
        Hardware(model: model, systemMajorVersion: version)
    }

    /// The model numbers run ahead of the names, and generation 15 holds two
    /// different phones. The 14 Pro pair is on the older side of the line.
    func testTheFourteenProsAreNotAFifteen() {
        XCTAssertFalse(hardware("iPhone15,2").isIPhone15OrNewer, "iPhone 14 Pro")
        XCTAssertFalse(hardware("iPhone15,3").isIPhone15OrNewer, "iPhone 14 Pro Max")
    }

    func testTheFifteensAndEverythingAfterThem() {
        XCTAssertTrue(hardware("iPhone15,4").isIPhone15OrNewer, "iPhone 15")
        XCTAssertTrue(hardware("iPhone15,5").isIPhone15OrNewer, "iPhone 15 Plus")
        XCTAssertTrue(hardware("iPhone16,1").isIPhone15OrNewer, "iPhone 15 Pro")
        XCTAssertTrue(hardware("iPhone16,2").isIPhone15OrNewer, "iPhone 15 Pro Max")
        XCTAssertTrue(hardware("iPhone17,3").isIPhone15OrNewer, "iPhone 16")
        XCTAssertTrue(hardware("iPhone18,1").isIPhone15OrNewer, "iPhone 17 Pro")
        XCTAssertTrue(hardware("iPhone99,1").isIPhone15OrNewer, "something not shipped yet")
    }

    func testTheOlderPhones() {
        XCTAssertFalse(hardware("iPhone14,7").isIPhone15OrNewer, "iPhone 14")
        XCTAssertFalse(hardware("iPhone14,2").isIPhone15OrNewer, "iPhone 13 Pro")
        XCTAssertFalse(hardware("iPhone12,1").isIPhone15OrNewer, "iPhone 11")
        XCTAssertFalse(hardware("iPhone8,4").isIPhone15OrNewer, "iPhone SE")
    }

    /// Anything that is not an iPhone in the shape this knows is not newer.
    /// A guess that goes the other way would put the island on a screen that
    /// has nothing to hang it from.
    func testSomethingUnrecognisableIsNotNewer() {
        XCTAssertFalse(hardware("").isIPhone15OrNewer)
        XCTAssertFalse(hardware("iPad14,3").isIPhone15OrNewer)
        XCTAssertFalse(hardware("x86_64").isIPhone15OrNewer)
        XCTAssertFalse(hardware("iPhone16").isIPhone15OrNewer)
        XCTAssertFalse(hardware("iPhone,1").isIPhone15OrNewer)
        XCTAssertFalse(hardware("iPhoneSE,3").isIPhone15OrNewer)
        XCTAssertFalse(hardware("iPhone16,1,2").isIPhone15OrNewer)
    }

    /// Both halves of the rule have to be true. A new phone on an old system
    /// draws the bar, and so does an old phone on a new one.
    func testTheShapeNeedsThePhoneAndTheSystem() {
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone16,1", iOS: 26)), .island)
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone16,1", iOS: 27)), .island)
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone16,1", iOS: 25)), .bar)
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone16,1", iOS: 18)), .bar)
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone15,2", iOS: 26)), .bar)
        XCTAssertEqual(RowShape.standard(on: hardware("iPhone14,7", iOS: 26)), .bar)
    }
}
