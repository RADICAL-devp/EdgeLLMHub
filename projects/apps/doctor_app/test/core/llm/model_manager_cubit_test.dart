import 'dart:async';
import 'dart:io';

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
      test('falls back to cloud mode on simulator', () async {
        when(() => mockCapabilityService.isSimulator).thenAnswer((_) async => true);
        when(() => mockCapabilityService.getRecommendedExecutionMode())
            .thenAnswer((_) async => ExecutionMode.cloud);

        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        await cubit.checkModelExists();

        expect(cubit.state, isA<ModelManagerReady>());
        expect((cubit.state as ModelManagerReady).executionMode, 'cloud');
      });

      test('falls back to cloud mode on low-capability device', () async {
        when(() => mockCapabilityService.canRunLocalLlm()).thenAnswer((_) async => false);
        when(() => mockCapabilityService.getRecommendedExecutionMode())
            .thenAnswer((_) async => ExecutionMode.cloud);

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
      test('simulated path ends in an error when URL is empty', () async {
        final dir = await Directory.systemTemp.createTemp('model-test');
        final cubit = ModelManagerCubit(
          capabilityService: mockCapabilityService,
          downloader: mockDownloader,
        );

        await cubit.downloadModel(downloadUrl: '', downloadDirectory: dir);

        expect(cubit.state, isA<ModelManagerError>());
        expect((cubit.state as ModelManagerError).message,
            contains('MODEL_DOWNLOAD_URL'));
        await cubit.close();
      });

      test('emits downloading progress during download', () async {
        final progressStates = <ModelManagerDownloading>[];
        final completer = Completer<void>();
        final dir = await Directory.systemTemp.createTemp('model-test');

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
          checksumSha256: List.filled(64, 'a').join(),
          downloadDirectory: dir,
        );

        await completer.future.timeout(const Duration(seconds: 5));

        expect(progressStates.length, greaterThan(1));
        expect(progressStates.last.progress, 1.0);
        await cubit.close();
      });
    });
  });
}