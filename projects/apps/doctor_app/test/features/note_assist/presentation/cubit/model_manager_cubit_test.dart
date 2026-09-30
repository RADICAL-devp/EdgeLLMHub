import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/llm/gemma_backend.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/model_manager_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

const _modelFileName = EnvironmentConfig.modelFileName;

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

class _MockConnectivity extends Mock implements Connectivity {}

/// Fake gemma backend: install state + verification result are scripted,
/// installed file bytes are captured for assertions.
class _FakeGemmaBackend implements GemmaBackend {
  _FakeGemmaBackend({
    this.installed = false,
    this.verifyText = 'Hello, patient.',
    this.verifyError,
    this.installError,
  });

  bool installed;
  String verifyText;
  Object? verifyError;
  Object? installError;

  List<int>? installedFileContent;
  String? installedFilePath;
  int installCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isModelInstalled(String fileName) async => installed;

  @override
  Future<void> installFromNetwork(
    String url, {
    required void Function(int progressPercent) onProgress,
  }) async {
    throw UnimplementedError('cubit uses Dio + installFromFile');
  }

  @override
  Future<void> installFromFile(String path) async {
    installCalls++;
    if (installError != null) throw installError!;
    installedFilePath = path;
    installedFileContent = await File(path).readAsBytes();
    installed = true;
  }

  @override
  Future<GemmaGeneration> generate({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async {
    if (verifyError != null) throw verifyError!;
    return GemmaGeneration(text: verifyText);
  }

  @override
  Stream<String> generateStream({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async* {}

  @override
  Future<void> close() async {}
}

/// Cubit with shortened verification timeout so timeout-path tests fail
/// fast instead of sleeping 45 seconds.
class _TestCubit extends ModelManagerCubit {
  _TestCubit({
    required super.capabilityService,
    super.gemmaBackend,
  });

  @override
  Duration get verificationTimeout => const Duration(milliseconds: 500);
}

/// Capability service answering like a physical, local-LLM-capable device.
DeviceCapabilityService _localCapability() {
  final cap = _MockCapabilityService();
  when(() => cap.isSimulator).thenAnswer((_) async => false);
  when(() => cap.canRunLocalLlm()).thenAnswer((_) async => true);
  when(() => cap.getRecommendedExecutionMode())
      .thenAnswer((_) async => ExecutionMode.local);
  return cap;
}

Connectivity _wifiConnectivity() {
  final connectivity = _MockConnectivity();
  when(() => connectivity.checkConnectivity())
      .thenAnswer((_) async => [ConnectivityResult.wifi]);
  return connectivity;
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

    test('reports not-installed on a fresh device', () async {
      // No platform branches exist anymore — a physical host with no
      // installed model routes straight to the download UI.
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _FakeGemmaBackend(installed: false),
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerInitial>());
      await cubit.close();
    });

    test('emits error when capability probing fails', () async {
      final cap = _MockCapabilityService();
      when(() => cap.isSimulator).thenThrow(Exception('plugin missing'));
      final cubit = ModelManagerCubit(capabilityService: cap);

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to check model'));
      await cubit.close();
    });
  });

  group('ModelManagerCubit.downloadModel (simulated path)', () {
    test('ends in an error without a configured URL', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final cubit = ModelManagerCubit(capabilityService: capabilityService);

      final future = cubit.downloadModel(
        downloadUrl: '',
        downloadDirectory: dir,
      );

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

  group('ModelManagerCubit.downloadModel (Wi-Fi gate)', () {
    test('blocks mobile-only connections with a Wi-Fi error', () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final connectivity = _MockConnectivity();
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.mobile]);
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        connectivity: connectivity,
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        downloadDirectory: dir,
      );

      expect((cubit.state as ModelManagerError).message, contains('Wi-Fi'));
      await cubit.close();
    });
  });

