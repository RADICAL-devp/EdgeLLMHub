import 'dart:io';

import 'package:dio/dio.dart';

import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/llm/ios_native_llm_adapter.dart';
import 'package:doctor_app/core/llm/android_native_llm_adapter.dart';
import 'package:doctor_app/core/llm/cloud_llm_adapter.dart';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/llm/stub_llm_adapter.dart';

/// Factory that assembles the correct [LlmPort] implementation based on
/// device capabilities, platform, and compliance settings.
///
/// Always returns a [HybridLlmAdapter] wrapping:
///   - Platform-appropriate native adapter (iOS → MLC, Android → Gemma)
///   - Cloud adapter (Dart Frog backend, compliance-gated)
///   - Stub adapter (offline fallback)
class LlmPortFactory {
  LlmPortFactory._();

  /// Create the hybrid LLM port for the current environment.
  ///
  /// [capabilityService] is used to detect simulator vs. physical device.
  /// [dio] is an optional pre-configured Dio instance (for testing/DI).
  static Future<HybridLlmAdapter> create(
    DeviceCapabilityService capabilityService, {
    Dio? dio,
  }) async {
    final isSimulator = await capabilityService.isSimulator;

    // --- Resolve backend URL ---
    String baseUrl = EnvironmentConfig.apiBaseUrl;
    if (Platform.isAndroid && isSimulator) {
      baseUrl = EnvironmentConfig.androidEmulatorApiUrl;
    }

    // --- Build Dio (use provided or create new) ---
    final dioInstance = dio ??
        Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ));

    // --- Build adapters ---
    final cloudAdapter = CloudLlmAdapter(dioInstance);
    final stubAdapter = StubLlmAdapter();

    // Pick the platform-appropriate native adapter.
    // On simulators, native won't work but HybridLlmAdapter will skip it
    // and fall through to cloud/stub.
    final LlmPort nativeAdapter;
    if (Platform.isIOS) {
      nativeAdapter = IosNativeLlmAdapter();
    } else if (Platform.isAndroid) {
      nativeAdapter = AndroidNativeLlmAdapter();
    } else {
      // Desktop/web — native LLM not supported, stub will handle it
      nativeAdapter = stubAdapter;
    }

    // --- Compliance gate ---
    // PHI must NOT leave the device unless explicitly approved.
    final cloudEnabled = EnvironmentConfig.cloudLlmEnabled;

    return HybridLlmAdapter(
      nativeAdapter: nativeAdapter,
      cloudAdapter: cloudAdapter,
      stubAdapter: stubAdapter,
      cloudEnabled: cloudEnabled,
    );
  }
}
