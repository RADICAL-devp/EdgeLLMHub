/// Port for generating text embeddings used by the vector store.
///
/// The vector store contract fixes the embedding dimension at 960
/// (SmolLM-360M hidden size). Implementations must return normalized
/// 960-dimensional vectors.
abstract class EmbeddingService {
  /// Embed a single text into a normalized 960-dim vector.
  Future<List<double>> embed(String text);

  /// Embed multiple texts in one batch.
  Future<List<List<double>>> embedBatch(List<String> texts);
}

/// Thrown when an embedding backend fails and no fallback is available.
class EmbeddingException implements Exception {
  const EmbeddingException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'EmbeddingException: $message';
}
