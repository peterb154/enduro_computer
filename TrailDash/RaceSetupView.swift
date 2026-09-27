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
                    NumberField(label: "Chart speed (mph)", value: $sprint.race.chartSpeedMph, placeholder: "mph")
                } header: {
                    Text("Roll chart")
                } footer: {
                    Text("Race start is the time the roll chart is based on; your due times are the chart times plus your offset. Chart speed (\"Start Speed\") works out test end times the chart doesn't print.")
                }

                // Identified by id, not index, so removing a test can't leave a field bound past the end.
                ForEach($sprint.race.tests) { $test in
                    testSection(number: (sprint.race.tests.firstIndex { $0.id == test.id } ?? 0) + 1, test: $test)
                }

                Section {
                    Button("Add test") { sprint.race.addTest() }
                    if !sprint.race.tests.isEmpty {
                        Button("Remove last test", role: .destructive) { sprint.race.tests.removeLast() }
                    }
                } footer: {
                    Text("Start: the whole-minute line where the test starts. End mile: the \"At\" mileage of the next reset. End time only if the chart prints it. Type times as digits: 94600 is 9:46:00.")
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
            NumberField(label: "Start mile", value: test.startMile, placeholder: "mile")
            ChartTimeField(label: "Start time", seconds: test.startTime, raceStartMinutes: sprint.race.raceStartMinutes)
            NumberField(label: "End mile", value: test.endMile, placeholder: "mile")
            ChartTimeField(label: "End time", seconds: test.endTime, raceStartMinutes: sprint.race.raceStartMinutes,
                           placeholder: "optional")
        } header: {
            Text("Test \(number)")
        } footer: {
            Text(summary(number: number, test: test.wrappedValue))
                .monospacedDigit()
        }
    }

    /// e.g. "Your start 10:06:00 · 9.50 mi · ideal 28:30 · ends 10:14:30 · 20.0 mph"
    private func summary(number: Int, test: ChartTest) -> String {
        let race = sprint.race
        var parts: [String] = []
        if let due = race.dueSeconds(for: number) { parts.append("Your start \(Format.clock(seconds: due))") }
        if let miles = test.lengthMiles { parts.append(String(format: "%.2f mi", miles)) }
        if let ideal = race.idealTime(for: number) { parts.append("ideal \(Format.duration(ideal))") }
        if test.endTime == nil, let end = race.endSeconds(for: number) { parts.append("ends \(Format.clock(seconds: end))") }
        if let pace = race.paceMph(for: number) { parts.append(String(format: "%.1f mph", pace)) }
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
    var placeholder = "94600"
    @State private var text = ""

    var body: some View {
        HStack {
            Text(label)
            TextField(placeholder, text: $text)
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

private struct NumberField: View {
    let label: String
    @Binding var value: Double?
    let placeholder: String

    var body: some View {
        HStack {
            Text(label)
            TextField(placeholder, value: $value, format: .number.precision(.fractionLength(0...2)))
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
