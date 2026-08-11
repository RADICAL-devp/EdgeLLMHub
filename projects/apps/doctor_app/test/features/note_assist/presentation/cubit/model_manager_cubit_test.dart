import 'dart:io';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/model_manager_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockCapabilityService extends Mock implements DeviceCapabilityService {}

void main() {
  late DeviceCapabilityService capabilityService;

  setUp(() {
    capabilityService = DeviceCapabilityService();
  });

  group('ModelManagerCubit.checkModelExists', () {
    test('emits ready in cloud mode on simulators', () async {
      final cap = _MockCapabilityService();
      when(() => cap.isSimulator).thenAnswer((_) async => true);
      when(() => cap.canRunLocalLlm()).thenAnswer((_) async => false);
      when(() => cap.getRecommendedExecutionMode())
          .thenAnswer((_) async => ExecutionMode.cloud);
      final cubit = ModelManagerCubit(capabilityService: cap);

      await cubit.checkModelExists();

      final state = cubit.state;
      expect(state, isA<ModelManagerReady>());
      expect((state as ModelManagerReady).executionMode, 'cloud');
      await cubit.close();
    });

    test('emits unsupported-platform error on desktop hosts', () async {
      final cap = _MockCapabilityService();
      when(() => cap.isSimulator).thenAnswer((_) async => false);
      when(() => cap.canRunLocalLlm()).thenAnswer((_) async => true);
      when(() => cap.getRecommendedExecutionMode())
          .thenAnswer((_) async => ExecutionMode.local);
      final cubit = ModelManagerCubit(capabilityService: cap);

      // Test hosts run on macOS → neither iOS nor Android branch applies.
      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerError>());
      expect((cubit.state as ModelManagerError).message,
          contains('Unsupported platform'));
      await cubit.close();
    });

    test('emits error when capability probing fails', () async {
      final cap = _MockCapabilityService();
      when(() => cap.isSimulator).thenThrow(Exception('plugin missing'));
      final cubit = ModelManagerCubit(capabilityService: cap);

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerError>());
      expect((cubit.state as ModelManagerError).message,
          contains('Failed to check model'));
      await cubit.close();
    });
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
