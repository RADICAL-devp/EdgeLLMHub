import 'dart:io';

import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_repository.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_summary_repository.dart';
import 'package:clinical_intelligence_dart/application/ports/vector_store_port.dart';
import 'package:clinical_intelligence_dart/application/services/doctor_note_generation_service.dart';
import 'package:clinical_intelligence_dart/application/services/summary_generation_service.dart';
import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_chunking_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_summary_aggregation_service.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/embeddings/hash_embedding_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/sqlite_vec_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

class _MockTranscriptRepository extends Mock implements TranscriptRepository {}

class _MockSummaryRepository extends Mock
    implements TranscriptSummaryRepository {}

class _MockVectorStore extends Mock implements VectorStorePort {}

class _MockLlmPort extends Mock implements LlmPort {}

void main() {
  late SummaryOrchestrator orchestrator;
  late _MockTranscriptRepository transcriptRepository;
  late _MockSummaryRepository summaryRepository;
  late _MockVectorStore vectorStore;
  late _MockLlmPort llmPort;
  late HashEmbeddingService embeddingService;

  setUpAll(() {
    registerFallbackValue(
      ConsultationTranscript(
        transcriptId: '',
        consultationId: '',
        patientId: '',
        doctorId: '',
        transcriptText: '',
      ),
    );
    registerFallbackValue(StructuredSummary(
      complaint: '',
      pastHistory: '',
      vitals: '',
      physicalExamination: '',
      investigationOrdered: '',
      diagnosis: '',
      advice: '',
    ));
    registerFallbackValue(DoctorNote(
      noteId: '',
      consultationId: '',
      patientId: '',
      doctorId: '',
      rawText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ));
    registerFallbackValue(TranscriptSummaryBundle(
      consultationId: '',
      transcriptId: '',
      structuredMedicalSummary: StructuredSummary(
        complaint: '',
        pastHistory: '',
        vitals: '',
        physicalExamination: '',
        investigationOrdered: '',
        diagnosis: '',
        advice: '',
      ),
      doctorNote: DoctorNote(
        noteId: '',
        consultationId: '',
        patientId: '',
        doctorId: '',
        rawText: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      generatedAt: '',
    ));
  });

  SummaryOrchestrator build() => SummaryOrchestrator(
        validationService: ValidationService(),
        normalizationService: TranscriptNormalizationService(),
        chunkingService: TranscriptChunkingService(),
        summaryGenerationService: SummaryGenerationService(llmPort: llmPort),
        doctorNoteGenerationService:
            DoctorNoteGenerationService(llmPort: llmPort),
        aggregationService: TranscriptSummaryAggregationService(),
        transcriptRepository: transcriptRepository,
        summaryRepository: summaryRepository,
        vectorStore: vectorStore,
        embeddingService: embeddingService,
        llmPort: llmPort,
      );

  setUp(() {
    transcriptRepository = _MockTranscriptRepository();
    summaryRepository = _MockSummaryRepository();
    vectorStore = _MockVectorStore();
    llmPort = _MockLlmPort();
    embeddingService = HashEmbeddingService();
    orchestrator = build();
  });

  group('buildPastContext', () {
    test('returns formatted blocks for similar past consultations', () async {
      when(() => vectorStore.search(
            queryEmbedding: any(named: 'queryEmbedding'),
            k: any(named: 'k'),
            filter: any(named: 'filter'),
          )).thenAnswer((invocation) async {
        return [
          VectorMatch(
            id: 'c-old-1',
            score: 0.82,
            metadata: {
              'transcriptText': 'Patient with chronic headaches.',
              'structuredSummary': {
                'complaint': 'Headaches',
                'pastHistory': '3 months',
                'vitals': '',
                'physicalExamination': '',
                'investigationOrdered': 'MRI',
                'diagnosis': 'Migraine',
                'advice': 'Rest',
              },
              'resource_type': 'consultation',
            },
          ),
        ];
      });

      final context = await orchestrator.buildPastContext(
        'Patient with chronic headaches.',
      );

      expect(context, contains('Consultation c-old-1'));
      expect(context, contains('Patient with chronic headaches.'));
      expect(context, contains('Migraine'));
    });

    test('returns empty string when the vector store has no matches', () async {
      when(() => vectorStore.search(
            queryEmbedding: any(named: 'queryEmbedding'),
            k: any(named: 'k'),
            filter: any(named: 'filter'),
          )).thenAnswer((invocation) async => []);

      final context =
          await orchestrator.buildPastContext('A brand-new complaint.');
      expect(context, isEmpty);
    });

    test('degrades gracefully when the vector store fails', () async {
      when(() => vectorStore.search(
            queryEmbedding: any(named: 'queryEmbedding'),
            k: any(named: 'k'),
            filter: any(named: 'filter'),
          )).thenThrow(Exception('vector store unavailable'));

      final context = await orchestrator.buildPastContext('Any text.');
      expect(context, isEmpty);
    });
  });

  group('generateSummary', () {
    final validRequest = TranscriptSummaryRequest(
      consultationId: 'c-new-1',
      patientId: 'p-1',
      doctorId: 'd-1',
      transcriptText: '56 year old male with SOB and DOE for 2 weeks.',
    );

    test('uses context enrichment when similar consultations exist', () async {
      when(() => vectorStore.search(
            queryEmbedding: any(named: 'queryEmbedding'),
            k: any(named: 'k'),
            filter: any(named: 'filter'),
          )).thenAnswer((invocation) async => [
            VectorMatch(
              id: 'c-old-2',
              score: 0.9,
              metadata: {
                'transcriptText': 'Prior SOB episode.',
                'structuredSummary': null,
              },
            ),
          ]);

      final summary = StructuredSummary(
        complaint: 'SOB',
        pastHistory: '2 weeks',
        vitals: 'normal',
        physicalExamination: 'clear',
        investigationOrdered: 'CXR',
        diagnosis: 'Bronchitis',
        advice: 'Rest',
      );

      when(() => llmPort.generateContextEnrichedSummary(
            any(),
            any(),
          )).thenAnswer((_) async => summary);
      when(() => llmPort.generateDoctorNote(any()))
          .thenAnswer((_) async => 'Note text');
      when(() => transcriptRepository.save(any()))
          .thenAnswer((_) async {});
      when(() => summaryRepository.save(any()))
          .thenAnswer((_) async {});
      when(() => vectorStore.add(
            id: any(named: 'id'),
            embedding: any(named: 'embedding'),
            metadata: any(named: 'metadata'),
          )).thenAnswer((_) async {});

      final response = await orchestrator.generateSummary(validRequest);

      final captured = verify(() => llmPort.generateContextEnrichedSummary(
            captureAny(),
            captureAny(),
          )).captured;
      expect(captured.last, contains('Prior SOB episode.'));
      expect(response.structuredMedicalSummary?.complaint, 'SOB');
    });

    test('uses plain generation when no past context exists', () async {
      when(() => vectorStore.search(
            queryEmbedding: any(named: 'queryEmbedding'),
            k: any(named: 'k'),
            filter: any(named: 'filter'),
          )).thenAnswer((invocation) async => []);

      final summary = StructuredSummary(
        complaint: 'SOB',
        pastHistory: '2 weeks',
        vitals: 'normal',
        physicalExamination: 'clear',
        investigationOrdered: 'CXR',
        diagnosis: 'Bronchitis',
        advice: 'Rest',
      );
      when(() => llmPort.generateStructuredSummary(any()))
          .thenAnswer((_) async => summary);
      when(() => llmPort.generateDoctorNote(any()))
          .thenAnswer((_) async => 'Note text');
      when(() => transcriptRepository.save(any()))
          .thenAnswer((_) async {});
      when(() => summaryRepository.save(any()))
          .thenAnswer((_) async {});
      when(() => vectorStore.add(
            id: any(named: 'id'),
            embedding: any(named: 'embedding'),
            metadata: any(named: 'metadata'),
          )).thenAnswer((_) async {});

      final response = await orchestrator.generateSummary(validRequest);

      verify(() => llmPort.generateStructuredSummary(any())).called(1);
      verifyNever(() => llmPort.generateContextEnrichedSummary(any(), any()));
      expect(response.doctorNote?.rawText, validRequest.transcriptText);
      expect(response.doctorNote?.cleanedText, 'Note text');
    });
  });

  group('SqliteVecStore end-to-end (hash embeddings)', () {
    late SqliteVecStore store;
    late String tmpPath;

    setUp(() {
      tmpPath = '${Directory.systemTemp.path}/vec_test_${DateTime.now().microsecondsSinceEpoch}.sqlite';
      store = SqliteVecStore(tmpPath);
    });

    tearDown(() async {
      await store.clear();
      await store.close();
      final file = File(tmpPath);
      if (file.existsSync()) file.deleteSync();
    });

    test('roundtrips add → search → delete', () async {
      final embed = HashEmbeddingService();
      final text = 'Patient with chronic headaches. MRI normal.';
      final embedding = await embed.embed(text);

      await store.add(
        id: 'c-seed-1',
        embedding: embedding,
        metadata: {
          'transcriptText': text,
          'resource_type': 'consultation',
          'resource_id': 'c-seed-1',
        },
      );

      final results = await store.search(
        queryEmbedding: await embed.embed(text),
        k: 5,
      );
      expect(results, isNotEmpty);
      expect(results.first.id, 'c-seed-1');

      await store.delete('c-seed-1');
      expect(await store.count(), 0);
    });
  });
}