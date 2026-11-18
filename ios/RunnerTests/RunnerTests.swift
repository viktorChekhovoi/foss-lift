import ActivityKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  @available(iOS 17.0, *)
  @MainActor func testIslandLogsOnlyTheDisplayedSet() async throws {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let id = try XCTUnwrap(Int64(try String(contentsOf: docs.appendingPathComponent("control-smoke-session"))))
    let timeout = Date().addingTimeInterval(30)
    var activity: Activity<WorkoutAttributes>?
    while Date() < timeout {
      activity = Activity<WorkoutAttributes>.activities.first { $0.attributes.session == id }
      if activity?.content.state.target != nil { break }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    let workout = try XCTUnwrap(activity, "The installed Flutter app must restore the fixture into a Live Activity")
    let first = workout.content.state
    XCTAssertEqual(first.setButtons?.map { $0.id }, ["set_done", "set_missed"])
    let press = WorkoutActionIntent(session: id, target: try XCTUnwrap(first.target), action: "set_done", restEndsAt: nil)
    _ = try await press.perform()
    let second = workout.content.state
    XCTAssertNotEqual(second.target, first.target)
    XCTAssertTrue(second.movement.contains("Rows"), second.movement)
    XCTAssertNil(second.restEndsAt, "There is no rest between the two superset movements")
    _ = try await press.perform()
    XCTAssertEqual(workout.content.state.target, second.target)
    print("Foss Lift simulator verified app launch, ActivityKit, the App Intent and the next superset row.")
  }
}
