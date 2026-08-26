import XCTest
@testable import Quiet

/// Sync is the one feature in this app that can hand somebody more time than
/// they agreed to, and do it silently. Every rule in the merge is here.
final class CarriedTests: XCTestCase {
    private let today = DayKey(ordinal: 9_000)
    private var tomorrow: DayKey { today.next }

    private func copy(
        version: Int,
        minutes: Int = 30,
        pending: PendingChange? = nil,
        lastIncrease: DayKey? = nil,
        cooldown: Int? = nil,
        day: DayKey? = nil,
        spent: [String: TimeInterval] = [:]
    ) -> Carried {
        Carried(
            version: version,
            limit: LimitState(
                minutes: minutes,
                pending: pending,
                lastIncrease: lastIncrease,
                cooldown: cooldown
            ),
            day: day ?? today,
            byDevice: spent
        )
    }

    // MARK: - What is spent

    /// The reason each phone keeps its own figure. Two phones that each spend
    /// ten minutes have spent twenty, and a single total could only be merged
    /// by adding — which spends it twice the second time you sync.
    func testTwoPhonesSpendingTheSameDayAddUp() {
        let merged = Carried.merge(
            copy(version: 3, spent: ["a": 600]),
            copy(version: 4, spent: ["b": 600])
        )
        XCTAssertEqual(merged.spentToday, 1200)
    }

    func testMergingTwiceSpendsItOnce() {
        let mine = copy(version: 3, spent: ["a": 600])
        let theirs = copy(version: 4, spent: ["b": 600])
        let once = Carried.merge(mine, theirs)
        let twice = Carried.merge(once, theirs)
        XCTAssertEqual(once, twice)
        XCTAssertEqual(twice.spentToday, 1200)
    }

    func testAPhoneThatHasSpentMoreSinceIsBelieved() {
        let merged = Carried.merge(
            copy(version: 5, spent: ["a": 900, "b": 100]),
            copy(version: 4, spent: ["b": 600])
        )
        XCTAssertEqual(merged.byDevice["b"], 600, "the other phone's own figure is its own")
        XCTAssertEqual(merged.spentToday, 1500)
    }

    func testYesterdaysFiguresDoNotFollowIntoToday() {
        let stale = copy(version: 9, day: today, spent: ["a": 1800])
        let fresh = copy(version: 2, day: tomorrow, spent: ["b": 60])
        let merged = Carried.merge(stale, fresh)
        XCTAssertEqual(merged.day, tomorrow)
        XCTAssertEqual(merged.spentToday, 60, "a new day starts at nothing, whoever is behind")
    }

    // MARK: - The agreement

    func testTheLaterWordWinsOnTheLimit() {
        let raised = copy(version: 8, minutes: 45)
        let stale = copy(version: 3, minutes: 30)
        XCTAssertEqual(Carried.merge(stale, raised).limit.minutes, 45)
        XCTAssertEqual(Carried.merge(raised, stale).limit.minutes, 45)
    }

    /// Neither phone has seen the other, so there is no later word — and the
    /// only tiebreak that cannot give time away is the smaller number.
    func testWhenNeitherIsNewerTheSmallerLimitWins() {
        let merged = Carried.merge(
            copy(version: 4, minutes: 45),
            copy(version: 4, minutes: 30)
        )
        XCTAssertEqual(merged.limit.minutes, 30)
    }

    /// The door this closes: without it, an increase on one phone and an old
    /// copy from the other would buy a second increase in the same week.
    func testAStaleCopyCannotResetTheWeeklyClock() {
        let raisedToday = copy(version: 8, minutes: 45, lastIncrease: today)
        let neverRaised = copy(version: 9, minutes: 45, lastIncrease: nil)
        XCTAssertEqual(Carried.merge(raisedToday, neverRaised).limit.lastIncrease, today)
        XCTAssertEqual(Carried.merge(neverRaised, raisedToday).limit.lastIncrease, today)
    }

    func testTheLaterIncreaseDayIsTheOneThatCounts() {
        let older = copy(version: 9, lastIncrease: today.adding(days: -3))
        let newer = copy(version: 2, lastIncrease: today)
        XCTAssertEqual(Carried.merge(older, newer).limit.lastIncrease, today)
    }

    /// Two phones offline, each queuing an increase, is the escape somebody
    /// would actually try. It buys the smaller of the two, which is no more
    /// than asking once.
    func testTwoQueuedIncreasesCollapseToTheSmaller() {
        let big = copy(version: 5, pending: PendingChange(minutes: 90, effective: tomorrow))
        let small = copy(version: 6, pending: PendingChange(minutes: 40, effective: tomorrow))
        XCTAssertEqual(Carried.merge(big, small).limit.pending?.minutes, 40)
        XCTAssertEqual(Carried.merge(small, big).limit.pending?.minutes, 40)
    }

    func testCancellingAQueuedIncreaseWins() {
        let queued = copy(version: 5, pending: PendingChange(minutes: 90, effective: tomorrow))
        let cancelled = copy(version: 6, pending: nil)
        XCTAssertNil(Carried.merge(queued, cancelled).limit.pending)
        XCTAssertNil(Carried.merge(cancelled, queued).limit.pending)
    }

    func testAQueuedIncreaseTheOtherPhoneHasNotHeardOfSurvives() {
        let queued = copy(version: 7, pending: PendingChange(minutes: 40, effective: tomorrow))
        let behind = copy(version: 3, pending: nil)
        XCTAssertEqual(Carried.merge(queued, behind).limit.pending?.minutes, 40)
    }

    func testTheLongerWaitWins() {
        let strict = copy(version: 2, cooldown: 30)
        let loose = copy(version: 8, cooldown: 7)
        XCTAssertEqual(Carried.merge(strict, loose).limit.cooldownDays, 30)
        XCTAssertEqual(Carried.merge(loose, strict).limit.cooldownDays, 30)
    }

    /// A default is not a value. Filling the wait in during a merge looks
    /// harmless and is not: the record comes back different from the one that
    /// was sent, so every reconciliation decides something has changed and
    /// writes again, for ever, over a field nobody touched.
    func testAWaitNobodyHasSetStaysUnset() {
        let merged = Carried.merge(copy(version: 3), copy(version: 4))
        XCTAssertNil(merged.limit.cooldown)
        XCTAssertEqual(merged.limit.cooldownDays, LimitPolicy.defaultCooldownDays)
    }

    // MARK: - The properties the whole thing rests on

    func testTheOrderThePhonesOpenInDoesNotMatter() {
        let mine = copy(
            version: 6,
            minutes: 45,
            pending: PendingChange(minutes: 60, effective: tomorrow),
            lastIncrease: today,
            cooldown: 14,
            spent: ["a": 300]
        )
        let theirs = copy(
            version: 4,
            minutes: 30,
            pending: PendingChange(minutes: 50, effective: tomorrow),
            lastIncrease: today.adding(days: -2),
            cooldown: 7,
            spent: ["b": 900]
        )
        XCTAssertEqual(Carried.merge(mine, theirs), Carried.merge(theirs, mine))
    }

    func testMergingAResultBackInChangesNothing() {
        let mine = copy(version: 6, minutes: 45, lastIncrease: today, spent: ["a": 300])
        let theirs = copy(version: 4, minutes: 30, cooldown: 14, spent: ["b": 900])
        let once = Carried.merge(mine, theirs)
        XCTAssertEqual(Carried.merge(once, mine), once)
        XCTAssertEqual(Carried.merge(once, theirs), once)
        XCTAssertEqual(Carried.merge(once, once), once)
    }
}
