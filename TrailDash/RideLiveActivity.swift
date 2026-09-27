import ActivityKit
import Foundation

/// Starts, updates, and ends the lock screen Live Activity for a ride.
/// Only pushes an update when the displayed values actually change.
final class RideLiveActivity {
    private var activity: Activity<RideActivityAttributes>?
    private var lastState: RideActivityAttributes.ContentState?

    func start(at startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RideActivityAttributes.ContentState(bpm: nil, miles: Format.miles(0))
        activity = try? Activity.request(
            attributes: RideActivityAttributes(startedAt: startedAt),
            content: .init(state: state, staleDate: nil)
        )
        lastState = state
    }

    func update(bpm: Int?, distance: Double) {
        let state = RideActivityAttributes.ContentState(bpm: bpm, miles: Format.miles(distance))
        guard let activity, state != lastState else { return }
        lastState = state
        let id = activity.id
        Task.detached { await Self.find(id)?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        let id = activity.id
        Task.detached { await Self.find(id)?.end(nil, dismissalPolicy: .immediate) }
    }

    /// Activity isn't Sendable, so background tasks look it up by id instead of capturing it.
    nonisolated private static func find(_ id: String) -> Activity<RideActivityAttributes>? {
        Activity<RideActivityAttributes>.activities.first { $0.id == id }
    }
}
