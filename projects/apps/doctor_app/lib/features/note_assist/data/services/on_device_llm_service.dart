import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../../domain/services/note_assist_service.dart';

class OnDeviceLlmService implements NoteAssistService {
  bool _isInitialized = false;

  /// Initializes the Gemma engine with the model path.
  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;
    await FlutterGemmaPlugin.instance.init(
      modelPath: modelPath,
      maxTokens: 1024,
      temperature: 0.2, // Low temp for clinical tasks
    );
    _isInitialized = true;
  }

  @override
  Stream<String> cleanUpText(String rawText) async* {
    if (!_isInitialized) {
      throw Exception('Model not initialized.');
    }

    final prompt = '''
You are a medical assistant. Clean up the following raw dictated note from a doctor.
Fix grammar, remove filler words (um, uh), and ensure professional medical terminology is used where appropriate.
Do not add any new clinical information. Just output the cleaned text.

RAW NOTE:
$rawText

CLEANED NOTE:
''';

    final stream = FlutterGemmaPlugin.instance.getResponseAsync(prompt: prompt);
    String currentText = '';
    
    await for (final token in stream) {
      if (token != null) {
        currentText += token;
        yield currentText;
      }
    }
  }

  @override
  Stream<String> structureNote(String cleanedText) async* {
    if (!_isInitialized) {
      throw Exception('Model not initialized.');
    }

    final prompt = '''
You are a medical assistant. Structure the following clinical note into standard sections:
Chief Complaint, History of Present Illness (HPI), Assessment, and Plan.
Use markdown formatting for headers. Do not add any new clinical information.

NOTE:
$cleanedText

STRUCTURED NOTE:
''';

    final stream = FlutterGemmaPlugin.instance.getResponseAsync(prompt: prompt);
    String currentText = '';
    
    await for (final token in stream) {
      if (token != null) {
        currentText += token;
        yield currentText;
      }
    }
  }

  @override
  Future<String> extractFields(String structuredText) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized.');
    }

    final prompt = '''
You are a medical assistant. Extract the following fields from the clinical note as a raw JSON object:
- symptoms (list of strings)
- duration (string)
- medications (list of strings)
- provisionalDiagnosis (string)

NOTE:
$structuredText

JSON:
''';

    final response = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
    return response ?? '{}';
  }

  @override
  Future<String> generateRecap(String structuredText) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized.');
    }

    final prompt = '''
You are a friendly medical assistant speaking directly to a patient.
Write a brief, easy-to-understand 2-3 sentence recap of their visit based on the doctor's note below.

NOTE:
$structuredText

RECAP:
''';

    final response = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
    return response ?? '';
  }
}
