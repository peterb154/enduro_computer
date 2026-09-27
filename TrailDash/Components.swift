import SwiftUI

/// Small gray line: HR connection on the left (tap to pick a device), GPS accuracy on the right.
struct StatusLine: View {
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    @State private var showingDevices = false

    var body: some View {
        HStack {
            Button { showingDevices = true } label: {
                Label(heartRate.status, systemImage: "heart")
                    .lineLimit(1)
                    .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(gpsStatus)
        }
        .font(.system(size: 16))
        .foregroundStyle(.gray)
        .sheet(isPresented: $showingDevices) { HeartRateDevicesView(heartRate: heartRate) }
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
    var color: Color = .white

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(color)
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
    var height: CGFloat = 100

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .heavy))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
    }
}
