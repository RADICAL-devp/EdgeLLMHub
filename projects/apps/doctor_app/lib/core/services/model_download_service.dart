import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:doctor_app/core/models/download_progress.dart';

class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  final StreamController<DownloadProgress> _progressController = StreamController.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  Future<void> downloadModel({
    required String modelId,
    required String url,
    required String expectedChecksum,
    required String outputPath,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$modelId.temp');

      final response = await http.get(Uri.parse(url), headers: {'Accept': 'application/octet-stream'});

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final totalBytes = response.bodyBytes.length;
      int downloaded = 0;

      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await http.Client().send(request);

      final file = await tempFile.create();
      final sink = file.openWrite();

      streamedResponse.stream.listen(
        (List<int> chunk) async {
          downloaded += chunk.length;
          final progress = totalBytes > 0 ? downloaded / totalBytes : 0.0;
          _progressController.add(DownloadProgress(
            progress: progress,
            bytesDownloaded: downloaded,
            totalBytes: totalBytes,
            status: 'downloading',
          ));
          sink.add(chunk);
        },
        onDone: () async {
          await sink.close();
          _progressController.add(DownloadProgress(
            progress: 1.0,
            bytesDownloaded: totalBytes,
            totalBytes: totalBytes,
            status: 'verifying',
          ));

          final fileBytes = await tempFile.readAsBytes();
          final fileChecksum = sha256.convert(fileBytes).toString();
          if (fileChecksum != expectedChecksum) {
            await tempFile.delete();
            throw Exception('Checksum mismatch: expected $expectedChecksum, got $fileChecksum');
          }

          final finalFile = File(outputPath);
          await tempFile.rename(finalFile.path);

          _progressController.add(DownloadProgress(
            progress: 1.0,
            bytesDownloaded: totalBytes,
            totalBytes: totalBytes,
            status: 'complete',
          ));
        },
        onError: (e) {
          _progressController.add(DownloadProgress(
            progress: downloaded / totalBytes,
            bytesDownloaded: downloaded,
            totalBytes: totalBytes,
            status: 'error',
            errorMessage: e.toString(),
          ));
          tempFile.deleteSync();
        },
      );
    } catch (e) {
      _progressController.add(DownloadProgress(
        progress: 0.0,
        bytesDownloaded: 0,
        totalBytes: 0,
        status: 'error',
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  void dispose() => _progressController.close();
}
