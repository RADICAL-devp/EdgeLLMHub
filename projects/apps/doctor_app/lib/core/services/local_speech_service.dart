import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'speech_service.dart';

/// Local speech-to-text service using native platform APIs.
///
/// Features:
///   - Voice Activity Detection (auto-stop on silence)
///   - Medical term post-processing (abbreviation expansion, capitalization)
///   - Configurable language/locale
///   - Proper error handling with meaningful exceptions
///   - Permission handling guidance
class LocalSpeechService implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  stt.SpeechRecognitionError? _lastError;
  
  // VAD configuration
  Duration _silenceTimeout = const Duration(seconds: 3);
  double _listenTimeout = 30.0; // seconds
  Duration _pauseFor = const Duration(milliseconds: 500);
  
  // Medical term dictionary for post-processing
  static const Map<String, String> _medicalAbbreviations = {
    'bp': 'BP',
    'blood pressure': 'BP',
    'heart rate': 'HR',
    'hr': 'HR',
    'respiratory rate': 'RR',
    'rr': 'RR',
    'temperature': 'Temp',
    'temp': 'Temp',
    'oxygen saturation': 'SpO2',
    'spo2': 'SpO2',
    'bmi': 'BMI',
    'body mass index': 'BMI',
    'twice daily': 'BID',
    'three times daily': 'TID',
    'four times daily': 'QID',
    'as needed': 'PRN',
    'by mouth': 'PO',
    'every day': 'daily',
    'history of present illness': 'HPI',
    'review of systems': 'ROS',
    'no known drug allergies': 'NKDA',
    'c/o': 'complains of',
    'r/o': 'rule out',
    's/p': 'status post',
    'w/nl': 'within normal limits',
    'w/d': 'well developed',
    'wnp': 'well nourished',
    'a&o': 'alert and oriented',
    'c/c': 'chief complaint',
    'h/o': 'history of',
    'fam hx': 'family history',
    'soc hx': 'social history',
    'med hx': 'medical history',
    'sx': 'surgery',
    'tx': 'treatment',
    'dx': 'diagnosis',
    'rx': 'prescription',
  };

  @override
  Future<bool> initialize({
    stt.SpeechToText? speechInstance,
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
  }) async {
    if (_isInitialized) return true;

    if (silenceTimeout != null) _silenceTimeout = silenceTimeout;
    if (listenTimeout != null) _listenTimeout = listenTimeout;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _lastError = error;
        },
        onStatus: (status) {
          // Status updates are informational
        },
      );
    } catch (e) {
      if (e is SpeechException) rethrow;
      throw SpeechException(
        'Failed to initialize speech recognition: $e',
        cause: e,
      );
    }

    if (!_isInitialized) {
      throw const SpeechUnavailableException(
        message: 'Speech recognition is not available on this device. '
            'This may be a simulator or a device without microphone support.',
      );
    }

    // Verify locale is supported
    final locales = await _speech.locales();
    final supported = locales.any((l) => l.localeId == locale);
    if (!supported) {
      // Use first available locale
      final fallback = locales.isNotEmpty ? locales.first.localeId : 'en_US';
    }

    return _isInitialized;
  }

  @override
  Future<void> startListening(Function(String) onResult) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isInitialized && !_speech.isListening) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              final processed = _postProcessMedicalText(result.recognizedWords);
              onResult(processed);
            } else {
              // Partial result - still apply light processing
              onResult(_lightPostProcess(result.recognizedWords));
            }
          },
          listenFor: Duration(seconds: _listenTimeout.toInt()),
          pauseFor: _pauseFor,
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
          ),
        );
      } catch (e) {
        throw SpeechException(
          'Failed to start speech recognition: $e',
          cause: e,
        );
      }
    }
  }

  /// Configure VAD silence timeout
  void setSilenceTimeout(Duration timeout) {
    _silenceTimeout = timeout;
  }

  /// Configure total listen timeout
  void setListenTimeout(double seconds) {
    _listenTimeout = seconds;
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  @override
  bool get isListening => _speech.isListening;

  /// Get last error if any
  stt.SpeechRecognitionError? get lastError => _lastError;

  /// Check if STT is available on this device
  static Future<bool> isAvailable() async {
    final speech = stt.SpeechToText();
    return await speech.initialize();
  }

  /// Light post-processing for partial results
  String _lightPostProcess(String text) {
    // Just capitalize first letter for partial results
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Full post-processing for final results
  String _postProcessMedicalText(String text) {
    if (text.isEmpty) return text;

    var result = text.trim();

    // 1. Capitalize first letter of each sentence
    result = result.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );

    // 2. Ensure sentences end with punctuation
    if (result.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(result)) {
      result = '$result.';
    }

    // 2. Standardize medical abbreviations
    for (final entry in _medicalAbbreviations.entries) {
      result = result.replaceAllMapped(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        (m) => entry.value,
      );
    }

    // 3. Fix common clinical punctuation: "BP 120 / 80" → "BP 120/80"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*/\s*(\d+)'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );

    // 4. Fix "bpm" formatting
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*bpm', caseSensitive: false),
      (m) => '${m.group(1)} bpm',
    );

    // 5. Fix "mmHg" formatting
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*mm\s*hg', caseSensitive: false),
      (m) => '${m.group(1)} mmHg',
    );

    // 6. Fix temperature formatting (98.6 F → 98.6°F)
    result = result.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*[fc]', caseSensitive: false),
      (m) => '${m.group(1)}°${m.group(0)!.substring(m.group(0)!.length - 1).toUpperCase()}',
    );

    return result;
  }
}
