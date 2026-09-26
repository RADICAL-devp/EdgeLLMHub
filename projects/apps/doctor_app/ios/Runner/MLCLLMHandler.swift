import Flutter
import Foundation
import MLCSwift
import os
import UIKit

/// Bridges Flutter to MLCSwift for on-device MLC LLM inference.
///
/// Wraps the real `MLCEngine` (from the MLCSwift local Swift package) that is
/// linked into the Runner target alongside the prebuilt MLC static libraries.
/// Loads the bundled Qwen3 model and routes `generate`/`generateStream` through
/// the engine, forwarding deltas on the EventChannel until `[DONE]`.
@available(iOS 15.0, *)
final class MLCLLMHandler: NSObject {
  private static let methodChannelName = "com.example.clinical/llm"
  private static let streamChannelName = "com.example.clinical/llm_stream"
  private static let doneSentinel = "[DONE]"
  private static let modelBundleName = "Qwen3-0.6B-Q4_K_M-MLC"
  private static let modelLib = "llama_q4f16_1_d5ba06e61253098870aaa5dc3f1a2589"
  private static let maxContextTokens = 2048
  private static let maxPromptCharacters = 4000
  private static let maxGeneratedTokens = 512
  /// Must stay in sync with `EnvironmentConfig.bundledModelVersion` in
  /// `lib/core/config/environment.dart`; the ModelManager cubit treats a
  /// missing `modelVersion` as "upgrade needed" and routes into the download
  /// flow instead of reporting ready.
  private static let modelBundleVersion = "1.2.0"

  private let logger = Logger(subsystem: "com.omoyari.greentech.doctorApp", category: "MLCLLMHandler")

  /// Trace id for the currently active generation, propagated from Dart so
  /// native logs can be correlated with the Flutter side.
  private var currentTraceId: String?

  private let methodChannel: FlutterMethodChannel
  private let streamChannel: FlutterEventChannel

  private var eventSink: FlutterEventSink?
  private var engine: MLCEngine?
  private var isEngineReady = false
  private var isEngineInitializing = false
  private var activeGenerationTask: Task<Void, Never>?

