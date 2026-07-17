import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Keep a strong reference to the MLC handler so it isn't deallocated.
  private var mlcHandler: MLCLLMHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Register the MLC LLM MethodChannel handler directly against
    // the engine's binary messenger — NOT via registrar(forPlugin:)
    // to avoid access-control issues.
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let messenger = controller.binaryMessenger
    mlcHandler = MLCLLMHandler(messenger: messenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
