import SwiftUI

struct TrailView: View {
    let ride: Ride
    let heartRate: HeartRateMonitor
    let location: LocationTracker

    var body: some View {
        VStack(spacing: 16) {
            StatusLine(heartRate: heartRate, location: location)
            HeartRateNumber(bpm: heartRate.bpm)
            if ride.isActive {
                liveStats
            } else if ride.endedAt != nil {
                summary
            }
            startStopButton
        }
        .sensoryFeedback(.success, trigger: ride.isActive)
    }

    private var liveStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 8) {
                HStack {
                    BigStat(value: Format.duration(ride.elapsed(at: context.date)), label: "TIME")
                    BigStat(value: Format.miles(ride.stats.distance), label: "MI")
                }
                HStack {
                    BigStat(value: Format.mph(ride.averageSpeed(at: context.date)), label: "AVG MPH")
                    BigStat(value: Format.mph(ride.stats.movingAverageSpeed), label: "MOVING MPH")
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

            if let log = ride.log {
                ShareButton(log: log)
            }
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

struct ShareButton: View {
    let log: RideLog

    var body: some View {
        ShareLink(items: [log.gpxURL, log.logURL]) {
            Label("Share GPX + log", systemImage: "square.and.arrow.up")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }
}
