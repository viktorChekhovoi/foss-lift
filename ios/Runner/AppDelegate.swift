import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  // A button may launch the app process without a scene. Attach the eventual
  // window to this same engine so it cannot overwrite the background set log.
  lazy var workoutEngine = FlutterEngine(name: "Foss Lift")
  private var dartReady = false
  private var waitingForDart: [CheckedContinuation<Void, Never>] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    workoutEngine.run()
    GeneratedPluginRegistrant.register(with: workoutEngine)
    let activity = FlutterMethodChannel(
      name: "com.fosslift.foss_lift/workout_activity",
      binaryMessenger: workoutEngine.binaryMessenger)
    activity.setMethodCallHandler { [weak self] call, result in
      if call.method == "ready" {
        self?.dartReady = true
        self?.waitingForDart.forEach { $0.resume() }
        self?.waitingForDart.removeAll()
        result(nil)
        return
      }
      guard call.method == "sync" else { result(FlutterMethodNotImplemented); return }
      guard #available(iOS 16.2, *) else { result(nil); return }
      Task { @MainActor in
        do {
          try await WorkoutLiveActivity.sync(call.arguments as? [String: Any])
          result(nil)
        } catch {
          result(FlutterError(code: "workout_activity", message: error.localizedDescription, details: nil))
        }
      }
    }
    if #available(iOS 17.0, *) {
      WorkoutActionIntent.apply = { [weak self] press in
        guard let self else { throw CocoaError(.executableNotLoadable) }
        if !self.dartReady {
          await withCheckedContinuation { self.waitingForDart.append($0) }
        }
        try await withCheckedThrowingContinuation { (reply: CheckedContinuation<Void, Error>) in
          activity.invokeMethod("performAction", arguments: [
            "session": press.session, "target": press.target, "action": press.action, "restEndsAt": press.deadline
          ]) { value in
            if value as? Bool != true {
              reply.resume(throwing: CocoaError(.executableRuntimeMismatch))
            } else {
              reply.resume()
            }
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
