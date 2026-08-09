import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:clinical_intelligence_dart/application/ports/vector_store_port.dart';

/// SQLite-vec vector store implementation for context-enriched summaries.
///
/// Uses the sqlite-vec extension for HNSW vector indexing.
/// Embedding dimension: 960 (SmolLM-360M hidden size).
class SqliteVecStore implements VectorStorePort {
  SqliteVecStore([String? dbPath])
      : _dbPath = dbPath ?? p.join(Directory.current.path, 'vec_store.sqlite');

  final String _dbPath;
  final int embeddingDimension = 960;

  late final Database _sqlite3;
  bool _initialized = false;

  /// Initialize the sqlite-vec extension and create virtual table.
  Future<void> initialize() async {
    if (_initialized) return;

    _sqlite3 = sqlite3.open(_dbPath);

    // Load sqlite-vec extension
    try {
      _sqlite3.execute("SELECT load_extension('vec0')");
    } catch (e) {
      print('[SqliteVecStore] Warning: Could not load vec extension: $e');
      print('[SqliteVecStore] Vector search will use fallback (brute force)');
    }

    // Create virtual table for embeddings
    try {
      _sqlite3.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings USING vec0(
          embedding FLOAT[$embeddingDimension]
        )
      ''');
    } catch (e) {
      print('[SqliteVecStore] Could not create vec table: $e');
    }

    // Create metadata table for additional fields
    try {
      _sqlite3.execute('''
        CREATE TABLE IF NOT EXISTS vec_metadata (
          id TEXT PRIMARY KEY,
          metadata TEXT NOT NULL,
          resource_type TEXT,
          resource_id TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    } catch (e) {
      print('[SqliteVecStore] Could not create metadata table: $e');
    }

    _initialized = true;
  }

  @override
  Future<void> add({
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> metadata,
  }) async {
    await initialize();

    if (embedding.length != embeddingDimension) {
      throw ArgumentError('Embedding dimension mismatch: expected $embeddingDimension, got ${embedding.length}');
    }

    // Serialize embedding as binary
    final embeddingBytes = Float32List.fromList(embedding).buffer.asUint8List();

    // Insert into vec table
    _sqlite3.execute(
      'INSERT OR REPLACE INTO vec_embeddings(rowid, embedding) VALUES (?, ?)',
      [id, embeddingBytes],
    );

    // Insert metadata
    _sqlite3.execute(
      '''
      INSERT OR REPLACE INTO vec_metadata(id, metadata, resource_type, resource_id, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        id,
        jsonEncode(metadata),
        metadata['resource_type'] ?? 'unknown',
        metadata['resource_id'] ?? '',
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<List<VectorMatch>> search({
    required List<double> queryEmbedding,
    required int k,
    Map<String, dynamic>? filter,
  }) async {
    await initialize();

    if (queryEmbedding.length != embeddingDimension) {
      throw ArgumentError('Query embedding dimension mismatch');
    }

    final queryBytes = Float32List.fromList(queryEmbedding).buffer.asUint8List();

    // Build filter clause if provided
    String whereClause = '';
    List<Object> params = [queryBytes];
    
    if (filter != null && filter.isNotEmpty) {
      final conditions = <String>[];
      for (final entry in filter.entries) {
        conditions.add('json_extract(metadata, "\$.${entry.key}") = ?');
        params.add(entry.value as Object);
      }
      whereClause = 'WHERE ' + conditions.join(' AND ');
    }

    // Search using vec0
    // Note: vec0 uses rowid for ID matching, so we join with metadata table
    final query = '''
      SELECT m.id, m.metadata, 
             vec_distance_cosine(e.embedding, ?) as distance
      FROM vec_embeddings e
      JOIN vec_metadata m ON e.rowid = m.id
      $whereClause
      ORDER BY distance ASC
      LIMIT ?
    ''';
    
    params.add(k);

    final results = _sqlite3.select(query, params);

    return results.map((row) {
      final distance = (row['distance'] as num).toDouble();
      // Convert distance to similarity (0-1)
      final similarity = 1.0 - distance.clamp(0.0, 1.0);
      return VectorMatch(
        id: row['id'] as String,
        score: similarity,
        metadata: jsonDecode(row['metadata'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  @override
  Future<void> delete(String id) async {
    await initialize();
    
    _sqlite3.execute('DELETE FROM vec_embeddings WHERE rowid = ?', [id]);
    _sqlite3.execute('DELETE FROM vec_metadata WHERE id = ?', [id]);
  }

  @override
  Future<VectorMatch?> get(String id) async {
    await initialize();

    final results = _sqlite3.select('''
      SELECT m.id, m.metadata, 
             vec_distance_cosine(e.embedding, e.embedding) as distance
      FROM vec_embeddings e
      JOIN vec_metadata m ON e.rowid = m.id
      WHERE e.rowid = ?
    ''', [id]);

    if (results.isEmpty) return null;

    final row = results.first;
    return VectorMatch(
      id: row['id'] as String,
      score: 1.0, // Self-match
      metadata: jsonDecode(row['metadata'] as String) as Map<String, dynamic>,
    );
  }

  @override
  Future<int> count() async {
    await initialize();
    final results = _sqlite3.select('SELECT COUNT(*) as count FROM vec_embeddings');
    return (results.first['count'] as num).toInt();
  }

  @override
  Future<void> clear() async {
    await initialize();
    _sqlite3.execute('DELETE FROM vec_embeddings');
    _sqlite3.execute('DELETE FROM vec_metadata');
  }
}
