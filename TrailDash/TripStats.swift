import Foundation

/// One GPS fix, decoupled from CoreLocation so the math can be unit-tested.
nonisolated struct Fix {
    var time: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double // meters; negative means invalid
    var speed: Double // m/s; negative means invalid
    var course: Double = -1 // degrees true north; negative means invalid
    var altitude: Double = 0 // meters
}

/// Great-circle distance in meters.
nonisolated func haversine(_ a: Fix, _ b: Fix) -> Double {
    let earthRadius = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = lat2 - lat1
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * earthRadius * asin(min(1, sqrt(h)))
}

/// Accumulates distance, moving time, and HR stats for one ride.
nonisolated struct TripStats {
    let settings: RideSettings
    private(set) var distance: Double = 0 // meters
    private(set) var movingTime: TimeInterval = 0
    private(set) var maxHeartRate: Int?
    private var heartRateSum = 0
    private var heartRateCount = 0
    private var lastFix: Fix?

    init(settings: RideSettings = .standard) {
        self.settings = settings
    }

    var averageHeartRate: Int? {
        heartRateCount == 0 ? nil : heartRateSum / heartRateCount
    }

    mutating func add(_ fix: Fix) {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= settings.maxHorizontalAccuracy else { return }

        guard let last = lastFix else {
            lastFix = fix
            return
        }
        guard fix.time > last.time else { return }
        lastFix = fix

        // Invalid speed (-1) counts as stopped: under tree cover, be conservative.
        guard fix.speed >= settings.minMovingSpeed else { return }
        distance += haversine(last, fix)
        movingTime += fix.time.timeIntervalSince(last.time)
    }

    mutating func add(heartRate: Int) {
        heartRateSum += heartRate
        heartRateCount += 1
        maxHeartRate = max(maxHeartRate ?? heartRate, heartRate)
    }
}
