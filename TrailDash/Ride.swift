import UIKit

/// A single trail ride: start/stop, plus the stats accumulated in between.
@Observable
final class Ride {
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var stats = TripStats()
    let location = LocationTracker()

    var isActive: Bool { startedAt != nil && endedAt == nil }

    init() {
        location.onFix = { [weak self] fix in
            guard let self, self.isActive else { return }
            self.stats.add(fix)
        }
    }

    func start() {
        stats = TripStats()
        startedAt = .now
        endedAt = nil
        location.setBackgroundUpdates(true)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        endedAt = .now
        location.setBackgroundUpdates(false)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func add(heartRate: Int) {
        guard isActive else { return }
        stats.add(heartRate: heartRate)
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return (endedAt ?? now).timeIntervalSince(startedAt)
    }
}
