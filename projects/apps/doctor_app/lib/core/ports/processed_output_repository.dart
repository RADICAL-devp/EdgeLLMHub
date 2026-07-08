import 'package:doctor_app/core/dto/clinical_processing_response.dart';

/// Port for persisting processed output from clinical text processing.
abstract class ProcessedOutputRepository {
  Future<void> save(String id, ClinicalProcessingResponse response);
  Future<ClinicalProcessingResponse?> findById(String id);
  Future<List<ClinicalProcessingResponse>> findByConsultationId(
    String consultationId,
  );
}
