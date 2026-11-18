import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let activity = FlutterMethodChannel(
      name: "com.fosslift.foss_lift/workout_activity",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    activity.setMethodCallHandler { call, result in
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
  }
}
