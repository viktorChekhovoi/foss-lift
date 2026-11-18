import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    guard let sceneWindow = scene as? UIWindowScene,
          let app = UIApplication.shared.delegate as? AppDelegate else { return }
    let engine = app.workoutEngine
    registerSceneLifeCycle(with: engine)
    let window = UIWindow(windowScene: sceneWindow)
    window.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    self.window = window
    window.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
