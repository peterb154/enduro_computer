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
    /// Rolling this much before the due time is still timed from the due time
    /// (you're counted from your minute); earlier than this is a practice roll.
    var sprintMaxEarlyStart: TimeInterval = 600
    /// If the bike has been stopped longer than this when STOP is pressed, the run
    /// ends when it stopped moving (time spent getting a glove off doesn't count).
    var sprintStoppedGrace: TimeInterval = 3
    /// Window for "is pushing harder helping": recent speed vs the test average.
    var sprintTrendWindow: TimeInterval = 60
    /// Recent speed must differ from the test average by this much to show a trend.
    var sprintTrendBand: Double = 0.22 // m/s, ~0.5 mph
    /// Pace for scoring tests that have no roll chart times entered.
    var sprintFallbackPaceMph: Double = 24

    static let standard = RideSettings()
}
