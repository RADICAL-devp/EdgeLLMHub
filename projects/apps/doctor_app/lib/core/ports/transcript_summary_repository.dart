import 'package:doctor_app/core/models/transcript_summary_bundle.dart';

/// Port for transcript summary persistence.
abstract class TranscriptSummaryRepository {
  Future<void> save(TranscriptSummaryBundle bundle);
  Future<TranscriptSummaryBundle?> findByConsultationId(String consultationId);
  Future<List<TranscriptSummaryBundle>> findByDoctorId(String doctorId);
}
