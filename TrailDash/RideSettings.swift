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
    /// Recent speed must beat (or trail) the test average by this much to show a trend...
    var sprintTrendBand: Double = 0.45 // m/s, ~1 mph
    /// ...and a trend stays on until it's back within this much, so it doesn't flicker.
    var sprintTrendExitBand: Double = 0.11 // m/s, ~0.25 mph
    /// Pace for scoring tests that have no roll chart times entered.
    var sprintFallbackPaceMph: Double = 24
    /// A stopped test can be resumed (accidental stop) for this long, until the next arm.
    var sprintResumeWindow: TimeInterval = 600

    // Heart rate sources
    /// A source with no reading for this long is stale; the backup takes over.
    var hrStaleAfter: TimeInterval = 5
    /// A "connected" source silent this long gets disconnected and reconnected.
    var hrReconnectAfter: TimeInterval = 10

    static let standard = RideSettings()
}
