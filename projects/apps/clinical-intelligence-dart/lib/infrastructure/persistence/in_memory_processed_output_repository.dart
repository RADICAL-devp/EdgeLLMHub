import '../../api/dto/clinical_processing_response.dart';
import '../../application/ports/processed_output_repository.dart';

/// In-memory implementation of [ProcessedOutputRepository].
class InMemoryProcessedOutputRepository implements ProcessedOutputRepository {
  final Map<String, ClinicalProcessingResponse> _byId = {};
  final Map<String, List<ClinicalProcessingResponse>> _byConsultationId = {};

  @override
  Future<void> save(String id, ClinicalProcessingResponse response) async {
    _byId[id] = response;
    final consultationId =
        response.metadata['consultationId'] as String?;
    if (consultationId != null) {
      _byConsultationId
          .putIfAbsent(consultationId, () => [])
          .add(response);
    }
  }

  @override
  Future<ClinicalProcessingResponse?> findById(String id) async {
    return _byId[id];
  }

  @override
  Future<List<ClinicalProcessingResponse>> findByConsultationId(
    String consultationId,
  ) async {
    return _byConsultationId[consultationId] ?? [];
  }
}
