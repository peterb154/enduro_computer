import SwiftUI

struct SprintView: View {
    let sprint: SprintSession
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    /// When the rider's thumb first hit STOP; the run ends here, not when the hold completes.
    @State private var stopPressedAt: Date?
    @State private var showingSetup = false

    var body: some View {
        VStack(spacing: 16) {
            StatusLine(heartRate: heartRate, location: location)
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
        .sheet(isPresented: $showingSetup) { RaceSetupView(sprint: sprint, location: location) }
    }

    // MARK: Idle: next test, results so far, arm

    private var idle: some View {
        VStack(spacing: 10) {
            // One compact line: labels sit beside the numbers instead of under them.
            HStack(alignment: .firstTextBaseline) {
                Text(heartRate.bpm.map(String.init) ?? "--")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("HR").font(.system(size: 16, weight: .bold)).foregroundStyle(.gray)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.clock(context.date))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                }
            }
            .monospacedDigit()
            .foregroundStyle(.white)
            if let due = sprint.nextTestDue() {
                DueCountdown(test: sprint.nextTest, due: due)
            }
            HStack(spacing: 12) {
                stepButton("minus") { sprint.changeNextTest(by: -1) }
                Text(nextTestTitle)
                    .font(.system(size: 28, weight: .heavy))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                stepButton("plus") { sprint.changeNextTest(by: 1) }
            }
            if !sprint.runs.isEmpty {
                RunList(runs: sprint.runs, total: sprint.totalTime, totalDropped: sprint.totalDropped)
            }
            Button { sprint.arm() } label: {
                // Pressed at the start line, not mid-ride, so it can be shorter than STOP.
                BigButtonLabel(title: "ARM TEST \(sprint.nextTest)", color: .yellow, height: 80)
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button { showingSetup = true } label: {
                    Label(sprint.hasSelectedRace ? sprint.race.name : "Races", systemImage: "clock")
                        .lineLimit(1)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                if sprint.isSessionOpen {
                    Text("Hold to end session")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .onLongPressGesture(minimumDuration: 1) { sprint.endSession() }
                }
            }
            if !sprint.isSessionOpen, let log = sprint.finishedLog {
                ShareButton(log: log)
            }
        }
    }

    private var nextTestTitle: String {
        guard let pace = sprint.chartPaceMph else { return "TEST \(sprint.nextTest)" }
        return "TEST \(sprint.nextTest) · \(Format.mph(pace / 2.236936)) MPH"
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
            HeartRateNumber(bpm: heartRate.bpm)
            Text("ARMED")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(.yellow)
            if let due = sprint.nextTestDue() {
                DueCountdown(test: sprint.nextTest, due: due)
            }
            Text("Test \(sprint.nextTest) · starts when you go")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.gray)
            BigButtonLabel(title: "HOLD TO DISARM", color: .gray)
                .onLongPressGesture(minimumDuration: 1) { sprint.disarm() }
        }
    }

    // MARK: Running

    private func running(since start: Date) -> some View {
        VStack(spacing: 16) {
            HeartRateNumber(bpm: heartRate.bpm)
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                let distance = sprint.timer.stats.distance
                let dropped = timeDropped(elapsed: elapsed, distance: distance, paceMph: sprint.livePaceMph)
                VStack(spacing: 8) {
                    HStack {
                        BigStat(value: Format.runTime(elapsed), label: "TIME")
                        BigStat(value: Format.signedMinutes(dropped), label: "DROPPED",
                                color: dropped > 0 ? .red : .green)
                    }
                    HStack {
                        BigStat(value: Format.mph(elapsed > 0 ? distance / elapsed : 0), label: "AVG MPH")
                        if let length = sprint.chartLengthMiles {
                            BigStat(value: String(format: "%.1f", milesToGo(lengthMiles: length, distanceMeters: distance)),
                                    label: "TO GO")
                        } else {
                            BigStat(value: Format.miles(distance), label: "MI")
                        }
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
