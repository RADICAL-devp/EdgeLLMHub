import 'dart:async';

import 'package:doctor_app/core/ai/edge_ai_gateway.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/model_manager_service.dart';
import 'package:doctor_app/core/services/settings_service.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart'
    hide DownloadCancelledException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GatewayRequest {
  const GatewayRequest({
    required this.systemInstruction,
    required this.prompt,
    required this.enableThinking,
    required this.maxOutputTokens,
  });

  final String systemInstruction;
  final String prompt;
  final bool enableThinking;
  final int? maxOutputTokens;
}

class FakeEdgeAiGateway implements EdgeAiGateway {
  FakeEdgeAiGateway({this.hasModel = true, List<String>? responses})
    : responses = responses ?? const ['{}'];

  @override
  bool hasModel;

  final List<String> responses;
  final List<GatewayRequest> requests = [];
  final List<String> tokens = [];

  @override
  Future<String> generate({
    required String systemInstruction,
    required String prompt,
    required bool enableThinking,
    int? maxOutputTokens,
    void Function(String token)? onToken,
  }) async {
    requests.add(
      GatewayRequest(
        systemInstruction: systemInstruction,
        prompt: prompt,
        enableThinking: enableThinking,
        maxOutputTokens: maxOutputTokens,
      ),
    );

    final index = requests.length - 1;
    final response = index < responses.length
        ? responses[index]
        : responses.isEmpty
        ? ''
        : responses.last;
    if (response.isNotEmpty) {
      tokens.add(response);
      onToken?.call(response);
    }
    return response;
  }
}

class FakeSettings extends SettingsService {
  FakeSettings({
    this.wifiOnly = true,
    this.thinking = false,
    this.language = 'en',
    this.consented = true,
    this.onboarded = true,
  });

  bool wifiOnly;
  bool thinking;
  String language;
  bool consented;
  bool onboarded;

  @override
  bool get wifiOnlyDownloads => wifiOnly;

  @override
  bool get thinkingMode => thinking;

  @override
  String get languageCode => language;

  @override
  bool get hasAcceptedConsent => consented;

  @override
  bool get hasCompletedOnboarding => onboarded;

  @override
  Future<void> setWifiOnlyDownloads(bool value) async {
    wifiOnly = value;
    notifyListeners();
  }

  @override
  Future<void> setThinkingMode(bool value) async {
    thinking = value;
    notifyListeners();
  }

  @override
  Future<void> setLanguageCode(String value) async {
    language = value;
    notifyListeners();
  }

  @override
  Future<void> completeOnboarding() async {
    consented = true;
    onboarded = true;
    notifyListeners();
  }

  @override
  Future<void> setConsentAccepted(bool value) async {
    consented = value;
    notifyListeners();
  }

  @override
  Future<void> resetOnboarding() async {
    consented = false;
    onboarded = false;
    notifyListeners();
  }
}

class FakeEdgeModelInstaller implements EdgeModelInstaller {
  bool llmReady = false;
  bool sttReady = false;
  int? storage = 0;

  bool failLlm = false;
  bool cancelLlm = false;
  bool failStt = false;

  int installCalls = 0;
  int uninstallCalls = 0;
  final List<double> llmProgress = [];
  final List<double> sttModelProgress = [];
  final List<double> sttTokenizerProgress = [];

  @override
  bool get hasLlm => llmReady;

  @override
  bool get hasStt => sttReady;

  @override
  Future<int?> storageBytes() async => storage;

  @override
  Future<void> installLlm({
    required void Function(double progress) onProgress,
    required CancelToken cancelToken,
  }) async {
    installCalls++;
    onProgress(0.25);
    llmProgress.add(0.25);
    await Future<void>.delayed(Duration.zero);
    if (cancelLlm) throw const DownloadCancelledException();
    if (failLlm) throw StateError('llm install exploded');
    onProgress(1);
    llmProgress.add(1);
    llmReady = true;
  }

  @override
  Future<void> installStt({
    required void Function(double progress) onModelProgress,
    required void Function(double progress) onTokenizerProgress,
    required CancelToken cancelToken,
  }) async {
    installCalls++;
    onModelProgress(0.5);
    sttModelProgress.add(0.5);
    onTokenizerProgress(0.5);
    sttTokenizerProgress.add(0.5);
    if (failStt) throw StateError('stt install exploded');
    onModelProgress(1);
    onTokenizerProgress(1);
    sttModelProgress.add(1);
    sttTokenizerProgress.add(1);
    sttReady = true;
  }

  @override
  Future<void> uninstallAll() async {
    uninstallCalls++;
    llmReady = false;
    sttReady = false;
  }
}

class FakeNetworkChecker implements NetworkChecker {
  FakeNetworkChecker({required this.online, required this.wifi});

  bool online;
  bool wifi;

  @override
  Future<NetworkState> check() async =>
      NetworkState(online: online, wifi: wifi);
}

class MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};
  AppleOptions? lastReadAppleOptions;
  AppleOptions? lastWriteAppleOptions;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    lastReadAppleOptions = iOptions;
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    lastWriteAppleOptions = iOptions;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
