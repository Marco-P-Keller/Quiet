import XCTest
@testable import Quiet

/// The rule, stated as tests.
///
/// If any of these ever have to be relaxed to make a feature work, the feature
/// is wrong.
final class LimitPolicyTests: XCTestCase {
    private let day0 = DayKey(ordinal: 1_000)

    private func state(_ minutes: Int, pending: PendingChange? = nil, lastIncrease: DayKey? = nil) -> LimitState {
        LimitState(minutes: minutes, pending: pending, lastIncrease: lastIncrease)
    }

    // MARK: - Asking for less

    func testLoweringAppliesImmediately() throws {
        let result = try LimitPolicy.request(10, from: state(30), today: day0).get()
        XCTAssertEqual(result.change, .now(10))
        XCTAssertEqual(result.state.minutes, 10)
        XCTAssertNil(result.state.pending)
    }

    func testLoweringDoesNotStartTheWeeklyClock() throws {
        let result = try LimitPolicy.request(10, from: state(30), today: day0).get()
        XCTAssertNil(result.state.lastIncrease, "asking for less must never cost the weekly allowance")
        XCTAssertNil(LimitPolicy.nextIncreaseDay(result.state, today: day0))
    }

    /// The hole this closes: raise the limit, drop it the next day, and raise it
    /// again — a weekly rule that resets on every reduction is no rule at all.
    func testLoweringDoesNotClearAnEarlierIncrease() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        let lowered = try LimitPolicy.request(15, from: raised, today: day0.adding(days: 1)).get().state

