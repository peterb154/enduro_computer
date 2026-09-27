import Foundation

/// One timed test from the roll chart. A test starts at the start check (the
/// whole-minute line after "Start Test N", or after a reset) and ends where the
/// next reset happens (or the chart's last line). Times are seconds since
/// midnight, as printed (i.e. for the race start, row 0). End time is optional:
/// many charts don't print the time at the reset mileage.
nonisolated struct ChartTest: Codable, Equatable, Identifiable {
    /// Stable identity for list editing; not saved.
    var id = UUID()
    var startTime: Int?
    var endTime: Int?
    var startMile: Double?
    var endMile: Double?

    private enum CodingKeys: String, CodingKey {
        case startTime, endTime, startMile, endMile
    }

    static func == (a: ChartTest, b: ChartTest) -> Bool {
        a.startTime == b.startTime && a.endTime == b.endTime && a.startMile == b.startMile && a.endMile == b.endMile
    }

    var lengthMiles: Double? {
        guard let startMile, let endMile, endMile > startMile else { return nil }
        return endMile - startMile
    }
}

/// Key time and roll chart. The rider's due times are the chart times shifted
/// by their key time offset (key time - race start).
nonisolated struct RaceSchedule: Codable, Equatable {
    var raceStartMinutes = 10 * 60
    var keyTimeMinutes = 10 * 60
    /// The chart's speed average ("Start Speed"). Used when a test's end time isn't printed.
    var chartSpeedMph: Double?
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

    /// Chart time for the test; time dropped is measured against this. Uses the
    /// printed end time if entered, else the test length at the chart speed.
    func idealTime(for number: Int) -> TimeInterval? {
        guard let test = test(number) else { return nil }
        if let start = test.startTime, let end = test.endTime, end > start {
            return TimeInterval(end - start)
        }
        guard let miles = test.lengthMiles, let speed = chartSpeedMph, speed > 0 else { return nil }
        return (miles / speed * 3600).rounded()
    }

    /// Chart end time: printed, or derived from the ideal time.
    func endSeconds(for number: Int) -> Int? {
        guard let start = test(number)?.startTime, let ideal = idealTime(for: number) else { return nil }
        return start + Int(ideal)
    }

    /// Average speed the chart expects over the test.
    func paceMph(for number: Int) -> Double? {
        guard let miles = test(number)?.lengthMiles, let ideal = idealTime(for: number), ideal > 0 else { return nil }
        return miles / (ideal / 3600)
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
