import 'dart:async';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Medical knowledge base retriever using sqlite-vec.
///
/// Implements RAG (Retrieval-Augmented Generation) by compressing
/// medical textbooks/PubMed snippets into ~20MB SQLite vector store.
class MedicalKnowledgeRetriever {
  static final MedicalKnowledgeRetriever _instance = MedicalKnowledgeRetriever._internal();
  factory MedicalKnowledgeRetriever() => _instance;
  MedicalKnowledgeRetriever._internal();

  Database? _database;

  Future<void> initialize() async {
    final dbPath = path.join(
      await getApplicationDocumentsDirectory().then((d) => d.path),
      'assets/knowledge/medical_db.sqlite',
    );
    _database = sqlite3.open(dbPath);
    _ensureTables();
  }

  void _ensureTables() {
    _database!.execute(
      'CREATE TABLE IF NOT EXISTS medical_chunks ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'chunk_text TEXT NOT NULL, '
      'embedding BLOB, '
      'specialty TEXT, '
      'source TEXT'
      ')'
    );
  }

  Future<List<String>> retrieve(String query, {int limit = 3}) async {
    if (_database == null) await initialize();
    // Simple text-based retrieval; in production, use vector similarity
    final results = await _database!.select(
      'SELECT chunk_text FROM medical_chunks WHERE chunk_text LIKE ? LIMIT ?',
      ['%$query%', limit],
    );
    return results.map((row) => row['chunk_text'] as String).toList();
  }

  void dispose() {
    _database?.dispose();
    _database = null;
  }
}
