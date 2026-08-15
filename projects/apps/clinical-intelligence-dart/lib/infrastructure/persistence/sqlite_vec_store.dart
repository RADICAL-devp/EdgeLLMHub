import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:clinical_intelligence_dart/application/ports/vector_store_port.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

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
  bool _vecAvailable = false;

  /// Filename of the sqlite-vec loadable extension for the host platform,
  /// as installed by `scripts/build_sqlite_vec.sh`.
  static String? get _vecExtensionFileName {
    if (Platform.isMacOS) return 'vec0.dylib';
    if (Platform.isLinux) return 'vec0.so';
    return null;
  }

  /// Candidate package roots, used to locate the bundled vec extension.
  static List<String> _packageRootCandidates() {
    final candidates = <String>[Directory.current.path];
    var dir = File(Platform.script.toFilePath()).parent;
    while (dir.path != dir.parent.path) {
      candidates.add(dir.path);
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) break;
      dir = dir.parent;
    }
    return candidates;
  }

  /// Absolute path of the sqlite-vec extension bundled with this package, or
  /// `null` when it has not been built for the host platform.
  ///
  /// The extension lives at `lib/infrastructure/persistence/vec_ext/` with a
  /// platform-specific name (`vec0.dylib` on macOS, `vec0.so` on Linux) and is
  /// installed by `scripts/build_sqlite_vec.sh`.
  @visibleForTesting
  static String? resolveVecExtensionPath() {
    final fileName = _vecExtensionFileName;
    if (fileName == null) return null;
    for (final root in _packageRootCandidates()) {
      final candidate =
          p.join(root, 'lib', 'infrastructure', 'persistence', 'vec_ext', fileName);
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Keeps the loaded vec extension alive for the process lifetime (Dart
  /// dlcloses a [DynamicLibrary] when it is garbage collected, which would
  /// leave the registered auto-extension entrypoint dangling).
  static late DynamicLibrary? _vecLibrary;

  /// Loads the sqlite-vec extension so HNSW search is available.
  ///
  /// The extension is registered via `sqlite3_auto_extension` (through
  /// [Sqlite3.ensureExtensionLoaded]), so it must be called before the
  /// database connection is opened. Brute-force search is kept as a fallback
  /// when the extension is missing or the host SQLite was built without
  /// dynamic extension support.
  void _loadVecExtension() {
    final extensionPath = resolveVecExtensionPath();
    if (extensionPath == null) {
      print('[SqliteVecStore] vec extension not found; '
          'run scripts/build_sqlite_vec.sh to enable HNSW search');
      print('[SqliteVecStore] Vector search will use fallback (brute force)');
      return;
    }
    try {
      _vecLibrary = DynamicLibrary.open(extensionPath);
      sqlite3.ensureExtensionLoaded(
        SqliteExtension.inLibrary(_vecLibrary!, 'sqlite3_vec_init'),
      );
      _vecAvailable = true;
      print('[SqliteVecStore] Loaded vec extension from $extensionPath');
    } catch (e) {
      print('[SqliteVecStore] Warning: Could not load vec extension '
          '($extensionPath): $e');
      print('[SqliteVecStore] Vector search will use fallback (brute force)');
    }
  }

  /// Initialize the sqlite-vec extension and create virtual table.
  Future<void> initialize() async {
    if (_initialized) return;

    // Load the extension before opening the connection so it is auto-
    // registered on the new connection.
    _loadVecExtension();

    _sqlite3 = sqlite3.open(_dbPath);

    // Create virtual table for embeddings (enables HNSW search when vec0 is present)
    if (_vecAvailable) {
      try {
        _sqlite3.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings USING vec0(
            embedding FLOAT[$embeddingDimension]
          )
        ''');
      } catch (e) {
        print('[SqliteVecStore] Could not create vec table: $e');
        _vecAvailable = false;
      }
    }

    // Plain-table fallback: used when sqlite-vec is unavailable.
    try {
      _sqlite3.execute('''
        CREATE TABLE IF NOT EXISTS vec_embeddings_fallback (
          id TEXT PRIMARY KEY,
          embedding BLOB NOT NULL
        )
      ''');
    } catch (e) {
      print('[SqliteVecStore] Could not create fallback table: $e');
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

    // Insert into vec table (or fallback table when vec0 is unavailable)
    if (_vecAvailable) {
      _sqlite3.execute(
        'INSERT OR REPLACE INTO vec_embeddings(rowid, embedding) VALUES (?, ?)',
        [id, embeddingBytes],
      );
    } else {
      _sqlite3.execute(
        'INSERT OR REPLACE INTO vec_embeddings_fallback(id, embedding) VALUES (?, ?)',
        [id, embeddingBytes],
      );
    }

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

  /// Whether sqlite-vec (HNSW) is in use rather than brute-force fallback.
  bool get usingHnsw => _vecAvailable;

  /// Close the underlying database connection (releases the file handle).
  Future<void> close() async {
    if (_initialized) {
      _sqlite3.dispose();
      _initialized = false;
    }
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

    if (_vecAvailable) {
      return _searchHnsw(
        queryEmbedding: queryEmbedding,
        k: k,
        filter: filter,
      );
    }
    return _searchBruteForce(
      queryEmbedding: queryEmbedding,
      k: k,
      filter: filter,
    );
  }

  Future<List<VectorMatch>> _searchHnsw({
    required List<double> queryEmbedding,
    required int k,
    Map<String, dynamic>? filter,
  }) async {
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

  Future<List<VectorMatch>> _searchBruteForce({
    required List<double> queryEmbedding,
    required int k,
    Map<String, dynamic>? filter,
  }) async {
    var rows = _sqlite3.select('''
      SELECT id, embedding FROM vec_embeddings_fallback
    ''');

    final candidates = <({String id, Uint8List embedding})>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final embedding = row['embedding'] as Uint8List;

      if (filter != null && filter.isNotEmpty) {
        final metaRows = _sqlite3.select(
          'SELECT metadata FROM vec_metadata WHERE id = ?',
          [id],
        );
        final metadata = metaRows.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(metaRows.first['metadata'] as String)
                as Map<String, dynamic>;
        final matches = filter.entries.every(
          (entry) => metadata[entry.key] == entry.value,
        );
        if (!matches) continue;
      }

      candidates.add((id: id, embedding: embedding));
    }

    candidates.sort((a, b) {
      final da = _cosineDistance(queryEmbedding, a.embedding);
      final db = _cosineDistance(queryEmbedding, b.embedding);
      return da.compareTo(db);
    });

    final results = <VectorMatch>[];
    for (final candidate in candidates.take(k)) {
      final distance = _cosineDistance(queryEmbedding, candidate.embedding);
      final similarity = 1.0 - distance.clamp(0.0, 1.0);
      final metaRows = _sqlite3.select(
        'SELECT metadata FROM vec_metadata WHERE id = ?',
        [candidate.id],
      );
      final metadata = metaRows.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(metaRows.first['metadata'] as String)
              as Map<String, dynamic>;
      results.add(
        VectorMatch(id: candidate.id, score: similarity, metadata: metadata),
      );
    }
    return results;
  }

  double _cosineDistance(List<double> query, Uint8List bytes) {
    final other = Float32List.view(bytes.buffer, bytes.offsetInBytes, bytes.length ~/ 4).toList();
    double dot = 0, normQ = 0, normO = 0;
    for (var i = 0; i < query.length; i++) {
      dot += query[i] * other[i];
      normQ += query[i] * query[i];
      normO += other[i] * other[i];
    }
    if (normQ == 0 || normO == 0) return 1.0;
    return 1.0 - (dot / (sqrt(normQ) * sqrt(normO)));
  }

  @override
  Future<void> delete(String id) async {
    await initialize();

    if (_vecAvailable) {
      _sqlite3.execute('DELETE FROM vec_embeddings WHERE rowid = ?', [id]);
    }
    _sqlite3.execute('DELETE FROM vec_embeddings_fallback WHERE id = ?', [id]);
    _sqlite3.execute('DELETE FROM vec_metadata WHERE id = ?', [id]);
  }

  @override
  Future<VectorMatch?> get(String id) async {
    await initialize();

    if (!_vecAvailable) {
      final rows = _sqlite3.select(
        'SELECT id, embedding FROM vec_embeddings_fallback WHERE id = ?',
        [id],
      );
      if (rows.isEmpty) return null;
      final metaRows = _sqlite3.select(
        'SELECT metadata FROM vec_metadata WHERE id = ?',
        [id],
      );
      final metadata = metaRows.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(metaRows.first['metadata'] as String)
              as Map<String, dynamic>;
      return VectorMatch(
        id: id,
        score: 1.0,
        metadata: metadata,
      );
    }

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
    String query;
    if (_vecAvailable) {
      query = '''
        SELECT COUNT(*) as count FROM (
          SELECT rowid as id FROM vec_embeddings
          UNION ALL
          SELECT id FROM vec_embeddings_fallback
        )
      ''';
    } else {
      query = 'SELECT COUNT(*) as count FROM vec_embeddings_fallback';
    }
    final results = _sqlite3.select(query);
    return (results.first['count'] as num).toInt();
  }

  @override
  Future<void> clear() async {
    await initialize();
    if (_vecAvailable) {
      _sqlite3.execute('DELETE FROM vec_embeddings');
    }
    _sqlite3.execute('DELETE FROM vec_embeddings_fallback');
    _sqlite3.execute('DELETE FROM vec_metadata');
  }
}
