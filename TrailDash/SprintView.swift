import SwiftUI

struct SprintView: View {
    let sprint: SprintSession
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(spacing: 16) {
            StatusLine(heartRate: heartRate, location: location)
            switch sprint.timer.state {
            case .idle:
                idle
            case .armed:
                armed
            case .running:
                running
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: sprint.timer.state)
    }

    // MARK: Idle: transfer to the next test, or results so far; arm

    private var idle: some View {
        Group {
            if let due = sprint.nextTestDue() {
                transfer(due: due)
            } else if isLandscape {
                // Two columns so nothing runs off the bottom: status left, actions right.
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 10) { clock; testStepper; Spacer(minLength: 0) }
                    VStack(spacing: 10) { results(listHeight: .infinity); raceButtons }
                }
            } else {
                // Portrait: big HR takes the free space; actions sit at the bottom.
                VStack(spacing: 10) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    clock
                    testStepper
                    results(listHeight: 160)
                    raceButtons
                }
            }
        }
    }

    /// Between tests (or before the first): time until due and miles to the start
    /// are all that matter, so they get the screen. Results wait until the end.
    private func transfer(due: Date) -> some View {
        let miles = sprint.transferMilesToGo
        let board = TransferBoard(test: sprint.nextTest, due: due, miles: miles)
        let row = TransferRow(due: due, miles: miles, heartRate: heartRate, location: location)
        return Group {
            if isLandscape {
                HStack(spacing: 20) {
                    board
                    VStack(spacing: 10) { row; Spacer(minLength: 0); testStepper; raceButtons }
                }
            } else {
                VStack(spacing: 10) { board; row; testStepper; raceButtons }
            }
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Format.clock(context.date))
                .font(.system(size: isLandscape ? 40 : 56, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    /// Which test is next, with -/+ to fix the count if one was skipped.
    private var testStepper: some View {
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

    @ViewBuilder
    private func results(listHeight: CGFloat) -> some View {
        if !sprint.runs.isEmpty {
            RunList(runs: sprint.runs, total: sprint.totalTime, totalDropped: sprint.totalDropped,
                    maxHeight: listHeight)
        } else if isLandscape {
            // No results yet: big HR fills the right side instead of empty space.
            HeartRateNumber(bpm: heartRate.bpm)
        }
    }

    /// Resume (after an accidental stop), then ARM, or START RACE before the race is open.
    @ViewBuilder
    private var raceButtons: some View {
        // Undo for a stop that wasn't meant (water or mud on the screen).
        TimelineView(.periodic(from: .now, by: 5)) { context in
            if sprint.canResume(at: context.date), let run = sprint.runs.last {
                SlideToConfirm(title: "SLIDE TO RESUME T\(run.test)", color: .orange,
                               height: isLandscape ? 64 : 80) { _ in sprint.resume() }
            }
        }
        if sprint.isSessionOpen {
            Button { sprint.arm() } label: {
                // Pressed at the start line, not mid-ride, so it can be shorter than STOP.
                BigButtonLabel(title: "ARM TEST \(sprint.nextTest)", color: .yellow, height: isLandscape ? 64 : 80)
            }
            .buttonStyle(.plain)
        } else {
            // Recording runs from here until the race is ended in Settings.
            Button { sprint.startSession() } label: {
                BigButtonLabel(title: "START RACE", color: .green, height: isLandscape ? 64 : 80)
            }
            .buttonStyle(.plain)
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
            SlideToConfirm(title: "SLIDE TO DISARM", color: .gray) { _ in sprint.disarm() }
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

    // MARK: Running: HR and miles to go, big enough to read in a glance. Slide to stop.

    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// Looking down mid-test is dangerous, so only two numbers are big: HR (zone
    /// colored) and miles to go. Avg speed is a small row whose color carries the
    /// trend. Elapsed time is in the results, not here.
    private var running: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let distance = sprint.timer.stats.distance
            // Speed uses riding time (from rolling), not the official clock, which may
            // start at the due minute and would skew the average early in the test.
            let average = sprint.timer.ridingAverageSpeed(at: context.date)
            let trend = sprint.timer.trend
            let toGo = sprint.chartLengthMiles.map { length in
                // Yellow past zero: the chart was short; keep counting how far over.
                let left = milesToGo(lengthMiles: length, distanceMeters: distance)
                return milesStat(String(format: "%.1f", left), label: "MI TO GO", color: left < 0 ? .yellow : .white)
            } ?? milesStat(Format.miles(distance), label: "MI", color: .white)
            let speed = BigStat(value: "\(Format.mph(average)) \(arrow(trend))", label: "AVG MPH",
                                color: color(trend), size: 40)
            // The run ends when the slide began, not when it finished.
            let slider = SlideToConfirm(title: "SLIDE TO STOP", color: .red, height: isLandscape ? 72 : 88) { began in
                sprint.stop(at: began)
            }

            if isLandscape {
                HStack(spacing: 24) {
                    HeartRateNumber(bpm: heartRate.bpm)
                    VStack(spacing: 8) { toGo; speed; slider }
                }
            } else {
                VStack(spacing: 8) {
                    HeartRateNumber(bpm: heartRate.bpm)
                        .layoutPriority(1)
                    toGo
                    speed
                    slider
                }
            }
        }
    }

    /// Second biggest number on the running screen.
    private func milesStat(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: isLandscape ? 150 : 130, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: isLandscape ? .infinity : nil)
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

/// Between tests, the two numbers that matter, as big as they'll go: time until
/// the rider is due at the next test, and miles to its start. Red when late.
/// Buzzes on entering the last minute, the last 10 s, and going late.
struct TransferBoard: View {
    let test: Int
    let due: Date
    /// Nil before the first test, or when the chart miles aren't entered.
    let miles: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = due.timeIntervalSince(context.date)
            let phase = countdownPhase(remaining: remaining)
            let late = phase == .late
            VStack(spacing: 4) {
                huge(late ? Format.signedMinutes(-remaining) : Format.duration(remaining.rounded(.up)),
                     label: "\(late ? "LATE · " : "")T\(test) DUE \(Format.clock(due))",
                     color: color(for: phase))
                if let miles {
                    // Yellow past zero: the chart distance was short.
                    huge(String(format: "%.1f", miles), label: "MI TO T\(test)",
                         color: miles < 0 ? .yellow : .white)
                }
            }
            .padding(.vertical, 8)
            .background(late ? Color.red.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 20))
            .sensoryFeedback(.warning, trigger: phase) { _, new in new != .waiting }
        }
    }

    private func huge(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 160, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .foregroundStyle(color)
                .frame(maxHeight: .infinity)
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for phase: CountdownPhase) -> Color {
        switch phase {
        case .waiting: .white
        case .oneMinute: .yellow
        case .tenSeconds: .orange
        case .late: .red
        }
    }
}

/// Under the transfer board: the speed needed to make it on time, live speed
/// (green when at or above what's needed), and HR. Low need: ease off and let HR
/// come down. High: haul.
struct TransferRow: View {
    let due: Date
    let miles: Double?
    let heartRate: HeartRateMonitor
    let location: LocationTracker

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let needed = miles.flatMap { requiredMph(miles: $0, secondsLeft: due.timeIntervalSince(context.date)) }
            let live = max(0, location.lastFix?.speed ?? 0) * 2.236936
            HStack {
                if miles != nil {
                    BigStat(value: needed.map { String(format: "%.0f", $0) } ?? "--", label: "NEED MPH", size: 44)
                    BigStat(value: String(format: "%.0f", live), label: "MPH",
                            color: needed.map { live >= $0 ? .green : .red } ?? .white, size: 44)
                }
                BigStat(value: heartRate.bpm.map(String.init) ?? "--", label: "HR",
                        color: HeartRateZones.color(bpm: heartRate.bpm), size: 44)
            }
        }
    }
}
