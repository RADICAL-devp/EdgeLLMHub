import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/model_manager_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

const _modelFileName = EnvironmentConfig.modelFileName;

/// Builds a real zip archive of the MLC-packaged model directory so the
/// cubit's extraction path has valid input.
List<int> _packedModelZip() {
  final archive = Archive()
    ..addFile(ArchiveFile(
      '${EnvironmentConfig.modelBundleDirName}/params.txt',
      5,
      utf8.encode('hello'),
    ))
    ..addFile(ArchiveFile(
      '${EnvironmentConfig.modelBundleDirName}/lib/libmodel.so',
      3,
      utf8.encode('lib'),
    ));
  return ZipEncoder().encodeBytes(archive);
}

/// Fake downloader that drives progress callbacks and writes bytes to the
/// destination so checksum verification has real content to read.
class _FakeDownloader implements ModelDownloader {
  _FakeDownloader({
    this.bytes = 1000,
    this.failWith,
    this.content,
  });

  final int bytes;
  final String? failWith;

  /// Bytes written to the destination; defaults to [bytes] of 0x07.
  final List<int>? content;

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
    File(savePath).writeAsBytesSync(content ?? List.filled(bytes, 7));
  }
}

class _MockCapabilityService extends Mock implements DeviceCapabilityService {}

/// Cubit whose platform gates are forced so the iOS/Android verification
/// flows (which are otherwise unreachable on a macOS test host) can be
/// exercised end-to-end through the mocked MethodChannel.
class _PlatformForcedCubit extends ModelManagerCubit {
  _PlatformForcedCubit({
    required super.capabilityService,
    this.ios = false,
    this.android = false,
  });

  final bool ios;
  final bool android;

  @override
  bool get isIosPlatform => ios;

  @override
  bool get isAndroidPlatform => android;
}

const _llmChannel = MethodChannel('com.example.clinical/llm');

void _mockChannel(Future<Object?> Function(MethodCall) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_llmChannel, handler);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_llmChannel, null);
  });
}

Map<String, Object?> _readyModelInfo() => {
      'installed': true,
      'ready': true,
      'checksumSha256': 'abc123',
      'path': '/models/smol',
      // Without a modelVersion the cubit assumes an upgrade is needed and
      // routes into downloadModel() instead of reporting ready.
      'modelVersion': EnvironmentConfig.bundledModelVersion.version,
    };

/// Capability service answering like a physical, local-LLM-capable device.
DeviceCapabilityService _localCapability() {
  final cap = _MockCapabilityService();
  when(() => cap.isSimulator).thenAnswer((_) async => false);
  when(() => cap.canRunLocalLlm()).thenAnswer((_) async => true);
  when(() => cap.getRecommendedExecutionMode())
      .thenAnswer((_) async => ExecutionMode.local);
  return cap;
}

