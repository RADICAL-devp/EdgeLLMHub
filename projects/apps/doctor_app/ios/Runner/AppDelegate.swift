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

    // Register the MLC LLM MethodChannel handler against the plugin
    // registrar's messenger. This always registers the handler,
    // even when MLCSwift is not linked — the handler will report
    // engine unavailability and the Dart adapter falls back to stub.
    if let registrar = self.registrar(forPlugin: "MLCLLMHandler") {
      let messenger = registrar.messenger()
      mlcHandler = MLCLLMHandler(messenger: messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
