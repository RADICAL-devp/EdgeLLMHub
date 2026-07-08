import 'dart:io';

/// Service to check if the current device has the hardware capabilities
/// (RAM, NPU/GPU) to run an on-device LLM (Gemma 2B or Llama 3B).
class DeviceCapabilityService {
  /// Returns true if the device is deemed capable of running the local LLM.
  Future<bool> canRunLocalLlm() async {
    try {
      // In a production app, use `device_info_plus` and native channels to check:
      // 1. Total Physical RAM (Need >= 6GB for iOS, >= 8GB for Android)
      // 2. Chipset (Need Apple A15+ or Snapdragon 8 Gen 1+)
      
      if (Platform.isIOS) {
        // Assume recent iPhones can run it.
        return true; 
      } else if (Platform.isAndroid) {
        // Assume recent Androids can run it.
        return true;
      }
      return false; // Not supported on other platforms natively yet
    } catch (e) {
      return false;
    }
  }

  /// Get a user-friendly message if the device cannot run the local LLM.
  String getUnsupportedMessage() {
    return 'Your device does not meet the minimum hardware requirements (e.g., sufficient RAM or modern processor) to run Clinical AI locally. Please use the cloud-sync option.';
  }
}
