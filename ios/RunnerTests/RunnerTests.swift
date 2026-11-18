import ActivityKit
import SQLite3
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
    _ = try await press.perform()
    let updateDeadline = Date().addingTimeInterval(20)
    while workout.content.state.target == first.target, Date() < updateDeadline {
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    let second = workout.content.state
    XCTAssertNotEqual(second.target, first.target)
    XCTAssertTrue(second.movement.contains("Rows"), second.movement)
    XCTAssertNil(second.restEndsAt, "There is no rest between the two superset movements")

    var db: OpaquePointer?
    let path = docs.appendingPathComponent("foss_lift.sqlite").path
    let opened = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
    defer { sqlite3_close(db) }
    guard opened == SQLITE_OK else { return XCTFail("Could not open the active session database") }
    var statement: OpaquePointer?
    let prepared = sqlite3_prepare_v2(db, "SELECT payload FROM live_sessions WHERE id=1", -1, &statement, nil)
    defer { sqlite3_finalize(statement) }
    guard prepared == SQLITE_OK, sqlite3_step(statement) == SQLITE_ROW else {
      return XCTFail("The active session must be readable after the button returns")
    }
    let payload = String(cString: try XCTUnwrap(sqlite3_column_text(statement, 0)))
    struct Session: Decodable {
      struct Exercise: Decodable {
        struct SetRow: Decodable { let logged: Int? }
        let sets: [SetRow]
      }
      let startedAt: Int64
      let exercises: [Exercise]
    }
    let saved = try JSONDecoder().decode(Session.self, from: Data(payload.utf8))
    XCTAssertEqual(saved.startedAt, id)
    XCTAssertEqual(saved.exercises.flatMap { $0.sets.map(\.logged) }, [8, nil])
    print("Foss Lift simulator verified ActivityKit, the native App Intent and exactly one persisted set after two taps.")
  }
}
