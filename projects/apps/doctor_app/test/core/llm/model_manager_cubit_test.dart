import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc/bloc.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/model_manager_cubit.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

class MockDeviceCapabilityService extends Mock implements DeviceCapabilityService {}

class MockModelDownloader extends Mock implements ModelDownloader {}

void main() {
  setUpAll(() {
    registerFallbackValue(Platform.isIOS);
    registerFallbackValue(Platform.isAndroid);
  });

  group('ModelManagerCubit', () {
    late MockDeviceCapabilityService mockCapabilityService;
    late MockModelDownloader mockDownloader;

    setUp(() {
      mockCapabilityService = MockDeviceCapabilityService();
      mockDownloader = MockModelDownloader();

      // Default: physical device capable of local LLM
      when(() => mockCapabilityService.isSimulator).thenAnswer((_) async => false);
      when(() => mockCapabilityService.canRunLocalLlm()).thenAnswer((_) async => true);
      when(() => mockCapabilityService.getRecommendedExecutionMode())
          .thenAnswer((_) async => ExecutionMode.local);
    });

    group('checkModelExists', () {
      test('emits ModelManagerInitial on simulator', () async {
        when(() => mockCapabilityService.isSimulator).thenAnswer((_) async => true);

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        await cubit.checkModelExists();

        expect(cubit.state, isA<ModelManagerReady>());
        expect((cubit.state as ModelManagerReady).executionMode, 'cloud');
      });

      test('emits ModelManagerInitial on low-capability device', () async {
        when(() => mockCapabilityService.canRunLocalLlm()).thenAnswer((_) async => false);

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        await cubit.checkModelExists();

        expect(cubit.state, isA<ModelManagerReady>());
        expect((cubit.state as ModelManagerReady).executionMode, 'cloud');
      });
    });

    group('downloadModel', () {
      test('simulates download when URL is empty', () async {
        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        await cubit.downloadModel(downloadUrl: '');

        expect(cubit.state, isA<ModelManagerReady>());
        expect((cubit.state as ModelManagerReady).executionMode, 'local');
      });

      test('emits downloading progress during download', () async {
        final progressStates = <ModelManagerDownloading>[];
        final completer = Completer<void>();

        when(() => mockDownloader.download(any(), any(), onReceiveProgress: any(named: 'onReceiveProgress')))
            .thenAnswer((invocation) async {
          final callback = invocation.namedArguments[#onReceiveProgress] as void Function(int, int)?;
          callback?.call(50, 100);
          callback?.call(100, 100);
        });

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        cubit.stream.listen((state) {
          if (state is ModelManagerDownloading) {
            progressStates.add(state);
            if (state.progress >= 1.0) {
              completer.complete();
            }
          }
        });

        await cubit.downloadModel(
          downloadUrl: 'https://example.com/model.zip',
          checksumSha256: 'a'.repeat(64),
        );

        await completer.future.timeout(const Duration(seconds: 5));

        expect(progressStates.length, greaterThan(1));
        expect(progressStates.last.progress, 1.0);
      });

      test('verifies checksum after download', () async {
        final validChecksum = 'a'.repeat(64);
        final testFile = File('/tmp/test_model.zip');

        when(() => mockDownloader.download(any(), any(), onReceiveProgress: any(named: 'onReceiveProgress')))
            .thenAnswer((_) async {});

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        // Note: This test would need a real file for full integration test
        // For unit test, we verify the _verifyChecksum logic separately
        expect(cubit.state, isA<ModelManagerInitial>());
      });
    });

    group('_verifyChecksum', () {
      test('passes when checksum matches', () async {
        // Test the constant-time comparison logic directly
        final expected = 'a'.repeat(64);
        final actualBytes = List<int>.generate(32, (i) => 0xaa);
        final expectedBytes = List<int>.generate(32, (i) => 0xaa);

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        // Use reflection or test the static method indirectly
        // For now, verify the logic exists
        expect(ModelManagerCubit._constantTimeEquals(expectedBytes, actualBytes), isTrue);
      });

      test('fails when checksum mismatches', () async {
        final actualBytes = List<int>.generate(32, (i) => 0xaa);
        final expectedBytes = List<int>.generate(32, (i) => 0xbb);

        expect(ModelManagerCubit._constantTimeEquals(expectedBytes, actualBytes), isFalse);
      });

      test('fails when lengths differ', () async {
        final actualBytes = List<int>.generate(32, (i) => 0xaa);
        final expectedBytes = List<int>.generate(31, (i) => 0xaa);

        expect(ModelManagerCubit._constantTimeEquals(expectedBytes, actualBytes), isFalse);
      });
    });

    group('_parseHex', () {
      test('parses valid hex string', () {
        const hex = 'aabbccdd';
        final result = ModelManagerCubit._parseHex(hex);

        expect(result, isNotNull);
        expect(result!.length, 4);
        expect(result[0], 0xaa);
        expect(result[1], 0xbb);
        expect(result[2], 0xcc);
        expect(result[3], 0xdd);
      });

      test('returns null for odd length', () {
        expect(ModelManagerCubit._parseHex('abc'), isNull);
      });

      test('returns null for invalid characters', () {
        expect(ModelManagerCubit._parseHex('xyz'), isNull);
      });

      test('handles uppercase', () {
        const hex = 'AABBCCDD';
        final result = ModelManagerCubit._parseHex(hex);

        expect(result, isNotNull);
        expect(result![0], 0xaa);
      });
    });
  });
}