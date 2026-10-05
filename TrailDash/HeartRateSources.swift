import Foundation

nonisolated enum HeartRateRole: String {
    case primary, backup
}

/// Picks which HR source to use: the primary (chest strap) while it's sending
/// real readings, else the backup (a watch broadcasting HR). 0 bpm means no skin
/// contact, so it doesn't count as a reading. Pure so it can be tested without Bluetooth.
nonisolated struct HeartRateSources {
    var staleAfter: TimeInterval = RideSettings.standard.hrStaleAfter
    private var lastReading: [HeartRateRole: (bpm: Int, time: Date)] = [:]

    /// Records a sample and returns whether it should be used (shown and logged).
    /// With no fresh source at all, primary samples (zeros) still go through for the log.
    mutating func add(_ bpm: Int, from role: HeartRateRole, at time: Date) -> Bool {
        if bpm > 0 { lastReading[role] = (bpm, time) }
        let active = active(at: time)
        return active == role || (active == nil && role == .primary)
    }

    /// The source to show: primary if fresh, else backup if fresh, else none.
    func active(at now: Date) -> HeartRateRole? {
        [HeartRateRole.primary, .backup].first { role in
            guard let reading = lastReading[role] else { return false }
            return now.timeIntervalSince(reading.time) <= staleAfter
        }
    }

    func bpm(at now: Date) -> Int? {
        active(at: now).flatMap { lastReading[$0]?.bpm }
    }

    /// Drop a source's readings, e.g. when it disconnects or is reassigned.
    mutating func forget(_ role: HeartRateRole) {
        lastReading[role] = nil
    }
}
