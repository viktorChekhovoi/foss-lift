import ActivityKit
import Foundation
import UserNotifications

@available(iOS 16.2, *)
enum WorkoutLiveActivity {
  typealias Workout = Activity<WorkoutAttributes>
  private static let lastSession = "workoutLiveActivitySession"

  @MainActor
  static func sync(_ arguments: [String: Any]?) async throws {
    let activities = Workout.activities
    guard let arguments else {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      UserDefaults.standard.removeObject(forKey: lastSession)
      return
    }

    guard let session = arguments["session"] as? Int64,
          let workout = arguments["workout"] as? String,
          let movement = arguments["movement"] as? String,
          let detail = arguments["detail"] as? String else {
      throw CocoaError(.coderInvalidValue)
    }
    let deadline = (arguments["restEndsAt"] as? Int64).map {
      Date(timeIntervalSince1970: Double($0) / 1000)
    }
    func buttons(_ key: String) -> [WorkoutButton]? {
      (arguments[key] as? [[String: String]])?.compactMap { entry in
        guard let id = entry["id"], let label = entry["label"] else { return nil }
        return WorkoutButton(id: id, label: label)
      }
    }
    let state = WorkoutAttributes.ContentState(
      workout: workout, movement: movement, detail: detail, restEndsAt: deadline,
      target: arguments["target"] as? String, setButtons: buttons("setButtons"), restButtons: buttons("restButtons"))
    let content = ActivityContent(state: state, staleDate: deadline)
    let current = activities.first { $0.attributes.session == session }
    for activity in activities where activity.id != current?.id {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    if let current {
      if current.content.state != state {
        await current.update(content)
      }
    } else if ActivityAuthorizationInfo().areActivitiesEnabled,
              UserDefaults.standard.object(forKey: lastSession) as? Int64 != session {
      // Remember a successful start so swiping this workout away also sticks after a process restart.
      _ = try Workout.request(attributes: WorkoutAttributes(session: session), content: content, pushType: nil)
      UserDefaults.standard.set(session, forKey: lastSession)
      // The first set can now be logged from another app. Ask about the rest sound
      // while the lifter is still in Foss Lift and iOS can present its prompt.
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
  }
}
