import 'package:clinical_intelligence_dart/application/services/transcript_summary_aggregation_service.dart';
import 'package:clinical_intelligence_dart/core/models/structured_summary.dart';
import 'package:clinical_intelligence_dart/core/models/transcript_chunk_summary.dart';
import 'package:test/test.dart';

void main() {
  late TranscriptSummaryAggregationService service;

  setUp(() {
    service = TranscriptSummaryAggregationService();
  });

  group('TranscriptSummaryAggregationService', () {
    test('returns empty summary for empty chunk list', () {
      final result = service.aggregate([]);
      expect(result.complaint, isNull);
    });

    test('returns single chunk summary unchanged', () {
      final summary = StructuredSummary(
        complaint: 'Headache',
        pastHistory: 'None',
        vitals: 'Normal',
        physicalExamination: 'NAD',
        investigationOrdered: 'None',
        diagnosis: 'Migraine',
        advice: 'Rest',
      );

      final result = service.aggregate([
        TranscriptChunkSummary(
          chunkIndex: 0,
          chunkText: 'text',
          structuredSummary: summary,
        ),
      ]);

      expect(result.complaint, equals('Headache'));
      expect(result.diagnosis, equals('Migraine'));
    });

    test('is deterministic — same input produces same output', () {
      final chunks = [
        TranscriptChunkSummary(
          chunkIndex: 0,
          chunkText: 'chunk1',
          structuredSummary: StructuredSummary(
            complaint: 'Headache',
            diagnosis: 'Migraine',
          ),
        ),
        TranscriptChunkSummary(
          chunkIndex: 1,
          chunkText: 'chunk2',
          structuredSummary: StructuredSummary(
            complaint: 'Nausea',
            diagnosis: 'Gastritis',
          ),
        ),
      ];

      final result1 = service.aggregate(chunks);
      final result2 = service.aggregate(chunks);

      expect(result1.complaint, equals(result2.complaint));
      expect(result1.diagnosis, equals(result2.diagnosis));
    });

    test('merges distinct values with separator', () {
      final chunks = [
        TranscriptChunkSummary(
          chunkIndex: 0,
          chunkText: 'chunk1',
          structuredSummary: StructuredSummary(complaint: 'Headache'),
        ),
        TranscriptChunkSummary(
          chunkIndex: 1,
          chunkText: 'chunk2',
          structuredSummary: StructuredSummary(complaint: 'Nausea'),
        ),
      ];

      final result = service.aggregate(chunks);

      expect(result.complaint, contains('Headache'));
      expect(result.complaint, contains('Nausea'));
    });

    test('deduplicates identical values', () {
      final chunks = [
        TranscriptChunkSummary(
          chunkIndex: 0,
          chunkText: 'chunk1',
          structuredSummary: StructuredSummary(complaint: 'Headache'),
        ),
        TranscriptChunkSummary(
          chunkIndex: 1,
          chunkText: 'chunk2',
          structuredSummary: StructuredSummary(complaint: 'Headache'),
        ),
      ];

      final result = service.aggregate(chunks);

      // Should not duplicate
      expect(result.complaint, equals('Headache'));
    });
  });
}
