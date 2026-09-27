import SwiftUI

/// Saved races: pick the one to use, or open one to edit its roll chart.
struct RaceSetupView: View {
    @Bindable var sprint: SprintSession
    let location: LocationTracker
    @Environment(\.dismiss) private var dismiss
    @State private var path: [UUID] = []
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button { sprint.selectedRaceID = nil } label: {
                        row(name: "No race (just timing)", selected: !sprint.hasSelectedRace)
                    }
                    ForEach(sprint.races) { race in
                        NavigationLink(value: race.id) {
                            row(name: race.name, selected: race.id == sprint.selectedRaceID)
                        }
                    }
                    .onDelete { sprint.deleteRaces(at: $0) }
                } footer: {
                    Text("Tap a race to edit its roll chart. Swipe left to delete.")
                }
                Section {
                    Button("New race") { path.append(sprint.newRace()) }
                }
                practiceSection
                sessionSection
            }
            .navigationTitle("Races")
            .navigationDestination(for: UUID.self) { id in
                if let index = sprint.races.firstIndex(where: { $0.id == id }) {
                    RaceEditor(race: $sprint.races[index], sprint: sprint)
                }
            }
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private var sessionSection: some View {
        Section {
            Button("Reset session", role: .destructive) { confirmingReset = true }
                .confirmationDialog("Clear \(sprint.runs.count) result(s) and go back to Test 1?",
                                    isPresented: $confirmingReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { sprint.reset() }
                }
        } header: {
            Text("Session")
        } footer: {
            Text("Ends the current session (its log is still saved and shareable), clears results, and starts again at Test 1. Saved races are kept.")
        }
    }

    /// Fake GPS so the armed/running screens can be tried at a desk.
    private var practiceSection: some View {
        Section {
            Toggle("Simulate riding", isOn: Binding(
                get: { location.simulatedSpeedMph != nil },
                set: { location.simulate(speedMph: $0 ? 0 : nil) }))
            if let speed = location.simulatedSpeedMph {
                Stepper(value: Binding(get: { speed }, set: { location.simulate(speedMph: $0) }),
                        in: 0...60, step: 5) {
                    Text("Speed: \(Int(speed)) mph").monospacedDigit()
                }
            }
        } header: {
            Text("Desk practice")
        } footer: {
            Text("Ignores real GPS. Starts at 0 mph: arm a test, then raise the speed to watch it auto-start. The status line shows SIM while on. Turns off when the app restarts.")
        }
    }

    private func row(name: String, selected: Bool) -> some View {
        HStack {
            Image(systemName: "checkmark").opacity(selected ? 1 : 0)
            Text(name).foregroundStyle(.primary)
        }
    }
}

/// Race morning setup for one race: name, key time, and each test's roll chart numbers.
struct RaceEditor: View {
    @Binding var race: RaceSchedule
    let sprint: SprintSession

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $race.name)
                if race.id == sprint.selectedRaceID {
                    Label("In use", systemImage: "checkmark")
                } else {
                    Button("Use this race") { sprint.selectedRaceID = race.id }
                }
            }

            Section {
                // en_GB locale forces 24-hour pickers, like the chart.
                DatePicker("Race start", selection: timeBinding($race.raceStartMinutes),
                           displayedComponents: .hourAndMinute)
                    .environment(\.locale, Locale(identifier: "en_GB"))
                DatePicker("My key time", selection: timeBinding($race.keyTimeMinutes),
                           displayedComponents: .hourAndMinute)
                    .environment(\.locale, Locale(identifier: "en_GB"))
                LabeledContent("Offset", value: "\(race.keyOffsetSeconds / 60) min")
                NumberField(label: "Chart speed (mph)", value: $race.chartSpeedMph, placeholder: "mph")
            } header: {
                Text("Roll chart")
            } footer: {
                Text("Race start is the time the roll chart is based on; your due times are the chart times plus your offset. Chart speed (\"Start Speed\") works out test end times the chart doesn't print.")
            }

            // Identified by id, not index, so removing a test can't leave a field bound past the end.
            ForEach($race.tests) { $test in
                testSection(number: (race.tests.firstIndex { $0.id == test.id } ?? 0) + 1, test: $test)
            }

            Section {
                Button("Add test") { race.addTest() }
                if !race.tests.isEmpty {
                    Button("Remove last test", role: .destructive) { race.tests.removeLast() }
                }
            } footer: {
                Text("Start: the whole-minute line where the test starts. End mile: the \"At\" mileage of the next reset. End time only if the chart prints it. Type times as digits (hhmmss): 130400 is 13:04:00.")
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(race.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func testSection(number: Int, test: Binding<ChartTest>) -> some View {
        Section {
            // Same order as a chart line: mile, then time.
            NumberField(label: "Start mile", value: test.startMile, placeholder: "mile")
            ChartTimeField(label: "Start time", seconds: test.startTime, raceStartMinutes: race.raceStartMinutes)
            NumberField(label: "End mile", value: test.endMile, placeholder: "mile")
            ChartTimeField(label: "End time", seconds: test.endTime, raceStartMinutes: race.raceStartMinutes,
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
    var placeholder = "hhmmss"
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

/// Decimal entry that saves on every keystroke. A formatted TextField only saves
/// on Return or focus loss, and the decimal pad has no Return key, so edits were lost.
private struct NumberField: View {
    let label: String
    @Binding var value: Double?
    let placeholder: String
    @State private var text = ""

    var body: some View {
        HStack {
            Text(label)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .onAppear {
            text = value.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
        }
        .onChange(of: text) { _, newText in
            value = parseDecimal(newText)
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
                Text("T\(test) DUE \(Format.clock(due))")
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
