import 'package:clinical_intelligence_dart/application/ports/transcript_summary_repository.dart';
import 'package:shared_models/shared_models.dart';

/// In-memory implementation of [TranscriptSummaryRepository].
class InMemorySummaryRepository implements TranscriptSummaryRepository {
  final Map<String, TranscriptSummaryBundle> _byConsultationId = {};

  @override
  Future<void> save(TranscriptSummaryBundle bundle) async {
    _byConsultationId[bundle.consultationId] = bundle;
  }

  @override
  Future<TranscriptSummaryBundle?> findByConsultationId(
    String consultationId,
  ) async {
    return _byConsultationId[consultationId];
  }

  @override
  Future<List<TranscriptSummaryBundle>> findByDoctorId(
    String doctorId,
  ) async {
    return _byConsultationId.values
        .where((b) => b.doctorNote?.doctorId == doctorId)
        .toList();
  }
}
