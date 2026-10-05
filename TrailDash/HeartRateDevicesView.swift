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

/// Heart rate devices in range: pick the main one (chest strap) and an optional
/// backup (watch broadcasting HR) that takes over when the main one goes quiet.
struct HeartRateDeviceSection: View {
    let heartRate: HeartRateMonitor

    var body: some View {
        Section {
            ForEach(heartRate.devices) { device in
                row(device, selected: device.id == heartRate.primaryID) { heartRate.selectPrimary(device.id) }
            }
        } header: {
            Text("Heart rate")
        } footer: {
            Text(heartRate.devices.isEmpty
                 ? "Searching… Put on the strap or start HR broadcast on your watch."
                 : "Your choice is remembered. Devices appear as they're found.")
        }
        Section {
            Button { heartRate.selectBackup(nil) } label: {
                HStack {
                    Image(systemName: "checkmark").opacity(heartRate.backupID == nil ? 1 : 0)
                    Text("None").foregroundStyle(.primary)
                }
            }
            ForEach(heartRate.devices.filter { $0.id != heartRate.primaryID }) { device in
                row(device, selected: device.id == heartRate.backupID) { heartRate.selectBackup(device.id) }
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Used when the main device sends nothing for a few seconds; switches back when it returns. On a Garmin, turn on Broadcast Heart Rate during the activity.")
        }
    }

    private func row(_ device: HeartRateDevice, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "checkmark").opacity(selected ? 1 : 0)
                Text(device.name).foregroundStyle(.primary)
                Spacer()
                Text(detail(device.id)).foregroundStyle(.secondary)
            }
        }
    }

    /// "152 bpm · 80%" for the live source, "connected" for others, blank if not connected.
    private func detail(_ id: UUID) -> String {
        guard heartRate.connectedIDs.contains(id) else { return "" }
        let reading = id == heartRate.activeID ? heartRate.bpm.map { "\($0) bpm" } : "connected"
        return [reading, heartRate.battery(of: id).map { "\($0)%" }].compactMap { $0 }.joined(separator: " · ")
    }
}
