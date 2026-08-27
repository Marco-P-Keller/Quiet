import XCTest
@testable import Quiet

/// The half of the clock that used to be open.
///
/// Turning the date back was always caught. Turning it forward bought a whole
/// fresh day, and the trade-offs said so plainly: it could not be seen without
/// a server. It can — every page the app loads comes back carrying Instagram's
/// own `Date` header, and the device's uptime counts real elapsed time from the
/// last restart whatever the wall clock is set to.
final class TimeAnchorTests: XCTestCase {
    private final class FakeTime: TimeSource {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    /// A stand-in for `systemUptime`: monotonic, and nothing in Settings can
    /// reach it — which is the whole reason the real one is used.
    private final class FakeUptime {
        var seconds: TimeInterval = 1_000
        var reading: () -> TimeInterval { { [self] in seconds } }
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    private func made(
        at now: Date,
        store: MemoryStore = MemoryStore(),
        uptime: FakeUptime = FakeUptime()
    ) -> (MonotonicClock, FakeTime, FakeUptime, MemoryStore) {
        let base = FakeTime(now)
        return (
            MonotonicClock(base: base, store: store, uptime: uptime.reading),
            base, uptime, store
        )
    }

    // MARK: - Reading the header

    func testTheHeaderIsReadInTheFormServersActuallySendIt() {
        XCTAssertEqual(
            ServerDate.parse("Sun, 06 Nov 1994 08:49:37 GMT"),
            Date(timeIntervalSince1970: 784_111_777)
        )
    }

    /// The formatter is pinned to POSIX and to GMT. Without that it inherits
    /// the reader's locale — and on a phone set to a calendar with different
    /// numerals it reads a perfectly ordinary header as nothing at all.
    func testNonsenseIsNotADate() {
        for header in ["", "   ", "yesterday", "1994-11-06T08:49:37Z"] {
            XCTAssertNil(ServerDate.parse(header), header)
        }
        XCTAssertNil(ServerDate.parse(nil))
    }

    /// A clock anybody on the network could set is not a clock. Only
    /// Instagram's own hosts, and only over HTTPS.
    func testOnlyInstagramOverHTTPSIsBelieved() {
        let header = ["Date": "Sun, 06 Nov 1994 08:49:37 GMT"]
        func response(_ address: String) -> HTTPURLResponse {
            HTTPURLResponse(
                url: URL(string: address)!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: header
            )!
        }

        XCTAssertNotNil(ServerDate.vouched(by: response("https://www.instagram.com/")))
        XCTAssertNotNil(ServerDate.vouched(by: response("https://i.instagram.com/api/v1/x")))
        XCTAssertNil(
            ServerDate.vouched(by: response("http://www.instagram.com/")),
            "plain text is a clock anybody on the network can set"
        )
        XCTAssertNil(ServerDate.vouched(by: response("https://example.com/")))
    }

    // MARK: - What the clock does with it

    /// The attack, and the answer. The phone is told it is a week later; the
    /// uptime says four seconds have passed; the app goes by the uptime.
    func testADateMovedForwardIsIgnored() {
        let (clock, base, uptime, _) = made(at: start)
        clock.vouch(start)

        uptime.seconds += 4
        base.now = start.addingTimeInterval(7 * day)

        XCTAssertEqual(
            clock.now,
            start.addingTimeInterval(4),
            "four seconds passed, whatever the settings screen says"
        )
        XCTAssertTrue(clock.isAdvanced)
    }

    /// And the ordinary case, which must not be disturbed: a phone whose clock
    /// agrees with the server, running for an hour.
    func testAnHonestClockIsLeftAlone() {
        let (clock, base, uptime, _) = made(at: start)
        clock.vouch(start)

        uptime.seconds += 3600
        base.now = start.addingTimeInterval(3600)

        XCTAssertEqual(clock.now, start.addingTimeInterval(3600))
        XCTAssertFalse(clock.isAdvanced)
    }

    /// Skew is not an attack. A phone a couple of minutes off a server is every
    /// phone, and being stubborn about it would break the app for everybody to
    /// catch nobody.
    func testASmallDisagreementIsSkewRatherThanAFact() {
        let (clock, base, uptime, _) = made(at: start)
        clock.vouch(start)

        uptime.seconds += 60
        base.now = start.addingTimeInterval(60 + 120)

        XCTAssertEqual(clock.now, start.addingTimeInterval(180))
        XCTAssertFalse(clock.isAdvanced)
    }

    /// Offline, nothing has vouched for anything, and the honest answer is not
    /// "the clock is fine" — it is "nobody has said". The device is followed,
    /// exactly as it was before any of this existed.
    func testWithNoAnchorTheDeviceIsFollowed() {
        let (clock, base, _, _) = made(at: start)
        base.now = start.addingTimeInterval(7 * day)

        XCTAssertEqual(clock.now, start.addingTimeInterval(7 * day))
        XCTAssertFalse(clock.isAdvanced)
    }

    /// The rewind protection still stands, and it stands *first*: a mark made
    /// of honest time is not lowered by a device that has since been pulled
    /// back.
    func testARewindIsStillRefused() {
        let (clock, base, uptime, _) = made(at: start)
        clock.vouch(start)
        uptime.seconds += 7200
        base.now = start.addingTimeInterval(7200)
        _ = clock.now

        base.now = start
        XCTAssertEqual(clock.now, start.addingTimeInterval(7200))
        XCTAssertTrue(clock.isRewound)
    }

    /// The case nothing could mend before.
    ///
    /// Push the clock forward a month, let the mark record it, pull it back.
    /// By its own rule the app then freezes for a month — correctly, and
    /// uselessly for the person holding the phone. A vouched-for instant behind
    /// the mark is evidence the mark was made of a lie, so the mark comes down.
    func testAnAnchorMendsAMarkMadeOfALie() {
        let (clock, base, uptime, store) = made(at: start)

        base.now = start.addingTimeInterval(30 * day)
        _ = clock.now
        XCTAssertEqual(clock.now, start.addingTimeInterval(30 * day))

        base.now = start
        XCTAssertTrue(clock.isRewound, "by its own rule, and it would stay this way")

        uptime.seconds += 5
        clock.vouch(start.addingTimeInterval(5))

        XCTAssertEqual(clock.now, start.addingTimeInterval(5), "the month never happened")
        XCTAssertFalse(clock.isRewound)
        XCTAssertEqual(store.highWaterMark, start.addingTimeInterval(5))
    }

    /// The anchor is a moment plus an uptime, and the uptime is what makes it
    /// worth anything. Read on its own it is arithmetic.
    func testAnAnchorCountsForwardsByRealTime() {
        let anchor = TimeAnchor(instant: start, uptime: 500)
        XCTAssertEqual(anchor.now(at: 500), start)
        XCTAssertEqual(anchor.now(at: 560), start.addingTimeInterval(60))
    }
}
