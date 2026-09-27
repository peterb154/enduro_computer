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
    let paceMph: Int

    var label: String { "Test \(test)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// Includes any stops, which is what matters for racing.
    var averageSpeed: Double { duration > 0 ? distance / duration : 0 }
    var timeDropped: TimeInterval { TrailDash.timeDropped(elapsed: duration, distance: distance, paceMph: paceMph) }
}

/// Time lost against the pace: elapsed time minus the time the distance
/// takes at pace speed. Positive means behind pace (the score); negative, ahead.
nonisolated func timeDropped(elapsed: TimeInterval, distance: Double, paceMph: Int) -> TimeInterval {
    guard paceMph > 0 else { return 0 }
    let paceSpeed = Double(paceMph) / 2.236936 // m/s
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
