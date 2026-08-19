import 'dart:io';

import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';

/// Generates an OpenAPI 3.1 specification from the route registry and the
/// request/response DTO schemas.
///
/// Usage:
///   dart run bin/generate_openapi.dart [--out openapi.yaml]
///
/// The generated spec is deterministic and committed so it can be served
/// statically, imported into API tooling, and diffed across changes.
void main(List<String> args) {
  final outPath =
      args.contains('--out') ? args[args.indexOf('--out') + 1] : 'openapi.yaml';

  final spec = _buildSpec();

  final out = File(outPath);
  out.writeAsStringSync(_toYaml(spec));
  stdout
    ..writeln('✅ Wrote OpenAPI 3.1 spec to ${out.path}')
    ..writeln('   Paths:  ${(spec['paths'] as Map).length}')
    ..writeln(
      '   Schemas: ${((spec['components'] as Map)['schemas'] as Map).length}',
    );
}

Map<String, dynamic> _buildSpec() {
  return {
    'openapi': '3.1.0',
    'info': {
      'title': 'Clinical Intelligence Backend',
      'description':
          'Clinical text processing (voice-notes workflow) and transcript '
              'summarization APIs. All endpoints except /api/v1/auth/token '
              'require a Bearer JWT (see auth/token).',
      'version': '0.1.0',
    },
    'servers': [
      {'url': 'http://localhost:8080', 'description': 'Local development'},
    ],
    'tags': [
      {'name': 'Auth', 'description': 'Token minting (dev only)'},
      {'name': 'Clinical Processing', 'description': 'Voice-notes workflow'},
      {'name': 'Transcript Summary', 'description': 'AI summarization API'},
      {'name': 'Notes', 'description': 'Doctor note sync'},
    ],
    'paths': _paths(),
    'components': {
      'securitySchemes': {
        'bearerAuth': {
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': 'JWT',
        },
      },
      'schemas': _schemas(),
    },
    'security': [
      {'bearerAuth': <Object>[]},
    ],
  };
}

