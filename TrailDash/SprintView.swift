import SwiftUI

struct SprintView: View {
    let sprint: SprintSession
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    /// When the rider's thumb first hit STOP; the run ends here, not when the hold completes.
    @State private var stopPressedAt: Date?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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
    }

    // MARK: Idle: next test, results so far, arm

    private var idle: some View {
        Group {
            if isLandscape {
                // Two columns so nothing runs off the bottom: status left, actions right.
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 10) { idleStatus; Spacer(minLength: 0) }
                    VStack(spacing: 10) { idleActions(listHeight: .infinity) }
                }
            } else {
                // Portrait: big HR takes the free space; actions sit at the bottom.
                VStack(spacing: 10) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    idleStatus
                    idleActions(listHeight: 160)
                }
            }
        }
    }

    /// Clock (with HR beside it in landscape), countdown to the next test, transfer,
    /// and which test is next.
    private var idleStatus: some View {
        VStack(spacing: 10) {
            // One compact line: labels sit beside the numbers instead of under them.
            HStack(alignment: .firstTextBaseline) {
                if isLandscape && !sprint.runs.isEmpty {
                    Text(heartRate.bpm.map(String.init) ?? "--")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("HR").font(.system(size: 16, weight: .bold)).foregroundStyle(.gray)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.clock(context.date))
                        .font(.system(size: isLandscape ? 40 : 56, weight: .heavy, design: .rounded))
                }
                // Centered unless HR sits beside it.
                if !(isLandscape && !sprint.runs.isEmpty) { Spacer() }
            }
            .monospacedDigit()
            .foregroundStyle(.white)
            if let due = sprint.nextTestDue() {
                DueCountdown(test: sprint.nextTest, due: due)
                if let miles = sprint.transferMilesToGo {
                    TransferPanel(miles: miles, due: due, location: location)
                }
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
        }
    }

    /// Results so far, ARM, and session/race buttons.
    @ViewBuilder
    private func idleActions(listHeight: CGFloat) -> some View {
        if !sprint.runs.isEmpty {
            RunList(runs: sprint.runs, total: sprint.totalTime, totalDropped: sprint.totalDropped,
                    maxHeight: listHeight)
        } else if isLandscape {
            // No results yet: big HR fills the right side instead of empty space.
            HeartRateNumber(bpm: heartRate.bpm)
        }
        Button { sprint.arm() } label: {
            // Pressed at the start line, not mid-ride, so it can be shorter than STOP.
            BigButtonLabel(title: "ARM TEST \(sprint.nextTest)", color: .yellow, height: isLandscape ? 64 : 80)
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

    private var nextTestTitle: String {
        // Short so it fits beside the −/+ buttons: "T1 · 1M", "T3 · 4.2M".
        guard let length = sprint.chartLengthMiles else { return "T\(sprint.nextTest)" }
        let miles = length == length.rounded() ? String(format: "%.0f", length) : String(format: "%.1f", length)
        return "T\(sprint.nextTest) · \(miles)M"
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
        let details = VStack(spacing: 12) {
            Text("ARMED")
                .font(.system(size: 72, weight: .heavy))
                .minimumScaleFactor(0.5)
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
        return Group {
            if isLandscape {
                HStack(spacing: 24) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    details
                }
            } else {
                VStack(spacing: 16) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    details
                }
            }
        }
    }

    // MARK: Running: HR, miles to go, time, speed trend. Hold anywhere to stop.

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private func running(since start: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let distance = sprint.timer.stats.distance
            // Speed uses riding time (from rolling), not the official clock, which may
            // start at the due minute and would skew the average early in the test.
            let average = sprint.timer.ridingAverageSpeed(at: context.date)
            let trend = sprint.timer.trend
            let size: CGFloat = isLandscape ? 76 : 64
            let toGo = sprint.chartLengthMiles.map { length in
                BigStat(value: String(format: "%.1f", milesToGo(lengthMiles: length, distanceMeters: distance)),
                        label: "TO GO", size: size)
            } ?? BigStat(value: Format.miles(distance), label: "MI", size: size)
            let time = BigStat(value: Format.runTime(elapsed), label: "TIME", size: size)
            let speed = BigStat(value: "\(Format.mph(average)) \(arrow(trend))", label: "AVG MPH",
                                color: color(trend), size: size)
            let hint = Text("HOLD ANYWHERE TO STOP")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.red)

            if isLandscape {
                HStack(spacing: 24) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    VStack(spacing: 8) { toGo; time; speed; hint }
                }
            } else {
                VStack(spacing: 16) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    HStack { toGo; time }
                    speed
                    hint
                }
            }
        }
        // The whole screen is the stop button: no aiming with gloves. Fill all the
        // space first, or only the drawn numbers would respond, not the black around them.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            sprint.stop(at: stopPressedAt ?? .now)
            stopPressedAt = nil
        } onPressingChanged: { pressing in
            stopPressedAt = pressing ? .now : stopPressedAt
        }
    }

    private func arrow(_ trend: SpeedTrend) -> String {
        switch trend {
        case .up: "▲"
        case .flat: ""
        case .down: "▼"
        }
    }

    private func color(_ trend: SpeedTrend) -> Color {
        switch trend {
        case .up: .green
        case .flat: .white
        case .down: .red
        }
    }
}

/// Test times, newest first, with the running total the event is scored on.
struct RunList: View {
    let runs: [SprintRun]
    let total: TimeInterval
    let totalDropped: TimeInterval
    var maxHeight: CGFloat = 200

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
        .frame(maxHeight: maxHeight)
    }
}

/// Between tests: miles to the next start, the speed needed to make it on time,
/// and live speed (green when at or above what's needed). Low need: ease off and
/// let HR come down. High: haul.
struct TransferPanel: View {
    let miles: Double
    let due: Date
    let location: LocationTracker

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let needed = requiredMph(miles: miles, secondsLeft: due.timeIntervalSince(context.date))
            let live = max(0, location.lastFix?.speed ?? 0) * 2.236936
            HStack {
                BigStat(value: String(format: "%.1f", miles), label: "MI TO START")
                BigStat(value: needed.map { String(format: "%.0f", $0) } ?? "LATE",
                        label: "NEED MPH", color: needed == nil ? .red : .white)
                BigStat(value: String(format: "%.0f", live), label: "MPH",
                        color: needed.map { live >= $0 ? .green : .red } ?? .red)
            }
        }
    }
}
