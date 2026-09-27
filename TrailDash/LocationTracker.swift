import CoreLocation

/// Streams best-accuracy GPS fixes. Runs in the foreground from launch so the
/// fix is warm before a ride; background updates are enabled only during a ride.
@Observable
final class LocationTracker: NSObject {
    private(set) var lastFix: Fix?
    var onFix: ((Fix) -> Void)?
    /// Desk practice: when set, real GPS is ignored and fake fixes head north at
    /// this speed, once a second, through the same path as real fixes.
    private(set) var simulatedSpeedMph: Double?

    private let manager = CLLocationManager()
    private var simulation: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func setBackgroundUpdates(_ enabled: Bool) {
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }

    /// Start (or change) simulated riding; nil returns to real GPS.
    func simulate(speedMph: Double?) {
        simulation?.cancel()
        simulatedSpeedMph = speedMph
        guard let speedMph else { return }
        simulation = Task { [weak self] in
            while !Task.isCancelled {
                self?.emitSimulatedFix(speedMph: speedMph)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func emitSimulatedFix(speedMph: Double) {
        let metersPerSecond = speedMph / 2.236936
        let from = lastFix ?? Fix(time: .now, latitude: 44.0, longitude: -115.0, horizontalAccuracy: 5, speed: 0)
        let fix = Fix(time: .now,
                      latitude: from.latitude + metersPerSecond / 111_195, // one second of travel north
                      longitude: from.longitude,
                      horizontalAccuracy: 5,
                      speed: metersPerSecond,
                      course: 0,
                      altitude: from.altitude)
        lastFix = fix
        onFix?(fix)
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard simulatedSpeedMph == nil else { return }
        for location in locations {
            let fix = Fix(
                time: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                speed: location.speed,
                course: location.course,
                altitude: location.altitude
            )
            lastFix = fix
            onFix?(fix)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        manager.startUpdatingLocation()
    }
}
