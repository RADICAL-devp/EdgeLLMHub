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

    // Register the MLC LLM MethodChannel handler against the plugin
    // registrar's messenger. With the scene-based lifecycle the window
    // (and its FlutterViewController) may not exist yet during
    // didFinishLaunching, so the registrar messenger is the reliable way
    // to reach the engine's binary messenger.
    if let registrar = self.registrar(forPlugin: "MLCLLMHandler") {
      let messenger = registrar.messenger()
#if canImport(MLCSwift)
      mlcHandler = MLCLLMHandler(messenger: messenger)
#else
      // MLCSwift package not linked — native LLM unavailable until it is
      // added in Xcode; the app falls back to the cloud LLM.
#endif
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
