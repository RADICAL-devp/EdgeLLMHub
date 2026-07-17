# Doctor Note App - Comprehensive Codebase Audit Report
# Part 2: Alternative Implementation Proposals

**Date:** 2026-07-12  
**Focus:** Architectural Improvements, Unified LLM Strategy, Simulator Fallback

---

## ALTERNATIVE IMPLEMENTATION PROPOSALS

---

## Proposal 1: Unified LLM Architecture with MediaPipe GenAI

### Current Problem
- Android: `flutter_gemma` (Google AI Edge LiteRT-LM, TFLite format, Gemma models)
- iOS: MethodChannel → MLC LLM (Metal GPU, MLC format, Llama models)
- **Result:** Completely different APIs, model formats, initialization flows

### Solution: MediaPipe GenAI

**Why MediaPipe GenAI?**
- Cross-platform C++ library (iOS, Android, Desktop)
- Multiple backends: CPU, GPU (Metal on iOS, Vulkan/OpenCL on Android)
- Multiple model formats: GGML, GGUF, SafariTensors
- Unified API across all platforms
- Actively maintained by Google
- Production-ready

### Architecture Comparison

```
CURRENT (FRACTURED)
┌─────────────────────────────┐
│   LlmPort                    │
│   └── NativeLlmAdapter        │
│       ├── if Android:        │
│       │   └── FlutterGemma   │
│       │       └── LiteRT-LM  │
│       │           └── Gemma  │
│       └── if iOS:            │
│           └── MethodChannel   │
│               └── MLC LLM     │
│                   └── Llama   │
└─────────────────────────────┘

PROPOSED (UNIFIED)
┌─────────────────────────────┐
│   LlmPort                    │
│   └── MediaPipeLlmAdapter    │
│       └── MediaPipe GenAI    │
│           ├── CPU Backend     │
│           ├── Metal Backend   │
│           └── Vulkan Backend  │
└─────────────────────────────┘
```

### Implementation Steps

#### Step 1: Add Dependencies

**iOS (Podfile):**
```ruby
pod 'MediaPipeGenAIGPU', '~> 0.10.0'
pod 'MediaPipeGenAICPU Metal', '~> 0.10.0'
```

**Android (build.gradle):**
```gradle
implementation 'com.google.mediapipe:genai:0.10.0'
```

**Flutter (pubspec.yaml):**
```yaml
# For FFI
ffi: ^2.0.0
# For C++ interop
path_provider: ^2.1.5
```

#### Step 2: Create C++ Bridge

**`ios/Runner/mediapipe_bridge.cc`**
```cpp
#include "media/pipe/genai/model.h"
#include "media/pipe/genai/inference.h"

class MediaPipeBridge {
 public:
  MediaPipeBridge(const std::string& model_path);
  std::string Generate(const std::string& prompt, float temperature, int max_tokens);
  
 private:
  std::unique_ptr<media::Pipe::GenAI::Model> model_;
  std::unique_ptr<media::Pipe::GenAI::Inference> inference_;
};

extern "C" {
void* MediaPipeBridge_Create(const char* model_path) {
  return new MediaPipeBridge(model_path);
}

char* MediaPipeBridge_Generate(
  void* bridge, const char* prompt, float temperature, int max_tokens
) {
  auto* bp = static_cast<MediaPipeBridge*>(bridge);
  std::string result = bp->Generate(prompt, temperature, max_tokens);
  char* output = new char[result.size() + 1];
  strcpy(output, result.c_str());
  return output;
}

void MediaPipeBridge_Delete(void* bridge) {
  delete static_cast<MediaPipeBridge*>(bridge);
}
}
```

#### Step 3: Create Dart FFI Bindings

**`lib/core/llm/ffi/mediapipe_bindings.dart`**
```dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class MediaPipeFFI {
  static DynamicLibrary? _lib;
  
  static void init() {
    if (Platform.isIOS) {
      _lib = DynamicLibrary.open('mediapipe_bridge.framework/mediapipe_bridge');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libmediapipe_bridge.so');
    }
  }
  
  static Pointer<Void> createBridge(String modelPath) {
    final func = _lib!.lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>),
      Pointer<Void> Function(Pointer<Utf8>)
    >('MediaPipeBridge_Create');
    return func(modelPath.toNativeUtf8());
  }
  
  static String generate(
    Pointer<Void> bridge,
    String prompt,
    double temperature,
    int maxTokens,
  ) {
    final func = _lib!.lookupFunction<
      Pointer<Utf8> Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Float,
        Int32,
      ),
      Pointer<Utf8> Function(
        Pointer<Void>,
        Pointer<Utf8>,
        double,
        int,
      )
    >('MediaPipeBridge_Generate');
    
    final resultPtr = func(
      bridge,
      prompt.toNativeUtf8(),
      temperature,
      maxTokens,
    );
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);
    return result;
  }
  
  static void deleteBridge(Pointer<Void> bridge) {
    final func = _lib!.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('MediaPipeBridge_Delete');
    func(bridge);
  }
}
```

