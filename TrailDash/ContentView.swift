import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("--")
                    .font(.system(size: 160, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("HR")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.gray)
            }
        }
    }
}

#Preview {
    ContentView()
}
