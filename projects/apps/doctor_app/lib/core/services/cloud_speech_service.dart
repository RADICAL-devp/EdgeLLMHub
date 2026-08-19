import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'speech_service.dart';

/// Cloud-based speech-to-text service for environments where native
/// STT is not available (e.g., iOS Simulator).
///
/// Sends audio or uses a text-based STT endpoint on the backend.
/// For simulator use, this provides a mock-like experience with
/// pre-recorded sample text until a real cloud STT endpoint is available.
class CloudSpeechService implements SpeechService {
  final Dio _dio;
  bool _isListening = false;
  Timer? _timer;

  CloudSpeechService(this._dio);

  @override
  Future<bool> initialize({
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
  }) async {
    // Verify the backend is reachable.
    // The mock STT below works fully offline, so a failing health check
    // must NOT fail app startup — degrade gracefully instead.
    try {
      // A simple health check — in production, this would ping a
      // speech-specific endpoint
      await _dio.get('/');
      return true;
    } on DioException catch (e) {
      developer.log(
        'Cloud STT backend unreachable: ${e.message} — '
        'continuing with offline mock STT.',
        name: 'CloudSpeechService',
        error: e,
      );
      return true;
    } catch (e) {
      // If backend is not reachable, fall through gracefully
      // The mock behavior below will provide a usable experience
      return true;
    }
  }

  @override
  Future<void> startListening(Function(String) onResult) async {
    _isListening = true;
    _timer?.cancel();

    // TODO: When a real cloud STT endpoint is available, stream audio
    // to the backend and return transcribed text.
    //
    // For now, simulate dictation for Simulator development/testing.
    _timer = Timer(const Duration(seconds: 2), () {
      if (_isListening) {
        onResult(
          'Patient presents with a three-day history of persistent '
          'headache, primarily frontal. Reports mild photophobia. '
          'Denies nausea, vomiting, or neck stiffness. '
          'Taking ibuprofen 400mg PRN with partial relief. '
          'No fever. No recent trauma.',
        );
        _isListening = false;
      }
    });
  }

  @override
  void setSilenceTimeout(Duration timeout) {
    // Not applicable for cloud STT
  }

  @override
  void setListenTimeout(double seconds) {
    // Not applicable for cloud STT
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _timer?.cancel();
  }

  @override
  bool get isListening => _isListening;
}
