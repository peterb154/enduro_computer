import Foundation

/// Pace (whole mph) per test. A pace set at a test applies to it and every
/// later test until the next change, so the rider can set the whole event's
/// paces up front by rolling forward through the tests.
nonisolated struct PaceSchedule: Equatable {
    let defaultMph: Int
    /// Test number -> pace from that test on.
    private(set) var changes: [Int: Int] = [:]

    init(defaultMph: Int = RideSettings.standard.sprintPaceMph) {
        self.defaultMph = defaultMph
    }

    func pace(for test: Int) -> Int {
        changes.filter { $0.key <= test }.max { $0.key < $1.key }?.value ?? defaultMph
    }

    mutating func setPace(_ mph: Int, from test: Int) {
        let inherited = test > 1 ? pace(for: test - 1) : defaultMph
        // Don't store a "change" that matches what the test would inherit anyway.
        changes[test] = mph == inherited ? nil : mph
        // Drop later changes that now repeat the pace before them.
        for later in changes.keys.sorted() where later > test && changes[later] == pace(for: later - 1) {
            changes[later] = nil
        }
    }

    /// True when some test's pace differs from Test 1's.
    var varies: Bool { changes.keys.contains { $0 > 1 } }

    /// Every test gets Test 1's pace.
    mutating func resetToFirstTestPace() {
        changes = changes.filter { $0.key == 1 }
    }

    /// e.g. "T1–4 24 · T5 22 · T6+ 24"
    var summary: String {
        let starts = [1] + changes.keys.filter { $0 > 1 }.sorted()
        return starts.enumerated().map { index, start in
            let mph = pace(for: start)
            guard index + 1 < starts.count else { return "T\(start)+ \(mph)" }
            let end = starts[index + 1] - 1
            return end == start ? "T\(start) \(mph)" : "T\(start)–\(end) \(mph)"
        }
        .joined(separator: " · ")
    }
}
