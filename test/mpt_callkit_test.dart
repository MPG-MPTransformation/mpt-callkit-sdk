import 'package:flutter_test/flutter_test.dart';
import 'package:mpt_callkit/mpt_callkit.dart';
import 'package:mpt_callkit/mpt_callkit_platform_interface.dart';
import 'package:mpt_callkit/mpt_callkit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMptCallkitPlatform
    with MockPlatformInterfaceMixin
    implements MptCallkitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  bool call(String phone, bool isVideo) {
    throw UnimplementedError();
  }

  @override
  void hangup() {
    // TODO: implement hangup
  }

  @override
  Future<Map<String, dynamic>> initSipConnection({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) {
    // TODO: implement initSipConnection
    throw UnimplementedError();
  }

  @override
  void registrationStateStream(
      {required void Function() onSuccess,
      required void Function() onFailure}) {
    // TODO: implement registrationStateStream
  }

  @override
  void startActivity() {
    // TODO: implement startActivity
  }

  @override
  void unregistrationStateStream(
      {required void Function() onSuccess,
      required void Function() onFailure}) {
    // TODO: implement unregistrationStateStream
  }

  @override
  Future<bool> unregisterConnection() {
    // TODO: implement unregisterConnection
    throw UnimplementedError();
  }

  @override
  void answer() {
    // TODO: implement answer
  }

  @override
  void cameraOff() {
    // TODO: implement cameraOff
  }

  @override
  void cameraOn() {
    // TODO: implement cameraOn
  }

  @override
  void changeAgentStatus() {
    // TODO: implement changeAgentStatus
  }

  @override
  void getAgentStatus() {
    // TODO: implement getAgentStatus
  }

  @override
  void getOutboundCallNumbers() {
    // TODO: implement getOutboundCallNumbers
  }

  @override
  void hold() {
    // TODO: implement hold
  }

  @override
  void mute() {
    // TODO: implement mute
  }

  @override
  void reject() {
    // TODO: implement reject
  }

  @override
  void transfer() {
    // TODO: implement transfer
  }

  @override
  void unhold() {
    // TODO: implement unhold
  }

  @override
  void unmute() {
    // TODO: implement unmute
  }
}

void main() {
  final MptCallkitPlatform initialPlatform = MptCallkitPlatform.instance;

  test('$MethodChannelMptCallkit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMptCallkit>());
  });

  test('getPlatformVersion', () async {
    MptCallkit mptCallkitPlugin = MptCallkit();
    MockMptCallkitPlatform fakePlatform = MockMptCallkitPlatform();
    MptCallkitPlatform.instance = fakePlatform;

    expect(await mptCallkitPlugin.getPlatformVersion(), '42');
  });
}
