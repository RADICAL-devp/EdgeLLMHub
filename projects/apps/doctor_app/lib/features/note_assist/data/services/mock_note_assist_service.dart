import 'dart:async';
import '../../domain/services/note_assist_service.dart';

class MockNoteAssistService implements NoteAssistService {
  @override
  Stream<String> cleanUpText(String rawText) async* {
    const cleaned = "Patient presents with headache and fever for 3 days. Denies any nausea or vomiting. Taking Tylenol with no relief.";
    
    // Simulate streaming word by word
    final words = cleaned.split(' ');
    String current = '';
    
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 100));
      current = current.isEmpty ? word : '$current $word';
      yield current;
    }
  }

  @override
  Stream<String> structureNote(String cleanedText) async* {
    const structured = '''
# Chief Complaint
Headache and fever for 3 days.

# History of Present Illness
Patient presents with a 3-day history of headache and fever. 
They deny any nausea or vomiting. 
Currently taking Tylenol, but reports no relief.

# Assessment
Viral illness vs. other etiology.

# Plan
1. Continue Tylenol for fever and pain.
2. Rest and hydration.
3. Return to clinic if symptoms worsen or do not resolve in 3-5 days.
''';

    // Simulate streaming by chunks
    final chunks = structured.split('\n');
    String current = '';
    
    for (final chunk in chunks) {
      await Future.delayed(const Duration(milliseconds: 200));
      current = current.isEmpty ? chunk : '$current\n$chunk';
      yield current;
    }
  }

  @override
  Future<String> extractFields(String structuredText) async {
    await Future.delayed(const Duration(seconds: 1));
    return '''
{
  "symptoms": ["headache", "fever"],
  "duration": "3 days",
  "medications": ["Tylenol"],
  "allergies": [],
  "testsRecommended": [],
  "followUpActions": ["Return to clinic if symptoms worsen"],
  "provisionalDiagnosis": "Viral illness"
}
''';
  }

  @override
  Future<String> generateRecap(String structuredText) async {
    await Future.delayed(const Duration(seconds: 1));
    return "You have a viral infection causing your headache and fever. Keep taking Tylenol, get plenty of rest, and drink fluids. Come back if it gets worse.";
  }
}
