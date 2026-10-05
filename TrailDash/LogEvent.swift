import Foundation

/// One line of the raw ride log (JSON Lines). Flat optional fields keep the
/// file easy to read and grep. `t` is Unix epoch seconds.
nonisolated struct LogEvent: Codable, Equatable {
    var t: Double
    var type: String // "fix", "hr", or "mark"
    var lat: Double?
    var lon: Double?
    var acc: Double?
    var speed: Double?
    var course: Double?
    var alt: Double?
    var bpm: Int?
    var name: String?
    /// HR source: "primary" or "backup". Missing in logs from before backup sources.
    var src: String?

    var time: Date { Date(timeIntervalSince1970: t) }

    static func fix(_ fix: Fix) -> LogEvent {
        LogEvent(t: fix.time.timeIntervalSince1970, type: "fix",
                 lat: fix.latitude, lon: fix.longitude, acc: fix.horizontalAccuracy,
                 speed: fix.speed, course: fix.course, alt: fix.altitude)
    }

    static func heartRate(_ bpm: Int, at time: Date, source: HeartRateRole = .primary) -> LogEvent {
        LogEvent(t: time.timeIntervalSince1970, type: "hr", bpm: bpm, src: source.rawValue)
    }

    static func mark(_ name: String, at time: Date) -> LogEvent {
        LogEvent(t: time.timeIntervalSince1970, type: "mark", name: name)
    }

    var fix: Fix? {
        guard type == "fix", let lat, let lon, let acc, let speed else { return nil }
        return Fix(time: time, latitude: lat, longitude: lon, horizontalAccuracy: acc,
                   speed: speed, course: course ?? -1, altitude: alt ?? 0)
    }
}

nonisolated func encodeLogLine(_ event: LogEvent) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    var data = (try? encoder.encode(event)) ?? Data()
    data.append(0x0A) // newline
    return data
}

/// Parses a JSON Lines log, skipping any malformed line (e.g. a partial last line after a crash).
nonisolated func decodeLog(_ data: Data) -> [LogEvent] {
    let decoder = JSONDecoder()
    return data.split(separator: 0x0A).compactMap { try? decoder.decode(LogEvent.self, from: Data($0)) }
}
