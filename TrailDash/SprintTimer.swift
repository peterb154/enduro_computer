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
    /// When the bike actually started moving; differs from `start` when the run
    /// is timed from the rider's due minute.
    var rolled: Date? = nil

    var label: String { "Test \(test)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// Over actual riding time (from rolling), stops included.
    var averageSpeed: Double {
        let riding = end.timeIntervalSince(rolled ?? start)
        return riding > 0 ? distance / riding : 0
    }
    /// Positive means slower than the chart (the score). Uses the chart's ideal
    /// time when entered; otherwise GPS distance at the fallback pace.
    var timeDropped: TimeInterval {
        if let idealTime { return duration - idealTime }
        return TrailDash.timeDropped(elapsed: duration, distance: distance,
                                     paceMph: RideSettings.standard.sprintFallbackPaceMph)
    }
}

/// When the test clock officially started: the rider's due minute, early or late,
/// since that's what the check counts from. No due time, or rolling implausibly far
/// from it (wrong test/race selected, or a practice roll), means rolling time.
nonisolated func officialStart(rolling: Date, due: Date?, settings: RideSettings = .standard) -> Date {
    guard let due else { return rolling }
    let late = rolling.timeIntervalSince(due)
    guard late <= settings.sprintMaxLateStart, -late <= settings.sprintMaxEarlyStart else { return rolling }
    return due
}

/// When a run ended: the press, unless the bike had already been stopped a while,
/// in which case when it stopped moving.
nonisolated func officialStop(pressed: Date, lastMoving: Date?, settings: RideSettings = .standard) -> Date {
    guard let lastMoving, lastMoving < pressed,
          pressed.timeIntervalSince(lastMoving) > settings.sprintStoppedGrace else { return pressed }
    return lastMoving
}

nonisolated enum SpeedTrend: Equatable {
    case up, flat, down
}

/// Is the last minute faster or slower than the test average? Answers
/// "I just turned up the heat; is it helping?" Hysteresis: a trend needs `band`
/// to switch on but only drops once back within `exitBand`, so it doesn't flicker.
nonisolated func speedTrend(recent: Double?, average: Double, previous: SpeedTrend = .flat,
                            settings: RideSettings = .standard) -> SpeedTrend {
    guard let recent else { return .flat }
    let difference = recent - average
    let upThreshold = previous == .up ? settings.sprintTrendExitBand : settings.sprintTrendBand
    let downThreshold = previous == .down ? settings.sprintTrendExitBand : settings.sprintTrendBand
    if difference > upThreshold { return .up }
    if difference < -downThreshold { return .down }
    return .flat
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
    /// Speed trend for the running screen, updated once per fix.
    private(set) var trend = SpeedTrend.flat
    /// When the bike started rolling. The run's official start may differ (due minute).
    private(set) var rolledAt: Date?
    /// Time of the last fix at moving speed while running.
    private(set) var lastMoving: Date?
    /// Recent (fix time, run distance) samples while running, for the speed trend.
    private var history: [(time: Date, distance: Double)] = []
    /// Start of the last stopped run while it can still be resumed (until the next
    /// arm), for undoing an accidental stop. Stats keep accumulating meanwhile.
    private(set) var resumableStart: Date?

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
        resumableStart = nil
    }

    mutating func disarm() {
        state = .idle
        launch = []
        resumableStart = nil
    }

    /// Undo the last stop: the run continues from its original start, with every
    /// fix since the stop counted. Returns false if there's nothing to resume.
    mutating func resume() -> Bool {
        guard state == .idle, let start = resumableStart else { return false }
        state = .running(start: start)
        resumableStart = nil
        return true
    }

    mutating func add(_ fix: Fix) {
        switch state {
        case .idle:
            if resumableStart != nil { track(fix) }
        case .running:
            track(fix)
        case .armed:
            watchForLaunch(fix)
        }
    }

    private mutating func track(_ fix: Fix) {
        stats.add(fix)
        if fix.speed >= settings.minMovingSpeed { lastMoving = fix.time }
        history.append((fix.time, stats.distance))
        let keep = settings.sprintTrendWindow * 1.5
        history.removeAll { fix.time.timeIntervalSince($0.time) > keep }
        trend = speedTrend(recent: recentSpeed(), average: ridingAverageSpeed(at: fix.time),
                           previous: trend, settings: settings)
    }

    mutating func add(heartRate: Int) {
        guard isRunning || resumableStart != nil else { return }
        stats.add(heartRate: heartRate)
    }

    /// Average speed over the last `sprintTrendWindow` of fixes (m/s), once there's
    /// at least a third of a window of history.
    func recentSpeed() -> Double? {
        guard let last = history.last,
              let first = history.first(where: { last.time.timeIntervalSince($0.time) <= settings.sprintTrendWindow }),
              last.time.timeIntervalSince(first.time) >= settings.sprintTrendWindow / 3 else { return nil }
        return (last.distance - first.distance) / last.time.timeIntervalSince(first.time)
    }

    /// Moves the start of a running test, e.g. back to the rider's due time when late.
    mutating func setStart(_ start: Date) {
        guard isRunning else { return }
        state = .running(start: start)
    }

    /// Ends the run and returns its start time and stats, or nil if not running.
    /// Average speed over actual riding time so far (m/s): distance since rolling,
    /// divided by time since rolling. Not skewed when timed from the due minute.
    func ridingAverageSpeed(at now: Date) -> Double {
        guard let rolledAt else { return 0 }
        let riding = now.timeIntervalSince(rolledAt)
        return riding > 0 ? stats.distance / riding : 0
    }

    mutating func stop() -> (start: Date, stats: TripStats)? {
        guard case .running(let start) = state else { return nil }
        state = .idle
        resumableStart = start
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
        history = []
        lastMoving = lastFix.time
        rolledAt = start
        trend = .flat
        state = .running(start: start)
    }
}
