import Foundation

enum Mode: String, CaseIterable {
    case trail = "Trail"
    case sprint = "Sprint"
}

/// Owns the shared sensor streams and fans them out to each mode.
/// Each mode ignores samples while it isn't active.
@Observable
final class AppModel {
    /// Remembered across launches so the app reopens where the rider left it.
    var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .trail {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") }
    }
    let heartRate = HeartRateMonitor()
    let location = LocationTracker()
    let overlay: HeartRateOverlay
    let ride: Ride
    let sprint: SprintSession

    init() {
        overlay = HeartRateOverlay(heartRate: heartRate)
        ride = Ride(location: location, overlay: overlay)
        sprint = SprintSession(location: location)
        location.onFix = { [ride, sprint] fix in
            ride.add(fix)
            sprint.add(fix)
        }
        heartRate.onSample = { [ride, sprint] bpm, source in
            ride.add(heartRate: bpm, source: source)
            sprint.add(heartRate: bpm, source: source)
        }
        heartRate.onEvent = { [ride, sprint] name in
            ride.mark(name)
            sprint.mark(name)
        }
    }

    /// Mode can't be switched mid-ride or mid-session.
    var isBusy: Bool { ride.isActive || sprint.isSessionOpen }
}
