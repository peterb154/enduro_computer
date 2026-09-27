import Foundation

/// Appends raw events for one ride to Documents/<start>.jsonl as they happen,
/// then writes <start>.gpx next to it when the ride ends.
final class RideLog {
    let logURL: URL
    let gpxURL: URL
    private let name: String
    private let handle: FileHandle?

    init(startedAt: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = formatter.string(from: startedAt)
        let documents = URL.documentsDirectory
        name = "TrailDash \(stamp)"
        logURL = documents.appending(path: "\(stamp).jsonl")
        gpxURL = documents.appending(path: "\(stamp).gpx")
        FileManager.default.createFile(atPath: logURL.path(), contents: nil)
        handle = try? FileHandle(forWritingTo: logURL)
    }

    func append(_ event: LogEvent) {
        handle?.write(encodeLogLine(event))
    }

    func finish() {
        try? handle?.close()
        guard let data = try? Data(contentsOf: logURL) else { return }
        let gpx = makeGPX(decodeLog(data), name: name)
        try? gpx.write(to: gpxURL, atomically: true, encoding: .utf8)
    }
}
