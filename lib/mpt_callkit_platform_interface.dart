import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mpt_callkit_method_channel.dart';

abstract class MptCallkitPlatform extends PlatformInterface {
  /// Constructs a MptCallkitPlatform.
  MptCallkitPlatform() : super(token: _token);

  static final Object _token = Object();

  static MptCallkitPlatform _instance = MethodChannelMptCallkit();

  /// The default instance of [MptCallkitPlatform] to use.
  ///
  /// Defaults to [MethodChannelMptCallkit].
  static MptCallkitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MptCallkitPlatform] when
  /// they register themselves.
  static set instance(MptCallkitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<String, dynamic>> initSipConnection({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,

    /// default UDP port is 5060
    // SipProtocol sipProtocol = SipProtocol.UDP,

    /// default protocol is UDP
  }) {
    throw UnimplementedError('initSipConnection() has not been implemented.');
  }

  void registrationStateStream({
    required void Function() onSuccess,
    required void Function() onFailure,
  }) {
    throw UnimplementedError(
        'registrationStateStream() has not been implemented.');
  }

  Future<bool> unregisterConnection() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  bool call(String phone, bool isVideoCall) {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void hangup() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void startActivity();

  Future<bool> requestAudioPermissions();

  Future<bool> configureAudioSession();

  Future<bool> refreshCamera();

  Future<bool> checkCameraPermissions();

  Future<bool> updateVideoQuality();

  Future<Map<String, dynamic>> getVideoState();

  Future<bool> forceRefreshVideo();

  void hold() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void unhold() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void mute() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void unmute() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void cameraOn() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void cameraOff() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void transfer() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void answer() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void reject() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void getOutboundCallNumbers() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void getAgentStatus() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }

  void changeAgentStatus() {
    throw UnimplementedError(
        'unregisterConnection() has not been implemented.');
  }
}
