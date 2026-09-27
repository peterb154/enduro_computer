import SwiftUI

/// Race morning setup: key time and each test's roll chart numbers.
struct RaceSetupView: View {
    @Bindable var sprint: SprintSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Race start", selection: timeBinding($sprint.race.raceStartMinutes),
                               displayedComponents: .hourAndMinute)
                    DatePicker("My key time", selection: timeBinding($sprint.race.keyTimeMinutes),
                               displayedComponents: .hourAndMinute)
                    LabeledContent("Offset", value: "\(sprint.race.keyOffsetSeconds / 60) min")
                } header: {
                    Text("Key time")
                } footer: {
                    Text("Race start is the time the roll chart is based on. Your due times are the chart times plus your offset.")
                }

                ForEach(sprint.race.tests.indices, id: \.self) { index in
                    testSection(number: index + 1, test: $sprint.race.tests[index])
                }

                Section {
                    Button("Add test") { sprint.race.addTest() }
                    if !sprint.race.tests.isEmpty {
                        Button("Remove last test", role: .destructive) { sprint.race.tests.removeLast() }
                    }
                } footer: {
                    Text("Each test runs from a \"Reset to\" line to the \"At\" line before the next reset. Type times as digits: 94600 is 9:46:00.")
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Race setup")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private func testSection(number: Int, test: Binding<ChartTest>) -> some View {
        Section {
            // Same order as a chart line: mile, then time.
            MileField(label: "Start mile", miles: test.startMile)
            ChartTimeField(label: "Start time", seconds: test.startTime, raceStartMinutes: sprint.race.raceStartMinutes)
            MileField(label: "End mile", miles: test.endMile)
            ChartTimeField(label: "End time", seconds: test.endTime, raceStartMinutes: sprint.race.raceStartMinutes)
        } header: {
            Text("Test \(number)")
        } footer: {
            Text(summary(number: number, test: test.wrappedValue))
                .monospacedDigit()
        }
    }

    /// e.g. "Your start 10:06:00 · 9.50 mi · ideal 28:30 · 20.0 mph"
    private func summary(number: Int, test: ChartTest) -> String {
        var parts: [String] = []
        if let due = sprint.race.dueSeconds(for: number) { parts.append("Your start \(Format.clock(seconds: due))") }
        if let miles = test.lengthMiles { parts.append(String(format: "%.2f mi", miles)) }
        if let ideal = test.idealTime { parts.append("ideal \(Format.duration(ideal))") }
        if let pace = test.paceMph { parts.append(String(format: "%.1f mph", pace)) }
        return parts.joined(separator: " · ")
    }

    /// Edits minutes-since-midnight with a time-only picker.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes.wrappedValue * 60))
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

/// A roll chart time typed as digits on the number pad, with the parsed time shown beside it.
private struct ChartTimeField: View {
    let label: String
    @Binding var seconds: Int?
    let raceStartMinutes: Int
    @State private var text = ""

    var body: some View {
        HStack {
            Text(label)
            TextField("94600", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
            Text(seconds.map(Format.clock) ?? (text.isEmpty ? "" : "?"))
                .monospacedDigit()
                .foregroundStyle(seconds == nil ? .red : .secondary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .onAppear {
            text = seconds.map { Format.clock(seconds: $0).filter(\.isNumber) } ?? ""
        }
        .onChange(of: text) { _, newText in
            seconds = parseChartTime(newText, raceStartMinutes: raceStartMinutes)
        }
    }
}

private struct MileField: View {
    let label: String
    @Binding var miles: Double?

    var body: some View {
        HStack {
            Text(label)
            TextField("mile", value: $miles, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

/// "T2 DUE 10:06:00   -4:12": counts down to the rider's minute, then up in red.
/// Buzzes on entering the last minute, the last 10 s, and going late.
struct DueCountdown: View {
    let test: Int
    let due: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = due.timeIntervalSince(context.date)
            let phase = countdownPhase(remaining: remaining)
            HStack(alignment: .firstTextBaseline) {
                Text("T\(test) DUE \(due.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute().second()))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.gray)
                Spacer()
                Text(Format.signedMinutes(-remaining))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color(for: phase))
            }
            .sensoryFeedback(.warning, trigger: phase) { _, new in new != .waiting }
        }
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
