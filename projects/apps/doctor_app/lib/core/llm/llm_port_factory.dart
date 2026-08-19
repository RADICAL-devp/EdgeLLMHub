import 'dart:io';

import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/llm/ios_native_llm_adapter.dart';
import 'package:doctor_app/core/llm/smol_llm_adapter.dart';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/llm/stub_llm_adapter.dart';

/// Factory that assembles the correct [LlmPort] implementation based on
/// device capabilities, platform, and compliance settings.
///
/// Always returns a [HybridLlmAdapter] wrapping:
///   - Platform-appropriate native adapter (iOS → MLC, Android → MLC)
///   - Stub adapter (offline fallback)
/// Cloud tier removed — PHI never leaves the device.
class LlmPortFactory {
  LlmPortFactory._();

  /// Create the hybrid LLM port for the current environment.
  ///
  /// [capabilityService] is used to detect simulator vs. physical device.
  static Future<HybridLlmAdapter> create(
    DeviceCapabilityService capabilityService,
  ) async {
    final isSimulator = await capabilityService.isSimulator;

    // --- Build adapters ---
    final stubAdapter = StubLlmAdapter();

    // Pick the platform-appropriate native adapter.
    // On simulators, native won't work but HybridLlmAdapter will skip it
    // and fall through to stub.
    final LlmPort nativeAdapter;
    if (Platform.isIOS) {
      nativeAdapter = IosNativeLlmAdapter();
    } else if (Platform.isAndroid) {
      nativeAdapter = SmolLLMAdapter();
    } else {
      // Desktop/web — native LLM not supported, stub will handle it
      nativeAdapter = stubAdapter;
    }

    return HybridLlmAdapter(
      nativeAdapter: nativeAdapter,
      stubAdapter: stubAdapter,
    );
  }
}
