import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct FocusWidgets: WidgetBundle {
    var body: some Widget {
        FocusWidget()
        if #available(iOS 26.0, *) { AlarmWidget() }
    }
}

/// AlarmKit draws its own countdown from the alarm it is running, so on iOS 26
/// this replaces the widget below rather than joining it.
@available(iOS 26.0, *)
struct AlarmWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<FocusMetadata>.self) { context in
            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.presentation.countdown?.title ?? "focus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                clock(context.state, size: 44)
            }
            .padding(20)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.trailing) { clock(context.state, size: 28) }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                clock(context.state, size: 14)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func clock(_ state: AlarmPresentationState, size: CGFloat) -> some View {
        let font = Font.system(size: size, weight: .light, design: .rounded)
        switch state.mode {
        case .countdown(let mode):
            Text(timerInterval: mode.startDate...mode.fireDate, countsDown: true)
                .font(font).monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: size * 3.2, alignment: .trailing)
        case .paused:
            Text("paused").font(font)
        default:
            Text("done").font(font)
        }
    }
}

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
