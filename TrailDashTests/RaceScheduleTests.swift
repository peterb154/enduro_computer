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

    @Test func idealFromPrintedEndTime() {
        #expect(race.idealTime(for: 2) == TimeInterval(28 * 60 + 30))
        #expect(abs((test2.lengthMiles ?? 0) - 9.5) < 1e-9)
        #expect(abs((race.paceMph(for: 2) ?? 0) - 20.0) < 1e-9)
    }

    @Test func incompleteTestHasNoDerivedValues() {
        #expect(race.idealTime(for: 1) == nil)
        #expect(race.paceMph(for: 1) == nil)
        #expect(race.endSeconds(for: 1) == nil)
    }

    /// 2026 Bartlett, Test 3: starts 34.0 at 11:08:00, reset at 44.5, 30 mph chart; end time not printed.
    @Test func idealFromChartSpeedWhenEndTimeMissing() {
        let bartlett = RaceSchedule(raceStartMinutes: 600, keyTimeMinutes: 600, chartSpeedMph: 30,
                                    tests: [ChartTest(startTime: 11 * 3600 + 8 * 60, startMile: 34.0, endMile: 44.5)])
        #expect(bartlett.idealTime(for: 1) == TimeInterval(21 * 60))
        #expect(bartlett.endSeconds(for: 1) == 11 * 3600 + 29 * 60)
        #expect(abs((bartlett.paceMph(for: 1) ?? 0) - 30) < 1e-9)
    }

    @Test func printedEndTimeWinsOverChartSpeed() {
        var withSpeed = race
        withSpeed.chartSpeedMph = 30
        #expect(withSpeed.idealTime(for: 2) == TimeInterval(28 * 60 + 30))
    }

    @Test func decodesSetupSavedBeforeChartSpeedExisted() throws {
        let old = #"{"raceStartMinutes":540,"keyTimeMinutes":560,"tests":[{"startMile":0,"startTime":32400,"endMile":8.8,"endTime":34220}]}"#
        let decoded = try JSONDecoder().decode(RaceSchedule.self, from: Data(old.utf8))
        #expect(decoded.name == "My race")
        #expect(decoded.chartSpeedMph == nil)
        #expect(decoded.idealTime(for: 1) == TimeInterval(30 * 60 + 20))
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
        let original = race // `race` builds a new instance (and id) on each access
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(RaceSchedule.self, from: data) == original)
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

    @Test func parsesDecimalPadInput() {
        #expect(parseDecimal("44.5") == 44.5)
        #expect(parseDecimal("44,5") == 44.5)
        #expect(parseDecimal("65") == 65)
        #expect(parseDecimal("") == nil)
        #expect(parseDecimal("4.4.5") == nil)
    }

    @Test func milesToGoCountsDownPastZero() {
        #expect(abs(milesToGo(lengthMiles: 7.0, distanceMeters: 1609.344 * 2.5) - 4.5) < 1e-9)
        // Past the chart length (wrong chart): keeps counting, negative.
        #expect(abs(milesToGo(lengthMiles: 7.0, distanceMeters: 1609.344 * 7.3) + 0.3) < 1e-9)
    }

    @Test func repeatedCourseUsesEarlierLapDistance() {
        // Bartlett: two laps of four tests; the chart said Test 4 was 3 mi, GPS said 11.
        var race = RaceSchedule(tests: (0..<8).map { _ in ChartTest(startMile: 10, endMile: 13) })
        let t0 = Date(timeIntervalSince1970: 0)
        let test4 = SprintRun(test: 4, start: t0, end: t0.addingTimeInterval(3000),
                              distance: 1609.344 * 11, averageHeartRate: nil, maxHeartRate: nil, idealTime: nil)
        #expect(race.lengthMiles(for: 8, ridden: [test4]) == 3) // no repeat set: chart
        race.repeatsAfterTest = 4
        #expect(abs((race.lengthMiles(for: 8, ridden: [test4]) ?? 0) - 11) < 1e-9)
        #expect(race.lengthMiles(for: 7, ridden: [test4]) == 3) // Test 3 not ridden: chart
        #expect(race.lengthMiles(for: 4, ridden: [test4]) == 3) // lap 1 always uses the chart
    }

    /// 2026 Bartlett resets (Test 5-7 "At" values as corrected by the rider).
    let bartlettResets = [(0.7, 1.5), (8.5, 15.9), (26.2, 33.7), (44.5, 53.1), (65, 91.3),
                          (99, 106.4), (116.7, 124.2), (134.9, 143.6)]
        .map { ChartReset(atMile: $0.0, toMile: $0.1) }

    @Test func riddenMilesSkipResets() {
        #expect(abs(riddenMiles(from: 8.5, to: 19.0, resets: bartlettResets) - 3.1) < 1e-9) // T1 -> T2
        #expect(abs(riddenMiles(from: 65, to: 92.0, resets: bartlettResets) - 0.7) < 1e-9)   // T4 -> T5
        #expect(abs(riddenMiles(from: 0, to: 1.5, resets: bartlettResets) - 0.7) < 1e-9)     // start -> T1
        #expect(abs(riddenMiles(from: 34.0, to: 44.5, resets: bartlettResets) - 10.5) < 1e-9) // no reset inside
    }

    @Test func transferMilesBetweenTests() {
        let race = RaceSchedule(chartSpeedMph: 30,
                                tests: [ChartTest(startMile: 1.5, endMile: 8.5), ChartTest(startMile: 19.0, endMile: 26.2)],
                                resets: bartlettResets)
        #expect(abs((race.transferMiles(afterTest: 1, to: 2) ?? 0) - 3.1) < 1e-9)
        #expect(race.transferMiles(afterTest: 2, to: 3) == nil)
    }

    @Test func requiredSpeedForTransfer() {
        #expect(abs((requiredMph(miles: 3.1, secondsLeft: 12 * 60) ?? 0) - 15.5) < 1e-9)
        #expect(requiredMph(miles: 3.1, secondsLeft: 0) == nil)
    }
}
