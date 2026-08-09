import 'dart:io';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/model_manager_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const _modelFileName = 'smolLM-350M.bin';

/// Fake downloader that drives progress callbacks and writes bytes to the
/// destination so checksum verification has real content to read.
class _FakeDownloader implements ModelDownloader {
  _FakeDownloader({
    this.bytes = 1000,
    this.failWith,
  });

  final int bytes;
  final String? failWith;

  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (failWith != null) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        message: failWith,
        type: DioExceptionType.connectionError,
      );
    }
    onReceiveProgress?.call(0, bytes);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onReceiveProgress?.call(bytes ~/ 2, bytes);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    onReceiveProgress?.call(bytes, bytes);
    File(savePath).writeAsBytesSync(List.filled(bytes, 7));
  }
}

String _sha256OfFakeBytes(int count) =>
    sha256.convert(List.filled(count, 7)).toString();

void main() {
  late DeviceCapabilityService capabilityService;

  setUp(() {
    capabilityService = DeviceCapabilityService();
  });

  group('ModelManagerCubit.downloadModel (simulated path)', () {
    test('reaches ready without a configured URL', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(capabilityService: capabilityService);

      final future = cubit.downloadModel(downloadDirectory: dir);

      while (cubit.state is! ModelManagerReady) {
        expect(cubit.state, isNot(isA<ModelManagerError>()));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await future;

      expect(File('${dir.path}/$_modelFileName').existsSync(), isTrue);
      await cubit.close();
    });
  });

  group('ModelManagerCubit.downloadModel (real path)', () {
    test('streams progress then reaches ready without checksum', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final downloader = _FakeDownloader();
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: downloader,
      );
      final progressStates = <ModelManagerDownloading>[];
      cubit.stream.listen((state) {
        if (state is ModelManagerDownloading) progressStates.add(state);
      });

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        downloadDirectory: dir,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<ModelManagerReady>());
      expect(progressStates, isNotEmpty);
      expect(progressStates.any((s) => s.progress == 1.0), isTrue);
      expect(
        progressStates.last.downloadedBytes,
        downloader.bytes,
      );
      expect(progressStates.last.totalBytes, downloader.bytes);
      expect(progressStates.last.speedBytesPerSec, greaterThan(0));
      expect(File('${dir.path}/$_modelFileName').existsSync(), isTrue);
      await cubit.close();
    });

    test('verifies checksum and reports ready on match', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: 4096),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        checksumSha256: _sha256OfFakeBytes(4096),
        downloadDirectory: dir,
      );

      expect(cubit.state, isA<ModelManagerReady>());
      await cubit.close();
    });

    test('deletes corrupt file and emits error on checksum mismatch',
        () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final file = File('${dir.path}/$_modelFileName');
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: 4096),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        checksumSha256: '0' * 64,
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerError>());
      expect((state as ModelManagerError).message, contains('Checksum mismatch'));
      expect(file.existsSync(), isFalse,
          reason: 'corrupt download must be deleted');
      await cubit.close();
    });

    test('cleans partial file and emits error on network failure', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final file = File('${dir.path}/$_modelFileName');
      file.writeAsBytesSync([1, 2, 3]);
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(failWith: 'connection reset'),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerError>());
      expect((state as ModelManagerError).message, contains('connection reset'));
      expect(file.existsSync(), isFalse,
          reason: 'partial download must be cleaned up');
      await cubit.close();
    });
  });
}