#### Step 4: Create MediaPipeLlmAdapter

**`lib/core/llm/media_pipe_llm_adapter.dart`**
```dart
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';
import 'ffi/mediapipe_bindings.dart';

class MediaPipeLlmAdapter implements LlmPort {
  Pointer<Void>? _bridge;
  bool _isInitialized = false;
  
  final String modelPath;
  final double temperature;
  final int maxTokens;
  
  MediaPipeLlmAdapter({
    required this.modelPath,
    this.temperature = 0.1,
    this.maxTokens = 2048,
  });
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    MediaPipeFFI.init();
    _bridge = MediaPipeFFI.createBridge(modelPath);
    _isInitialized = true;
  }
  
  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    await initialize();
    final prompt = _buildPrompt(input, mode);
    return MediaPipeFFI.generate(_bridge!, prompt, temperature, maxTokens);
  }
  
  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) async {
    await initialize();
    final prompt = '${ClinicalPrompts.structuredSummary}\n$transcriptText';
    final response = MediaPipeFFI.generate(_bridge!, prompt, temperature, maxTokens);
    return _parseStructuredSummary(response);
  }
  
  // ... other LlmPort methods
  
  String _buildPrompt(String input, ProcessingMode mode) {
    return switch (mode) {
      ProcessingMode.vocabAssist => '${ClinicalPrompts.vocabAssist}\n$input',
      ProcessingMode.cleanTranscript => '${ClinicalPrompts.cleanTranscript}\n$input',
      ProcessingMode.summarize => '${ClinicalPrompts.structuredSummary}\n$input',
      ProcessingMode.generateDoctorNote => '${ClinicalPrompts.doctorNote}\n$input',
      _ => input,
    };
  }
  
  StructuredSummary _parseStructuredSummary(String response) {
    // Same parsing logic as NativeLlmAdapter
    // ...
  }
  
  @override
  void close() {
    if (_bridge != null) {
      MediaPipeFFI.deleteBridge(_bridge!);
      _bridge = null;
    }
    _isInitialized = false;
  }
}
```

### Benefits

| Aspect | Current | With MediaPipe |
|--------|---------|---------------|
| Code Paths | 2 (Android/iOS) | 1 (Unified) |
| Model Format | Platform-specific | GGML/GGUF (Cross-platform) |
| Initialization | Platform-specific | Unified API |
| Maintenance | High | Low |
| GPU Support | Platform-specific | Auto-detected |
| Bundle Size | Varies | ~5-10MB |

### Challenges

1. **Learning Curve**: MediaPipe GenAI has steeper learning curve than flutter_gemma
2. **Model Conversion**: Need GGML/GGUF versions of models
3. **Build Complexity**: Requires C++ build setup for both platforms
4. **Testing**: Need to verify on multiple device configurations

### Model Recommendations

| Model | Size (GGUF) | RAM Required | Quality | Recommended |
|-------|-------------|--------------|---------|-------------|
| Llama-3.2-1B | ~500MB | 2GB | Good | ✅ Development |
| Llama-3.2-3B | ~1.8GB | 4GB | Very Good | ✅ iPhone 14+ |
| Mistral-7B | ~3.8GB | 6GB | Excellent | ✅ High-end devices |
| Gemma-2B | ~1.5GB | 3GB | Very Good | ✅ Android |

---

## Proposal 2: Environment-Aware Service Architecture

### Current Problem
```
iOS Simulator:
  Speech-to-Text: ❌ (SFSpeechRecognizer not supported)
  Local LLM: ❌ (MLC LLM needs Metal GPU)
  Result: App is unusable

Physical iOS:
  Speech-to-Text: ✅
  Local LLM: ✅ (if A15+ with sufficient RAM)
  Result: Works but iOS code is fractured

Physical Android:
  Speech-to-Text: ✅
  Local LLM: ✅ (if Snapdragon 8 Gen 1+ with 8GB+ RAM)
  Result: Works but Android code is fractured
```

