abstract class NoteAssistService {
  /// Cleans up raw dictated text (fixes grammar, removes filler words).
  /// Streams the result back character by character/word by word.
  Stream<String> cleanUpText(String rawText);

  /// Structures the cleaned text into standard sections (Chief Complaint, HPI, etc.).
  /// Streams the formatted markdown/text result.
  Stream<String> structureNote(String cleanedText);

  /// Extracts structured clinical fields as a JSON string.
  Future<String> extractFields(String structuredText);

  /// Generates a brief recap for the patient.
  Future<String> generateRecap(String structuredText);
}
