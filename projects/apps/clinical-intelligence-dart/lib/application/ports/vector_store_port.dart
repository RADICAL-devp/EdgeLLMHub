/// Port for vector store operations (embeddings for context-enriched summaries).
abstract class VectorStorePort {
  /// Add an embedding with metadata.
  Future<void> add({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  });

  /// Search for similar embeddings.
  Future<List<VectorMatch>> search({
    required List<double> queryEmbedding,
    required int k,
    Map<String, dynamic>? filter,
  });

  /// Delete an embedding by ID.
  Future<void> delete(String id);

  /// Get embedding by ID.
  Future<VectorMatch?> get(String id);

  /// Count total embeddings.
  Future<int> count();

  /// Clear all embeddings (for testing).
  Future<void> clear();
}

/// Result of a vector search.
class VectorMatch {
  VectorMatch({
    required this.id,
    required this.score,
    required this.metadata,
    this.embedding,
  });

  final String id;
  final double score; // Cosine similarity (0-1)
  final Map<String, dynamic> metadata;
  final List<double>? embedding;

  Map<String, dynamic> toJson() => {
        'id': id,
        'score': score,
        'metadata': metadata,
        'embedding': embedding,
      };
}
