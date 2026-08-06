import 'package:shared_models/shared_models.dart';

/// Port for transcript summary persistence.
abstract class TranscriptSummaryRepository {
  Future<void> save(TranscriptSummaryBundle bundle);
  Future<TranscriptSummaryBundle?> findByConsultationId(String consultationId);
  Future<List<TranscriptSummaryBundle>> findByDoctorId(String doctorId);
}
