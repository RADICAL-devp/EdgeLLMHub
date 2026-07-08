import '../../application/ports/transcript_repository.dart';
import '../../core/models/consultation_transcript.dart';

/// In-memory implementation of [TranscriptRepository].
///
/// For development/testing. Replace with a database-backed
/// implementation for production.
class InMemoryTranscriptRepository implements TranscriptRepository {
  final Map<String, ConsultationTranscript> _byTranscriptId = {};
  final Map<String, ConsultationTranscript> _byConsultationId = {};

  @override
  Future<void> save(ConsultationTranscript transcript) async {
    _byTranscriptId[transcript.transcriptId] = transcript;
    _byConsultationId[transcript.consultationId] = transcript;
  }

  @override
  Future<ConsultationTranscript?> findByTranscriptId(
    String transcriptId,
  ) async {
    return _byTranscriptId[transcriptId];
  }

  @override
  Future<ConsultationTranscript?> findByConsultationId(
    String consultationId,
  ) async {
    return _byConsultationId[consultationId];
  }

  @override
  Future<List<ConsultationTranscript>> findByDoctorId(
    String doctorId,
  ) async {
    return _byTranscriptId.values
        .where((t) => t.doctorId == doctorId)
        .toList();
  }
}
