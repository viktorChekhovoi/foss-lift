import ActivityKit
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
  }
}
