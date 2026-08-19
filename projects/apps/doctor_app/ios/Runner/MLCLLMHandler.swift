import Flutter
import Foundation
#if canImport(MLCSwift)
import MLCSwift
#else
// Native on-device LLM is disabled until the MLCSwift Swift Package is
// added to the Xcode project (File → Add Package Dependencies → Add Local
// → ios/mlc-llm/ios/MLCSwift). The Dart adapter then reports the engine as
// unavailable and the app falls back to the cloud LLM.
#endif

#if canImport(MLCSwift)

/// Bridges Flutter to MLCSwift for on-device SmolLM-360M inference.
final class MLCLLMHandler: NSObject {
  private static let methodChannelName = "com.example.clinical/llm"
  private static let streamChannelName = "com.example.clinical/llm_stream"
  private static let doneSentinel = "[DONE]"
  // Model directory name as produced by `mlc_llm package` with HF://HuggingFaceTB/SmolLM-360M-Instruct + q4f16_1
  private static let modelBundleName = "SmolLM-360M-Instruct-q4f16_1-MLC"
  // `model_lib` field from bundle/mlc-app-config.json — the compiled system
  // library registers under this exact name (llama arch + quantization hash).
  private static let modelLib = "llama_q4f16_1_d5ba06e61253098870aaa5dc3f1a2589"
  private static let maxContextTokens = 2048

  private let methodChannel: FlutterMethodChannel
  private let streamChannel: FlutterEventChannel
  private let engine = MLCEngine()

