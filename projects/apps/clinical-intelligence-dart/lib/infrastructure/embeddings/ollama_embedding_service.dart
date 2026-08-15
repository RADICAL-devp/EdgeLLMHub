import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clinical_intelligence_dart/application/ports/embedding_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/embeddings/hash_embedding_service.dart';

/// Embedding service backed by a locally running Ollama instance
/// (POST /api/embed), projecting any model output to the 960-dim
/// contract of the vector store.
///
/// Projection: if the model's output dimension differs from 960, the
/// vector is averaged-pooled (larger) or zero-padded (smaller), then
/// normalized. This is a placeholder until a true 960-dim embedding
/// model (SmolLM-360M hidden size) is available; semantic quality is
/// best when OLLAMA_EMBEDDING_MODEL outputs exactly 960 dims.
class OllamaEmbeddingService implements EmbeddingService {
  OllamaEmbeddingService({
    this.baseUrl = 'http://127.0.0.1:11434',
    this.model = 'nomic-embed-text',
    this.targetDimension = 960,
    EmbeddingService? fallback,
  }) : _fallback = fallback ?? HashEmbeddingService(dimension: targetDimension);

  final String baseUrl;
  final String model;
  final int targetDimension;
  final EmbeddingService _fallback;

  @override
  Future<List<double>> embed(String text) async {
    final batch = await embedBatch([text]);
    return batch.first;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (texts.isEmpty) return const [];

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/embed'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'model': model, 'input': texts}));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw EmbeddingException(
          'Ollama embed error (${response.statusCode}): $body',
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawEmbeddings = (json['embeddings'] as List<dynamic>)
          .map((e) => (e as List<dynamic>)
              .map((x) => (x as num).toDouble())
              .toList())
          .toList();

      return rawEmbeddings.map(_projectToTarget).toList();
    } on EmbeddingException {
      rethrow;
    } catch (e) {
      // Fall back to deterministic hashing so the vector store keeps working.
      return _fallback.embedBatch(texts);
    } finally {
      client.close();
    }
  }

  /// Project any-dimension vector to [targetDimension] and normalize.
  List<double> _projectToTarget(List<double> vector) {
    if (vector.length == targetDimension) return _normalize(vector);
    if (vector.length > targetDimension) {
      final pooled = <double>[];
      final bucket = vector.length / targetDimension;
      for (var i = 0; i < targetDimension; i++) {
        final start = (i * bucket).floor();
        final end = ((i + 1) * bucket).ceil().clamp(start + 1, vector.length);
        var sum = 0.0;
        for (var j = start; j < end; j++) {
          sum += vector[j];
        }
        pooled.add(sum / (end - start));
      }
      return _normalize(pooled);
    }
    final padded = List<double>.from(vector)
      ..addAll(List<double>.filled(targetDimension - vector.length, 0));
    return _normalize(padded);
  }

  List<double> _normalize(List<double> v) {
    final norm = math.sqrt(v.fold<double>(0, (a, b) => a + b * b));
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }
}