### Solution: Automatic Environment Detection & Routing

```
┌─────────────────────────────────────────────────┐
│         Environment Detection Layer               │
├─────────────────────────────────────────────────┤
│  DeviceCapabilityService                          │
│  ├── isSimulator()                                │
│  ├── canRunLocalLlm()                             │
│  ├── canUseSpeechToText()                         │
│  └── getRecommendedExecutionMode() → Local/Cloud  │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│         Service Factory Layer                      │
├─────────────────────────────────────────────────┤
│  LlmPortFactory.create(mode:)                     │
│     ├── ExecutionMode.local → NativeLlmAdapter   │
│     ├── ExecutionMode.cloud → CloudLlmAdapter     │
│     └── ExecutionMode.stub → StubLlmAdapter       │
│                                                         │
│  SpeechServiceFactory.create(useLocal:)           │
│     ├── true → LocalSpeechService (speech_to_text)│
│     └── false → CloudSpeechService (HTTP STT)    │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│         Usage in App                               │
├─────────────────────────────────────────────────┤
│  iOS Simulator:                                   │
│    LLM: CloudLlmAdapter → Dart Frog backend       │
│    Speech: CloudSpeechService → Cloud STT API     │
│                                                         │
│  Physical iOS (A15+, 6GB+ RAM):                    │
│    LLM: NativeLlmAdapter → MLC LLM                │
│    Speech: LocalSpeechService → SFSpeechRecognizer│
│                                                         │
│  Physical Android (8GB+ RAM):                     │
│    LLM: NativeLlmAdapter → flutter_gemma          │
│    Speech: LocalSpeechService → Google STT       │
└─────────────────────────────────────────────────┘
```

### Implementation

#### Step 1: Enhanced DeviceCapabilityService

**`lib/core/services/device_capability_service.dart`**
```dart
import 'dart:io';

enum ExecutionMode { local, cloud, stub }

class DeviceCapabilityService {
  late final bool _isSimulator;
  late final bool _isPhysicalDevice;
  late final int _totalRamGB;
  late final String? _chipset;
  
  DeviceCapabilityService() {
    _detectEnvironment();
  }
  
  void _detectEnvironment() {
    if (Platform.isIOS) {
      _isSimulator = _detectIosSimulator();
      _isPhysicalDevice = !_isSimulator;
      _totalRamGB = 6; // iPhones typically have 4-8GB
    } else if (Platform.isAndroid) {
      _isSimulator = _detectAndroidEmulator();
      _isPhysicalDevice = !_isSimulator;
      _totalRamGB = 8; // Android flagships typically have 8-16GB
    } else {
      _isSimulator = false;
      _isPhysicalDevice = false;
      _totalRamGB = 0;
    }
    _chipset = _detectChipset();
  }
  
  bool _detectIosSimulator() {
    return Platform.environment['SIMULATOR_ROOT'] != null ||
           Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
  }
  
  bool _detectAndroidEmulator() {
    final hardware = Platform.environment['ANDROID_HARDWARE']?.toLowerCase() ?? '';
    return hardware.contains('emulator') || 
           hardware.contains('goldfish') || 
           hardware.contains('ranchu');
  }
  
  String? _detectChipset() {
    if (Platform.isIOS) {
      // Would need native channel to get iOS device model
      return null;
    }
    if (Platform.isAndroid) {
      // Would use device_info_plus
      return null;
    }
    return null;
  }
  
  // Public API
  bool get isSimulator => _isSimulator;
  bool get isPhysicalDevice => _isPhysicalDevice;
  int get totalRamGB => _totalRamGB;
  String? get chipset => _chipset;
  
  bool canRunLocalLlm() {
    if (_isSimulator) return false;
    if (Platform.isIOS) return _totalRamGB >= 6;
    if (Platform.isAndroid) return _totalRamGB >= 8;
    return false;
  }
  
  bool canUseSpeechToText() {
    if (Platform.isIOS) return !_isSimulator;
    return true; // Works on Android emulator too
  }
  
  ExecutionMode getRecommendedExecutionMode() {
    if (_isSimulator) return ExecutionMode.cloud;
    if (canRunLocalLlm()) return ExecutionMode.local;
    return ExecutionMode.cloud;
  }
  
  String getUnsupportedMessage() {
    if (_isSimulator) {
      return 'Running on simulator. Using cloud AI services.';
    }
    if (Platform.isIOS && _totalRamGB < 6) {
      return 'iPhone requires 6GB+ RAM for local AI.';
    }
    if (Platform.isAndroid && _totalRamGB < 8) {
      return 'Android device requires 8GB+ RAM for local AI.';
    }
    return 'Device does not meet minimum requirements.';
  }
}
```

