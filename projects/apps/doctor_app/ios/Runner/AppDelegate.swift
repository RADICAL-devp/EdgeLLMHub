import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
#if canImport(MLCSwift)
  /// Keep a strong reference to the MLC handler so it isn't deallocated.
  private var mlcHandler: MLCLLMHandler?
#endif

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
#if canImport(MLCSwift)
    mlcHandler = MLCLLMHandler(messenger: messenger)
#else
    // MLCSwift package not linked — native LLM unavailable until it is
    // added in Xcode; the app falls back to the cloud LLM.
#endif

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
