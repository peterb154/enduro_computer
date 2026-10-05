import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TrailDashWidgets: WidgetBundle {
    var body: some Widget {
        RideLiveActivityWidget()
    }
}

struct RideLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // This phone has no Dynamic Island, but the API requires a layout.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(bpmText(context.state)).font(.largeTitle.bold()) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.miles) mi") }
            } compactLeading: {
                Image(systemName: "heart.fill").foregroundStyle(.red)
            } compactTrailing: {
                Text(bpmText(context.state))
            } minimal: {
                Text(bpmText(context.state))
            }
        }
    }
}

private func bpmText(_ state: RideActivityAttributes.ContentState) -> String {
    state.bpm.map(String.init) ?? "--"
}

private struct LockScreenView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(bpmText(context.state))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(HeartRateZones.color(zone: context.state.zone ?? 1))
                Text("HR").font(.headline).foregroundStyle(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                Text("\(context.state.miles) mi")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}
