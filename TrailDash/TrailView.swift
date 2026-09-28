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
        return VStack(spacing: 16) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("Distance"); Text("\(Format.miles(stats.distance)) mi") }
                GridRow { Text("Moving"); Text(Format.duration(stats.movingTime)) }
                GridRow { Text("Total"); Text(Format.duration(ride.elapsed(at: .now))) }
                GridRow { Text("Avg speed"); Text("\(Format.mph(ride.averageSpeed(at: .now))) mph") }
                GridRow { Text("Moving avg"); Text("\(Format.mph(stats.movingAverageSpeed)) mph") }
                GridRow { Text("Avg / Max HR"); Text("\(stats.averageHeartRate.map(String.init) ?? "--") / \(stats.maxHeartRate.map(String.init) ?? "--")") }
            }
            .font(.system(size: 24, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)

        }
    }

    @ViewBuilder
    private var startStopButton: some View {
        if ride.isActive {
            // Hold to stop, so a gloved bump mid-ride can't end the session.
            BigButtonLabel(title: "HOLD TO STOP", color: .red)
                .onLongPressGesture(minimumDuration: 1) { ride.stop() }
        } else {
            Button { ride.start() } label: { BigButtonLabel(title: "START", color: .green) }
                .buttonStyle(.plain)
        }
    }
}
