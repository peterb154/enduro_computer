import Foundation
import Testing
@testable import TrailDash

struct RaceScheduleTests {
    /// Test 2 from the IERA sample roll chart: Reset to 13.50 at 9:46:00, At 23.00 at 10:14:30.
    let test2 = ChartTest(startTime: 9 * 3600 + 46 * 60, endTime: 10 * 3600 + 14 * 60 + 30,
                          startMile: 13.5, endMile: 23.0)

    /// Race at 10:00, row 20 -> key time 10:20.
    var race: RaceSchedule {
        RaceSchedule(raceStartMinutes: 600, keyTimeMinutes: 620,
                     tests: [ChartTest(startTime: 36000), test2])
    }

    @Test func chartTestDerivedValues() {
        #expect(test2.idealTime == TimeInterval(28 * 60 + 30))
        #expect(abs((test2.lengthMiles ?? 0) - 9.5) < 1e-9)
        #expect(abs((test2.paceMph ?? 0) - 20.0) < 1e-9)
    }

    @Test func incompleteTestHasNoDerivedValues() {
        let test = ChartTest(startTime: 36000)
        #expect(test.idealTime == nil)
        #expect(test.lengthMiles == nil)
        #expect(test.paceMph == nil)
    }

    @Test func dueTimesShiftByKeyOffset() {
        #expect(race.keyOffsetSeconds == 20 * 60)
        #expect(race.dueSeconds(for: 1) == 10 * 3600 + 20 * 60)
        #expect(race.dueSeconds(for: 2) == 10 * 3600 + 6 * 60)
        #expect(race.dueSeconds(for: 3) == nil)
        #expect(race.dueSeconds(for: 0) == nil)
    }

    @Test func dueDateIsOnTheGivenDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let raceDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 7))!
        let due = race.dueDate(for: 2, on: raceDay, calendar: calendar)!
        let parts = calendar.dateComponents([.day, .hour, .minute, .second], from: due)
        #expect(parts.day == 11 && parts.hour == 10 && parts.minute == 6 && parts.second == 0)
    }

    @Test func parsesDigitsTypedOnNumberPad() {
        #expect(parseChartTime("94600", raceStartMinutes: 540) == 9 * 3600 + 46 * 60)
        #expect(parseChartTime("102230", raceStartMinutes: 540) == 10 * 3600 + 22 * 60 + 30)
        #expect(parseChartTime("946", raceStartMinutes: 540) == 9 * 3600 + 46 * 60)
        #expect(parseChartTime("10:22:30", raceStartMinutes: 540) == 10 * 3600 + 22 * 60 + 30)
    }

    @Test func afternoonChartTimesRollToPM() {
        // Chart prints "01:07:15" for 1:07 PM in a race that started at 9:00.
        #expect(parseChartTime("010715", raceStartMinutes: 540) == 13 * 3600 + 7 * 60 + 15)
        #expect(parseChartTime("124845", raceStartMinutes: 540) == 12 * 3600 + 48 * 60 + 45)
        // Shortly before the start stays AM.
        #expect(parseChartTime("83000", raceStartMinutes: 540) == 8 * 3600 + 30 * 60)
    }

    @Test func rejectsNonsense() {
        #expect(parseChartTime("", raceStartMinutes: 540) == nil)
        #expect(parseChartTime("12", raceStartMinutes: 540) == nil)
        #expect(parseChartTime("96000", raceStartMinutes: 540) == nil) // 60 minutes
        #expect(parseChartTime("1234567", raceStartMinutes: 540) == nil)
    }

    @Test func survivesJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(race)
        #expect(try JSONDecoder().decode(RaceSchedule.self, from: data) == race)
    }

    @Test func countdownPhases() {
        #expect(countdownPhase(remaining: 300) == .waiting)
        #expect(countdownPhase(remaining: 60) == .oneMinute)
        #expect(countdownPhase(remaining: 10) == .tenSeconds)
        #expect(countdownPhase(remaining: 0) == .late)
        #expect(countdownPhase(remaining: -30) == .late)
    }

    @Test func firstTestStartsAtMileZero() {
        var schedule = RaceSchedule()
        schedule.addTest()
        schedule.addTest()
        #expect(schedule.tests[0].startMile == 0)
        #expect(schedule.tests[1].startMile == nil)
    }
}
