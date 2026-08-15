import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/android_speech_service.dart';
import 'package:doctor_app/core/services/cloud_speech_service.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/services/ios_speech_service.dart';
import 'package:doctor_app/core/services/local_speech_service.dart';
import 'package:doctor_app/core/services/speech_service_factory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _MockDeviceCapabilityService extends Mock
    implements DeviceCapabilityService {}

class _FakePermissionHandler extends PermissionHandlerPlatform {
  bool granted = true;
  final requested = <Permission>[];

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions, {
    bool throwIfPermanentlyDenied = false,
  }) async {
    requested.addAll(permissions);
    return {
      for (final p in permissions)
        p: granted ? PermissionStatus.granted : PermissionStatus.denied,
    };
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(Permission permission) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speechChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  late _MockDeviceCapabilityService deviceService;
  late _FakePermissionHandler fakePermissions;

  setUp(() {
    deviceService = _MockDeviceCapabilityService();
    fakePermissions = _FakePermissionHandler();
    PermissionHandlerPlatform.instance = fakePermissions;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
        case 'locales':
          return call.method == 'locales'
              ? ['en_US:English (United States)']
              : true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, null);
    PermissionHandlerPlatform.instance = _FakePermissionHandler();
  });

  // NOTE: must run first — the SpeechToText singleton caches a successful
  // initialize, so only this test sees local init fail.
  test('createWithFallback falls back to cloud when local init fails',
      () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
          return false;
        case 'locales':
          return <String>[];
      }
      return null;
    });

    final service = await SpeechServiceFactory.createWithFallback(
      deviceService,
      operatingSystem: 'ios',
    );

    expect(service, isA<CloudSpeechService>());
  });

  test('simulator-style device (no local STT) gets CloudSpeechService',
      () async {
    when(() => deviceService.canUseSpeechToText()).thenAnswer((_) async => false);

    final service = await SpeechServiceFactory.create(
      deviceService,
      operatingSystem: 'ios',
    );

    expect(service, isA<CloudSpeechService>());
  });

  test('physical iOS device with permission gets IosSpeechService', () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);

    final service = await SpeechServiceFactory.create(
      deviceService,
      operatingSystem: 'ios',
    );

    expect(service, isA<IosSpeechService>());
    expect(fakePermissions.requested, contains(Permission.microphone));
  });

  test('physical Android device gets AndroidSpeechService', () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);

    final service = await SpeechServiceFactory.create(
      deviceService,
      operatingSystem: 'android',
    );

    expect(service, isA<AndroidSpeechService>());
  });

  test('denied microphone permission throws SpeechException', () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);
    fakePermissions.granted = false;

    await expectLater(
      SpeechServiceFactory.create(
        deviceService,
        operatingSystem: 'ios',
      ),
      throwsA(isA<SpeechException>()),
    );
  });

  test('non-mobile OS gets the base LocalSpeechService', () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);

    final service = await SpeechServiceFactory.create(deviceService);

    expect(service, isA<LocalSpeechService>());
  });

  test('createWithFallback returns local service when init succeeds',
      () async {
    when(() => deviceService.canUseSpeechToText())
        .thenAnswer((_) async => true);

    final service = await SpeechServiceFactory.createWithFallback(
      deviceService,
      operatingSystem: 'android',
    );

    expect(service, isA<AndroidSpeechService>());
  });
}