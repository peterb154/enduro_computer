import SwiftUI

struct TrailView: View {
    let ride: Ride
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(spacing: 16) {
            StatusLine(heartRate: heartRate, location: location)
            if verticalSizeClass == .compact {
                // Landscape: HR on the left half, everything else on the right, so nothing shrinks.
                HStack(spacing: 24) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    VStack(spacing: 12) { details; startStopButton }
                }
            } else {
                HeartRateNumber(bpm: heartRate.bpm)
                details
                startStopButton
            }
        }
        .sensoryFeedback(.success, trigger: ride.isActive)
    }

    @ViewBuilder
    private var details: some View {
        if ride.isActive {
            liveStats
        } else if ride.endedAt != nil {
            summary
        }
    }

    private var liveStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let size: CGFloat = verticalSizeClass == .compact ? 64 : 56
            VStack(spacing: 8) {
                HStack {
                    BigStat(value: Format.duration(ride.elapsed(at: context.date)), label: "TIME", size: size)
                    BigStat(value: Format.miles(ride.stats.distance), label: "MI", size: size)
                }
                HStack {
                    BigStat(value: Format.mph(ride.averageSpeed(at: context.date)), label: "AVG MPH", size: size)
                    BigStat(value: Format.mph(ride.stats.movingAverageSpeed), label: "MOVING MPH", size: size)
                }
            }
        }
    }

    private var summary: some View {
        let stats = ride.stats
        let rows: [(String, String)] = [
            ("Distance", "\(Format.miles(stats.distance)) mi"),
            ("Moving", Format.duration(stats.movingTime)),
            ("Total", Format.duration(ride.elapsed(at: .now))),
            ("Avg speed", "\(Format.mph(ride.averageSpeed(at: .now))) mph"),
            ("Moving avg", "\(Format.mph(stats.movingAverageSpeed)) mph"),
            ("Avg / Max HR", "\(stats.averageHeartRate.map(String.init) ?? "--") / \(stats.maxHeartRate.map(String.init) ?? "--")"),
        ]
        // Landscape has half the height: two label/value columns of three rows.
        let perRow = isLandscape ? 2 : 1
        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: rows.count, by: perRow)), id: \.self) { start in
                GridRow {
                    ForEach(rows[start..<min(start + perRow, rows.count)], id: \.0) { label, value in
                        Text(label).foregroundStyle(.gray)
                        Text(value)
                    }
                }
            }
        }
        .font(.system(size: isLandscape ? 20 : 24, weight: .semibold))
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        .monospacedDigit()
        .foregroundStyle(.white)
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    @ViewBuilder
    private var startStopButton: some View {
        if ride.isActive {
            // A slide, so a gloved bump or water on the screen can't end the ride.
            SlideToConfirm(title: "SLIDE TO STOP", color: .red, height: isLandscape ? 72 : 96) { _ in ride.stop() }
        } else {
            Button { ride.start() } label: { BigButtonLabel(title: "START", color: .green, height: isLandscape ? 72 : 100) }
                .buttonStyle(.plain)
        }
    }
}
