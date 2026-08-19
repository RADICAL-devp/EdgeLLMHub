import 'package:shared_models/shared_models.dart';

/// Port for LLM-based text processing.
///
/// Abstracts the LLM provider (Ollama, OpenAI, or stub).
/// All implementations MUST be conservative and healthcare-safe:
///   - Do not hallucinate facts
///   - Do not infer unsupported diagnoses
///   - Preserve uncertainty and speaker intent
///   - Preserve medical meaning
///   - Clearly distinguish input-derived content from generated formatting
abstract class LlmPort {
  /// Process text according to the specified mode.
  ///
  /// Used by the generic clinical processing endpoint (API Family A).
  Future<String> processText(String input, ProcessingMode mode);

  /// Generate a structured 7-field clinical summary from transcript text.
  ///
  /// Used by the transcript summary endpoint (API Family B).
  Future<StructuredSummary> generateStructuredSummary(String transcriptText);

  /// Generate a context-enriched summary using past consultation context.
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  );

  /// Generate an executive summary from transcript text.
  Future<String> generateExecutiveSummary(String transcriptText);

  /// Generate a doctor note from transcript text.
  Future<String> generateDoctorNote(String transcriptText);

  // ============ FIELD-LEVEL GENERATION FOR EHR ASSISTANCE ============
  /// Generate a single EHR field suggestion from transcript text.
  ///
  /// [fieldName] must be one of: complaint, pastHistory, vitals,
  /// physicalExamination, investigationOrdered, diagnosis, advice,
  /// manualPrescription
  ///
  /// Returns the extracted field value as a String (JSON value, not the full JSON object).
  Future<String> generateField(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  });

  /// Stream a single EHR field suggestion from transcript text.
  ///
  /// Emits partial results as they are generated. Final emission is the complete field value.
  /// [fieldName] must be one of: complaint, pastHistory, vitals,
  /// physicalExamination, investigationOrdered, diagnosis, advice,
  /// manualPrescription
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  });

  /// Generate multiple fields at once.
  ///
  /// [fieldNames] is a list of field names to generate.
  /// Returns a map of fieldName -> fieldValue.
  Future<Map<String, String>> generateFields(
    List<String> fieldNames,
    String transcriptText, {
    PatientContext? patientContext,
  });
}
