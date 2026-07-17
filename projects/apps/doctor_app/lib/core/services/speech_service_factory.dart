import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'speech_service.dart';
import 'local_speech_service.dart';
import 'cloud_speech_service.dart';
import 'device_capability_service.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Factory that selects the appropriate [SpeechService] implementation
/// based on device capabilities.
///
/// - Physical devices → [LocalSpeechService] (native STT)
/// - Simulators → [CloudSpeechService] (HTTP STT / mock)
/// - Fallback: If local initialization fails, falls back to cloud
class SpeechServiceFactory {
  SpeechServiceFactory._();

  /// Create the appropriate speech service for the current device.
  ///
  /// [deviceService] is used to detect simulator vs. physical device.
  /// [dio] is passed to [CloudSpeechService] for HTTP-based STT.
  static Future<SpeechService> create(
    DeviceCapabilityService deviceService, {
    Dio? dio,
  }) async {
    final canUseLocalStt = await deviceService.canUseSpeechToText();

    if (canUseLocalStt) {
      developer.log(
        'Using LocalSpeechService (physical device)',
        name: 'SpeechServiceFactory',
      );
      return LocalSpeechService();
    }

    developer.log(
      'Using CloudSpeechService (simulator or local STT unavailable)',
      name: 'SpeechServiceFactory',
    );

    // Use provided Dio or create a minimal one
    final dioInstance = dio ?? Dio();
    return CloudSpeechService(dioInstance);
  }

  /// Create with explicit fallback: try local first, fall back to cloud
  /// if local initialization fails.
  static Future<SpeechService> createWithFallback(
    DeviceCapabilityService deviceService, {
    Dio? dio,
  }) async {
    final canUseLocalStt = await deviceService.canUseSpeechToText();

    if (canUseLocalStt) {
      final local = LocalSpeechService();
      try {
        await local.initialize();
        developer.log(
          'LocalSpeechService initialized successfully',
          name: 'SpeechServiceFactory',
        );
        return local;
      } on SpeechException catch (e) {
        developer.log(
          'LocalSpeechService failed to initialize: $e. '
          'Falling back to CloudSpeechService.',
          name: 'SpeechServiceFactory',
        );
      }
    }

    final dioInstance = dio ?? Dio();
    return CloudSpeechService(dioInstance);
  }
}
