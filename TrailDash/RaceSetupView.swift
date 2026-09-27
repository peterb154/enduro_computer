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

                Section("Test start times (from roll chart)") {
                    ForEach(sprint.race.rollChart.indices, id: \.self) { index in
                        HStack {
                            DatePicker("Test \(index + 1)", selection: timeBinding($sprint.race.rollChart[index]),
                                       displayedComponents: .hourAndMinute)
                            Text("→ \(Format.clock(minutes: sprint.race.dueMinutes(for: index + 1) ?? 0))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Add test") { sprint.race.addTest() }
                    if !sprint.race.rollChart.isEmpty {
                        Button("Remove last test", role: .destructive) { sprint.race.rollChart.removeLast() }
                    }
                }
            }
            .navigationTitle("Race setup")
            .toolbar {
                Button("Done") { dismiss() }
            }
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
