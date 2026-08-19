import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'speech_service.dart';
import 'local_speech_service.dart';
import 'ios_speech_service.dart';
import 'android_speech_service.dart';
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
  /// [locale] - BCP-47 locale code (e.g., 'en_US', 'en_GB', 'es_ES')
  /// [silenceTimeout] - VAD silence timeout for local STT
  /// [listenTimeout] - Maximum listening duration in seconds
  /// [operatingSystem] - override injected for tests; defaults to the real
  /// host OS (`Platform.operatingSystem`).
  static Future<SpeechService> create(
    DeviceCapabilityService deviceService, {
    Dio? dio,
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
    String? operatingSystem,
  }) async {
    final os = operatingSystem ?? Platform.operatingSystem;
    final canUseLocalStt = await deviceService.canUseSpeechToText();

    if (canUseLocalStt) {
      // Request microphone permission on physical devices
      if (os == 'ios' || os == 'android') {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          throw const SpeechException(
            'Microphone permission is required for speech recognition.',
          );
        }
      }

      developer.log(
        'Using ${_platformAdapter(os)} (physical device)',
        name: 'SpeechServiceFactory',
      );
      final local = _createPlatformAdapter(os);
      await local.initialize(
        locale: locale,
        silenceTimeout: silenceTimeout,
        listenTimeout: listenTimeout,
      );
      return local;
    }

    developer.log(
      'Using CloudSpeechService (simulator or local STT unavailable)',
      name: 'SpeechServiceFactory',
    );

    // Use provided Dio or create a minimal one
    final dioInstance = dio ?? Dio();
    final cloud = CloudSpeechService(dioInstance);
    await cloud.initialize(
      locale: locale,
      listenTimeout: listenTimeout,
    );
    return cloud;
  }

  /// Create with explicit fallback: try local first, fall back to cloud
  /// if local initialization fails.
  static Future<SpeechService> createWithFallback(
    DeviceCapabilityService deviceService, {
    Dio? dio,
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
    String? operatingSystem,
  }) async {
    final os = operatingSystem ?? Platform.operatingSystem;
    final canUseLocalStt = await deviceService.canUseSpeechToText();

    if (canUseLocalStt) {
      final local = _createPlatformAdapter(os);
      try {
        await local.initialize(
          locale: locale,
          silenceTimeout: silenceTimeout,
          listenTimeout: listenTimeout,
        );
        developer.log(
          '${_platformAdapter(os)} initialized successfully',
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
    final cloud = CloudSpeechService(dioInstance);
    await cloud.initialize(
      locale: locale,
      listenTimeout: listenTimeout,
    );
    return cloud;
  }

  /// Name of the platform adapter selected for the current OS.
  static String _platformAdapter(String os) {
    if (os == 'ios') return 'IosSpeechService';
    if (os == 'android') return 'AndroidSpeechService';
    return 'LocalSpeechService';
  }

  /// Create the platform-specific local STT adapter (thin wrappers around
  /// the `speech_to_text` plugin, which bridges Speech.framework on iOS and
  /// RecognizerIntent on Android).
  static LocalSpeechService _createPlatformAdapter(String os) {
    if (os == 'ios') return IosSpeechService();
    if (os == 'android') return AndroidSpeechService();
    return LocalSpeechService();
  }
}