#### Step 2: LlmPortFactory

**`lib/core/factories/llm_port_factory.dart`**
```dart
import '../ports/llm_port.dart';
import '../llm/native_llm_adapter.dart';
import '../llm/cloud_llm_adapter.dart';
import '../llm/stub_llm_adapter.dart';

enum LlmImplementation { native, cloud, stub, hybrid }

class LlmPortFactory {
  static LlmPort create({
    LlmImplementation implementation = LlmImplementation.hybrid,
    String? modelPath,
    String? cloudBaseUrl,
  }) {
    switch (implementation) {
      case LlmImplementation.native:
        return NativeLlmAdapter();
      case LlmImplementation.cloud:
        return CloudLlmAdapter(baseUrl: cloudBaseUrl);
      case LlmImplementation.stub:
        return StubLlmAdapter();
      case LlmImplementation.hybrid:
        return HybridLlmAdapter(
          localLlm: NativeLlmAdapter(),
          cloudLlm: CloudLlmAdapter(baseUrl: cloudBaseUrl),
          stubLlm: StubLlmAdapter(),
        );
    }
  }
}
```

#### Step 3: HybridLlmAdapter

**`lib/core/llm/hybrid_llm_adapter.dart`**
```dart
import 'package:doctor_app/core/ports/llm_port.dart';

class HybridLlmAdapter implements LlmPort {
  final LlmPort _localLlm;
  final LlmPort _cloudLlm;
  final LlmPort _stubLlm;
  
  bool _localFailed = false;
  bool _cloudFailed = false;
  
  HybridLlmAdapter({
    required LlmPort localLlm,
    required LlmPort cloudLlm,
    required LlmPort stubLlm,
  })  : _localLlm = localLlm,
        _cloudLlm = cloudLlm,
        _stubLlm = stubLlm;
  
  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    try {
      if (!_localFailed) {
        try {
          final result = await _localLlm.processText(input, mode);
          _cloudFailed = false; // Reset cloud failure
          return result;
        } catch (e) {
          _localFailed = true;
          debugPrint('Local LLM failed, falling back to cloud: $e');
        }
      }
      
      if (!_cloudFailed) {
        try {
          final result = await _cloudLlm.processText(input, mode);
          return result;
        } catch (e) {
          _cloudFailed = true;
          debugPrint('Cloud LLM failed, falling back to stub: $e');
        }
      }
      
      // Both failed, use stub with clear indicator
      final stubResult = await _stubLlm.processText(input, mode);
      return '[OFFLINE MODE] $stubResult';
    }
  }
  
  // Reset failure state (useful after reconnection)
  void resetFailures() {
    _localFailed = false;
    _cloudFailed = false;
  }
  
  // ... implement other LlmPort methods with same pattern
}
```

#### Step 4: CloudLlmAdapter

