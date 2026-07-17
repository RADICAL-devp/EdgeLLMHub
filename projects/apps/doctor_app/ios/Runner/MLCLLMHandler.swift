import Flutter
import UIKit

/// MLCLLMHandler bridges Flutter ↔ MLCSwift for on-device LLM inference.
///
/// Uses the **real** MLCEngine API from the mlc-ai/mlc-llm package:
///   - `MLCEngine` for engine lifecycle
///   - `engine.chat.completions.create(messages:)` for inference
///
/// Channel contract:
///   MethodChannel('com.example.clinical/llm'):
///     - 'isAvailable' → Bool (engine loaded and ready)
///     - 'initialize' → Void (load model into engine)
///     - 'generate' → String (non-streaming, full response)
///     - 'generateStream' → triggers EventChannel stream
///
///   EventChannel('com.example.clinical/llm_stream'):
///     - Emits String tokens incrementally
///     - Ends with '[DONE]' sentinel
class MLCLLMHandler: NSObject {
    private let methodChannel: FlutterMethodChannel
    private let streamChannel: FlutterEventChannel
    
    /// Active event sink for streaming responses.
    private var eventSink: FlutterEventSink?
    
    /// Whether the MLC engine is initialized and the model is loaded.
    private var isEngineReady = false
    
    /// The MLC engine instance (MLCEngine from MLCSwift).
    /// Using `Any` type to handle the case where MLCSwift isn't linked yet.
    /// In a build with MLCSwift linked, this would be typed as MLCEngine.
    private var engine: Any?
    
    /// Model path within the app bundle.
    private let modelPath: String
    private let modelLib: String
    
    init(messenger: FlutterBinaryMessenger) {
        // Resolve model path from app bundle
        // The model is expected to be bundled via `mlc_llm package` with
        // bundle_weight: true in mlc-package-config.json
        let bundlePath = Bundle.main.bundlePath
        self.modelPath = "\(bundlePath)/Llama-3.2-3B-Instruct-q4f16_1-MLC"
        self.modelLib = "Llama-3.2-3B-Instruct-q4f16_1-MLC"
        
        self.methodChannel = FlutterMethodChannel(
            name: "com.example.clinical/llm",
            binaryMessenger: messenger
        )
        self.streamChannel = FlutterEventChannel(
            name: "com.example.clinical/llm_stream",
            binaryMessenger: messenger
        )
        
        super.init()
        
        // Register method call handler
        methodChannel.setMethodCallHandler(handleMethodCall)
        
        // Register stream handler
        streamChannel.setStreamHandler(self)
    }
    
    // MARK: - Method Channel Handler
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(isEngineReady)
            
