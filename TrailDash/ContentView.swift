import SwiftUI

struct ContentView: View {
    @State private var heartRate = HeartRateMonitor()
    @State private var ride = Ride()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                statusLine
                Text(heartRate.bpm.map(String.init) ?? "--")
                    .font(.system(size: 200, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .frame(maxHeight: .infinity)
                if ride.isActive {
                    liveStats
                } else if ride.endedAt != nil {
                    summary
                }
                startStopButton
            }
            .padding()
        }
        .onChange(of: heartRate.bpm) { _, bpm in
            if let bpm { ride.add(heartRate: bpm) }
        }
        .sensoryFeedback(.success, trigger: ride.isActive)
        // Screen never sleeps while the app is open, riding or not.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    }

    private var statusLine: some View {
        HStack {
            Text(heartRate.status)
            Spacer()
            Text(gpsStatus)
        }
        .font(.system(size: 16))
        .foregroundStyle(.gray)
    }

    private var gpsStatus: String {
        guard let fix = ride.location.lastFix, fix.horizontalAccuracy >= 0 else { return "GPS: no fix" }
        return "GPS ±\(Int(fix.horizontalAccuracy)) m"
    }

    private var liveStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                bigStat(Format.duration(ride.elapsed(at: context.date)), label: "TIME")
                bigStat(Format.miles(ride.stats.distance), label: "MI")
            }
        }
    }

    private var summary: some View {
        let stats = ride.stats
        return VStack(spacing: 16) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow { Text("Distance"); Text("\(Format.miles(stats.distance)) mi") }
            GridRow { Text("Moving"); Text(Format.duration(stats.movingTime)) }
            GridRow { Text("Total"); Text(Format.duration(ride.elapsed(at: .now))) }
            GridRow { Text("Avg / Max HR"); Text("\(stats.averageHeartRate.map(String.init) ?? "--") / \(stats.maxHeartRate.map(String.init) ?? "--")") }
            }
            .font(.system(size: 24, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)

            if let log = ride.log {
                ShareLink(items: [log.gpxURL, log.logURL]) {
                    Label("Share GPX + log", systemImage: "square.and.arrow.up")
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func bigStat(_ value: String, label: String) -> some View {
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

    @ViewBuilder
    private var startStopButton: some View {
        if ride.isActive {
            // Hold to stop, so a gloved bump mid-ride can't end the session.
            bigButtonLabel("HOLD TO STOP", color: .red)
                .onLongPressGesture(minimumDuration: 1) { ride.stop() }
        } else {
            Button { ride.start() } label: { bigButtonLabel("START", color: .green) }
                .buttonStyle(.plain)
        }
    }

    private func bigButtonLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(color, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
