import Foundation
import Testing
@testable import TrailDash

struct TripStatsTests {
    let start = Date(timeIntervalSince1970: 0)

    /// Fix `meters` north of a fixed origin, `seconds` after start.
    func fix(meters: Double, seconds: Double, speed: Double = 5, accuracy: Double = 5) -> Fix {
        Fix(time: start.addingTimeInterval(seconds),
            latitude: 44.0 + meters / 111_195,
            longitude: -115.0,
            horizontalAccuracy: accuracy,
            speed: speed)
    }

    @Test func haversineMatchesKnownDistance() {
        // One degree of latitude is ~111.2 km.
        let d = haversine(fix(meters: 0, seconds: 0), fix(meters: 111_195, seconds: 0))
        #expect(abs(d - 111_195) < 1)
    }

    @Test func accumulatesDistanceAndMovingTime() {
        var stats = TripStats()
        stats.add(fix(meters: 0, seconds: 0))
        stats.add(fix(meters: 10, seconds: 2))
        stats.add(fix(meters: 20, seconds: 4))
        #expect(abs(stats.distance - 20) < 0.1)
        #expect(stats.movingTime == 4)
    }

    @Test func ignoresJitterWhileStopped() {
        var stats = TripStats()
        stats.add(fix(meters: 0, seconds: 0, speed: 0))
        stats.add(fix(meters: 4, seconds: 1, speed: 0.3))
        stats.add(fix(meters: 1, seconds: 2, speed: -1))
        #expect(stats.distance == 0)
        #expect(stats.movingTime == 0)
    }

    @Test func dropsInaccurateFixes() {
        var stats = TripStats()
        stats.add(fix(meters: 0, seconds: 0))
        stats.add(fix(meters: 200, seconds: 1, accuracy: 50)) // bad fix under trees
        stats.add(fix(meters: 10, seconds: 2))
        #expect(abs(stats.distance - 10) < 0.1)
    }

    @Test func ignoresOutOfOrderFixes() {
        var stats = TripStats()
        stats.add(fix(meters: 0, seconds: 5))
        stats.add(fix(meters: 10, seconds: 3))
        #expect(stats.distance == 0)
    }

    @Test func heartRateAverageAndMax() {
        var stats = TripStats()
        #expect(stats.averageHeartRate == nil)
        for hr in [120, 150, 180] { stats.add(heartRate: hr) }
        #expect(stats.averageHeartRate == 150)
        #expect(stats.maxHeartRate == 180)
    }

    @Test func movingAverageSpeedIgnoresStops() {
        var stats = TripStats()
        stats.add(fix(meters: 0, seconds: 0))
        stats.add(fix(meters: 10, seconds: 2)) // 5 m/s
        stats.add(fix(meters: 10, seconds: 60, speed: 0)) // stopped almost a minute
        stats.add(fix(meters: 20, seconds: 62)) // moving again
        #expect(stats.movingTime == 4)
        #expect(abs(stats.movingAverageSpeed - 5) < 0.01)
    }

    @Test func movingAverageSpeedIsZeroBeforeMoving() {
        #expect(TripStats().movingAverageSpeed == 0)
    }
}
