import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/llm/flutter_gemma_llm_adapter.dart';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/llm/stub_llm_adapter.dart';

/// Factory that assembles the correct [LlmPort] implementation based on
/// device capabilities, platform, and compliance settings.
///
/// Always returns a [HybridLlmAdapter] wrapping:
///   - [FlutterGemmaLlmAdapter] (on-device Qwen3 via flutter_gemma,
///     cross-platform — no per-OS native adapter needed)
///   - Stub adapter (offline fallback)
/// Cloud tier removed — PHI never leaves the device.
class LlmPortFactory {
  LlmPortFactory._();

  /// Create the hybrid LLM port for the current environment.
  static Future<HybridLlmAdapter> create(
    DeviceCapabilityService capabilityService,
  ) async {
    // --- Build adapters ---
    final stubAdapter = StubLlmAdapter();

    // Single cross-platform native adapter. On simulators, desktop, or
    // unsupported ABIs it fails fast and HybridLlmAdapter falls through
    // to stub.
    final LlmPort nativeAdapter = FlutterGemmaLlmAdapter();

    return HybridLlmAdapter(
      nativeAdapter: nativeAdapter,
      stubAdapter: stubAdapter,
    );
  }
}