**`lib/core/llm/cloud_llm_adapter.dart`**
```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import '../models/processing_mode.dart';
import '../models/structured_summary.dart';
import '../llm/prompts/clinical_prompts.dart';

class CloudLlmAdapter implements LlmPort {
  final Dio _dio;
  final String _baseUrl;
  
  CloudLlmAdapter({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;
  
  static String get _defaultBaseUrl {
    if (kDebugMode) {
      return 'http://localhost:8080';
    }
    return 'https://api.your-clinical-backend.com';
  }
  
  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = _buildPrompt(input, mode);
    
    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/clinical-processing/process',
        data: {
          'inputText': prompt,
          'processingMode': mode.toJson(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Cloud API error: ${response.statusCode}');
      }
      
      return response.data['processedText'] as String? ?? '';
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Cloud API endpoint not found');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Cloud API timeout');
      }
      throw Exception('Cloud API error: ${e.message}');
    }
  }
  
  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/transcript-summary/generate',
        data: {
          'transcriptText': transcriptText,
          'consultationId': 'cloud-${DateTime.now().millisecondsSinceEpoch}',
          'patientId': 'cloud-patient',
          'doctorId': 'cloud-doctor',
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Cloud API error: ${response.statusCode}');
      }
      
      final data = response.data as Map<String, dynamic>;
      return StructuredSummary.fromJson(
        data['structuredMedicalSummary'] as Map<String, dynamic>? ?? {}
      );
    } catch (e) {
      // Fallback with error indicator
      debugPrint('Cloud structured summary failed: $e');
      return StructuredSummary(
        complaint: '[Cloud API unavailable] See transcript',
        pastHistory: '[Cloud API unavailable]',
        vitals: '[Cloud API unavailable]',
        physicalExamination: '[Cloud API unavailable]',
        investigationOrdered: '[Cloud API unavailable]',
        diagnosis: '[Cloud API unavailable]',
        advice: 'Cloud AI processing unavailable. Input length: ${transcriptText.length} chars.',
      );
    }
  }
  
  String _buildPrompt(String input, ProcessingMode mode) {
    return switch (mode) {
      ProcessingMode.vocabAssist => '${ClinicalPrompts.vocabAssist}\n$input',
      ProcessingMode.cleanTranscript => '${ClinicalPrompts.cleanTranscript}\n$input',
      ProcessingMode.summarize => '${ClinicalPrompts.structuredSummary}\n$input',
      ProcessingMode.generateDoctorNote => '${ClinicalPrompts.doctorNote}\n$input',
      _ => input,
    };
  }
}
```

#### Step 5: Update Service Registration

**In `lib/main.dart`:**
```dart
Future<void> setupDependencies() async {
  final getIt = GetIt.instance;
  
  // Initialize capability service FIRST
  final capabilityService = DeviceCapabilityService();
  getIt.registerSingleton<DeviceCapabilityService>(capabilityService);
  
  // Determine execution mode
  final executionMode = capabilityService.getRecommendedExecutionMode();
  
  // Register appropriate LLM port based on environment
  final llmPort = LlmPortFactory.create(
    implementation: LlmImplementation.hybrid,
    cloudBaseUrl: capabilityService.isSimulator 
        ? 'http://localhost:8080' 
        : 'https://api.your-clinical-backend.com',
  );
  getIt.registerSingleton<LlmPort>(llmPort);
  
  // Initialize speech service
  final canUseLocalSpeech = capabilityService.canUseSpeechToText();
  final speechService = canUseLocalSpeech 
      ? LocalSpeechService() 
      : CloudSpeechService();
  
  await speechService.initialize();
  getIt.registerSingleton<SpeechService>(speechService);
  
  // ... rest of registration
}
```

### Benefits

1. **Seamless Simulator Testing**
   - Automatically uses cloud APIs on simulator
   - Developers can test all features without physical device

2. **Progressive Enhancement**
   - Uses local when available, falls back gracefully
   - User gets best possible experience for their device

3. **Transparent to User**
   - App works regardless of device capabilities
   - Clear indicators when using cloud vs local

4. **Configurable**
   - Can override execution mode for testing
   - Easy to add new execution modes

5. **Future-Proof**
   - Easy to add new LLM backends
   - Simple to extend to new platforms (web, desktop)

---

## Proposal 3: Improved Error Handling Strategy

### Current Issues

1. **Dio Exceptions**: Generic catch blocks, no retry logic
2. **Native LLM Errors**: Unclear error messages, no fallback
3. **Speech Errors**: Silent failures on simulator
4. **Database Errors**: No error recovery

### Solution: Structured Error Handling

#### Step 1: Define Error Types

**`lib/core/errors/app_exceptions.dart`**
```dart
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  
  const AppException(this.message, {this.code, this.details});
  
  @override
  String toString() => '[${code ?? 'ERROR'}] $message';
}

class NetworkException extends AppException {
  final int? statusCode;
  final bool isTimeout;
  final bool isOffline;
  
  const NetworkException(
    String message, {
    String? code,
    this.statusCode,
    this.isTimeout = false,
    this.isOffline = false,
    dynamic details,
  }) : super(message, code: code ?? 'NETWORK_ERROR', details: details);
}

class LlmException extends AppException {
  final LlmProvider provider;
  final bool isFatal;
  
  const LlmException(
    String message, {
    String? code,
    this.provider = LlmProvider.unknown,
    this.isFatal = false,
    dynamic details,
  }) : super(message, code: code ?? 'LLM_ERROR', details: details);
}

class SpeechException extends AppException {
  final bool isPermissionDenied;
  final bool isUnavailable;
  
  const SpeechException(
    String message, {
    String? code,
    this.isPermissionDenied = false,
    this.isUnavailable = false,
    dynamic details,
  }) : super(message, code: code ?? 'SPEECH_ERROR', details: details);
}

class DatabaseException extends AppException {
  const DatabaseException(
    String message, {
    String? code,
    dynamic details,
  }) : super(message, code: code ?? 'DB_ERROR', details: details);
}

enum LlmProvider { local, cloud, stub, gemma, mlc, mediapipe, unknown }
```

