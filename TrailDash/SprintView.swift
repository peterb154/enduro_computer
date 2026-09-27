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

    // MARK: Idle: pick a test, review runs, arm

    private var idle: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(SprintSession.tests, id: \.self) { test in
                    testButton(test)
                }
            }
            if !sprint.runs.isEmpty {
                RunList(runs: sprint.runs)
            }
            Button { sprint.arm() } label: {
                BigButtonLabel(title: "ARM T\(sprint.selectedTest) R\(sprint.runNumber(for: sprint.selectedTest))", color: .yellow)
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

    private func testButton(_ test: Int) -> some View {
        let selected = test == sprint.selectedTest
        return Button { sprint.selectedTest = test } label: {
            Text("T\(test)")
                .font(.system(size: 32, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 64)
                .foregroundStyle(selected ? .black : .white)
                .background(selected ? Color.white : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: Armed: waiting for launch

    private var armed: some View {
        VStack(spacing: 16) {
            Text("ARMED")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(.yellow)
            Text("Test \(sprint.selectedTest) run \(sprint.runNumber(for: sprint.selectedTest)) · starts when you go")
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
                VStack(spacing: 8) {
                    BigStat(value: Format.runTime(elapsed), label: "TIME")
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

/// Runs, newest first, with each run's gap to the best run of the same test.
struct RunList: View {
    let runs: [SprintRun]

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                ForEach(runs.reversed()) { run in
                    let best = runs.filter { $0.test == run.test }.map(\.duration).min() ?? run.duration
                    let isBest = run.duration == best
                    GridRow {
                        Text(run.id)
                        Text(Format.runTime(run.duration))
                        Text(isBest ? "best" : "+" + String(format: "%.1f", run.duration - best))
                            .foregroundStyle(isBest ? .green : .gray)
                        Text("\(Format.mph(run.averageSpeed)) mph")
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
