import Foundation

/// Appends raw events for one ride to Documents/<start>.jsonl as they happen,
/// then writes <start>.gpx next to it when the ride ends.
final class RideLog {
    let logURL: URL
    private let handle: FileHandle?

    init(startedAt: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        logURL = URL.documentsDirectory.appending(path: "\(formatter.string(from: startedAt)).jsonl")
        FileManager.default.createFile(atPath: logURL.path(), contents: nil)
        handle = try? FileHandle(forWritingTo: logURL)
    }

    func append(_ event: LogEvent) {
        handle?.write(encodeLogLine(event))
    }

    func finish() {
        try? handle?.close()
        Self.writeGPX(for: logURL)
    }

    /// Every raw log on the phone, newest first (names are start times).
    static func allLogs() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: .documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Writes <start>.gpx next to a raw log from whatever it holds so far, so a
    /// ride or race still recording can be shared too. Returns the GPX file.
    @discardableResult
    nonisolated static func writeGPX(for logURL: URL) -> URL? {
        guard let data = try? Data(contentsOf: logURL) else { return nil }
        let stamp = logURL.deletingPathExtension().lastPathComponent
        let gpxURL = logURL.deletingPathExtension().appendingPathExtension("gpx")
        let gpx = makeGPX(decodeLog(data), name: "TrailDash \(stamp)")
        guard (try? gpx.write(to: gpxURL, atomically: true, encoding: .utf8)) != nil else { return nil }
        return gpxURL
    }
}