  /// Whether the app is in the active (foreground) state.
  ///
  /// iOS blocks Metal GPU command-buffer submission once the app resigns
  /// active; the MLC/TVM runtime does not expect this and throws an uncaught
  /// `tvm::ffi::Error` that terminates the process. We track the lifecycle so
  /// GPU-bound work (init/reload/warm-up/generate) is never submitted from the
  /// background and any in-flight generation is cancelled on transition.
  private var isAppInForeground = true

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: Self.methodChannelName,
      binaryMessenger: messenger
    )
    streamChannel = FlutterEventChannel(
      name: Self.streamChannelName,
      binaryMessenger: messenger
    )

    super.init()

    methodChannel.setMethodCallHandler(handleMethodCall)
    streamChannel.setStreamHandler(self)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    activeGenerationTask?.cancel()
    NotificationCenter.default.removeObserver(self)
    engine = nil
  }

  @objc private func appDidResignActive() {
    isAppInForeground = false
    // Cancel any in-flight generation so the MLC/TVM runtime never submits
    // Metal command buffers while the app is resigning active/backgrounded,
    // which otherwise throws an uncaught tvm::ffi::Error that kills the app.
    activeGenerationTask?.cancel()
    self.logger.info("App resigning active — cancelled in-flight generation")
  }

  @objc private func appDidEnterBackground() {
    isAppInForeground = false
    activeGenerationTask?.cancel()
  }

  @objc private func appDidBecomeActive() {
    isAppInForeground = true
  }

  /// Guards GPU-bound MLC operations: submitting Metal work from the
  /// background is not permitted and crashes the app (IOGPUMetalError /
  /// tvm::ffi::Error). Returns nil when it is safe to proceed, otherwise a
  /// descriptive [NSError].
  private func ensureForegroundForGPU() -> Error? {
    guard isAppInForeground else {
      return NSError(
        domain: "MLCLLMHandler",
        code: 5,
        userInfo: [
          NSLocalizedDescriptionKey:
            "App is in the background; MLC on-device inference cannot run. Bring the app to the foreground and try again."
        ]
      )
    }
    return nil
  }

  private var modelPath: String? {
    if let documentsDir = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first {
      let downloaded = documentsDir.appendingPathComponent(Self.modelBundleName)
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: downloaded.path, isDirectory: &isDir), isDir.boolValue {
        return downloaded.path
      }
    }
    if let path = Bundle.main.path(forResource: Self.modelBundleName, ofType: nil) {
      return path
    }
    let matchingDir = Bundle.main.urls(
      forResourcesWithExtension: nil,
      subdirectory: nil
    )?.first { url in
      var isDir: ObjCBool = false
      return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        && isDir.boolValue && url.lastPathComponent.contains(Self.modelBundleName)
    }
    return matchingDir?.path
  }

  // MARK: - Method channel

  private func handleMethodCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let modelAvailable = modelPath != nil
    switch call.method {
    case "isAvailable":
      result(isEngineReady)
    case "getModelInfo":
      result([
        "modelId": Self.modelBundleName,
        "modelPath": modelPath ?? "",
        "installed": modelAvailable,
        "ready": isEngineReady,
        "modelVersion": Self.modelBundleVersion,
        "contextWindowTokens": Self.maxContextTokens,
        "checksumSha256": "",
        "runtime": "MLCSwift",
        "processor": "CPU+GPU",
      ])
    case "initialize":
      Task {
        do {
          try await initialize()
          result(nil)
        } catch {
          result(FlutterError(
            code: "INIT_FAILED",
            message: "Failed to initialize MLC engine: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    case "generate":
      let traceId = traceIdArgument(from: call)
      currentTraceId = traceId
      self.logger.info("Generation requested (trace=\(self.traceSuffix(traceId)))")
      activeGenerationTask?.cancel()
      let generateTask = Task {
        do {
          let text = try await runGeneration(for: call, traceId: traceId)
          result(text)
        } catch {
          self.logger.error("Generation failed (trace=\(self.traceSuffix(traceId))): \(error.localizedDescription)")
          result(FlutterError(
            code: "GENERATE_FAILED",
            message: "MLC generation failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
      activeGenerationTask = generateTask
    case "generateStream":
      guard let prompt = promptArgument(from: call, result: result) else { return }
      let traceId = traceIdArgument(from: call)
      currentTraceId = traceId
      self.logger.info("Stream generation requested (trace=\(self.traceSuffix(traceId)))")
      Task {
        do {
          try await initialize()
          startStreaming(prompt: prompt, traceId: traceId)
          result(nil)
        } catch {
          result(FlutterError(
            code: "STREAM_FAILED",
            message: "MLC stream failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    case "warmUp":
      activeGenerationTask?.cancel()
      let warmUpTask = Task {
        do {
          if let foregroundError = ensureForegroundForGPU() {
            throw foregroundError
          }
          let engine = try await ensureEngine()
          // Run a short completion to warm up the GPU JIT pipeline and
          // populate the KV-cache so the first real request is faster.
          let messages = [ChatCompletionMessage(role: .user, content: "Hi")]
          let stream = await engine.chat.completions.create(
            messages: messages,
            model: Self.modelBundleName,
            max_tokens: 4,
            temperature: 0.2
          )
          for await _ in stream { /* drain */ }
          result(nil)
        } catch {
          // Warm-up failures are non-fatal — the model may still work.
          self.logger.warning("Warm-up failed (non-fatal): \(error.localizedDescription)")
          result(nil)
        }
      }
      activeGenerationTask = warmUpTask
    case "cancel":
      let traceId = traceIdArgument(from: call)
      currentTraceId = traceId
      self.logger.info("Cancelled active generation (trace=\(self.traceSuffix(traceId)))")
      activeGenerationTask?.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func promptArgument(
    from call: FlutterMethodCall,
    result: FlutterResult
  ) -> String? {
    guard let args = call.arguments as? [String: Any],
          let prompt = args["prompt"] as? String,
          !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(FlutterError(
        code: "INVALID_ARGS",
        message: "Missing non-empty 'prompt' argument",
        details: nil
      ))
      return nil
    }
    guard prompt.count <= Self.maxPromptCharacters else {
      result(FlutterError(
        code: "PROMPT_TOO_LONG",
        message: "Prompt exceeds the on-device model context budget. Split the transcript before generating.",
        details: ["maxCharacters": Self.maxPromptCharacters]
      ))
      return nil
    }
    return prompt
  }

  /// Reads the optional `traceId` argument passed from Dart so native log
  /// lines can be correlated with the Flutter-side trace.
  private func traceIdArgument(from call: FlutterMethodCall) -> String? {
    guard let args = call.arguments as? [String: Any] else { return nil }
    return args["traceId"] as? String
  }

  /// Renders a trace id for log interleaving, defaulting to `n/a` when the
  /// caller did not supply one (e.g. engine warm-up).
  private func traceSuffix(_ traceId: String?) -> String {
    traceId ?? "n/a"
  }

  // MARK: - Engine lifecycle

  private func initialize() async throws {
    if isEngineReady { return }
    if isEngineInitializing {
      while isEngineInitializing && !isEngineReady {
        try await Task.sleep(nanoseconds: 50_000_000)
      }
      if isEngineReady { return }
    }
    if let foregroundError = ensureForegroundForGPU() {
      throw foregroundError
    }
    isEngineInitializing = true
    defer { isEngineInitializing = false }

    self.logger.info("Model load started (trace=\(self.traceSuffix(self.currentTraceId)))")

    guard let modelPath = modelPath else {
      throw NSError(
        domain: "MLCLLMHandler",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Model \(Self.modelBundleName) not found in bundle or documents"]
      )
    }

    guard modelPathHasBeam(modelPath) else {
      throw NSError(
        domain: "MLCLLMHandler",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Model artifacts missing at \(modelPath)"]
      )
    }

    let engine = MLCEngine()
    self.engine = engine
    await engine.reload(modelPath: modelPath, modelLib: Self.modelLib)
    isEngineReady = true
    self.logger.info("MLC engine reloaded; model=\(modelPath, privacy: .public) (trace=\(self.traceSuffix(self.currentTraceId)))")
  }

  private func modelPathHasBeam(_ path: String) -> Bool {
    let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    // mlc-chat-config.json is the authoritative marker of a packaged MLC model.
    let hasConfig = entries.contains { $0 == "mlc-chat-config.json" }
    // Weight shards are named "params_shard_*.bin" (no literal ".params").
    let hasParams = entries.contains { $0.hasSuffix(".bin") || $0 == "params" }
    return hasConfig && hasParams
  }

  private func ensureEngine() async throws -> MLCEngine {
    if isEngineReady, let engine = engine {
      return engine
    }
    try await initialize()
    guard isEngineReady, let engine = engine else {
      throw NSError(
        domain: "MLCLLMHandler",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "MLC engine failed to initialize"]
      )
    }
    return engine
  }

  // MARK: - Generation

  private func runGeneration(for call: FlutterMethodCall, traceId: String?) async throws -> String {
    guard let prompt = promptArgument(from: call, result: { _ in }) else {
      throw NSError(
        domain: "MLCLLMHandler",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Missing non-empty prompt"]
      )
    }
    let engine = try await ensureEngine()
    self.logger.info("Generation started (trace=\(self.traceSuffix(traceId)))")
    if let foregroundError = ensureForegroundForGPU() {
      throw foregroundError
    }
    let messages = [ChatCompletionMessage(role: .user, content: prompt)]
    let stream = await engine.chat.completions.create(
      messages: messages,
      model: Self.modelBundleName,
      max_tokens: Self.maxGeneratedTokens,
      temperature: 0.2
    )
    var buffer = ""
    for await response in stream {
      for choice in response.choices {
        if let delta = choice.delta.content {
          buffer += delta.asText()
        }
      }
    }
    self.logger.info("Generation completed (trace=\(self.traceSuffix(traceId)), chars=\(buffer.count))")
    return buffer
  }

  private func startStreaming(prompt: String, traceId: String?) {
    activeGenerationTask?.cancel()
    let task = Task { [weak self] in
      guard let self else { return }
      do {
        let engine = try await self.ensureEngine()
        self.logger.info("Generation started (trace=\(self.traceSuffix(traceId)))")
        if let foregroundError = self.ensureForegroundForGPU() {
          throw foregroundError
        }
        let messages = [ChatCompletionMessage(role: .user, content: prompt)]
        let stream = await engine.chat.completions.create(
          messages: messages,
          model: Self.modelBundleName,
          max_tokens: Self.maxGeneratedTokens,
          temperature: 0.2
        )
        for await response in stream {
          if Task.isCancelled { break }
          for choice in response.choices {
            if let content = choice.delta.content {
              let delta = content.asText()
              if !delta.isEmpty {
                self.emit(delta)
              }
            }
          }
        }
        self.logger.info("Generation stream completed (trace=\(self.traceSuffix(traceId)))")
        self.emit(Self.doneSentinel)
      } catch {
        self.logger.error("Stream generation error (trace=\(traceSuffix(traceId))): \(error.localizedDescription)")
        self.emitError(
          code: "GENERATION_FAILED",
          message: "MLC generation failed: \(error.localizedDescription)"
        )
      }
    }
    activeGenerationTask = task
  }

  private func emit(_ event: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let sink = self.eventSink else { return }
      sink(event)
    }
  }

  private func emitError(code: String, message: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let sink = self.eventSink else { return }
      sink(FlutterError(code: code, message: message, details: nil))
    }
  }
}

@available(iOS 15.0, *)
extension MLCLLMHandler: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    activeGenerationTask?.cancel()
    activeGenerationTask = nil
    eventSink = nil
    return nil
  }
}
