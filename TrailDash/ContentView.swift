import SwiftUI

struct ContentView: View {
    @State private var heartRate = HeartRateMonitor()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(heartRate.bpm.map(String.init) ?? "--")
                    .font(.system(size: 160, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("HR")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.gray)
                Text(heartRate.status)
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
                    .padding(.top, 24)
            }
        }
    }
}

#Preview {
    ContentView()
}
