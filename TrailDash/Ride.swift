import Foundation

/// A single trail ride: start/stop, plus the stats accumulated in between.
@Observable
final class Ride {
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var stats = TripStats()
    private(set) var log: RideLog?
    private var lastHeartRate: Int?
    private let liveActivity = RideLiveActivity()
    private let location: LocationTracker

    var isActive: Bool { startedAt != nil && endedAt == nil }

    init(location: LocationTracker) {
        self.location = location
    }

    func add(_ fix: Fix) {
        guard isActive else { return }
        stats.add(fix)
        log?.append(.fix(fix))
        liveActivity.update(bpm: lastHeartRate, distance: stats.distance)
    }

    func start() {
        let now = Date.now
        stats = TripStats()
        startedAt = now
        endedAt = nil
        log = RideLog(startedAt: now)
        log?.append(.mark("start", at: now))
        liveActivity.start(at: now)
        location.setBackgroundUpdates(true)
    }

    func stop() {
        let now = Date.now
        endedAt = now
        log?.append(.mark("stop", at: now))
        log?.finish()
        liveActivity.end()
        location.setBackgroundUpdates(false)
    }

    func mark(_ name: String) {
        guard isActive else { return }
        log?.append(.mark(name, at: .now))
    }

    func add(heartRate: Int, source: HeartRateRole = .primary) {
        guard isActive else { return }
        stats.add(heartRate: heartRate)
        log?.append(.heartRate(heartRate, at: .now, source: source))
        lastHeartRate = heartRate > 0 ? heartRate : nil
        liveActivity.update(bpm: heartRate, distance: stats.distance)
    }

    /// Distance over total elapsed time, stops included (m/s).
    func averageSpeed(at now: Date) -> Double {
        let elapsed = elapsed(at: now)
        return elapsed > 0 ? stats.distance / elapsed : 0
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (endedAt ?? now).timeIntervalSince(startedAt)
    }
}