        XCTAssertEqual(lowered.lastIncrease, day0)
        let refusal = LimitPolicy.request(60, from: lowered, today: day0.adding(days: 2))
        XCTAssertEqual(refusal, .failure(.tooSoon(nextAllowed: day0.adding(days: 7))))
    }

    func testLoweringCancelsAQueuedIncrease() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        XCTAssertNotNil(raised.pending)

        let lowered = try LimitPolicy.request(20, from: raised, today: day0).get()
        XCTAssertNil(lowered.state.pending, "a queued increase must not survive a reduction")
        XCTAssertEqual(lowered.state.minutes, 20)
    }

    func testAskingForTheCurrentLimitCancelsAQueuedIncrease() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        let cancelled = try LimitPolicy.request(30, from: raised, today: day0).get()
        XCTAssertEqual(cancelled.change, .now(30))
        XCTAssertNil(cancelled.state.pending)
    }

    // MARK: - Asking for more

    func testRaisingNeverTakesEffectToday() throws {
        let result = try LimitPolicy.request(60, from: state(30), today: day0).get()
        XCTAssertEqual(result.change, .on(day0.next, 60))
        XCTAssertEqual(result.state.minutes, 30, "today keeps the limit it started with")
        XCTAssertEqual(result.state.pending, PendingChange(minutes: 60, effective: day0.next))
    }

    func testRaisingIsRefusedForSevenDays() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state

        for offset in 1...6 {
            let attempt = LimitPolicy.request(90, from: raised, today: day0.adding(days: offset))
            XCTAssertEqual(
                attempt, .failure(.tooSoon(nextAllowed: day0.adding(days: 7))),
                "day \(offset) after an increase must still be refused"
            )
        }
    }

    func testRaisingIsPossibleAgainOnTheSeventhDay() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        let rolled = LimitPolicy.rolled(raised, to: day0.adding(days: 7))
        let again = try LimitPolicy.request(90, from: rolled, today: day0.adding(days: 7)).get()
        XCTAssertEqual(again.change, .on(day0.adding(days: 8), 90))
    }

    func testTheFirstIncreaseIsNotBlockedBySetup() throws {
        let fresh = state(20)
        XCTAssertNil(LimitPolicy.nextIncreaseDay(fresh, today: day0))
        let result = try LimitPolicy.request(30, from: fresh, today: day0).get()
        XCTAssertEqual(result.change, .on(day0.next, 30))
    }

    func testTheWeekRunsFromTheDecisionNotFromTheDayItTakesEffect() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        XCTAssertEqual(raised.lastIncrease, day0)
        XCTAssertEqual(LimitPolicy.nextIncreaseDay(raised, today: day0), day0.adding(days: 7))
    }

    // MARK: - Revising a queued increase

    func testAQueuedIncreaseCanBeRevisedDownWithoutSpendingTheWeek() throws {
        let raised = try LimitPolicy.request(120, from: state(30), today: day0).get().state
        let revised = try LimitPolicy.request(45, from: raised, today: day0).get()

        XCTAssertEqual(revised.change, .on(day0.next, 45))
        XCTAssertEqual(revised.state.pending, PendingChange(minutes: 45, effective: day0.next))
        XCTAssertEqual(revised.state.lastIncrease, day0, "the clock keeps running from the original decision")
    }

    func testAQueuedIncreaseCannotBeRevisedUp() {
        let raised = try? LimitPolicy.request(45, from: state(30), today: day0).get().state
        let attempt = LimitPolicy.request(120, from: raised!, today: day0)
        XCTAssertEqual(attempt, .failure(.tooSoon(nextAllowed: day0.adding(days: 7))))
    }

    // MARK: - Rolling over

    func testAQueuedIncreaseTakesEffectOnItsDay() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state

        XCTAssertEqual(LimitPolicy.rolled(raised, to: day0).minutes, 30, "not yet")

        let tomorrow = LimitPolicy.rolled(raised, to: day0.next)
        XCTAssertEqual(tomorrow.minutes, 60)
        XCTAssertNil(tomorrow.pending)
    }

    func testRollingOverIsIdempotentAndSurvivesASkippedDay() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        let once = LimitPolicy.rolled(raised, to: day0.adding(days: 4))
        let twice = LimitPolicy.rolled(once, to: day0.adding(days: 4))
        XCTAssertEqual(once, twice)
        XCTAssertEqual(once.minutes, 60, "a phone left in a drawer still gets the change it was owed")
    }

    func testRollingOverKeepsTheWeeklyClock() throws {
        let raised = try LimitPolicy.request(60, from: state(30), today: day0).get().state
        let rolled = LimitPolicy.rolled(raised, to: day0.next)
        XCTAssertEqual(rolled.lastIncrease, day0)
    }

    // MARK: - Bounds

    func testRefusesNumbersOutsideTheSupportedRange() {
        XCTAssertEqual(
            LimitPolicy.request(0, from: state(30), today: day0),
            .failure(.outOfRange(LimitPolicy.allowed))
        )
        XCTAssertEqual(
            LimitPolicy.request(10_000, from: state(30), today: day0),
            .failure(.outOfRange(LimitPolicy.allowed))
        )
    }

    func testRefusesANumberThatChangesNothing() {
        XCTAssertEqual(LimitPolicy.request(30, from: state(30), today: day0), .failure(.unchanged))
    }
}

/// `Result` is only `Equatable` when both of its types are, and the success side
/// here is a tuple. Comparing the two halves by hand keeps the assertions above
/// readable.
private func XCTAssertEqual(
    _ actual: Result<(state: LimitState, change: LimitChange), LimitRefusal>,
    _ expected: Result<(state: LimitState, change: LimitChange), LimitRefusal>,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    switch (actual, expected) {
    case let (.success(a), .success(b)):
        XCTAssertEqual(a.state, b.state, message(), file: file, line: line)
        XCTAssertEqual(a.change, b.change, message(), file: file, line: line)
    case let (.failure(a), .failure(b)):
        XCTAssertEqual(a, b, message(), file: file, line: line)
    default:
        XCTFail("expected \(expected), got \(actual). \(message())", file: file, line: line)
    }
}

/// How long the wait is, which is itself a thing that can be asked about.
///
/// The whole app is one asymmetry — asking for less is free, asking for more
/// waits — and the wait is the load-bearing half of it. So the number saying
/// how long the wait is has to obey the same rule, or it becomes the way around
/// it: the one dial you could turn down at the exact moment it started to bite.
final class CooldownTests: XCTestCase {
    private let day0 = DayKey(ordinal: 20_000)