#### Step 2: Enhanced Dio Error Handling

**`lib/core/network/dio_error_handler.dart`**
```dart
import 'package:dio/dio.dart';
import '../errors/app_exceptions.dart';

class DioErrorHandler {
  static Never? handleDioError(DioException e, {String? context}) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException(
        'Request timed out. Please check your connection.',
        code: 'TIMEOUT',
        isTimeout: true,
        isOffline: false,
        details: {'url': e.requestOptions.uri, 'context': context},
      );
    }
    
    if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        'Cannot connect to server. Please check your internet connection.',
        code: 'CONNECTION_FAILED',
        isTimeout: false,
        isOffline: true,
        details: {'url': e.requestOptions.uri, 'context': context},
      );
    }
    
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      if (statusCode == 404) {
        throw NetworkException(
          'API endpoint not found',
          code: 'NOT_FOUND',
          statusCode: statusCode,
          details: {'url': e.requestOptions.uri},
        );
      }
      
      if (statusCode == 500) {
        throw NetworkException(
          'Server error. Please try again later.',
          code: 'SERVER_ERROR',
          statusCode: statusCode,
          details: data,
        );
      }
      
      if (statusCode == 401) {
        throw NetworkException(
          'Authentication failed. Please log in again.',
          code: 'UNAUTHORIZED',
          statusCode: statusCode,
        );
      }
      
      // For other 4xx errors, include the message from server
      if (statusCode! >= 400 && statusCode < 500) {
        final errorMessage = data is Map && data.containsKey('error')
            ? data['error'].toString()
            : 'Request failed';
        throw NetworkException(
          errorMessage,
          code: 'CLIENT_ERROR',
          statusCode: statusCode,
          details: data,
        );
      }
    }
    
    // Generic error
    throw NetworkException(
      'An unexpected error occurred: ${e.message}',
      details: {'url': e.requestOptions.uri, 'context': context},
    );
  }
  
  static Dio createDioWithErrorHandler({String? baseUrl}) {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        handleDioError(error);
        return handler.next(error);
      },
    ));
    
    return dio;
  }
}
```

#### Step 3: Retry Mechanism

**`lib/core/network/retry_interceptor.dart`**
```dart
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;
  final List<int> retryableStatusCodes;
  
  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryableStatusCodes = const [500, 502, 503, 504],
  });
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldRetry(err)) {
      final retries = err.requestOptions.extra['retries'] as int? ?? 0;
      
      if (retries < maxRetries) {
        // Wait before retrying
        await Future.delayed(retryDelay * (retries + 1));
        
        // Create new request options with incremented retry count
        final newOptions = err.requestOptions.copyWith(
          extra: {...err.requestOptions.extra, 'retries': retries + 1},
        );
        
        // Retry the request
        final response = await Dio().fetch(newOptions);
        return handler.resolve(response);
      }
    }
    
    // Don't retry, pass error to next interceptor/handler
    return handler.next(err);
  }
  
  bool _shouldRetry(DioException err) {
    // Retry on connection errors
    if (err.type == DioExceptionType.connectionError) {
      return true;
    }
    
    // Retry on specific status codes
    if (err.response?.statusCode != null) {
      return retryableStatusCodes.contains(err.response!.statusCode);
    }
    
    return false;
  }
}
```

#### Step 4: Circuit Breaker Pattern

