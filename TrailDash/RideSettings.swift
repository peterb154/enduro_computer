import Foundation

/// Every tunable threshold lives here. Distances in meters, speeds in m/s.
nonisolated struct RideSettings {
    /// Fixes with worse horizontal accuracy than this are dropped.
    var maxHorizontalAccuracy: Double = 20
    /// Below this GPS speed we treat the bike as stopped; stopped jitter inflates distance.
    var minMovingSpeed: Double = 1.0 // ~2.2 mph

    // Sprint enduro auto-start
    /// An armed test starts once GPS speed stays at or above this...
    var sprintStartSpeed: Double = 2.24 // ~5 mph
    /// ...for at least this long.
    var sprintStartSustain: TimeInterval = 1
    /// The start is backdated to when the bike began rolling, but never further than this.
    var sprintMaxBackdate: TimeInterval = 3
    /// Rolling off later than this after the due time is treated as a setup
    /// mismatch (wrong test or race), and the rolling time is used instead.
    var sprintMaxLateStart: TimeInterval = 3600
    /// Pace for scoring tests that have no roll chart times entered.
    var sprintFallbackPaceMph: Double = 24

    static let standard = RideSettings()
}
