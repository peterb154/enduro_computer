import UIKit

/// A single trail ride: start/stop, plus the stats accumulated in between.
@Observable
final class Ride {
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var stats = TripStats()
    private(set) var log: RideLog?
    let location = LocationTracker()

    var isActive: Bool { startedAt != nil && endedAt == nil }

    init() {
        location.onFix = { [weak self] fix in
            guard let self, self.isActive else { return }
            self.stats.add(fix)
            self.log?.append(.fix(fix))
        }
    }

    func start() {
        let now = Date.now
        stats = TripStats()
        startedAt = now
        endedAt = nil
        log = RideLog(startedAt: now)
        log?.append(.mark("start", at: now))
        location.setBackgroundUpdates(true)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        let now = Date.now
        endedAt = now
        log?.append(.mark("stop", at: now))
        log?.finish()
        location.setBackgroundUpdates(false)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func add(heartRate: Int) {
        guard isActive else { return }
        stats.add(heartRate: heartRate)
        log?.append(.heartRate(heartRate, at: .now))
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (endedAt ?? now).timeIntervalSince(startedAt)
    }
}
