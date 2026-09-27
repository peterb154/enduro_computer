import Foundation
import Testing
@testable import TrailDash

struct RaceScheduleTests {
    /// Race at 10:00, row 20 -> key 10:20, roll chart T1 10:00, T2 10:34, T3 11:02.
    var race: RaceSchedule {
        RaceSchedule(raceStartMinutes: 600, keyTimeMinutes: 620, rollChart: [600, 634, 662])
    }

    @Test func dueTimesShiftByKeyOffset() {
        #expect(race.keyOffsetMinutes == 20)
        #expect(race.dueMinutes(for: 1) == 620)
        #expect(race.dueMinutes(for: 2) == 654)
        #expect(race.dueMinutes(for: 3) == 682)
    }

    @Test func testsOffTheRollChartHaveNoDueTime() {
        #expect(race.dueMinutes(for: 0) == nil)
        #expect(race.dueMinutes(for: 4) == nil)
    }

    @Test func dueDateIsOnTheGivenDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let raceDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 7))!
        let due = race.dueDate(for: 2, on: raceDay, calendar: calendar)!
        let parts = calendar.dateComponents([.day, .hour, .minute], from: due)
        #expect(parts.day == 11 && parts.hour == 10 && parts.minute == 54)
    }

    @Test func addTestSteps30MinutesFromLast() {
        var schedule = RaceSchedule(raceStartMinutes: 600, keyTimeMinutes: 600)
        schedule.addTest()
        schedule.addTest()
        #expect(schedule.rollChart == [600, 630])
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
}
