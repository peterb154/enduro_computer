import SwiftUI

/// Small gray line: HR connection on the left, GPS accuracy on the right.
struct StatusLine: View {
    let heartRate: HeartRateMonitor
    let location: LocationTracker

    var body: some View {
        HStack {
            Text(heartRate.status)
            Spacer()
            Text(gpsStatus)
        }
        .font(.system(size: 16))
        .foregroundStyle(.gray)
    }

    private var gpsStatus: String {
        guard let fix = location.lastFix, fix.horizontalAccuracy >= 0 else { return "GPS: no fix" }
        return "GPS ±\(Int(fix.horizontalAccuracy)) m"
    }
}

/// The biggest thing on screen. Fills whatever vertical space is left.
struct HeartRateNumber: View {
    let bpm: Int?

    var body: some View {
        Text(bpm.map(String.init) ?? "--")
            .font(.system(size: 200, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
    }
}

struct BigStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BigButtonLabel: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .heavy))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
    }
}
