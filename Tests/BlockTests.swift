import XCTest
@testable import Done

/// The rules that decide whether apps are shielded. All of it is pure, so it
/// runs without a device — which is the half of this feature that can be
/// checked automatically.
final class BlockTests: XCTestCase {

    private func block(_ conditions: [Condition]) -> Habit {
        var h = Habit(name: "Read your book")
        h.conditions = conditions
        return h
    }

    // MARK: unlock rules

    func testNoConditionsNeverLocks() {
        XCTAssertTrue(block([]).isUnlocked(on: Date(), gate: Gate()))
    }

    func testHealthConditionNeedsTheGate() {
        let h = block([.steps(count: 10_000)])
        XCTAssertFalse(h.isUnlocked(on: Date(), gate: Gate()))

        var gate = Gate()
        gate.healthMet.insert(h.id)
        XCTAssertTrue(h.isUnlocked(on: Date(), gate: gate))
    }

    func testBankedUnlockIsNotASpentOne() {
        let h = block([.appTime(minutes: 5)])
        var gate = Gate()
        gate.banked.insert(h.id)
        XCTAssertFalse(h.isUnlocked(on: Date(), gate: gate),
                       "banking earns the right to open, it does not open")

        gate.banked.remove(h.id)
        gate.open.insert(h.id)
        XCTAssertTrue(h.isUnlocked(on: Date(), gate: gate))
    }

    func testEveryConditionMustBeMet() {
        let h = block([.steps(count: 10), .appTime(minutes: 5)])
        var gate = Gate()
        gate.healthMet.insert(h.id)
        XCTAssertFalse(h.isUnlocked(on: Date(), gate: gate), "half met is not met")
        gate.open.insert(h.id)
        XCTAssertTrue(h.isUnlocked(on: Date(), gate: gate))
    }

    func testDayTheBlockDoesNotRunOnIsOpen() {
        var h = block([.steps(count: 10_000)])
        let today = Date()
        h.days = Set((1...7).filter { $0 != Calendar.current.component(.weekday, from: today) })
        XCTAssertTrue(h.isUnlocked(on: today, gate: Gate()))
    }

    // MARK: health thresholds

    func testHealthMetComparesEachSourceToItsOwnTarget() {
        let h = block([.steps(count: 1_000), .workout(minutes: 30), .mindful(minutes: 10)])
        XCTAssertFalse(h.healthMet(steps: 999, workoutMinutes: 30, mindfulMinutes: 10))
        XCTAssertFalse(h.healthMet(steps: 1_000, workoutMinutes: 29, mindfulMinutes: 10))
        XCTAssertFalse(h.healthMet(steps: 1_000, workoutMinutes: 30, mindfulMinutes: 9))
        XCTAssertTrue(h.healthMet(steps: 1_000, workoutMinutes: 30, mindfulMinutes: 10))
    }

    func testAppTimeIsNotAnswerableByHealth() {
        XCTAssertTrue(block([.appTime(minutes: 5)])
            .healthMet(steps: 0, workoutMinutes: 0, mindfulMinutes: 0),
                      "health has no opinion on app time; the gate decides")
    }

    // MARK: daily roll over

    func testRollOverClearsYesterdayButNotToday() {
        var gate = Gate()
        gate.banked.insert(UUID())
        gate.open.insert(UUID())
        gate.day = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        XCTAssertTrue(gate.rollOverIfNeeded())
        XCTAssertTrue(gate.banked.isEmpty)
        XCTAssertTrue(gate.open.isEmpty)

        gate.banked.insert(UUID())
        XCTAssertFalse(gate.rollOverIfNeeded(), "same day must not wipe anything")
        XCTAssertEqual(gate.banked.count, 1)
    }

    // MARK: shield copy

    func testShieldAsksForWhatIsMissing() {
        // The count is grouped for the reader's locale, so the expectation has
        // to be too — hardcoding "10,000" only passes in an English simulator.
        let grouped = 10_000.formatted(.number.grouping(.automatic))
        XCTAssertEqual(block([.steps(count: 10_000)]).shieldSubtitle,
                       "Walk \(grouped) steps to unlock.")
        XCTAssertEqual(block([.workout(minutes: 45)]).shieldSubtitle,
                       "Finish a 45 min workout to unlock.")
    }

    func testShieldJoinsSeveralConditions() {
        let text = block([.steps(count: 100), .mindful(minutes: 5)]).shieldSubtitle
        XCTAssertEqual(text, "Walk 100 steps and meditate for 5 min to unlock.",
                       "three-digit counts are not grouped in any locale")
    }

    func testShieldNamesTheBankedTimeWhenBlockAgainIsSet() {
        var h = block([.appTime(minutes: 2)])
        h.blockAgainMinutes = 5
        XCTAssertEqual(h.shieldSubtitle, "Use Read your book for 2 min to bank a 5-min unlock.")
    }

    // MARK: chips

    func testCompactNumbersDropWholeDecimals() {
        XCTAssertEqual(235.compact, "235")
        XCTAssertEqual(5_000.compact, "5k")
        XCTAssertEqual(12_500.compact, "12.5k")
        XCTAssertEqual(100_000.compact, "100k")
        XCTAssertEqual(1_200_000.compact, "1.2M")
    }

