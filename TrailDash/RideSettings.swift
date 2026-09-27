import Foundation

/// Every tunable threshold lives here. Distances in meters, speeds in m/s.
nonisolated struct RideSettings {
    /// Fixes with worse horizontal accuracy than this are dropped.
    var maxHorizontalAccuracy: Double = 20
    /// Below this GPS speed we treat the bike as stopped; stopped jitter inflates distance.
    var minMovingSpeed: Double = 1.0 // ~2.2 mph

    static let standard = RideSettings()
}
