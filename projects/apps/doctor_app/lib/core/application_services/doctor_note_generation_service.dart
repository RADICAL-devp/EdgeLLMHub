import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/doctor_note.dart';
import 'package:uuid/uuid.dart';

/// Generates doctor notes via LLM (Milestone 2).
///
/// TODO: Implement full note generation with structured sections.
class DoctorNoteGenerationService {
  DoctorNoteGenerationService({required this.llmPort});

  final LlmPort llmPort;

  /// Generate a doctor note from normalized transcript text.
  Future<DoctorNote> generate({
    required String normalizedText,
    String? consultationId,
    String? patientId,
    String? doctorId,
  }) async {
    final noteText = await llmPort.generateDoctorNote(normalizedText);
    final now = DateTime.now().toUtc();

    return DoctorNote(
      noteId: const Uuid().v4(),
      consultationId: consultationId,
      patientId: patientId,
      doctorId: doctorId,
      rawText: normalizedText,
      cleanedText: noteText,
      status: 'draft',
      createdAt: now,
      updatedAt: now,
    );
  }
}