Map<String, dynamic> _paths() {
  return {
    '/api/v1/auth/token': {
      'post': {
        'tags': ['Auth'],
        'operationId': 'authToken',
        'summary': 'Mint a development JWT (disabled when '
            'DISABLE_DEV_AUTH=true)',
        'security': <Object>[],
        'responses': {
          '200': {
            'description': 'Signed access token',
            'content': _jsonSchemaRef('TokenResponse'),
          },
          '404': {'description': 'Dev auth disabled'},
        },
      },
    },
    '/api/v1/clinical-processing/process': {
      'post': {
        'tags': ['Clinical Processing'],
        'operationId': 'clinicalProcess',
        'summary': 'Process clinical text in a given mode '
            '(VOCAB_ASSIST, CLEAN_TRANSCRIPT, SUMMARIZE, '
            'GENERATE_DOCTOR_NOTE)',
        'requestBody': _jsonSchemaRef('ClinicalProcessingRequest'),
        'responses': {
          '200': {
            'description': 'Processed text',
            'content': _jsonSchemaRef('ClinicalProcessingResponse'),
          },
          '400': _errorRef('Validation failure'),
          '401': _errorRef('Missing or invalid token'),
        },
      },
    },
    '/api/v1/transcript-summary/structured': {
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'structuredSummary',
        'summary': 'Generate a 7-field structured clinical summary',
        'requestBody': _jsonSchemaRef('StructuredSummaryRequest'),
        'responses': {
          '200': {
            'description': 'Structured summary',
            'content': _jsonSchemaRef('StructuredSummary'),
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/transcript-summary/context-enriched': {
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'contextEnrichedSummary',
        'summary': 'Generate a structured summary using past consultation '
            'context; when pastContext is omitted it is retrieved from the '
            'vector store',
        'requestBody': _jsonSchemaRef('ContextEnrichedRequest'),
        'responses': {
          '200': {
            'description': 'Structured summary',
            'content': _jsonSchemaRef('StructuredSummary'),
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/transcript-summary/executive': {
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'executiveSummary',
        'summary': 'Generate an executive summary',
        'requestBody': _jsonSchemaRef('TranscriptTextRequest'),
        'responses': {
          '200': {
            'description': 'Executive summary',
            'content': _jsonSchemaRef('TextResponse')
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/transcript-summary/doctor-note': {
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'doctorNote',
        'summary': 'Generate a doctor note',
        'requestBody': _jsonSchemaRef('DoctorNoteRequest'),
        'responses': {
          '200': {
            'description': 'Doctor note text',
            'content': _jsonSchemaRef('TextResponse')
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/transcript-summary/generate': {
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'generateSummaryBundle',
        'summary': 'Generate a full summary bundle (structured summary, '
            'doctor note) and seed the vector store with the consultation',
        'requestBody': _jsonSchemaRef('SummaryBundleRequest'),
        'responses': {
          '200': {
            'description': 'Generated summary bundle',
            'content': _jsonSchemaRef('TranscriptSummaryResponse'),
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/transcript-summary/{consultationId}': {
      'get': {
        'tags': ['Transcript Summary'],
        'operationId': 'getSummaryBundle',
        'summary': 'Fetch a generated summary bundle',
        'parameters': [
          {
            'name': 'consultationId',
            'in': 'path',
            'required': true,
            'schema': {'type': 'string'},
          },
        ],
        'responses': {
          '200': {
            'description': 'Summary bundle',
            'content': _jsonSchemaRef('TranscriptSummaryResponse'),
          },
          '404': _errorRef('No summary for consultation'),
        },
      },
      'post': {
        'tags': ['Transcript Summary'],
        'operationId': 'regenerateSummary',
        'summary': 'Regenerate the summary for an existing transcript',
        'parameters': [
          {
            'name': 'consultationId',
            'in': 'path',
            'required': true,
            'schema': {'type': 'string'},
          },
        ],
        'responses': {
          '200': {
            'description': 'Regenerated summary bundle',
            'content': _jsonSchemaRef('TranscriptSummaryResponse'),
          },
          '404': _errorRef('No transcript for consultation'),
        },
      },
    },
    '/api/v1/notes/sync': {
      'post': {
        'tags': ['Notes'],
        'operationId': 'syncNote',
        'summary': 'Upsert a doctor note (last-write-wins)',
        'requestBody': _jsonSchemaRef('NotesSyncRequest'),
        'responses': {
          '200': {
            'description': 'Sync acknowledgement',
            'content': _jsonSchemaRef('SyncResponse'),
          },
          '400': _errorRef('Validation failure'),
        },
      },
    },
    '/api/v1/notes/consultation/{consultationId}': {
      'get': {
        'tags': ['Notes'],
        'operationId': 'getNote',
        'summary': 'Fetch the most recent synced note for a consultation',
        'parameters': [
          {
            'name': 'consultationId',
            'in': 'path',
            'required': true,
            'schema': {'type': 'string'},
          },
        ],
        'responses': {
          '200': {
            'description': 'Doctor note',
            'content': _jsonSchemaRef('DoctorNoteModel'),
          },
          '404': _errorRef('No note for consultation'),
        },
      },
    },
    '/': {
      'get': {
        'tags': ['System'],
        'operationId': 'health',
        'summary': 'Service health check',
        'responses': {
          '200': {'description': 'Service is up'},
        },
      },
    },
  };
}

Map<String, dynamic> _schemas() {
  final requests = {
    'ClinicalProcessingRequest': RequestSchemas.clinicalProcess,
    'StructuredSummaryRequest': RequestSchemas.structuredSummary,
    'ContextEnrichedRequest': RequestSchemas.contextEnriched,
    'DoctorNoteRequest': RequestSchemas.doctorNote,
    'TranscriptTextRequest': RequestSchemas.executiveSummary,
    'NotesSyncRequest': RequestSchemas.notesSync,
    'SummaryBundleRequest': RequestSchemas.summaryBundle,
  };

  final responses = {
    'TokenResponse': {
      'type': 'object',
      'properties': {
        'token': {'type': 'string'},
        'tokenType': {
          'type': 'string',
          'enum': ['Bearer']
        },
        'expiresAt': {'type': 'string', 'format': 'date-time'},
        'scopes': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    },
    'ClinicalProcessingResponse': {
      'type': 'object',
      'properties': {
        'processedText': {'type': 'string'},
        'processingMode': {'type': 'string'},
        'warnings': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'generatedAt': {'type': 'string', 'format': 'date-time'},
        'metadata': {'type': 'object'},
      },
    },
    'StructuredSummary': {
      'type': 'object',
      'properties': {
        'complaint': {
          'type': ['string', 'null']
        },
        'pastHistory': {
          'type': ['string', 'null']
        },
        'vitals': {
          'type': ['string', 'null']
        },
        'physicalExamination': {
          'type': ['string', 'null']
        },
        'investigationOrdered': {
          'type': ['string', 'null']
        },
        'diagnosis': {
          'type': ['string', 'null']
        },
        'advice': {
          'type': ['string', 'null']
        },
      },
    },
    'TextResponse': {
      'type': 'object',
      'properties': {
        'note': {'type': 'string'},
        'summary': {'type': 'string'},
      },
    },
    'SyncResponse': {
      'type': 'object',
      'properties': {
        'synced': {'type': 'boolean'},
        'noteId': {'type': 'string'},
      },
    },
    'DoctorNoteModel': {
      'type': 'object',
      'properties': {
        'noteId': {'type': 'string'},
        'consultationId': {'type': 'string'},
        'patientId': {'type': 'string'},
        'doctorId': {'type': 'string'},
        'rawText': {'type': 'string'},
        'richTextDelta': {
          'type': ['string', 'null']
        },
        'status': {'type': 'string'},
        'patientRecap': {
          'type': ['string', 'null']
        },
        'createdAt': {'type': 'string', 'format': 'date-time'},
        'updatedAt': {'type': 'string', 'format': 'date-time'},
      },
    },
    'TranscriptSummaryResponse': {
      'type': 'object',
      'properties': {
        'consultationId': {'type': 'string'},
        'transcriptId': {'type': 'string'},
        'executiveSummary': {r'$ref': '#/components/schemas/StructuredSummary'},
        'structuredMedicalSummary': {
          r'$ref': '#/components/schemas/StructuredSummary',
        },
        'doctorNote': {r'$ref': '#/components/schemas/DoctorNoteModel'},
        'generatedAt': {'type': 'string', 'format': 'date-time'},
        'consultationMode': {
          'type': ['string', 'null']
        },
      },
    },
    'ErrorResponse': {
      'type': 'object',
      'properties': {
        'error': {'type': 'string'},
        'errors': {
          'type': ['array', 'null'],
          'items': {'type': 'string'},
        },
      },
    },
  };

  return {...requests, ...responses};
}

Map<String, dynamic> _jsonSchemaRef(String schemaName) {
  return {
    'required': true,
    'content': {
      'application/json': {
        'schema': {r'$ref': '#/components/schemas/$schemaName'},
      },
    },
  };
}

Map<String, dynamic> _errorRef(String description) {
  return {
    'description': description,
    'content': {
      'application/json': {
        'schema': {r'$ref': '#/components/schemas/ErrorResponse'},
      },
    },
  };
}

/// Minimal YAML emitter for the spec subset we use
/// (maps, lists, scalars, and `$ref` keys).
String _toYaml(dynamic value, [int indent = 0]) {
  final pad = ' ' * (indent * 2);
  final sb = StringBuffer();

  void emitScalar(Object? v) {
    if (v is bool) {
      sb.write(v ? 'true' : 'false');
    } else if (v is num) {
      sb.write('$v');
    } else if (v is String) {
      if (v.isEmpty) {
        sb.write("''");
      } else if (v.contains('\n')) {
        sb.write('|\n');
        for (final line in v.split('\n')) {
          sb.write('$pad  $line\n');
        }
      } else if (v.startsWith('{') ||
          v.startsWith('[') ||
          v.startsWith('#') ||
          v.contains(': ') ||
          v == 'true' ||
          v == 'false' ||
          v == 'null' ||
          v.contains(' #')) {
        sb.write("'${v.replaceAll("'", "''")}'");
      } else {
        sb.write(v);
      }
    } else {
      sb.write('null');
    }
  }

  void emit(dynamic val, int level) {
    final innerPad = ' ' * (level * 2);
    if (val is Map) {
      for (final entry in val.entries) {
        sb.write('$innerPad${_escapeKey(entry.key.toString())}:');
        final child = entry.value;
        if (child is Map && child.isNotEmpty) {
          sb.write('\n');
          emit(child, level + 1);
        } else if (child is List && child.isNotEmpty) {
          sb.write('\n');
          emit(child, level + 1);
        } else if (child is List) {
          sb.write(' []\n');
        } else {
          sb.write(' ');
          emitScalar(child);
          sb.write('\n');
        }
      }
    } else if (val is List) {
      for (final item in val) {
        if (item is Map) {
          final entries = item.entries.toList();
          final first = entries.first;
          final firstValue = first.value;
          sb.write('$innerPad- ${_escapeKey(first.key.toString())}:');
          if (firstValue is Map && firstValue.isNotEmpty) {
            sb.write('\n');
            emit(firstValue, level + 1);
          } else if (firstValue is List && firstValue.isNotEmpty) {
            sb.write('\n');
            emit(firstValue, level + 1);
          } else {
            sb.write(' ');
            emitScalar(firstValue);
            sb.write('\n');
          }
          if (entries.length > 1) {
            emit(Map.fromEntries(entries.skip(1)), level + 1);
          }
        } else {
          sb.write('$innerPad- ');
          emitScalar(item);
          sb.write('\n');
        }
      }
    } else {
      sb.write('$innerPad');
      emitScalar(val);
      sb.write('\n');
    }
  }

  emit(value, indent);
  return sb.toString();
}

String _escapeKey(String key) => key.startsWith(r'$') ? "'$key'" : key;
