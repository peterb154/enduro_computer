import Foundation

enum Mode: String, CaseIterable {
    case trail = "Trail"
    case sprint = "Sprint"
}

/// Owns the shared sensor streams and fans them out to each mode.
/// Each mode ignores samples while it isn't active.
@Observable
final class AppModel {
    var mode = Mode.trail
    let heartRate = HeartRateMonitor()
    let location = LocationTracker()
    let ride: Ride
    let sprint: SprintSession

    init() {
        ride = Ride(location: location)
        sprint = SprintSession(location: location)
        location.onFix = { [ride, sprint] fix in
            ride.add(fix)
            sprint.add(fix)
        }
        heartRate.onSample = { [ride, sprint] bpm in
            ride.add(heartRate: bpm)
            sprint.add(heartRate: bpm)
        }
    }

    /// Mode can't be switched mid-ride or mid-session.
    var isBusy: Bool { ride.isActive || sprint.isSessionOpen }
}
