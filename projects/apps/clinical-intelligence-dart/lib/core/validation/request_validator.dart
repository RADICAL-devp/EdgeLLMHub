import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:json_schema/json_schema.dart';

/// JSON Schema (draft 2020-12) definitions for all request bodies.
abstract final class RequestSchemas {
  /// POST /api/v1/clinical-processing/process
  static const Map<String, dynamic> clinicalProcess = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['inputText', 'processingMode'],
    'properties': {
      'inputText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
        'description': 'Raw clinical text to process.',
      },
      'processingMode': {
        'type': 'string',
        'enum': [
          'VOCAB_ASSIST',
          'CLEAN_TRANSCRIPT',
          'SUMMARIZE',
          'GENERATE_DOCTOR_NOTE',
          'FULL_BUNDLE',
        ],
      },
      'consultationId': {'type': 'string'},
      'patientId': {'type': 'string'},
      'doctorId': {'type': 'string'},
      'consultationMode': {
        'type': 'string',
        'enum': ['IN_PERSON', 'ONLINE'],
      },
      'source': {'type': 'string'},
    },
  };

  /// POST /api/v1/transcript-summary/generate
  static const Map<String, dynamic> summaryBundle = {
    'type': 'object',
    'required': [
      'consultationId',
      'patientId',
      'doctorId',
      'transcriptText',
    ],
    'properties': {
      'consultationId': {'type': 'string', 'minLength': 1},
      'patientId': {'type': 'string', 'minLength': 1},
      'doctorId': {'type': 'string', 'minLength': 1},
      'sleepLabId': {'type': 'string'},
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'consultationMode': {
        'type': 'string',
        'enum': ['IN_PERSON', 'ONLINE'],
      },
    },
  };

  /// POST /api/v1/transcript-summary/structured
  static const Map<String, dynamic> structuredSummary = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
    },
  };

  /// POST /api/v1/transcript-summary/context-enriched
  static const Map<String, dynamic> contextEnriched = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'pastContext': {
        'type': 'string',
        'maxLength': 10000000,
        'description': 'Optional. When omitted, similar past consultations are '
            'retrieved automatically from the vector store.',
      },
    },
  };

  /// POST /api/v1/transcript-summary/doctor-note
  static const Map<String, dynamic> doctorNote = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'consultationId': {'type': 'string'},
      'patientId': {'type': 'string'},
      'doctorId': {'type': 'string'},
    },
  };

  /// POST /api/v1/transcript-summary/executive
  static const Map<String, dynamic> executiveSummary = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
    },
  };

  /// POST /api/v1/notes/sync
  static const Map<String, dynamic> notesSync = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'noteId',
      'consultationId',
      'createdAt',
      'updatedAt',
    ],
    'properties': {
      'noteId': {'type': 'string', 'minLength': 1},
      'consultationId': {'type': 'string', 'minLength': 1},
      'patientId': {'type': 'string'},
      'doctorId': {'type': 'string'},
      'rawText': {'type': 'string'},
      'richTextDelta': {'type': 'string'},
      'status': {'type': 'string'},
      'patientRecap': {'type': 'string'},
      'extractedFields': {
        'type': 'object',
        'properties': {
          'symptoms': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'duration': {'type': 'string'},
          'medications': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'allergies': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'testsRecommended': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'followUpActions': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'provisionalDiagnosis': {'type': 'string'},
        },
      },
      'createdAt': {'type': 'string', 'format': 'date-time'},
      'updatedAt': {'type': 'string', 'format': 'date-time'},
    },
  };

  // ============ EHR ASSISTANCE ROUTES ============

  /// POST /api/v1/ehr/field-suggestion
  static const Map<String, dynamic> ehrFieldSuggestion = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText', 'fieldName'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'fieldName': {
        'type': 'string',
        'enum': [
          'complaint',
          'pastHistory',
          'vitals',
          'physicalExamination',
          'investigationOrdered',
          'diagnosis',
          'advice',
          'manualPrescription',
        ],
      },
      'patientContext': {
        'type': 'object',
        'properties': {
          'patientName': {'type': 'string'},
          'sleepLab': {'type': 'string'},
          'consultationDate': {'type': 'string'},
          'patientId': {'type': 'string'},
          'age': {'type': 'integer'},
          'gender': {'type': 'string'},
          'referringDoctor': {'type': 'string'},
        },
      },
    },
  };

  /// POST /api/v1/ehr/stream-field
  static const Map<String, dynamic> ehrStreamField = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText', 'fieldName'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'fieldName': {
        'type': 'string',
        'enum': [
          'complaint',
          'pastHistory',
          'vitals',
          'physicalExamination',
          'investigationOrdered',
          'diagnosis',
          'advice',
          'manualPrescription',
        ],
      },
      'patientContext': {
        'type': 'object',
        'properties': {
          'patientName': {'type': 'string'},
          'sleepLab': {'type': 'string'},
          'consultationDate': {'type': 'string'},
          'patientId': {'type': 'string'},
          'age': {'type': 'integer'},
          'gender': {'type': 'string'},
          'referringDoctor': {'type': 'string'},
        },
      },
    },
  };

  /// POST /api/v1/ehr/full-summary
  static const Map<String, dynamic> ehrFullSummary = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['transcriptText'],
    'properties': {
      'transcriptText': {
        'type': 'string',
        'minLength': 1,
        'pattern': '\\S',
        'maxLength': 10000000,
      },
      'fieldNames': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': [
            'complaint',
            'pastHistory',
            'vitals',
            'physicalExamination',
            'investigationOrdered',
            'diagnosis',
            'advice',
            'manualPrescription',
          ],
        },
        'minItems': 1,
        'maxItems': 8,
      },
      'patientContext': {
        'type': 'object',
        'properties': {
          'patientName': {'type': 'string'},
          'sleepLab': {'type': 'string'},
          'consultationDate': {'type': 'string'},
          'patientId': {'type': 'string'},
          'age': {'type': 'integer'},
          'gender': {'type': 'string'},
          'referringDoctor': {'type': 'string'},
        },
      },
    },
  };
}

/// Validates POST request bodies against a JSON Schema.
///
/// Apply per route:
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   return jsonSchemaValidation(RequestSchemas.structuredSummary)(
///     (ctx) => requireAuth(...)(ctx),
///   )(context);
/// }
/// ```
///
/// Returns 400 with `{"error": "...", "errors": [...]}` on validation
/// failure; passes through otherwise. Non-POST requests pass through
/// untouched so method handling stays in the route handler.
Middleware jsonSchemaValidation(Map<String, dynamic> schema) {
  return (handler) {
    return (context) async {
      if (context.request.method != HttpMethod.post) {
        return handler(context);
      }

      Map<String, dynamic> json;
      try {
        final body = await context.request.body();
        if (body.isEmpty) {
          return _jsonError('Request body is required.');
        }
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException catch (e) {
        return _jsonError('Invalid JSON: ${e.message}');
      } on TypeError {
        return _jsonError('Request body must be a JSON object.');
      }

      final validator = JsonSchema.create(schema);
      final results = validator.validate(json);
      if (!results.isValid) {
        return _jsonError(
          'Request body failed schema validation.',
          errors: results.errors
              .map(
                (e) =>
                    '${e.instancePath.isEmpty ? '# (root)' : e.instancePath}: '
                    '${e.message}',
              )
              .toList(),
        );
      }

      return handler(context);
    };
  };
}

Response _jsonError(String message, {List<String> errors = const []}) {
  return Response(
    statusCode: HttpStatus.badRequest,
    body: jsonEncode({
      'error': message,
      if (errors.isNotEmpty) 'errors': errors,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
