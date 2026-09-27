import Foundation

/// One timed test as printed on the roll chart. In restart enduros each test
/// is the stretch between resets: it starts at a "Reset to" line and ends at
/// the "At" line before the next reset (or the chart's last line).
/// Times are seconds since midnight, as printed (i.e. for the race start, row 0).
nonisolated struct ChartTest: Codable, Equatable {
    var startTime: Int?
    var endTime: Int?
    var startMile: Double?
    var endMile: Double?

    /// Chart time for the test; time dropped is measured against this.
    var idealTime: TimeInterval? {
        guard let startTime, let endTime, endTime > startTime else { return nil }
        return TimeInterval(endTime - startTime)
    }

    var lengthMiles: Double? {
        guard let startMile, let endMile, endMile > startMile else { return nil }
        return endMile - startMile
    }

    /// Average speed the chart expects over the test.
    var paceMph: Double? {
        guard let lengthMiles, let idealTime else { return nil }
        return lengthMiles / (idealTime / 3600)
    }
}

/// Key time and roll chart. The rider's due times are the chart times shifted
/// by their key time offset (key time - race start).
nonisolated struct RaceSchedule: Codable, Equatable {
    var raceStartMinutes = 10 * 60
    var keyTimeMinutes = 10 * 60
    /// Index 0 is Test 1.
    var tests: [ChartTest] = []

    var keyOffsetSeconds: Int { (keyTimeMinutes - raceStartMinutes) * 60 }

    /// The chart always starts at mile 0.00, so Test 1 starts there.
    mutating func addTest() {
        tests.append(tests.isEmpty ? ChartTest(startMile: 0) : ChartTest())
    }

    func test(_ number: Int) -> ChartTest? {
        tests.indices.contains(number - 1) ? tests[number - 1] : nil
    }

    /// This rider's due time at the test start, in seconds since midnight.
    func dueSeconds(for test: Int) -> Int? {
        self.test(test)?.startTime.map { $0 + keyOffsetSeconds }
    }

    func dueDate(for test: Int, on day: Date, calendar: Calendar = .current) -> Date? {
        dueSeconds(for: test).map { calendar.startOfDay(for: day).addingTimeInterval(TimeInterval($0)) }
    }
}

/// Parses a roll chart time typed as digits on the number pad: "94600" -> 9:46:00,
/// "102230" -> 10:22:30, "946" -> 9:46:00. Charts use a 12-hour clock without
/// AM/PM, so a time more than an hour before the race start is taken as PM.
nonisolated func parseChartTime(_ text: String, raceStartMinutes: Int) -> Int? {
    let digits = text.filter(\.isNumber).compactMap(\.wholeNumberValue)
    guard (3...6).contains(digits.count) else { return nil }
    let number = digits.reduce(0) { $0 * 10 + $1 }
    let hasSeconds = digits.count >= 5
    let hour = hasSeconds ? number / 10000 : number / 100
    let minute = hasSeconds ? number / 100 % 100 : number % 100
    let second = hasSeconds ? number % 100 : 0
    guard (0...23).contains(hour), minute < 60, second < 60 else { return nil }

    var seconds = hour * 3600 + minute * 60 + second
    if hour < 12, seconds < raceStartMinutes * 60 - 3600 {
        seconds += 12 * 3600
    }
    return seconds
}

nonisolated enum CountdownPhase: Equatable {
    case waiting, oneMinute, tenSeconds, late
}

nonisolated func countdownPhase(remaining: TimeInterval) -> CountdownPhase {
    if remaining <= 0 { return .late }
    if remaining <= 10 { return .tenSeconds }
    if remaining <= 60 { return .oneMinute }
    return .waiting
}
