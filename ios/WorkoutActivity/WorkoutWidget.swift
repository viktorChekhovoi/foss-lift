import ActivityKit
import AppIntents
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
        if #available(iOS 17.0, *) { WorkoutControls(context: context) }
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
            if #available(iOS 17.0, *) { WorkoutControls(context: context) }
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

@available(iOS 17.0, *)
private struct WorkoutControls: View {
  let context: ActivityViewContext<WorkoutAttributes>

  var body: some View {
    let state = context.state
    let resting = !context.isStale && (state.restEndsAt.map { $0 > Date() } ?? false)
    if let target = state.target, let buttons = resting ? state.restButtons : state.setButtons, !buttons.isEmpty {
      HStack(spacing: 6) {
        ForEach(buttons) { button in
          if button.id == "set_start" {
            Link(destination: URL(string: "fosslift://session")!) {
              Label(button.label, systemImage: "stopwatch")
            }
          } else {
            Button(intent: WorkoutActionIntent(session: context.attributes.session, target: target,
                                               action: button.id, restEndsAt: state.restEndsAt)) {
              Text(verbatim: button.label)
            }
          }
        }
      }
      .font(.subheadline.weight(.semibold))
      .controlSize(.small)
      .buttonStyle(.bordered)
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
