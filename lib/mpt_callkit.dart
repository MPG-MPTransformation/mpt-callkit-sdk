import 'package:mpt_callkit/mpt_callkit_auth_method.dart';

import 'mpt_callkit_platform_interface.dart';

class MptCallkit {
  Future<String?> getPlatformVersion() {
    return MptCallkitPlatform.instance.getPlatformVersion();
  }

  Future<Map<String, dynamic>> initSipConnection({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) async {
    return MptCallkitPlatform.instance.initSipConnection(
        apiKey: apiKey, baseUrl: baseUrl, userPhoneNumber: userPhoneNumber);
  }

  void registrationStateStream({
    required void Function() onSuccess,
    required void Function() onFailure,
  }) {
    MptCallkitPlatform.instance
        .registrationStateStream(onSuccess: onSuccess, onFailure: onFailure);
  }

  Future<bool> unregisterConnection() async {
    return await MptCallkitPlatform.instance.unregisterConnection();
  }

  bool call(String phone, bool isVideoCall) {
    return MptCallkitPlatform.instance.call(phone, isVideoCall);
  }

  void hangup() {
    MptCallkitPlatform.instance.hangup();
  }

  void startActivity() {
    MptCallkitPlatform.instance.startActivity();
  }

  Future<bool> requestAudioPermissions() async {
    return await MptCallkitPlatform.instance.requestAudioPermissions();
  }

  Future<bool> configureAudioSession() async {
    return await MptCallkitPlatform.instance.configureAudioSession();
  }

  Future<bool> refreshCamera() async {
    return await MptCallkitPlatform.instance.refreshCamera();
  }

  Future<bool> checkCameraPermissions() async {
    return await MptCallkitPlatform.instance.checkCameraPermissions();
  }

  Future<bool> updateVideoQuality() async {
    return await MptCallkitPlatform.instance.updateVideoQuality();
  }

  Future<Map<String, dynamic>> getVideoState() async {
    return await MptCallkitPlatform.instance.getVideoState();
  }

  Future<bool> forceRefreshVideo() async {
    return await MptCallkitPlatform.instance.forceRefreshVideo();
  }
}