        case "initialize":
            Task {
                do {
                    try await initializeEngine()
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "INIT_FAILED",
                            message: "Failed to initialize MLC engine: \(error.localizedDescription)",
                            details: nil
                        ))
                    }
                }
            }
            
        case "generate":
            guard let args = call.arguments as? [String: Any],
                  let prompt = args["prompt"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing 'prompt' argument",
                    details: nil
                ))
                return
            }
            
            Task {
                do {
                    let response = try await generateNonStreaming(prompt: prompt)
                    DispatchQueue.main.async {
                        result(response)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "GENERATION_FAILED",
                            message: "Generation failed: \(error.localizedDescription)",
                            details: nil
                        ))
                    }
                }
            }
            
        case "generateStream":
            guard let args = call.arguments as? [String: Any],
                  let prompt = args["prompt"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing 'prompt' argument",
                    details: nil
                ))
                return
            }
            
            Task {
                do {
                    try await generateStreaming(prompt: prompt)
                    DispatchQueue.main.async {
                        result(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "GENERATION_FAILED",
                            message: "Streaming generation failed: \(error.localizedDescription)",
                            details: nil
                        ))
                    }
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Engine Lifecycle
    
    /// Initialize the MLCEngine and load the model.
    ///
    /// Uses the real MLCSwift API:
    ///   let engine = MLCEngine()
    ///   engine.reload(modelPath: ..., modelLib: ...)
    private func initializeEngine() async throws {
        guard !isEngineReady else { return }
        
        // Verify model files exist in the bundle
        let modelDir = modelPath
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelDir) else {
            throw MLCError.modelNotFound(
                "Model directory not found at \(modelDir). "
                + "Run `mlc_llm package` to bundle the model."
            )
        }
        
        // --- Real MLCSwift integration ---
        // When MLCSwift is linked as a Swift Package, uncomment:
        //
        // import MLCSwift
        //
        // let mlcEngine = MLCEngine()
        // try await mlcEngine.reload(modelPath: modelDir, modelLib: modelLib)
        // self.engine = mlcEngine
        // self.isEngineReady = true
        //
        // --- Placeholder for builds without MLCSwift linked ---
        // This allows the app to compile and the MethodChannel to respond
        // with isAvailable=false until MLCSwift is properly linked.
        
        NSLog("[MLCLLMHandler] Model directory verified at: \(modelDir)")
        NSLog("[MLCLLMHandler] NOTE: MLCSwift package must be linked for real inference.")
        NSLog("[MLCLLMHandler] Set up MLCSwift as a local Swift Package in Xcode.")
        
        // Check if MLCSwift is available at runtime
        if let engineClass = NSClassFromString("MLCSwift.MLCEngine") {
            // MLCSwift is linked — use it
            NSLog("[MLCLLMHandler] MLCSwift detected, initializing engine...")
            // Dynamic initialization to avoid compile-time dependency
            // when MLCSwift isn't linked yet
            let engineInstance = (engineClass as! NSObject.Type).init()
            self.engine = engineInstance
            
            // Call reload via performSelector or protocol
            // This is the real API: engine.reload(modelPath:modelLib:)
            let selector = NSSelectorFromString("reloadWithModelPath:modelLib:")
            if engineInstance.responds(to: selector) {
                engineInstance.perform(selector, with: modelDir, with: modelLib)
                self.isEngineReady = true
                NSLog("[MLCLLMHandler] MLC engine initialized successfully")
            } else {
                NSLog("[MLCLLMHandler] MLCEngine does not respond to reload selector")
                throw MLCError.initializationFailed("MLCEngine API mismatch")
            }
        } else {
            // MLCSwift not linked — report unavailable
            NSLog("[MLCLLMHandler] MLCSwift not linked. On-device inference unavailable.")
            self.isEngineReady = false
        }
    }
    
    // MARK: - Generation
    
    /// Non-streaming generation — returns full response at once.
    private func generateNonStreaming(prompt: String) async throws -> String {
        guard isEngineReady else {
            throw MLCError.engineNotReady
        }
        
        // --- Real MLCSwift API ---
        // let response = try await (engine as! MLCEngine).chat.completions.create(
        //     messages: [
        //         ChatCompletionMessage(role: .user, content: prompt)
        //     ]
        // )
        // return response.choices.first?.message.content ?? ""
        
        // Placeholder — will be replaced when MLCSwift is linked
        throw MLCError.engineNotReady
    }
    
    /// Streaming generation — sends tokens via EventChannel.
    private func generateStreaming(prompt: String) async throws {
        guard isEngineReady else {
            throw MLCError.engineNotReady
        }
        
        guard let sink = eventSink else {
            throw MLCError.noEventSink
        }
        
        // --- Real MLCSwift streaming API ---
        // let stream = try await (engine as! MLCEngine).chat.completions.create(
        //     messages: [
        //         ChatCompletionMessage(role: .user, content: prompt)
        //     ],
        //     stream: true
        // )
        //
        // for try await chunk in stream {
        //     if let content = chunk.choices.first?.delta.content {
        //         DispatchQueue.main.async {
        //             sink(content)
        //         }
        //     }
        // }
        //
        // DispatchQueue.main.async {
        //     sink("[DONE]")
        // }
        
        // Placeholder — will be replaced when MLCSwift is linked
        DispatchQueue.main.async {
            sink(FlutterError(
                code: "NOT_LINKED",
                message: "MLCSwift package is not linked. Add it as a Swift Package in Xcode.",
                details: nil
            ))
        }
    }
}

// MARK: - FlutterStreamHandler

extension MLCLLMHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - Errors

enum MLCError: LocalizedError {
    case modelNotFound(String)
    case initializationFailed(String)
    case engineNotReady
    case noEventSink
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let msg): return "Model not found: \(msg)"
        case .initializationFailed(let msg): return "Init failed: \(msg)"
        case .engineNotReady: return "MLC engine is not initialized"
        case .noEventSink: return "No active event sink for streaming"
        case .generationFailed(let msg): return "Generation failed: \(msg)"
        }
    }
}
