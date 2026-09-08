import Flutter
import Foundation
import MLCSwift
import os

/// Bridges Flutter to MLCSwift for on-device MLC LLM inference.
///
/// Wraps the real `MLCEngine` (from the MLCSwift local Swift package) that is
/// linked into the Runner target alongside the prebuilt MLC static libraries.
/// Loads the bundled Qwen3 model and routes `generate`/`generateStream` through
/// the engine, forwarding deltas on the EventChannel until `[DONE]`.
@available(iOS 14.0.0, *)
final class MLCLLMHandler: NSObject {
  private static let methodChannelName = "com.example.clinical/llm"
  private static let streamChannelName = "com.example.clinical/llm_stream"
  private static let doneSentinel = "[DONE]"
  private static let modelBundleName = "Qwen3-0.6B-Q4_K_M-MLC"
  private static let modelLib = "llama_q4f16_1_d5ba06e61253098870aaa5dc3f1a2589"
  private static let maxContextTokens = 2048

  private let logger = Logger(subsystem: "com.omoyari.greentech.doctorApp", category: "MLCLLMHandler")

  private let methodChannel: FlutterMethodChannel
  private let streamChannel: FlutterEventChannel

  private var eventSink: FlutterEventSink?
  private var engine: MLCEngine?
  private var isEngineReady = false
  private var isEngineInitializing = false
  private var activeGenerationTask: Task<Void, Never>?

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
  }

  deinit {
    activeGenerationTask?.cancel()
    engine = nil
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
      Task {
        do {
          let text = try await runGeneration(for: call)
          result(text)
        } catch {
          result(FlutterError(
            code: "GENERATE_FAILED",
            message: "MLC generation failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    case "generateStream":
      guard let prompt = promptArgument(from: call, result: result) else { return }
      Task {
        do {
          try await initialize()
          startStreaming(prompt: prompt)
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
      Task {
        do {
          try await initialize()
          result(nil)
        } catch {
          result(FlutterError(
            code: "WARMUP_FAILED",
            message: "MLC warm-up failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    case "cancel":
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
    return prompt
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
    isEngineInitializing = true
    defer { isEngineInitializing = false }

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
    logger.info("MLC engine reloaded; model=\(modelPath, privacy: .public)")
  }

  private func modelPathHasBeam(_ path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    let hasConfig = entries.contains { $0 == "mlc-chat-config.json" }
    let hasParams = entries.contains { $0.contains(".params") || $0 == "params" }
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

  private func runGeneration(for call: FlutterMethodCall) async throws -> String {
    guard let prompt = promptArgument(from: call, result: { _ in }) else {
      throw NSError(
        domain: "MLCLLMHandler",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Missing non-empty prompt"]
      )
    }
    let engine = try await ensureEngine()
    let messages = [ChatCompletionMessage(role: .user, content: prompt)]
    let stream = await engine.chat.completions.create(
      messages: messages,
      model: Self.modelBundleName,
      max_tokens: Self.maxContextTokens,
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
    return buffer
  }

  private func startStreaming(prompt: String) {
    activeGenerationTask?.cancel()
    let task = Task { [weak self] in
      guard let self else { return }
      do {
        let engine = try await self.ensureEngine()
        let messages = [ChatCompletionMessage(role: .user, content: prompt)]
        let stream = await engine.chat.completions.create(
          messages: messages,
          model: Self.modelBundleName,
          max_tokens: Self.maxContextTokens,
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
        self.emit(Self.doneSentinel)
      } catch {
        self.logger.error("Stream generation error: \(error.localizedDescription)")
        self.emit(Self.doneSentinel)
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
}

@available(iOS 14.0.0, *)
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