    private func state(cooldown: Int? = nil, lastIncrease: DayKey? = nil) -> LimitState {
        LimitState(minutes: 30, lastIncrease: lastIncrease, cooldown: cooldown)
    }

    func testAWeekUnlessSomebodySaysOtherwise() {
        XCTAssertEqual(state().cooldownDays, LimitPolicy.defaultCooldownDays)
        XCTAssertEqual(state(cooldown: 30).cooldownDays, 30)
    }

    /// A state written before this number existed decodes without it. A
    /// synthesised decoder throws for a missing key rather than reaching for a
    /// default, which is why it is optional and read through an accessor.
    func testAStateWrittenBeforeThisExistedStillReads() throws {
        let old = #"{"minutes":45}"#.data(using: .utf8)!
        let read = try JSONDecoder().decode(LimitState.self, from: old)
        XCTAssertEqual(read.minutes, 45)
        XCTAssertEqual(read.cooldownDays, 7)
    }

    func testAskingToBeHeldToAStricterRuleIsFree() throws {
        // Even with an increase asked for today, which would refuse anything
        // that made the rule looser.
        let after = try LimitPolicy.requestCooldown(
            30, from: state(lastIncrease: day0), today: day0
        ).get()
        XCTAssertEqual(after.cooldownDays, 30)
    }

    func testAskingForALooserRuleWaits() {
        let result = LimitPolicy.requestCooldown(
            7, from: state(cooldown: 30, lastIncrease: day0), today: day0.adding(days: 5)
        )
        XCTAssertEqual(result, .failure(.tooSoon(nextAllowed: day0.adding(days: 30))))
    }

    /// And when it is allowed, it spends the wait — otherwise shortening the
    /// wait would be the free move that shortening the limit is, and the weekly
    /// rule would have a door in it.
    func testALooserRuleCostsTheWaitItJustUsed() throws {
        let after = try LimitPolicy.requestCooldown(
            7, from: state(cooldown: 30, lastIncrease: day0), today: day0.adding(days: 30)
        ).get()

        XCTAssertEqual(after.cooldownDays, 7)
        XCTAssertEqual(after.lastIncrease, day0.adding(days: 30))
        XCTAssertEqual(
            LimitPolicy.request(60, from: after, today: day0.adding(days: 30)),
            .failure(.tooSoon(nextAllowed: day0.adding(days: 37))),
            "the new wait starts now rather than being backdated to the old one"
        )
    }

    /// A first change, with nothing to wait for yet.
    func testWithNoIncreaseEverAskedForTheWaitCanBeSetEitherWay() throws {
        let after = try LimitPolicy.requestCooldown(
            14, from: state(cooldown: 30), today: day0
        ).get()
        XCTAssertEqual(after.cooldownDays, 14)
    }

    func testTheSameNumberIsNotAChange() {
        XCTAssertEqual(
            LimitPolicy.requestCooldown(7, from: state(), today: day0),
            .failure(.unchanged)
        )
    }

    func testOnlyTheWaitsOnOfferAreAccepted() {
        for days in [0, 1, 6, 8, 365] {
            XCTAssertEqual(
                LimitPolicy.requestCooldown(days, from: state(), today: day0),
                .failure(.outOfRange(7...30)),
                "\(days)"
            )
        }
    }

    /// The rule the whole thing rests on, said as a sentence: the wait in force
    /// is the one that decides when the next increase is allowed.
    func testALongerWaitActuallyMakesTheNextIncreaseWait() {
        let strict = state(cooldown: 30, lastIncrease: day0)
        XCTAssertEqual(
            LimitPolicy.request(60, from: strict, today: day0.adding(days: 8)),
            .failure(.tooSoon(nextAllowed: day0.adding(days: 30)))
        )
        XCTAssertEqual(
            LimitPolicy.nextIncreaseDay(strict, today: day0.adding(days: 8)),
            day0.adding(days: 30)
        )
    }
}
