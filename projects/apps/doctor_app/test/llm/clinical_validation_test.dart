import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/llm/llm_port_factory.dart';
import 'package:mockito/mockito.dart';
import '../fixtures/clinical_samples.dart';

class MockDeviceCapabilityService extends Mock implements DeviceCapabilityService {}

void main() {
  group('Qwen 3 0.6B Clinical Validation Tests', () {
    late HybridLlmAdapter llmAdapter;

    setUp(() async {
      llmAdapter = await LlmPortFactory.create(MockDeviceCapabilityService());
    });

    tearDown(() async {
      await llmAdapter.dispose();
    });

    group('Structured Summary Validation', () {
      test('All samples produce valid structured summaries', () async {
        ClinicalSamples.assertMinSamples(50);

        for (final sample in ClinicalSamples.allSamples) {
          final summary = await llmAdapter.generateStructuredSummary(sample);

          expect(summary.complaint, isNotEmpty, reason: 'Complaint empty for sample: $sample');
          expect(summary.pastHistory, isNotEmpty, reason: 'Past history empty for sample: $sample');
          expect(summary.vitals, isNotEmpty, reason: 'Vitals empty for sample: $sample');
          expect(summary.physicalExamination, isNotEmpty, reason: 'Physical exam empty for sample: $sample');
          expect(summary.investigationOrdered, isNotEmpty, reason: 'Investigations empty for sample: $sample');
          expect(summary.diagnosis, isNotEmpty, reason: 'Diagnosis empty for sample: $sample');
          expect(summary.advice, isNotEmpty, reason: 'Advice empty for sample: $sample');

          expect(summary.complaint, isNot(contains('[OFFLINE MODE]')), reason: 'Offline mode placeholder in sample: $sample');
          expect(summary.complaint, isNot(contains('[STUB]')), reason: 'Stub placeholder in sample: $sample');
        }
      });

      test('Structured summaries are clinically coherent', () async {
        const sample = ClinicalSamples.cardiology.first;
        final summary = await llmAdapter.generateStructuredSummary(sample);

        expect(summary.complaint.length, greaterThan(20), reason: 'Complaint too short');
        expect(summary.diagnosis.length, greaterThan(10), reason: 'Diagnosis too short');

        final lowerSummary = '''
          ${summary.complaint.toLowerCase()}
          ${summary.pastHistory.toLowerCase()}
          ${summary.diagnosis.toLowerCase()}
          ${summary.advice.toLowerCase()}
        ''';
        expect(lowerSummary, containsAny([
          'chest pain', 'st elevation', 'myocardial infarction', 'acute coronary syndrome',
          'hypertension', 'diabetes', 'dyspnea', 'ecg', 'troponin', 'cardiac', 'coronary'
        ]), reason: 'Missing expected cardiac terminology in: $lowerSummary');
      });
    });

    group('Specialty Prompt Validation', () {
      test('Cardiology prompts produce cardiology-relevant output', () async {
        const sample = ClinicalSamples.cardiology.first;
        final summary = await llmAdapter.generateStructuredSummary(
          '${sample}\n\nSpecialty: Cardiology',
        );

        final lowerSummary = '''
          ${summary.complaint.toLowerCase()}
          ${summary.diagnosis.toLowerCase()}
          ${summary.advice.toLowerCase()}
        ''';

        expect(lowerSummary, containsAny([
          'heart', 'cardiac', 'ecg', 'bp', 'chest pain', 'myocardial',
          'coronary', 'infarction', 'angina', 'arrhythmia', 'heart failure'
        ]), reason: 'Cardiology prompt missing cardiac terms in: $lowerSummary');
      });

      test('Neurology prompts produce neurology-relevant output', () async {
        const sample = ClinicalSamples.neurology.first;
        final summary = await llmAdapter.generateStructuredSummary(
          '${sample}\n\nSpecialty: Neurology',
        );

        final lowerSummary = '''
          ${summary.complaint.toLowerCase()}
          ${summary.diagnosis.toLowerCase()}
          ${summary.advice.toLowerCase()}
        ''';

        expect(lowerSummary, containsAny([
          'neurological', 'stroke', 'seizure', 'headache', 'mri', 'ct head',
          'focal deficit', 'weakness', 'numbness', 'speech', 'ataxia', 'cognitive'
        ]), reason: 'Neurology prompt missing neuro terms in: $lowerSummary');
      });

      test('Pediatrics prompts produce pediatrics-relevant output', () async {
        const sample = ClinicalSamples.pediatrics.first;
        final summary = await llmAdapter.generateStructuredSummary(
          '${sample}\n\nSpecialty: Pediatrics',
        );

        final lowerSummary = '''
          ${summary.complaint.toLowerCase()}
          ${summary.diagnosis.toLowerCase()}
          ${summary.advice.toLowerCase()}
        ''';

        expect(lowerSummary, containsAny([
          'pediatric', 'child', 'infant', 'vaccination', 'growth', 'development',
          'fever', 'rash', 'congenital', 'newborn', 'milestone'
        ]), reason: 'Pediatrics prompt missing pediatric terms in: $lowerSummary');
      });
    });

    group('Field Extraction Validation', () {
      test('All fields are extracted for every sample', () async {
        const sample = ClinicalSamples.general.first;
        final fields = await llmAdapter.generateFields(
          ClinicalPrompts.fieldPrompts.keys.toList(),
          sample,
        );

        expect(fields.length, equals(ClinicalPrompts.fieldPrompts.length),
          reason: 'Field count mismatch');

        for (final entry in fields.entries) {
          expect(entry.value, isNotEmpty, reason: 'Field ${entry.key} is empty');
          expect(entry.value, isNot(contains('[OFFLINE MODE]')), reason: 'Offline placeholder in ${entry.key}');
          expect(entry.value, isNot(contains('[STUB]')), reason: 'Stub placeholder in ${entry.key}');
        }
      });

      test('Field extraction is consistent across specialties', () async {
        const cardiologySample = ClinicalSamples.cardiology.first;
        const neurologySample = ClinicalSamples.neurology.first;

        final cardiologyFields = await llmAdapter.generateFields(
          ClinicalPrompts.fieldPrompts.keys.toList(),
          cardiologySample,
          specialty: 'Cardiology',
        );

        final neurologyFields = await llmAdapter.generateFields(
          ClinicalPrompts.fieldPrompts.keys.toList(),
          neurologySample,
          specialty: 'Neurology',
        );

        expect(cardiologyFields.length, equals(ClinicalPrompts.fieldPrompts.length));
        expect(neurologyFields.length, equals(ClinicalPrompts.fieldPrompts.length));

        final cardiologyDiagnosis = cardiologyFields['diagnosis']?.toLowerCase() ?? '';
        expect(cardiologyDiagnosis, containsAny(['heart', 'cardiac', 'mi', 'acs', 'coronary']));

        final neurologyDiagnosis = neurologyFields['diagnosis']?.toLowerCase() ?? '';
        expect(neurologyDiagnosis, containsAny(['stroke', 'seizure', 'neurological', 'cva', 'tia']));
      });
    });

    group('Performance Validation', () {
      test('Structured summary generation completes in <10 seconds', () async {
        const sample = ClinicalSamples.general.first;
        final stopwatch = Stopwatch()..start();
        await llmAdapter.generateStructuredSummary(sample);
        stopwatch.stop();
        expect(stopwatch.elapsed.inSeconds, lessThan(10),
          reason: 'Summary generation too slow: ${stopwatch.elapsed}');
      }, timeout: Timeout(Duration(seconds: 15)));

      test('Field extraction completes in <5 seconds per field', () async {
        const sample = ClinicalSamples.general.first;
        final fields = ClinicalPrompts.fieldPrompts.keys.toList();
        final stopwatch = Stopwatch()..start();
        await llmAdapter.generateFields(fields, sample);
        stopwatch.stop();
        final perFieldTime = stopwatch.elapsed.inMilliseconds / fields.length;
        expect(perFieldTime, lessThan(5000),
          reason: 'Field extraction too slow: ${perFieldTime}ms per field');
      }, timeout: Timeout(Duration(seconds: 30)));
    });
  });
}
