import Flutter
import Foundation
import MLCSwift

/// Bridges Flutter to MLCSwift for on-device SmolLM-350M inference.
final class MLCLLMHandler: NSObject {
  private static let methodChannelName = "com.example.clinical/llm"
  private static let streamChannelName = "com.example.clinical/llm_stream"
  private static let doneSentinel = "[DONE]"
  // Model directory name as produced by `mlc_llm package` with HF://HuggingFaceTB/SmolLM-350M-Instruct + q4f16_1
  private static let modelBundleName = "SmolLM-350M-Instruct-q4f16_1-MLC"
  private static let modelLib = "SmolLM-350M-Instruct-q4f16_1-MLC"
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
    Task { await engine.unload() }
  }

  private var modelPath: String? {
    Bundle.main.path(forResource: Self.modelBundleName, ofType: nil)
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
        "SmolLM-350M not bundled. Run ios/scripts/setup_ios_mlc.sh --model HuggingFaceTB/SmolLM-350M-Instruct --quant q4f16_1."
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
    guard eventSink != nil else { throw MLCBridgeError.noEventSink }

    try await streamCompletion(prompt: prompt) { [weak self] token in
      await MainActor.run {
        self?.eventSink?(token)
      }
    }

    await MainActor.run {
      eventSink?(Self.doneSentinel)
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
      "bundled": path != nil,
      "ready": isEngineReady,
      "contextWindowTokens": Self.maxContextTokens,
      "checksumSha256": bundleChecksum() ?? "",
      "runtime": "MLCSwift"
    ]
  }

  private func bundleChecksum() -> String? {
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
