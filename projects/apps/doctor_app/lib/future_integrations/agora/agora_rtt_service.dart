import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/network/dio_error_handler.dart';

// PARKED INTEGRATION.
//
// Agora RTT is intentionally not wired into the app. It is kept here as a
// reference for a future remote/real-time feature, and it is not imported by
// any screen, service, or dependency-injection registration. The current app
// is local-only: no audio or transcript leaves the device.
//
// Before enabling this later:
//   1. Revisit the product's privacy/consent model with a clinician and counsel.
//   2. Replace the placeholder token generator with the official Agora token
//      service (the implementation below is NOT production-ready).
//   3. Add explicit consent, retention, and audit controls.

/// Configuration for Agora Real-Time Transcription (RTT) service.
class AgoraRttConfig {
  const AgoraRttConfig({
    required this.appId,
    required this.appCertificate,
    required this.baseUrl,
    this.customerId,
    this.customerSecret,
  });

  final String appId;
  final String appCertificate;
  final String baseUrl; // e.g., 'https://api.agora.io/v1/projects'
  final String? customerId;
  final String? customerSecret;

  /// Create from environment variables or dart-defines.
  static AgoraRttConfig? fromEnvironment() {
    const appId = String.fromEnvironment('AGORA_APP_ID');
    const appCertificate = String.fromEnvironment('AGORA_APP_CERTIFICATE');
    const baseUrl = String.fromEnvironment(
      'AGORA_BASE_URL',
      defaultValue: 'https://api.agora.io/v1/projects',
    );
    const customerId = String.fromEnvironment('AGORA_CUSTOMER_ID');
    const customerSecret = String.fromEnvironment('AGORA_CUSTOMER_SECRET');

    if (appId.isEmpty || appCertificate.isEmpty) {
      return null;
    }

    return AgoraRttConfig(
      appId: appId,
      appCertificate: appCertificate,
      baseUrl: baseUrl,
      customerId: customerId.isEmpty ? null : customerId,
      customerSecret: customerSecret.isEmpty ? null : customerSecret,
    );
  }
}

/// Represents an active Agora RTT transcription session.
class AgoraTranscriptionSession {
  AgoraTranscriptionSession({
    required this.channelName,
    required this.taskId,
    required this.doctorId,
    required this.languageCode,
    required this.startedAt,
  });

  final String channelName;
  final String taskId;
  final String doctorId;
  final String languageCode;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
    'channelName': channelName,
    'taskId': taskId,
    'doctorId': doctorId,
    'languageCode': languageCode,
    'startedAt': startedAt.toIso8601String(),
  };
}

/// A segment of transcribed text from Agora RTT.
class AgoraTranscriptSegment {
  AgoraTranscriptSegment({
    required this.text,
    required this.startTimeMs,
    required this.endTimeMs,
    this.speaker,
    this.confidence,
    this.isFinal = true,
  });

  final String text;
  final int startTimeMs;
  final int endTimeMs;
  final String? speaker;
  final double? confidence;
  final bool isFinal;

