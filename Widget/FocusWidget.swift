import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FocusWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            HStack(alignment: .firstTextBaseline) {
                Text(context.state.phase)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                countdown(context.state, size: 44)
            }
            .padding(20)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.phase).font(.headline).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state, size: 28)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdown(context.state, size: 14)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func countdown(_ state: FocusAttributes.ContentState, size: CGFloat) -> some View {
        Text(timerInterval: state.startedAt...state.endsAt, countsDown: true)
            .font(.system(size: size, weight: .light, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: size * 3.2, alignment: .trailing)
    }
}