    func testCustomFieldAsksForTheRightUnit() {
        XCTAssertEqual(Condition.unit(kind: "steps"), "Steps")
        XCTAssertEqual(Condition.unit(kind: "appTime"), "Minutes")
        XCTAssertEqual(Condition.make(kind: "appTime", value: 7), .appTime(minutes: 7))
        XCTAssertNil(Condition.make(kind: "nonsense", value: 1))
    }
}

/// The pomodoro round the shield reads to explain itself.
final class FocusSessionTests: XCTestCase {

    func testMinutesLeftRoundsUpSoItNeverReadsZeroEarly() {
        let session = FocusSession(endsAt: Date().addingTimeInterval(61))
        XCTAssertEqual(session.minutesLeft, 2)
    }

    func testAFinishedRoundHasNoMinutesLeft() {
        XCTAssertEqual(FocusSession(endsAt: Date().addingTimeInterval(-60)).minutesLeft, 0)
    }

    func testStoringNilClearsTheRound() {
        FocusSession.store(FocusSession(endsAt: Date().addingTimeInterval(600)))
        XCTAssertNotNil(FocusSession.current)
        FocusSession.store(nil)
        XCTAssertNil(FocusSession.current)
    }

    func testAnExpiredRoundReadsAsNoRound() {
        FocusSession.store(FocusSession(endsAt: Date().addingTimeInterval(-1)))
        XCTAssertNil(FocusSession.current, "a stale entry must not keep the focus copy up")
        FocusSession.store(nil)
    }
}

extension BlockTests {
    func testCardDetailListsWhatItAsksAndWhatItPays() {
        var h = block([.appTime(minutes: 2)])
        h.blockAgainMinutes = 5
        XCTAssertEqual(h.cardDetail, "2 min in the app · 5 min per unlock")
    }

    func testCardDetailIsEmptyWithoutConditions() {
        XCTAssertEqual(block([]).cardDetail, "")
    }
}

extension BlockTests {
    func testDurationKeepsTheTwoUnitsThatCarryInformation() {
        XCTAssertEqual(45.duration, "45s")
        XCTAssertEqual(60.duration, "1m")
        XCTAssertEqual(200.duration, "3m 20s")
        XCTAssertEqual(3600.duration, "1h")
        XCTAssertEqual(3900.duration, "1h 5m")
        XCTAssertEqual(0.duration, "0s", "a short visit must not read as 0m")
    }
}

final class ScheduleTests: XCTestCase {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func testNoRangesMeansAllDay() {
        let habit = Habit(name: "All day")
        XCTAssertTrue(habit.applies(at: at(3)))
        XCTAssertTrue(habit.applies(at: at(14)))
    }

    func testBlockDuringOnlyInsideTheRange() {
        var habit = Habit(name: "Work hours")
        habit.ranges = [TimeRange(start: 9 * 60, end: 17 * 60)]
        XCTAssertFalse(habit.applies(at: at(8, 59)))
        XCTAssertTrue(habit.applies(at: at(9)))
        XCTAssertTrue(habit.applies(at: at(16, 59)))
        XCTAssertFalse(habit.applies(at: at(17)))
    }

    func testUnblockDuringIsTheInverse() {
        var habit = Habit(name: "Lunch only")
        habit.blockDuring = false
        habit.ranges = [TimeRange(start: 12 * 60, end: 13 * 60)]
        XCTAssertTrue(habit.applies(at: at(9)))
        XCTAssertFalse(habit.applies(at: at(12, 30)))
        XCTAssertTrue(habit.applies(at: at(20)))
    }

    func testOutsideItsWindowAConditionBlockIsOpen() {
        var habit = Habit(name: "Chess", conditions: [.steps(count: 10_000)])
        habit.ranges = [TimeRange(start: 9 * 60, end: 17 * 60)]
        let gate = Gate()
        XCTAssertTrue(habit.isUnlocked(on: at(20), gate: gate), "steps unmet, but the block is off duty")
        XCTAssertFalse(habit.isUnlocked(on: at(10), gate: gate))
    }
}

final class ZoneTests: XCTestCase {
    private func home(_ blockInside: Bool) -> Habit {
        var habit = Habit(name: "Home", conditions: [.steps(count: 10_000)])
        habit.zone = Zone(name: "Home", latitude: -9.6, longitude: -35.7, radius: 50,
                          blockInside: blockInside)
        return habit
    }

    func testNoZoneAppliesEverywhere() {
        XCTAssertTrue(Habit(name: "Anywhere").appliesHere(gate: Gate()))
    }

    func testBlockHereOnlyLocksInsideTheCircle() {
        let habit = home(true)
        var gate = Gate()
        XCTAssertFalse(habit.appliesHere(gate: gate))
        gate.inZone.insert(habit.id)
        XCTAssertTrue(habit.appliesHere(gate: gate))
    }

    func testUnlockHereIsTheInverse() {
        let habit = home(false)
        var gate = Gate()
        XCTAssertTrue(habit.appliesHere(gate: gate), "away from the circle the block still holds")
        gate.inZone.insert(habit.id)
        XCTAssertFalse(habit.appliesHere(gate: gate))
    }

    func testAwayFromAZoneTheAppsOpenWithoutTheSteps() {
        let habit = home(true)
        XCTAssertTrue(habit.isUnlocked(on: Date(), gate: Gate()))
    }
}

