import SwiftUI

/// Small gray line: HR connection on the left (tap to pick a device), GPS accuracy on the right.
struct StatusLine: View {
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    @State private var showingDevices = false

    var body: some View {
        HStack {
            Button { showingDevices = true } label: {
                HStack(spacing: 4) {
                    Label(heartRate.status, systemImage: "heart")
                        .lineLimit(1)
                    if let battery = heartRate.batteryPercent {
                        // Red while there's still time to swap the battery before a race.
                        Text("· \(battery)%")
                            .foregroundStyle(battery < 20 ? .red : .gray)
                            .fixedSize()
                    }
                }
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
        if let speed = location.simulatedSpeedMph { return "SIM \(Int(speed)) mph" }
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
    var size: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
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

/// Drag the handle all the way across to confirm. A gloved thumb can; water or
/// mud on the screen, which can fake a tap or a hold, can't drag it that far.
/// `action` gets when the slide began, so the slide itself doesn't add time.
struct SlideToConfirm: View {
    let title: String
    let color: Color
    var height: CGFloat = 96
    let action: (Date) -> Void
    @State private var offset: CGFloat = 0
    @State private var began: Date?

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - height)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20).fill(color.opacity(0.3))
                Text(title)
                    .font(.system(size: 30, weight: .heavy))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, height)
                RoundedRectangle(cornerRadius: 20).fill(color)
                    .frame(width: height, height: height)
                    .overlay {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(.black)
                    }
                    .offset(x: offset)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if began == nil { began = .now }
                            offset = min(max(0, drag.translation.width), travel)
                        }
                        .onEnded { _ in
                            if travel > 0, offset >= travel * 0.95 { action(began ?? .now) }
                            began = nil
                            withAnimation(.spring(duration: 0.3)) { offset = 0 }
                        })
            }
        }
        .frame(height: height)
    }
}
