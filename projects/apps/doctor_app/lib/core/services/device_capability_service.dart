import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

enum ExecutionMode {
  local,
  cloud,
  mock
}

/// Service to check if the current device has the hardware capabilities
/// to run an on-device LLM, dictation, etc., and to detect simulators.
class DeviceCapabilityService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  bool? _isSimulatorCache;

  Future<bool> get isSimulator async {
    if (_isSimulatorCache != null) return _isSimulatorCache!;
    
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      _isSimulatorCache = !iosInfo.isPhysicalDevice;
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _isSimulatorCache = !androidInfo.isPhysicalDevice;
    } else {
      _isSimulatorCache = false;
    }
    
    return _isSimulatorCache!;
  }

  /// Returns true if the device is deemed capable of running the local LLM natively.
  Future<bool> canRunLocalLlm() async {
    try {
      final simulator = await isSimulator;
      if (simulator) {
        // Simulators generally do not have the required Metal/Vulkan GPU setup
        // or RAM allocation required for 3B parameter models efficiently.
        return false; 
      }
      
      if (Platform.isIOS || Platform.isAndroid) {
        // Assume physical devices can run it for now.
        return true; 
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canUseSpeechToText() async {
    // Dictation relies on native Siri/Google Assistant services, which fail on Simulators.
    final simulator = await isSimulator;
    return !simulator;
  }

  Future<ExecutionMode> getRecommendedExecutionMode() async {
    if (await canRunLocalLlm()) {
      return ExecutionMode.local;
    }
    return ExecutionMode.cloud;
  }

  /// Get a user-friendly message if the device cannot run the local LLM.
  String getUnsupportedMessage() {
    return 'Your device (or Simulator) does not support running Clinical AI locally. The cloud-fallback mode will be used.';
  }
}
