import SwiftUI

/// Pick which heart rate device to use when more than one is on.
struct HeartRateDevicesView: View {
    let heartRate: HeartRateMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                HeartRateDeviceSection(heartRate: heartRate)
            }
            .navigationTitle("Heart rate")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// Heart rate devices in range, with a checkmark on the chosen one. Tap to switch.
struct HeartRateDeviceSection: View {
    let heartRate: HeartRateMonitor

    var body: some View {
        Section {
            ForEach(heartRate.devices) { device in
                Button {
                    heartRate.select(device.id)
                } label: {
                    HStack {
                        Image(systemName: "checkmark").opacity(device.id == heartRate.preferredID ? 1 : 0)
                        Text(device.name).foregroundStyle(.primary)
                        Spacer()
                        if device.id == heartRate.connectedID {
                            Text([heartRate.bpm.map { "\($0) bpm" } ?? "connected",
                                  heartRate.batteryPercent.map { "\($0)%" }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Heart rate")
        } footer: {
            Text(heartRate.devices.isEmpty
                 ? "Searching… Put on the strap or start HR broadcast on your watch."
                 : "Your choice is remembered. Devices appear as they're found.")
        }
    }
}
