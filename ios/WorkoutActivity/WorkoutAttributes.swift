import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.2, *)
struct WorkoutAttributes: ActivityAttributes {
  let session: Int64

  var startedAt: Date { Date(timeIntervalSince1970: Double(session) / 1000) }

  struct ContentState: Codable, Hashable {
    let workout: String
    let movement: String
    let detail: String
    let restEndsAt: Date?
    // Optional so an activity started by the previous build remains readable.
    let target: String?
    let setButtons: [WorkoutButton]?
    let restButtons: [WorkoutButton]?
  }
}

struct WorkoutButton: Codable, Hashable, Identifiable {
  let id: String
  let label: String
}

@available(iOS 17.0, *)
struct WorkoutActionIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Workout control"
  static var isDiscoverable: Bool { false }
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Workout") var session: Int
  @Parameter(title: "Set") var target: String
  @Parameter(title: "Action") var action: String
  @Parameter(title: "Rest deadline") var deadline: Int

  init() {}

  init(session: Int64, target: String, action: String, restEndsAt: Date?) {
    self.session = Int(session)
    self.target = target
    self.action = action
    self.deadline = restEndsAt.map { Int(($0.timeIntervalSince1970 * 1000).rounded()) } ?? 0
  }

  // LiveActivityIntent runs in Runner's process. Both targets share the same intent
  // definition, and only Runner installs the handler that owns the live session.
  @MainActor static var apply: ((WorkoutActionIntent) async throws -> Void)?

  @MainActor func perform() async throws -> some IntentResult {
    guard let apply = Self.apply else { throw CocoaError(.executableNotLoadable) }
    try await apply(self)
    return .result()
  }
}
