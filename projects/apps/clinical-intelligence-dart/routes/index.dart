import 'package:dart_frog/dart_frog.dart';

/// Root index route — health check / API info.
Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'service': 'Clinical Intelligence (Dart Frog)',
      'version': '0.1.0',
      'status': 'running',
      'endpoints': {
        'clinical-processing': 'POST /api/v1/clinical-processing/process',
        'transcript-summary-generate':
            'POST /api/v1/transcript-summary/generate',
        'transcript-summary-get':
            'GET /api/v1/transcript-summary/{consultationId}',
        'transcript-summary-regenerate':
            'POST /api/v1/transcript-summary/{consultationId}/regenerate',
      },
      'notes': [
        'Speech-to-text is app-side only.',
        'This backend accepts already-transcribed text.',
        'LLM adapter: StubLlmAdapter (on-device, no API keys required).',
      ],
    },
  );
}
