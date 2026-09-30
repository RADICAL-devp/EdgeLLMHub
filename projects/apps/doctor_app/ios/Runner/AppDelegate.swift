import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // DEPRECATED (flutter_gemma migration): the MLC LLM MethodChannel handler
  // is dormant — flutter_gemma (LiteRT-LM) is the on-device engine now and
  // needs no native registration. MLCLLMHandler.swift is kept for reference;
  // the MLC model is no longer bundled (post-install download only).
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
