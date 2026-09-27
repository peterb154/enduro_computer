import SwiftUI

struct SprintView: View {
    let sprint: SprintSession
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    /// When the rider's thumb first hit STOP; the run ends here, not when the hold completes.
    @State private var stopPressedAt: Date?

    var body: some View {
        VStack(spacing: 16) {
            StatusLine(heartRate: heartRate, location: location)
            HeartRateNumber(bpm: heartRate.bpm)
            switch sprint.timer.state {
            case .idle:
                idle
            case .armed:
                armed
            case .running(let start):
                running(since: start)
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: sprint.timer.state)
    }

    // MARK: Idle: next test, results so far, arm

    private var idle: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                stepButton("minus") { sprint.changeNextTest(by: -1) }
                Text("NEXT: TEST \(sprint.nextTest)")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                stepButton("plus") { sprint.changeNextTest(by: 1) }
            }
            HStack(spacing: 12) {
                stepButton("minus") { sprint.changePace(by: -1) }
                Text("PACE \(sprint.paceMph) MPH")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                stepButton("plus") { sprint.changePace(by: 1) }
            }
            Text(sprint.paces.summary)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.gray)
            if !sprint.runs.isEmpty {
                RunList(runs: sprint.runs, total: sprint.totalTime, totalDropped: sprint.totalDropped)
            }
            Button { sprint.arm() } label: {
                BigButtonLabel(title: "ARM TEST \(sprint.nextTest)", color: .yellow)
            }
            .buttonStyle(.plain)

            if sprint.isSessionOpen {
                Text("Hold to end session")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    .onLongPressGesture(minimumDuration: 1) { sprint.endSession() }
            } else if let log = sprint.finishedLog {
                ShareButton(log: log)
            }
        }
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .frame(width: 64, height: 56)
                .foregroundStyle(.white)
                .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: Armed: waiting for launch

    private var armed: some View {
        VStack(spacing: 16) {
            Text("ARMED")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(.yellow)
            Text("Test \(sprint.nextTest) · \(sprint.paceMph) mph pace · starts when you go")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.gray)
            BigButtonLabel(title: "HOLD TO DISARM", color: .gray)
                .onLongPressGesture(minimumDuration: 1) { sprint.disarm() }
        }
    }

    // MARK: Running

    private func running(since start: Date) -> some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                let distance = sprint.timer.stats.distance
                let dropped = timeDropped(elapsed: elapsed, distance: distance, paceMph: sprint.paceMph)
                VStack(spacing: 8) {
                    HStack {
                        BigStat(value: Format.runTime(elapsed), label: "TIME")
                        BigStat(value: Format.signedMinutes(dropped), label: "DROPPED",
                                color: dropped > 0 ? .red : .green)
                    }
                    HStack {
                        BigStat(value: Format.mph(elapsed > 0 ? distance / elapsed : 0), label: "AVG MPH")
                        BigStat(value: Format.miles(distance), label: "MI")
                    }
                }
            }
            BigButtonLabel(title: "HOLD TO STOP", color: .red)
                .onLongPressGesture(minimumDuration: 0.5) {
                    sprint.stop(at: stopPressedAt ?? .now)
                    stopPressedAt = nil
                } onPressingChanged: { pressing in
                    stopPressedAt = pressing ? .now : stopPressedAt
                }
        }
    }
}

/// Test times, newest first, with the running total the event is scored on.
struct RunList: View {
    let runs: [SprintRun]
    let total: TimeInterval
    let totalDropped: TimeInterval

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                GridRow {
                    Text("Total")
                    Text(Format.duration(total))
                    Text(Format.signedMinutes(totalDropped))
                    Text("")
                }
                .foregroundStyle(.yellow)
                ForEach(runs.reversed()) { run in
                    GridRow {
                        Text("T\(run.test)")
                        Text(Format.runTime(run.duration))
                        Text(Format.signedMinutes(run.timeDropped))
                            .foregroundStyle(run.timeDropped > 0 ? .red : .green)
                        Text("\(Format.mph(run.averageSpeed))/\(run.paceMph)")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .font(.system(size: 22, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
    }
}
