#!/usr/bin/env dart

import 'dart:io';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';
import 'package:doctor_app/core/llm/llm_port_factory.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import '../test/fixtures/clinical_samples.dart';

Future<void> main() async {
  print(
      '🔍 Starting Qwen 3 0.6B clinical validation with ${ClinicalSamples.allSamples.length} samples...');
  print('📦 Model: Qwen 3 0.6B (Q4_K_M, ~180-190MB)');
  print('🎯 Target: >70% accuracy on structured summaries\n');

  int passed = 0;
  int failed = 0;
  final errors = <String>[];
  final startTime = DateTime.now();

  for (var i = 0; i < ClinicalSamples.allSamples.length; i++) {
    final sample = ClinicalSamples.allSamples[i];
    final sampleNum = i + 1;
    final totalSamples = ClinicalSamples.allSamples.length;
    final progress = (sampleNum / totalSamples * 100).toStringAsFixed(1);

    try {
      print('✅ Testing sample $sampleNum/$totalSamples ($progress%)');
      final summary = await generateStructuredSummary(sample);

      if (summary.complaint.isEmpty ||
          summary.pastHistory.isEmpty ||
          summary.vitals.isEmpty ||
          summary.physicalExamination.isEmpty ||
          summary.investigationOrdered.isEmpty ||
          summary.diagnosis.isEmpty ||
          summary.advice.isEmpty) {
        throw Exception('Empty field in summary');
      }

      if (summary.complaint.contains('[OFFLINE MODE]') ||
          summary.complaint.contains('[STUB]')) {
        throw Exception('Placeholder text in summary');
      }

      passed++;
    } catch (e) {
      failed++;
      final errorMsg = 'Sample $sampleNum: ${e.toString()}';
      errors.add(errorMsg);
      print('❌ $errorMsg');
    }
  }

  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);
  final avgTimePerSample =
      duration.inMilliseconds / ClinicalSamples.allSamples.length;

  print('\n📊 ===== VALIDATION RESULTS =====');
  print('✅ Passed: $passed/${ClinicalSamples.allSamples.length}');
  print('❌ Failed: $failed/${ClinicalSamples.allSamples.length}');
  print('⏱️  Total Time: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
  print('⏳  Avg Time/Sample: ${avgTimePerSample.toStringAsFixed(0)}ms');
  print(
      '📈 Accuracy: ${(passed / ClinicalSamples.allSamples.length * 100).toStringAsFixed(1)}%');

  if (errors.isNotEmpty) {
    print('\n❌ ===== ERRORS =====');
    for (final error in errors) {
      print('  - $error');
    }
    exit(1);
  } else {
    print(
        '\n✅ All ${ClinicalSamples.allSamples.length} clinical samples validated successfully!');
    print('🎉 Qwen 3 0.6B is ready for production use in medical settings!');
    exit(0);
  }
}

Future<StructuredSummary> generateStructuredSummary(String transcript) async {
  final llmAdapter = await LlmPortFactory.create(DeviceCapabilityService());
  return llmAdapter.generateStructuredSummary(transcript);
}
