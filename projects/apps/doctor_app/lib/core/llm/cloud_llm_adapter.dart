import 'package:dio/dio.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';

/// Cloud LLM adapter — calls the Dart Frog clinical-intelligence backend.
///
/// All Dio failures are mapped to [NetworkException] with transience
/// information so the [HybridLlmAdapter] can decide whether to retry
/// or fall back.
class CloudLlmAdapter implements LlmPort {
  final Dio _dio;

  CloudLlmAdapter(this._dio);

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final cleanInput = ClinicalPrompts.sanitize(input);
    final response = await _post(
      '/api/v1/clinical-processing/process',
      data: {
        'inputText': cleanInput,
        'processingMode': mode.name,
      },
    );
    return response['processedText'] as String? ?? '';
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
      String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final response = await _post(
      '/api/v1/transcript-summary/structured',
      data: {'transcriptText': cleanText},
    );
    return _parseSummary(response);
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
      String transcriptText, String pastContext) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final cleanContext = ClinicalPrompts.sanitize(pastContext);
    final response = await _post(
      '/api/v1/transcript-summary/context-enriched',
      data: {
        'transcriptText': cleanText,
        'pastContext': cleanContext,
      },
    );
    return _parseSummary(response);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final response = await _post(
      '/api/v1/transcript-summary/executive',
      data: {'transcriptText': cleanText},
    );
    return response['summary'] as String? ?? '';
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final response = await _post(
      '/api/v1/transcript-summary/doctor-note',
      data: {'transcriptText': cleanText},
    );
    return response['note'] as String? ?? '';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// POST with structured error handling.
  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      if (response.data == null) {
        throw const LlmException(
          'Cloud LLM returned null response',
          provider: LlmProvider.cloud,
        );
      }
      return response.data!;
    } on DioException catch (e) {
      throw _mapDioException(e, path);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        'Cloud LLM request failed: $e',
        cause: e,
      );
    }
  }

  StructuredSummary _parseSummary(Map<String, dynamic> json) {
    try {
      // The backend may wrap the summary in a 'summary' key or return it flat
      if (json.containsKey('summary') && json['summary'] is Map) {
        return StructuredSummary.fromJson(
            json['summary'] as Map<String, dynamic>);
      }
      return StructuredSummary.fromJson(json);
    } catch (e) {
      throw LlmException(
        'Failed to parse cloud LLM structured summary: $e',
        cause: e,
        provider: LlmProvider.cloud,
      );
    }
  }

  /// Map [DioException] to typed [NetworkException].
  NetworkException _mapDioException(DioException e, String path) {
    final statusCode = e.response?.statusCode;

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NetworkException(
          'Cloud LLM request timed out on $path',
          cause: e,
          statusCode: statusCode,
          isTransient: true,
        ),
      DioExceptionType.connectionError => NetworkException(
          'Cannot reach cloud LLM backend',
          cause: e,
          isTransient: true,
        ),
      DioExceptionType.badResponse => NetworkException(
          'Cloud LLM returned ${statusCode ?? "unknown"} on $path: '
          '${e.response?.data}',
          cause: e,
          statusCode: statusCode,
          // 5xx are transient (server issues), 4xx are permanent (bad request)
          isTransient: statusCode != null && statusCode >= 500,
        ),
      DioExceptionType.cancel => NetworkException(
          'Cloud LLM request cancelled',
          cause: e,
          isTransient: false,
        ),
      _ => NetworkException(
          'Cloud LLM request failed: ${e.message}',
          cause: e,
          isTransient: true,
        ),
    };
  }
}
