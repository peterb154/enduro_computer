import ActivityKit
import Foundation

/// Shared between the app (which starts/updates the Live Activity) and the
/// widget extension (which draws it).
nonisolated struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bpm: Int?
        /// HR zone (1-5) for the color; worked out in the app, where Settings live.
        var zone: Int?
        var miles: String
    }

    /// The lock screen timer counts up from here on its own; no updates needed.
    var startedAt: Date
}