**`lib/core/network/circuit_breaker.dart`**
```dart
import 'package:dio/dio.dart';

class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;
  
  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
  });
  
  bool get isOpen => _isOpen;
  
  bool canExecute() {
    // Check if circuit is open
    if (_isOpen) {
      // Check if reset timeout has passed
      if (_lastFailureTime != null) {
        final timeSinceFailure = DateTime.now().difference(_lastFailureTime!);
        if (timeSinceFailure >= resetTimeout) {
          _isOpen = false;
          _failureCount = 0;
          return true;
        }
      }
      return false;
    }
    return true;
  }
  
  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
  }
  
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
    }
  }
  
  Future<T> execute<T>(Future<T> Function() action) async {
    if (!canExecute()) {
      throw CircuitBreakerOpenException(
        'Service temporarily unavailable. Please try again in ${resetTimeout.inMinutes} minutes.',
      );
    }
    
    try {
      final result = await action();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      rethrow;
    }
  }
}

class CircuitBreakerOpenException implements Exception {
  final String message;
  const CircuitBreakerOpenException(this.message);
  @override
  String toString() => message;
}
```

---

## Proposal 4: Database Improvements

### Current Issues

1. No migration strategy
2. Not properly closed
3. Duplicate mapping logic in repositories

### Solution

#### Step 1: Add Database Migrations

**`lib/features/note_assist/data/local/local_database.dart`**
```dart
@DriftDatabase(
  tables: [DoctorNotes, Transcripts, TranscriptSummaries],
  daos: [],  // Consider adding DAOs
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 2;  // Incremented from 1
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // Create all tables
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1) {
        // Migration from version 1 to 2
        // Add new columns, tables, etc.
        await m.addColumn(doctorNotes, doctorNotes.extractedFieldsJson);
      }
    },
  );
}
```

#### Step 2: Proper Database Cleanup

**Create a DatabaseService:**
```dart
// lib/core/services/database_service.dart
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';

class DatabaseService {
  final LocalDatabase db;
  
  DatabaseService(this.db);
  
  Future<void> close() async {
    await db.close();
  }
  
  static DatabaseService? _instance;
  
  static DatabaseService get instance {
    assert(_instance != null, 'DatabaseService not initialized');
    return _instance!;
  }
  
  static Future<DatabaseService> initialize() async {
    final db = LocalDatabase();
    _instance = DatabaseService(db);
    return _instance!;
  }
}
```

**Update main.dart:**
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database first
  final dbService = await DatabaseService.initialize();
  
  await setupDependencies();
  
  runApp(const DoctorApp());
  
  // Close database on app exit
  FlutterError.onError = (details) {
    // Log error
    dbService.close();
  };
}
```

#### Step 3: Add Transactions

**`lib/features/note_assist/data/repositories/note_sync_repository.dart`**
```dart
import 'package:drift/drift.dart';

class NoteSyncRepository {
  final NoteLocalRepository _local;
  final NoteRemoteDatasource _remote;
  
  NoteSyncRepository(this._local, this._remote);
  
  Future<void> syncNoteToBackend(String consultationId) async {
    await _local.db.transaction(() async {
      // Get note within transaction
      final note = await _local.getNoteByConsultationId(consultationId);
      if (note == null) return;
      
      // Update sync status
      final updatedNote = note.copyWith(status: NoteStatus.syncing);
      await _local.saveNote(updatedNote);
      
      // Sync to remote
      await _remote.syncNote(note);
      
      // Update to synced
      final syncedNote = note.copyWith(status: NoteStatus.finalized);
      await _local.saveNote(syncedNote);
    });
  }
}
```

---

## Summary of Recommendations

| Priority | Task | Complexity | Impact |
|----------|------|------------|--------|
| 1 | Fix iOS MethodChannel | Medium | Critical |
| 2 | Add MLC LLM iOS integration | High | Critical |
| 3 | Implement environment detection | Medium | High |
| 4 | Create LlmPortFactory | Low | High |
| 5 | Create HybridLlmAdapter | Medium | High |
| 6 | Create CloudLlmAdapter | Medium | High |
| 7 | Improve Dio error handling | Low | Medium |
| 8 | Add retry mechanism | Medium | Medium |
| 9 | Add circuit breaker | Medium | Medium |
| 10 | Add database migrations | Low | Medium |
| 11 | Evaluate MediaPipe GenAI | High | Long-term |

**Recommended Path:**
1. **Week 1-2**: Fix critical iOS issues (#1, #2) + environment detection (#3)
2. **Week 3-4**: Implement factory pattern (#4, #5, #6) + cloud adapter
3. **Week 5-6**: Add error handling improvements (#7, #8, #9) + database fixes (#10)
4. **Month 3+**: Evaluate MediaPipe GenAI (#11) for long-term unification

---

## Next

**See Part 3** for the complete iOS Native MLC LLM Implementation Guide with step-by-step Swift and C++ code.
