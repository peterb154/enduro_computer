import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                if !model.isBusy {
                    Picker("Mode", selection: $model.mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
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
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    }
}

#Preview {
    ContentView()
}
