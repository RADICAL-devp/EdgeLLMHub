// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/api/v1/transcript-summary/generate.dart' as api_v1_transcript_summary_generate;
import '../routes/api/v1/transcript-summary/[consultationId]/regenerate.dart' as api_v1_transcript_summary_$consultation_id_regenerate;
import '../routes/api/v1/transcript-summary/[consultationId]/index.dart' as api_v1_transcript_summary_$consultation_id_index;
import '../routes/api/v1/clinical-processing/process.dart' as api_v1_clinical_processing_process;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/api/v1/clinical-processing', (context) => buildApiV1ClinicalProcessingHandler()(context))
    ..mount('/api/v1/transcript-summary/<consultationId>', (context,consultationId,) => buildApiV1TranscriptSummary$consultationIdHandler(consultationId,)(context))
    ..mount('/api/v1/transcript-summary', (context) => buildApiV1TranscriptSummaryHandler()(context))
    ..mount('/', (context) => buildHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildApiV1ClinicalProcessingHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/process', (context) => api_v1_clinical_processing_process.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1TranscriptSummary$consultationIdHandler(String consultationId,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/regenerate', (context) => api_v1_transcript_summary_$consultation_id_regenerate.onRequest(context,consultationId,))..all('/', (context) => api_v1_transcript_summary_$consultation_id_index.onRequest(context,consultationId,));
  return pipeline.addHandler(router);
}

Handler buildApiV1TranscriptSummaryHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/generate', (context) => api_v1_transcript_summary_generate.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

