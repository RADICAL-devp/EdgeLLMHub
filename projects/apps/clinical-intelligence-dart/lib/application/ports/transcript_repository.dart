import '../../core/models/consultation_transcript.dart';

/// Port for transcript persistence.
///
/// Backed by in-memory storage initially; can be swapped for a database.
abstract class TranscriptRepository {
  Future<void> save(ConsultationTranscript transcript);
  Future<ConsultationTranscript?> findByConsultationId(String consultationId);
  Future<ConsultationTranscript?> findByTranscriptId(String transcriptId);
  Future<List<ConsultationTranscript>> findByDoctorId(String doctorId);
}
