import Foundation

/// Key time and roll chart. The roll chart is printed for the race start
/// (row 0); each rider's due times are shifted by their key time offset.
/// Times are minutes since midnight so a setup entered the night before
/// still applies to race day.
nonisolated struct RaceSchedule: Codable, Equatable {
    var raceStartMinutes = 10 * 60
    var keyTimeMinutes = 10 * 60
    /// Roll chart start time per test; index 0 is Test 1.
    var rollChart: [Int] = []

    var keyOffsetMinutes: Int { keyTimeMinutes - raceStartMinutes }

    /// This rider's due time for a test, or nil if the test isn't on the roll chart.
    func dueMinutes(for test: Int) -> Int? {
        guard rollChart.indices.contains(test - 1) else { return nil }
        return rollChart[test - 1] + keyOffsetMinutes
    }

    func dueDate(for test: Int, on day: Date, calendar: Calendar = .current) -> Date? {
        dueMinutes(for: test).map { calendar.startOfDay(for: day).addingTimeInterval(TimeInterval($0 * 60)) }
    }

    /// New tests default to 30 minutes after the previous one.
    mutating func addTest() {
        rollChart.append((rollChart.last ?? raceStartMinutes - 30) + 30)
    }
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