  factory AgoraTranscriptSegment.fromJson(Map<String, dynamic> json) {
    return AgoraTranscriptSegment(
      text: json['text'] as String? ?? '',
      startTimeMs: json['startTimeMs'] as int? ?? 0,
      endTimeMs: json['endTimeMs'] as int? ?? 0,
      speaker: json['speaker'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isFinal: json['isFinal'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'startTimeMs': startTimeMs,
    'endTimeMs': endTimeMs,
    if (speaker != null) 'speaker': speaker,
    if (confidence != null) 'confidence': confidence,
    'isFinal': isFinal,
  };
}

/// Service for managing Agora Real-Time Transcription (RTT) sessions.
///
/// This service communicates with Agora's REST API to start/stop transcription
/// agents for video call channels. Transcripts are received via webhook.
class AgoraRttService {
  AgoraRttService({required this.config, required Dio dio}) : _dio = dio;

  final AgoraRttConfig config;
  final Dio _dio;

  /// Placeholder. Use Agora's official token generator in a future integration.
  String _generateRtcToken({
    required String channelName,
    required int uid,
    required int expireTimestamp,
  }) {
    return '006${config.appId}$channelName$uid$expireTimestamp';
  }

  Future<AgoraTranscriptionSession> startTranscription({
    required String channelName,
    required String doctorId,
    String languageCode = 'en-US',
    int? uid,
  }) async {
    final expireTimestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).round();
    final rtcToken = _generateRtcToken(
      channelName: channelName,
      uid: uid ?? 0,
      expireTimestamp: expireTimestamp,
    );

    final url = '${config.baseUrl}/${config.appId}/rtsc/speech-to-text/start';
    final payload = {
      'channelName': channelName,
      'uid': uid?.toString() ?? '0',
      'token': rtcToken,
      'channelType': 'LIVE_TYPE',
      'subscribeAudioUids': ['*'],
      'recognizeConfig': {
        'language': languageCode,
        'interimResults': true,
        'punctuation': true,
      },
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
      );
      final data = response.data;
      if (data == null) {
        throw const NetworkException('Agora RTT start returned null response');
      }

      final taskId = data['taskId'] as String? ?? data['task_id'] as String?;
      if (taskId == null || taskId.isEmpty) {
        throw NetworkException('Agora RTT start did not return taskId: $data');
      }

      return AgoraTranscriptionSession(
        channelName: channelName,
        taskId: taskId,
        doctorId: doctorId,
        languageCode: languageCode,
        startedAt: DateTime.now().toUtc(),
      );
    } on DioException catch (e) {
      throw DioErrorHandler.handle(e, context: 'agoraRttStart');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Failed to start Agora RTT: $e', cause: e);
    }
  }

  Future<void> stopTranscription(String taskId) async {
    final url = '${config.baseUrl}/${config.appId}/rtsc/speech-to-text/stop';
    final payload = {'taskId': taskId};

    try {
      await _dio.post(url, data: payload);
    } on DioException catch (e) {
      throw DioErrorHandler.handle(e, context: 'agoraRttStop');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Failed to stop Agora RTT: $e', cause: e);
    }
  }

  Future<AgoraRttStatus> queryStatus(String taskId) async {
    final url = '${config.baseUrl}/${config.appId}/rtsc/speech-to-text/query';
    final payload = {'taskId': taskId};

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
      );
      final data = response.data;
      if (data == null) {
        throw const NetworkException('Agora RTT query returned null response');
      }
      return AgoraRttStatus.fromJson(data);
    } on DioException catch (e) {
      throw DioErrorHandler.handle(e, context: 'agoraRttQuery');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Failed to query Agora RTT status: $e', cause: e);
    }
  }
}

/// Status of an Agora RTT transcription session.
class AgoraRttStatus {
  AgoraRttStatus({
    required this.taskId,
    required this.status,
    this.channelName,
    this.startTime,
    this.endTime,
  });

  final String taskId;
  final String status; // 'RUNNING', 'STOPPED', 'FAILED'
  final String? channelName;
  final DateTime? startTime;
  final DateTime? endTime;

  factory AgoraRttStatus.fromJson(Map<String, dynamic> json) {
    return AgoraRttStatus(
      taskId: json['taskId'] as String? ?? json['task_id'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      channelName:
          json['channelName'] as String? ?? json['channel_name'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
    );
  }
}

/// Callback interface for receiving transcript segments from Agora webhook.
typedef AgoraTranscriptCallback = void Function(AgoraTranscriptSegment segment);

/// Webhook handler for receiving Agora RTT transcript segments.
class AgoraWebhookHandler {
  static List<AgoraTranscriptSegment> parseWebhookPayload(String payload) {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final events = data['events'] as List<dynamic>? ?? [];
    return events
        .map((e) => AgoraTranscriptSegment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