  group('ModelManagerCubit.downloadModel (real path)', () {
    test('streams progress then installs and reaches ready', () async {
      final content = List<int>.generate(2048, (i) => i % 251);
      final dir = await Directory.systemTemp.createTemp('model-test');
      final backend = _FakeGemmaBackend();
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: content.length, content: content),
        gemmaBackend: backend,
        connectivity: _wifiConnectivity(),
      );
      final progressStates = <ModelManagerDownloading>[];
      cubit.stream.listen((state) {
        if (state is ModelManagerDownloading) progressStates.add(state);
      });

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        checksumSha256: sha256.convert(content).toString(),
        requireWifi: false,
        downloadDirectory: dir,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<ModelManagerReady>());
      expect(progressStates, isNotEmpty);
      expect(progressStates.any((s) => s.progress == 1.0), isTrue);
      expect(progressStates.last.downloadedBytes, content.length);
      expect(backend.installCalls, 1);
      expect(backend.installedFileContent, content);
      expect(File('${dir.path}/$_modelFileName').existsSync(), isFalse,
          reason: 'the staged download must be removed after install');
      final ready = cubit.state as ModelManagerReady;
      expect(ready.modelPath, contains('flutter_gemma'));
      await cubit.close();
    });

    test('verifies checksum and reports ready on match', () async {
      final content = List<int>.generate(512, (i) => i % 251);
      final dir = await Directory.systemTemp.createTemp('model-test');
      final backend = _FakeGemmaBackend();
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: content.length, content: content),
        gemmaBackend: backend,
        connectivity: _wifiConnectivity(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        checksumSha256: sha256.convert(content).toString(),
        requireWifi: false,
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerReady>());
      expect((state as ModelManagerReady).modelPath,
          contains('flutter_gemma'));
      await cubit.close();
    });

    test('deletes corrupt file and emits error on checksum mismatch',
        () async {
      final dir = await Directory.systemTemp.createTemp('model-test');
      final file = File('${dir.path}/$_modelFileName');
      final backend = _FakeGemmaBackend();
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: 4096),
        gemmaBackend: backend,
        connectivity: _wifiConnectivity(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        checksumSha256: '0' * 64,
        requireWifi: false,
        downloadDirectory: dir,
      );

      final state = cubit.state;
      expect(state, isA<ModelManagerError>());
      expect((state as ModelManagerError).message, contains('Checksum mismatch'));
      expect(file.existsSync(), isFalse,
          reason: 'corrupt download must be deleted');
      expect(backend.installCalls, 0);
      await cubit.close();
    });

    test('emits error when the install step fails', () async {
      final content = List<int>.generate(512, (i) => i % 251);
      final dir = await Directory.systemTemp.createTemp('model-test');
      final backend =
          _FakeGemmaBackend(installError: Exception('store full'));
      final cubit = ModelManagerCubit(
        capabilityService: capabilityService,
        downloader: _FakeDownloader(bytes: content.length, content: content),
        gemmaBackend: backend,
        connectivity: _wifiConnectivity(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        checksumSha256: sha256.convert(content).toString(),
        requireWifi: false,
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
        gemmaBackend: _FakeGemmaBackend(),
        connectivity: _wifiConnectivity(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.litertlm',
        requireWifi: false,
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
        gemmaBackend: _FakeGemmaBackend(),
        connectivity: _wifiConnectivity(),
      );

      await cubit.downloadModel(
        downloadUrl: 'https://example.com/model.bin',
        requireWifi: false,
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

  group('ModelManagerCubit.checkModelExists (flutter_gemma flow)', () {
    test('verifies sample inference and reports ready', () async {
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _FakeGemmaBackend(installed: true),
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerReady>());
      expect((cubit.state as ModelManagerReady).executionMode, 'local');
      expect((cubit.state as ModelManagerReady).modelPath,
          contains('flutter_gemma'));
      await cubit.close();
    });

    test('routes to the download UI when the model is not installed',
        () async {
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _FakeGemmaBackend(installed: false),
      );

      await cubit.checkModelExists();

      expect(cubit.state, isA<ModelManagerInitial>());
      await cubit.close();
    });

    test('reports corruption when verification produces no output',
        () async {
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _FakeGemmaBackend(installed: true, verifyText: ''),
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('produced no output'));
      await cubit.close();
    });

    test('emits error when verification throws', () async {
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _FakeGemmaBackend(
          installed: true,
          verifyError: Exception('engine gone'),
        ),
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('Failed to verify flutter_gemma'));
      await cubit.close();
    });

    test('emits timeout error when verification is too slow', () async {
      final backend = _FakeGemmaBackend(installed: true);
      final cubit = _TestCubit(
        capabilityService: _localCapability(),
        gemmaBackend: _SlowGemmaBackend(backend),
      );

      await cubit.checkModelExists();

      expect((cubit.state as ModelManagerError).message,
          contains('timed out'));
      await cubit.close();
    });
  });
}

/// Backend wrapper that delays verification past the cubit's short test
/// timeout.
class _SlowGemmaBackend implements GemmaBackend {
  _SlowGemmaBackend(this._inner);

  final _FakeGemmaBackend _inner;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<bool> isModelInstalled(String fileName) =>
      _inner.isModelInstalled(fileName);

  @override
  Future<void> installFromNetwork(
    String url, {
    required void Function(int progressPercent) onProgress,
  }) =>
      _inner.installFromNetwork(url, onProgress: onProgress);

  @override
  Future<void> installFromFile(String path) => _inner.installFromFile(path);

  @override
  Future<GemmaGeneration> generate({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    return _inner.generate(
      systemInstruction: systemInstruction,
      prompt: prompt,
      maxOutputTokens: maxOutputTokens,
    );
  }

  @override
  Stream<String> generateStream({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) =>
      _inner.generateStream(prompt: prompt);

  @override
  Future<void> close() => _inner.close();
}