  private var eventSink: FlutterEventSink?
  private var isEngineReady = false
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
    let engineCopy = engine
    Task.detached { await engineCopy.unload() }
  }

  private var modelPath: String? {
    // Primary: the model downloaded on first run. The Dart ModelManagerCubit
    // downloads and checksum-verifies the archive into the app Documents
    // directory and extracts it there, so this is the single source of truth
    // for both platforms.
    if let documentsDir = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first {
      let downloaded = documentsDir
        .appendingPathComponent(Self.modelBundleName)
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(
        atPath: downloaded.path,
        isDirectory: &isDir
      ), isDir.boolValue {
        return downloaded.path
      }
    }
    // Legacy/dev fallback: the model folder bundled into the app bundle
    // (pre-download era, and local `flutter run` setups that copy the model
    // in as a folder reference).
    if let path = Bundle.main.path(forResource: Self.modelBundleName, ofType: nil) {
      return path
    }
    // Fallback: synchronized groups may flatten resources — scan the
    // bundle for any directory whose name contains the model lib.
    let matchingDir = Bundle.main.urls(
      forResourcesWithExtension: nil,
      subdirectory: nil
    )?.first { url in
      var isDir: ObjCBool = false
      return FileManager.default.fileExists(
        atPath: url.path,
        isDirectory: &isDir
      ) && isDir.boolValue && url.lastPathComponent.contains(Self.modelLib)
    }
    return matchingDir?.path
  }

  private func handleMethodCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isAvailable":
      result(isEngineReady)

    case "getModelInfo":
      result(modelInfo())

    case "initialize":
      Task {
        do {
          try await initializeEngine()
          await MainActor.run { result(nil) }
        } catch {
          await MainActor.run { result(flutterError(from: error)) }
        }
      }

    case "generate":
      guard let prompt = promptArgument(from: call, result: result) else { return }
      Task {
        do {
          let response = try await generateNonStreaming(prompt: prompt)
          await MainActor.run { result(response) }
        } catch {
          await MainActor.run { result(flutterError(from: error)) }
        }
      }

    case "generateStream":
      guard let prompt = promptArgument(from: call, result: result) else { return }
      activeGenerationTask?.cancel()
      activeGenerationTask = Task { [weak self] in
        guard let self else { return }
        do {
          try await self.generateStreaming(prompt: prompt)
        } catch {
          await MainActor.run {
            self.eventSink?(self.flutterError(from: error))
          }
        }
      }
      result(nil)

    case "warmUp":
      Task {
        do {
          _ = try await generateNonStreaming(prompt: "Hello")
          await MainActor.run { result("OK") }
        } catch {
          await MainActor.run { result(flutterError(from: error)) }
        }
      }

    case "cancel":
      activeGenerationTask?.cancel()
      activeGenerationTask = nil
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

  private func initializeEngine() async throws {
    guard !isEngineReady else { return }
    guard let path = modelPath else {
      throw MLCBridgeError.modelNotFound(
        "SmolLM-360M not installed. Download it from the Model Manager screen first."
      )
    }

    await engine.reload(modelPath: path, modelLib: Self.modelLib)
    isEngineReady = true
  }

  private func generateNonStreaming(prompt: String) async throws -> String {
    var output = ""
    try await streamCompletion(prompt: prompt) { token in
      output.append(token)
    }
    return output
  }

  private func generateStreaming(prompt: String) async throws {
    guard let sink = eventSink else { throw MLCBridgeError.noEventSink }

    try await streamCompletion(prompt: prompt) { token in
      await MainActor.run {
        sink(token)
      }
    }

    await MainActor.run {
      sink(Self.doneSentinel)
    }
  }

  private func streamCompletion(
    prompt: String,
    onToken: @escaping (String) async -> Void
  ) async throws {
    guard isEngineReady else { throw MLCBridgeError.engineNotReady }

    let messages = [
      ChatCompletionMessage(role: .user, content: prompt)
    ]

    for await chunk in await engine.chat.completions.create(messages: messages) {
      if Task.isCancelled {
        throw MLCBridgeError.cancelled
      }
      guard let choice = chunk.choices.first,
            let content = choice.delta.content,
            case let .text(token) = content,
            !token.isEmpty else {
        continue
      }
      await onToken(token)
    }
  }

  private func modelInfo() -> [String: Any] {
    let path = modelPath
    return [
      "modelId": Self.modelBundleName,
      "modelLib": Self.modelLib,
      "modelPath": path ?? "",
      "installed": path != nil,
      "ready": isEngineReady,
      "contextWindowTokens": Self.maxContextTokens,
      "checksumSha256": bundleChecksum() ?? "",
      "runtime": "MLCSwift",
      "processor": deviceProcessor(),
    ]
  }

  /// Human-readable execution device: the Metal GPU name when a Metal device
  /// is available (physical A-series hardware), otherwise the CPU (simulator
  /// or devices without Metal).
  private func deviceProcessor() -> String {
    if let metalDevice = MTLCreateSystemDefaultDevice() {
      return "\(metalDevice.name) (Metal)"
    }
    return "CPU (\(hostCpuArchitecture()))"
  }

  private func hostCpuArchitecture() -> String {
    var uts = utsname()
    uname(&uts)
    let raw = withUnsafePointer(to: &uts.machine) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: 64) { cstr in
        String(cString: cstr)
      }
    }
    return raw
  }

  private func bundleChecksum() -> String? {
    // The downloaded-model flow verifies the SHA-256 in Dart (single source
    // of truth); a checksums.sha256 file may still accompany the model in
    // the Documents dir (written by the download tooling) or ship inside
    // the bundle for dev builds.
    if let documentsDir = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first {
      let checksumFile = documentsDir.appendingPathComponent("checksums.sha256")
      if let value = try? String(contentsOf: checksumFile, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
        return value
      }
    }
    guard let checksumPath = Bundle.main.path(forResource: "checksums", ofType: "sha256") else {
      return nil
    }
    return try? String(contentsOfFile: checksumPath, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func flutterError(from error: Error) -> FlutterError {
    if let bridgeError = error as? MLCBridgeError {
      return FlutterError(
        code: bridgeError.code,
        message: bridgeError.localizedDescription,
        details: nil
      )
    }

    return FlutterError(
      code: "GENERATION_FAILED",
      message: error.localizedDescription,
      details: nil
    )
  }
}

extension MLCLLMHandler: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
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

private enum MLCBridgeError: LocalizedError {
  case modelNotFound(String)
  case engineNotReady
  case noEventSink
  case cancelled

  var code: String {
    switch self {
    case .modelNotFound: return "MODEL_NOT_FOUND"
    case .engineNotReady: return "ENGINE_NOT_READY"
    case .noEventSink: return "STREAM_NOT_LISTENING"
    case .cancelled: return "CANCELLED"
    }
  }

  var errorDescription: String? {
    switch self {
    case .modelNotFound(let message): return message
    case .engineNotReady: return "MLC engine is not initialized."
    case .noEventSink: return "No active Flutter event stream is listening."
    case .cancelled: return "Generation was cancelled."
    }
  }
}

#endif  // canImport(MLCSwift)
