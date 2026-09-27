import SwiftUI

/// Pre-race form: key time and roll chart test start times.
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
                    LabeledContent("Offset", value: "\(sprint.race.keyOffsetMinutes) min")
                } header: {
                    Text("Key time")
                } footer: {
                    Text("Race start is the time the roll chart is based on. Your due times are the roll chart times plus your offset.")
                }

                Section {
                    if sprint.race.rollChart.isEmpty {
                        paceStepper(label: "All tests", test: 1)
                    }
                    ForEach(sprint.race.rollChart.indices, id: \.self) { index in
                        let test = index + 1
                        VStack(alignment: .leading) {
                            HStack {
                                DatePicker("Test \(test)", selection: timeBinding($sprint.race.rollChart[index]),
                                           displayedComponents: .hourAndMinute)
                                Text("→ \(Format.clock(minutes: sprint.race.dueMinutes(for: test) ?? 0))")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            paceStepper(label: "Pace", test: test)
                        }
                    }
                    Button("Add test") { sprint.race.addTest() }
                    if !sprint.race.rollChart.isEmpty {
                        Button("Remove last test", role: .destructive) { sprint.race.rollChart.removeLast() }
                    }
                } header: {
                    Text("Tests (from roll chart)")
                } footer: {
                    Text("A pace applies to that test and every later test until you change it. Tests past the last one listed keep the last pace.")
                }

                Section {
                    LabeledContent("Paces", value: sprint.paces.summary)
                        .monospacedDigit()
                    if sprint.paces.varies {
                        Button("Reset all paces to Test 1's", role: .destructive) { sprint.resetPaces() }
                    }
                }
            }
            .navigationTitle("Race setup")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private func paceStepper(label: String, test: Int) -> some View {
        Stepper(value: Binding(get: { sprint.paces.pace(for: test) },
                               set: { sprint.setPace($0, from: test) }),
                in: 1...99) {
            Text("\(label): \(sprint.paces.pace(for: test)) mph").monospacedDigit()
        }
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

/// "T2 DUE 10:54   -4:12": counts down to the rider's minute, then up in red.
/// Buzzes on entering the last minute, the last 10 s, and going late.
struct DueCountdown: View {
    let test: Int
    let due: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = due.timeIntervalSince(context.date)
            let phase = countdownPhase(remaining: remaining)
            HStack(alignment: .firstTextBaseline) {
                Text("T\(test) DUE \(due.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))")
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
