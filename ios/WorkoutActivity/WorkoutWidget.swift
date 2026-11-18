import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WorkoutWidget: Widget {
  private let sessionURL = URL(string: "fosslift://session")

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutAttributes.self) { context in
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Label(context.state.workout, systemImage: "figure.strengthtraining.traditional")
            .font(.subheadline.weight(.semibold))
          Spacer()
          WorkoutClock(context: context)
        }
        Text(context.state.movement).font(.headline)
        Text(context.state.detail).font(.subheadline).foregroundStyle(.secondary)
      }
      .lineLimit(1)
      .padding()
      .widgetURL(sessionURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.state.workout).font(.subheadline).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          WorkoutClock(context: context)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 3) {
            Text(context.state.movement).font(.headline)
            Text(context.state.detail).font(.subheadline).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .lineLimit(1)
        }
      } compactLeading: {
        Image(systemName: "figure.strengthtraining.traditional")
      } compactTrailing: {
        WorkoutClock(context: context, compact: true)
      } minimal: {
        Image(systemName: context.state.restEndsAt != nil && !context.isStale ? "timer" : "figure.strengthtraining.traditional")
      }
      .widgetURL(sessionURL)
    }
  }
}

private struct WorkoutClock: View {
  let context: ActivityViewContext<WorkoutAttributes>
  var compact = false

  var body: some View {
    HStack(spacing: 4) {
      if let end = context.state.restEndsAt, !context.isStale {
        if !compact { Image(systemName: "timer") }
        Text(timerInterval: min(context.attributes.startedAt, end)...end, countsDown: true)
          .foregroundStyle(.orange)
      } else {
        if !compact { Image(systemName: "clock") }
        Text(context.attributes.startedAt, style: .timer)
      }
    }
    .font(.subheadline.weight(.semibold))
    .monospacedDigit()
    .lineLimit(1)
    .multilineTextAlignment(.trailing)
    .frame(width: compact ? 52 : 90, alignment: .trailing)
  }
}
