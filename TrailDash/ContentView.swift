import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @AppStorage("orientationLock") private var orientation = OrientationLock.auto

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                if !model.isBusy {
                    HStack(spacing: 12) {
                        Picker("Mode", selection: $model.mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        Button { orientation = orientation.next } label: {
                            Label(orientation.rawValue.capitalized, systemImage: orientation.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(minWidth: 110, minHeight: 32)
                                .foregroundStyle(.white)
                                .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
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
        }
        // Screen never sleeps while the app is open, riding or not.
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            orientation.apply()
        }
        .onChange(of: orientation) { _, lock in lock.apply() }
    }
}

#Preview {
    ContentView()
}
