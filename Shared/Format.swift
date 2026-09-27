import Foundation

nonisolated enum Format {
    static func miles(_ meters: Double) -> String {
        String(format: "%.1f", meters / 1609.344)
    }

    /// h:mm:ss, or m:ss under an hour.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
