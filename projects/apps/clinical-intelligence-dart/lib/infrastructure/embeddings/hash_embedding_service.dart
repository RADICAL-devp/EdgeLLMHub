import 'dart:math' as math;

import '../../application/ports/embedding_service.dart';

/// Deterministic, dependency-free embedding service.
///
/// Produces reproducible normalized 960-dim vectors using a salted hash
/// of the input text. Suitable for development, CI, and as a fallback
/// when no embedding model is configured.
///
/// In production, replace with a real embedding model (e.g. SmolLM-360M
/// sentence embeddings via the Python bridge, or Ollama embeddings).
class HashEmbeddingService implements EmbeddingService {
  HashEmbeddingService({this.dimension = 960});

  final int dimension;

  @override
  Future<List<double>> embed(String text) async => _embedText(text, dimension);

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async =>
      texts.map((t) => _embedText(t, dimension)).toList();

  List<double> _embedText(String text, int dim) {
    final hash =
        text.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final raw = List<double>.generate(dim, (i) {
      // Deterministic pseudo-random value in [0, 1) from the hash + index.
      final seed = (hash * (i + 1) * 16807) % 2147483647;
      return seed / 2147483647.0;
    });
    return _normalize(raw);
  }

  List<double> _normalize(List<double> v) {
    final norm = math.sqrt(v.fold<double>(0, (a, b) => a + b * b));
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }
}
