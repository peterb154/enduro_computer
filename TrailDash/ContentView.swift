import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @AppStorage("orientationLock") private var orientation = OrientationLock.auto
    @State private var showingSettings = false

    /// Settings are reachable whenever nothing is being timed, including between tests.
    private var settingsAvailable: Bool {
        !model.ride.isActive && model.sprint.timer.state == .idle
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                if !model.isBusy || settingsAvailable {
                    HStack(spacing: 12) {
                        if !model.isBusy {
                            Picker("Mode", selection: $model.mode) {
                                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Spacer()
                        }
                        if settingsAvailable {
                            Button { showingSettings = true } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 56, height: 32)
                                    .foregroundStyle(.white)
                                    .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                switch model.mode {
                case .trail:
                    TrailView(ride: model.ride, heartRate: model.heartRate, location: model.location)
                case .sprint:
                    SprintView(sprint: model.sprint, heartRate: model.heartRate, location: model.location)
                }
            }
            .padding()
            // Pin to the top; each screen decides what fills the rest.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Screen never sleeps while the app is open, riding or not.
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            orientation.apply()
        }
        .onChange(of: orientation) { _, lock in lock.apply() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(sprint: model.sprint, ride: model.ride, heartRate: model.heartRate, location: model.location)
        }
    }
}

#Preview {
    ContentView()
}
