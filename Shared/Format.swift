import Foundation

nonisolated enum Format {
    static func miles(_ meters: Double) -> String {
        String(format: "%.1f", meters / 1609.344)
    }

    static func mph(_ metersPerSecond: Double) -> String {
        String(format: "%.1f", metersPerSecond * 2.236936)
    }

    /// m:ss.t for race timing (tenths, truncated like a stopwatch).
    static func runTime(_ seconds: TimeInterval) -> String {
        let tenths = Int((max(0, seconds) * 10).rounded(.down))
        return String(format: "%d:%02d.%d", tenths / 600, (tenths % 600) / 10, tenths % 10)
    }

    /// "+1:05" behind pace, "-0:12" ahead. Whole seconds, truncated toward zero.
    static func signedMinutes(_ seconds: TimeInterval) -> String {
        let total = Int(abs(seconds))
        return String(format: "%@%d:%02d", seconds < 0 ? "-" : "+", total / 60, total % 60)
    }

    /// Seconds since midnight as a 24-hour clock, like the roll chart: 47040 -> "13:04:00".
    static func clock(seconds: Int) -> String {
        let wrapped = ((seconds % 86400) + 86400) % 86400
        return String(format: "%d:%02d:%02d", wrapped / 3600, wrapped / 60 % 60, wrapped % 60)
    }

    /// Time of day as a 24-hour clock, regardless of the phone's 12/24-hour setting.
    static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return clock(seconds: (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0))
    }

    /// h:mm:ss, or m:ss under an hour.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
