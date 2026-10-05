import SwiftUI

/// Everything that isn't riding: races and roll charts, display, heart rate
/// device, logs, session reset, and desk practice.
struct SettingsView: View {
    @Bindable var sprint: SprintSession
    let ride: Ride
    let heartRate: HeartRateMonitor
    let location: LocationTracker
    @AppStorage("orientationLock") private var orientation = OrientationLock.auto
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    @State private var confirmingReset = false
    @State private var confirmingEnd = false

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
                    Button("New race") { path.append(sprint.newRace()) }
                } header: {
                    Text("Races")
                } footer: {
                    Text("Check the race to use for sprint mode. Tap to edit its roll chart; swipe left to delete.")
                }
                Section("Display") {
                    Picker("Rotation", selection: $orientation) {
                        ForEach(OrientationLock.allCases, id: \.self) { lock in
                            Label(lock.rawValue.capitalized, systemImage: lock.icon).tag(lock)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                HeartRateDeviceSection(heartRate: heartRate)
                logsSection
                sessionSection
                practiceSection
            }
            .navigationTitle("Settings")
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

    private var logsSection: some View {
        Section {
            let logs = RideLog.allLogs()
            ForEach(logs.prefix(20), id: \.self) { url in
                NavigationLink {
                    LogShareView(logURL: url)
                } label: {
                    HStack {
                        Text(logTitle(url))
                        Spacer()
                        if url == recordingURL {
                            Text("Recording").foregroundStyle(.red)
                        }
                    }
                }
            }
            if logs.isEmpty {
                Text("No rides or races yet.").foregroundStyle(.secondary)
            }
        } header: {
            Text("Logs")
        } footer: {
            Text("Newest first, including one still recording. Every log is also in the Files app under On My iPhone > TrailDash.")
        }
    }

    /// The log of the ride or race in progress, if any.
    private var recordingURL: URL? {
        if ride.isActive { return ride.log?.logURL }
        return sprint.log?.logURL
    }

    /// "2026-10-04_102104.jsonl" -> "Oct 4, 10:21"
    private func logTitle(_ url: URL) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd_HHmmss"
        guard let date = parser.date(from: url.deletingPathExtension().lastPathComponent) else {
            return url.lastPathComponent
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var sessionSection: some View {
        Section {
            if sprint.isSessionOpen {
                Button("End race", role: .destructive) { confirmingEnd = true }
                    .confirmationDialog("End the race and stop recording?",
                                        isPresented: $confirmingEnd, titleVisibility: .visible) {
                        Button("End race", role: .destructive) { sprint.endSession() }
                    }
            }
            Button("Reset results", role: .destructive) { confirmingReset = true }
                .confirmationDialog("Clear \(sprint.runs.count) result(s) and go back to Test 1?",
                                    isPresented: $confirmingReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { sprint.reset() }
                }
        } header: {
            Text("Sprint race")
        } footer: {
            Text(sprint.isSessionOpen
                 ? "The race records GPS and HR until you end it here. Reset clears results and goes back to Test 1; recording continues."
                 : "Reset clears results and goes back to Test 1. Saved races are kept.")
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
                Stepper(value: Binding(get: { race.repeatsAfterTest ?? 0 },
                                       set: { race.repeatsAfterTest = $0 > 0 ? $0 : nil }),
                        in: 0...20) {
                    Text(race.repeatsAfterTest.map { "Course repeats after Test \($0)" } ?? "Course doesn't repeat")
                }
            } header: {
                Text("Roll chart")
            } footer: {
                Text("Race start is the time the roll chart is based on; your due times are the chart times plus your offset. Chart speed (\"Start Speed\") works out test end times the chart doesn't print. For a multi-lap race, set where the course repeats: later laps use your GPS distance from the earlier lap for miles to go, in case the chart is wrong.")
            }

            // Identified by id, not index, so removing a test can't leave a field bound past the end.
            ForEach($race.tests) { $test in
                testSection(number: (race.tests.firstIndex { $0.id == test.id } ?? 0) + 1, test: $test)
            }

            Section {
                ForEach($race.resets) { $reset in
                    HStack(spacing: 8) {
                        Text("At")
                        DecimalInput(value: $reset.atMile, placeholder: "mile")
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        DecimalInput(value: $reset.toMile, placeholder: "mile")
                    }
                }
                Button("Add reset") { race.resets.append(ChartReset()) }
                if !race.resets.isEmpty {
                    Button("Remove last reset", role: .destructive) { race.resets.removeLast() }
                }
            } header: {
                Text("Resets")
            } footer: {
                Text("Every \"At X Reset To Y\" line, in order. Used to work out real miles on transfers between tests.")
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
            // One line each, in chart order: mile, then time.
            chartLine("Start", miles: test.startMile, seconds: test.startTime, timePlaceholder: "hhmmss")
            chartLine("End", miles: test.endMile, seconds: test.endTime, timePlaceholder: "optional")
        } header: {
            Text("Test \(number)")
        } footer: {
            Text(summary(number: number, test: test.wrappedValue))
                .monospacedDigit()
        }
    }

    private func chartLine(_ label: String, miles: Binding<Double?>, seconds: Binding<Int?>,
                           timePlaceholder: String) -> some View {
        HStack(spacing: 8) {
            Text(label).fixedSize()
            DecimalInput(value: miles, placeholder: "mile")
                .frame(width: 64)
            Text("mi").foregroundStyle(.secondary)
            ChartTimeInput(seconds: seconds, raceStartMinutes: race.raceStartMinutes, placeholder: timePlaceholder)
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

/// A roll chart time: shows "10:38:00", switches to digits ("103800") on the
/// number pad while editing, and back when done. Red if it doesn't parse.
private struct ChartTimeInput: View {
    @Binding var seconds: Int?
    let raceStartMinutes: Int
    let placeholder: String
    @State private var text = ""
    @FocusState private var editing: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .focused($editing)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .foregroundStyle(seconds == nil && !text.isEmpty ? .red : .primary)
            .onAppear { text = display }
            .onChange(of: editing) { _, isEditing in
                if isEditing {
                    text = text.filter(\.isNumber)
                } else if seconds != nil {
                    text = display
                }
            }
            .onChange(of: text) { _, newText in
                // Digits only are kept, so "10:38:00" and "103800" parse the same.
                seconds = parseChartTime(newText, raceStartMinutes: raceStartMinutes)
            }
    }

    private var display: String { seconds.map(Format.clock) ?? "" }
}

/// Decimal entry that saves on every keystroke. A formatted TextField only saves
/// on Return or focus loss, and the decimal pad has no Return key, so edits were lost.
private struct DecimalInput: View {
    @Binding var value: Double?
    let placeholder: String
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .onAppear {
                text = value.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
            }
            .onChange(of: text) { _, newText in
                value = parseDecimal(newText)
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
            DecimalInput(value: $value, placeholder: placeholder)
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
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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

    private var label: String {
        "T\(test) · DUE \(Format.clock(due))"
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

/// Builds the GPX from a raw log (so far, if still recording) and offers both to share.
private struct LogShareView: View {
    let logURL: URL
    @State private var gpxURL: URL?

    var body: some View {
        List {
            if let gpxURL {
                ShareLink(items: [gpxURL, logURL]) {
                    Label("Share GPX and raw log", systemImage: "square.and.arrow.up")
                }
            } else {
                ProgressView()
            }
            ShareLink(item: logURL) {
                Label("Share raw log only", systemImage: "doc")
            }
        }
        .navigationTitle(logURL.deletingPathExtension().lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let url = logURL
            gpxURL = await Task.detached { RideLog.writeGPX(for: url) }.value
        }
    }
}
