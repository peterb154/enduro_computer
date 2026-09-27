import Foundation

/// One completed timed test. Tests are ridden once each, in order.
nonisolated struct SprintRun: Identifiable, Equatable {
    let id = UUID()
    let test: Int
    let start: Date
    let end: Date
    let distance: Double // meters
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    /// Roll chart time for this test, if entered.
    let idealTime: TimeInterval?

    var label: String { "Test \(test)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// Includes any stops, which is what matters for racing.
    var averageSpeed: Double { duration > 0 ? distance / duration : 0 }
    /// Positive means slower than the chart (the score). Uses the chart's ideal
    /// time when entered; otherwise GPS distance at the fallback pace.
    var timeDropped: TimeInterval {
        if let idealTime { return duration - idealTime }
        return TrailDash.timeDropped(elapsed: duration, distance: distance,
                                     paceMph: RideSettings.standard.sprintFallbackPaceMph)
    }
}

/// When the test clock officially started. A rider who leaves late is timed from
/// their due minute; early or on time, from when they rolled. No due time (or a
/// due time implausibly far back) means rolling time.
nonisolated func officialStart(rolling: Date, due: Date?, settings: RideSettings = .standard) -> Date {
    guard let due, due < rolling, rolling.timeIntervalSince(due) <= settings.sprintMaxLateStart else { return rolling }
    return due
}

/// Time lost against a pace: elapsed time minus the time the distance
/// takes at pace speed. Positive means behind pace; negative, ahead.
nonisolated func timeDropped(elapsed: TimeInterval, distance: Double, paceMph: Double) -> TimeInterval {
    guard paceMph > 0 else { return 0 }
    let paceSpeed = paceMph / 2.236936 // m/s
    return elapsed - distance / paceSpeed
}

/// Arm -> auto-start -> stop state machine for one sprint enduro test.
///
/// While armed, it watches GPS speed. Once speed stays at or above
/// `sprintStartSpeed` for `sprintStartSustain`, the run starts, backdated to the
/// first fix of the current rolling streak (capped at `sprintMaxBackdate`).
/// Fix timestamps are measurement times, so this also removes GPS delivery lag.
nonisolated struct SprintTimer {
    enum State: Equatable {
        case idle
        case armed
        case running(start: Date)
    }

    let settings: RideSettings
    private(set) var state = State.idle
    private(set) var stats: TripStats
    /// Fixes since the bike started rolling, while armed.
    private var launch: [Fix] = []

    init(settings: RideSettings = .standard) {
        self.settings = settings
        stats = TripStats(settings: settings)
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    mutating func arm() {
        state = .armed
        launch = []
    }

    mutating func disarm() {
        state = .idle
        launch = []
    }

    mutating func add(_ fix: Fix) {
        switch state {
        case .idle:
            return
        case .running:
            stats.add(fix)
        case .armed:
            watchForLaunch(fix)
        }
    }

    mutating func add(heartRate: Int) {
        guard isRunning else { return }
        stats.add(heartRate: heartRate)
    }

    /// Moves the start of a running test, e.g. back to the rider's due time when late.
    mutating func setStart(_ start: Date) {
        guard isRunning else { return }
        state = .running(start: start)
    }

    /// Ends the run and returns its start time and stats, or nil if not running.
    mutating func stop() -> (start: Date, stats: TripStats)? {
        guard case .running(let start) = state else { return nil }
        state = .idle
        return (start, stats)
    }

    private mutating func watchForLaunch(_ fix: Fix) {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= settings.maxHorizontalAccuracy else { return }
        guard fix.speed >= settings.minMovingSpeed else {
            launch = []
            return
        }
        launch.append(fix)

        // The trailing streak of fixes at or above start speed.
        let fastStart = (launch.lastIndex { $0.speed < settings.sprintStartSpeed } ?? -1) + 1
        guard fastStart < launch.count,
              let lastFix = launch.last,
              lastFix.time.timeIntervalSince(launch[fastStart].time) >= settings.sprintStartSustain else { return }

        let earliestAllowed = launch[fastStart].time.addingTimeInterval(-settings.sprintMaxBackdate)
        let start = max(launch[0].time, earliestAllowed)

        // Seed run stats with the launch fixes so distance covers the backdated part.
        stats = TripStats(settings: settings)
        for launchFix in launch where launchFix.time >= start {
            stats.add(launchFix)
        }
        launch = []
        state = .running(start: start)
    }
}