/// Downloader that throws a plain (non-Dio) exception.
class _FailingDownloader implements ModelDownloader {
  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    throw Exception('boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    test('ends in an error without a configured URL', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(capabilityService: capabilityService);

      final future = cubit.downloadModel(downloadDirectory: dir);

      while (cubit.state is! ModelManagerError) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await future;

      expect((cubit.state as ModelManagerError).message,
          contains('MODEL_DOWNLOAD_URL'));
      expect(
        File('${dir.path}/$_modelFileName').existsSync(),
        isFalse,
        reason: 'no placeholder artifact should be left behind',
      );
      await cubit.close();
    });
  });

  group('ModelManagerCubit.downloadModel (real path)', () {
    test('streams progress then extracts and reaches ready without checksum',
        () async {
      final zip = _packedModelZip();
      final dir = await Directory.systemTemp.createTemp('model-test');
      final downloader = _FakeDownloader(bytes: zip.length, content: zip);
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: downloader,
      );
      final progressStates = <ModelManagerDownloading>[];
      cubit.stream.listen((state) {
        if (state is ModelManagerDownloading) progressStates.add(state);
      });

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.zip',
        downloadDirectory: dir,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<ModelManagerReady>());
      expect(progressStates, isNotEmpty);
      expect(progressStates.any((s) => s.progress == 1.0), isTrue);
      expect(progressStates.last.speedBytesPerSec, greaterThan(0));
      expect(File('${dir.path}/$_modelFileName').existsSync(), isFalse,
          reason: 'the downloaded archive must be removed after extraction');
      expect(
        File('${dir.path}/${EnvironmentConfig.modelBundleDirName}/params.txt')
            .readAsStringSync(),
        'hello',
      );
      expect(
        File('${dir.path}/${EnvironmentConfig.modelBundleDirName}/lib/libmodel.so')
            .existsSync(),
        isTrue,
      );
      final ready = cubit.state as ModelManagerReady;
      expect(ready.modelPath, contains(EnvironmentConfig.modelBundleDirName));
      await cubit.close();
    });

    test('verifies checksum and reports ready on match', () async {
      final zip = _packedModelZip();
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: zip.length, content: zip),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.zip',
        checksumSha256: sha256.convert(zip).toString(),
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerReady>());
      expect((state as ModelManagerReady).modelPath,
          contains(EnvironmentConfig.modelBundleDirName));
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
        downloadUrl: 'https://example.com/model.zip',
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

    test('emits error when the downloaded archive is corrupt', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: 4096),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.zip',
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerError>());
      expect((state as ModelManagerError).message, contains('Download failed'));
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

    test('cleans partial file on generic (non-Dio) download failure',
        () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final file = File('${dir.path}/$_modelFileName');
      file.writeAsBytesSync([1, 2, 3]);
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FailingDownloader(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerError>());
      expect((state as ModelManagerError).message, contains('boom'));
      expect(file.existsSync(), isFalse,
          reason: 'partial download must be cleaned up');
      await cubit.close();
    });
  });

  group('ModelManagerCubit.checkModelExists (iOS flow)', () {
    test('verifies, warms up, runs sample inference, and reports ready',
        () async {
      _mockChannel((call) async {
        switch (call.method) {
          case 'getModelInfo':
            return _readyModelInfo();
          case 'initialize':
            return null;
          case 'warmUp':
            return 'ok';
          case 'generate':
            return 'Hello, patient.';
        }
        return null;
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerReady>());
      expect((cubit.state as ModelManagerReady).executionMode, 'local');
      expect((cubit.state as ModelManagerReady).modelInfo, _readyModelInfo());
      await cubit.close();
    });

    test('emits error when model info is missing', () async {
      _mockChannel((call) async => null);
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('did not return model info'));
      await cubit.close();
    });

    test('routes to the download UI when the model is not bundled', () async {
      _mockChannel((call) async => {'installed': false});
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerInitial>());
      await cubit.close();
    });

    test('emits error when engine initialization fails', () async {
      _mockChannel((call) async {
        if (call.method == 'getModelInfo') {
          return {'installed': true, 'ready': false};
        }
        throw PlatformException(code: 'init', message: 'metal unavailable');
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to initialize'));
      await cubit.close();
    });

    test('reports corruption when verification produces no output', () async {
      _mockChannel((call) async {
        if (call.method == 'getModelInfo') return _readyModelInfo();
        if (call.method == 'generate') return '';
        return null;
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('produced no output'));
      await cubit.close();
    });

    test('emits not-registered error on MissingPluginException', () async {
      _mockChannel((call) async {
        throw MissingPluginException('no handler');
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('not registered'));
      await cubit.close();
    });

    test('emits platform error from the channel', () async {
      _mockChannel((call) async {
        if (call.method == 'getModelInfo') return _readyModelInfo();
        throw PlatformException(code: 'gen', message: 'gpu oom');
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('gpu oom'));
      await cubit.close();
    });

    test('emits timeout error when verification is too slow', () async {
      _mockChannel((call) async {
        if (call.method == 'getModelInfo') return _readyModelInfo();
        if (call.method == 'generate') {
          await Future<void>.delayed(const Duration(seconds: 30));
          return 'late';
        }
        return null;
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('timed out'));
      await cubit.close();
    });

    test('emits generic error for malformed channel payloads', () async {
      _mockChannel((call) async {
        return {'installed': true, 'ready': true, 'checksumSha256': 123};
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        ios: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to verify MLC LLM'));
      await cubit.close();
    });
  });

  group('ModelManagerCubit.checkModelExists (Android flow)', () {
    test('verifies and reports ready on a physical device', () async {
      _mockChannel((call) async {
        switch (call.method) {
          case 'getModelInfo':
            return _readyModelInfo();
          case 'initialize':
            return null;
          case 'warmUp':
            return 'ok';
          case 'generate':
            return 'Hello, patient.';
        }
        return null;
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        android: true,
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerReady>());
      expect((cubit.state as ModelManagerReady).modelPath,
          contains('MLC Android'));
      await cubit.close();
    });

    test('routes to the download UI when the model is not in assets',
        () async {
      _mockChannel((call) async => {'installed': false});
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        android: true,
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerInitial>());
      await cubit.close();
    });

    test('emits error when Android engine initialization fails', () async {
      _mockChannel((call) async {
        if (call.method == 'getModelInfo') {
          return {'installed': true, 'ready': false};
        }
        throw PlatformException(code: 'init', message: 'vulkan missing');
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        android: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to initialize'));
      await cubit.close();
    });

    test('emits not-registered error on Android', () async {
      _mockChannel((call) async {
        throw MissingPluginException('no handler');
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        android: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('not registered'));
      await cubit.close();
    });

    test('emits generic error for malformed Android payloads', () async {
      _mockChannel((call) async {
        return {'installed': true, 'ready': true, 'checksumSha256': 123};
      });
      final cubit = _PlatformForcedCubit(
        capabilityService: _localCapability(),
        android: true,
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to verify MLC Android'));
      await cubit.close();
    });
  });
}
