import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';

import 'mpt_callkit_platform_interface.dart';

/// An implementation of [MptCallkitPlatform] that uses method channels.
class MethodChannelMptCallkit extends MptCallkitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('port_sip_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// initSipConnection
  /// requires:
  /// 1. username -> String : sip username required
  /// 2. password -> String : sip password required
  /// 3. domain -> String : sip domain required
  /// 4. port -> int : not required default port is 5060 (UDP)
  /// 5. protocol -> String : default is UDP but also TCP and TLS are supported
  @override
  Future<Map<String, dynamic>> initSipConnection({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) async {
    initSdk(
      apiKey: apiKey,
      userPhoneNumber: userPhoneNumber,
      baseUrl: baseUrl,
    );
    final extension = await getExtension();
    if (extension == null) {
      methodChannel.invokeMethod('registrationStateStream', false);
      return {'status': 'fail', 'message': 'Không thể lấy được extension'};
    }

    final response = await methodChannel.invokeMethod(
      'initSipConnection',
      <String, dynamic>{
        'username': userPhoneNumber,
        'password': extension.password,
        'domain': extension.domain,
        'sipServer': extension.sipServer,
        'port': extension.port,
      },
    );
    Map<String, dynamic> castedData =
        Map<String, dynamic>.from(response as Map);
    return {'status': 'success'};
  }

  @override
  void registrationStateStream({
    required void Function() onSuccess,
    required void Function() onFailure,
  }) {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'registrationStateStream') {
        if (call.arguments == true) {
          onSuccess.call();
        } else {
          onFailure.call();
        }
      }
    });
  }

  @override
  void videoQualityStream({
    required void Function(Map<String, dynamic>) onQualityChanged,
  }) {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'videoQualityChanged') {
        if (call.arguments is Map<String, dynamic>) {
          onQualityChanged.call(call.arguments as Map<String, dynamic>);
        }
      }
    });
  }

  @override
  Future<bool> unregisterConnection() async {
    final extension = await releaseExtension();
    if (extension == false) {
      return false;
    }
    methodChannel.invokeMethod('unregisterConnection');
    return true;
  }

  @override
  bool call(String phone, bool isVideoCall) {
    methodChannel.invokeMethod(
      'call',
      <String, dynamic>{
        'phoneNumber': phone,
        'isVideoCall': isVideoCall,
      },
    );
    return true;
  }

  @override
  void hangup() {
    methodChannel.invokeMethod('hangup');
  }

  @override
  void startActivity() {
    methodChannel.invokeMethod('startActivity');
  }

  @override
  Future<bool> requestAudioPermissions() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('requestAudioPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint("Error requesting audio permissions: $e");
      return false;
    }
  }

  @override
  Future<bool> configureAudioSession() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('configureAudioSession');
      return result ?? false;
    } catch (e) {
      debugPrint("Error configuring audio session: $e");
      return false;
    }
  }

  @override
  Future<bool> refreshCamera() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('refreshCamera');
      return result ?? false;
    } catch (e) {
      debugPrint("Error refreshing camera: $e");
      return false;
    }
  }

  @override
  Future<bool> checkCameraPermissions() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('checkCameraPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint("Error checking camera permissions: $e");
      return false;
    }
  }

  @override
  Future<bool> updateVideoQuality() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('updateVideoQuality');
      return result ?? false;
    } catch (e) {
      debugPrint("Error updating video quality: $e");
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getVideoState() async {
    try {
      final result = await methodChannel.invokeMethod<Map<String, dynamic>>('getVideoState');
      return result ?? {};
    } catch (e) {
      debugPrint("Error getting video state: $e");
      return {};
    }
  }

  @override
  Future<bool> forceRefreshVideo() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('forceRefreshVideo');
      return result ?? false;
    } catch (e) {
      debugPrint("Error forcing video refresh: $e");
      return false;
    }
  }

  @override
  void hold() {
    methodChannel.invokeMethod('hold');
  }

  @override
  void unhold() {
    methodChannel.invokeMethod('unhold');
  }

  @override
  void mute() {
    methodChannel.invokeMethod('mute');
  }

  @override
  void unmute() {
    methodChannel.invokeMethod('unmute');
  }

  @override
  void cameraOn() {
    methodChannel.invokeMethod('cameraOn');
  }

  @override
  void cameraOff() {
    methodChannel.invokeMethod('cameraOff');
  }

  @override
  void transfer() {}

  @override
  void answer() {
    methodChannel.invokeMethod('answer');
  }

  @override
  void reject() {
    methodChannel.invokeMethod('reject');
  }

  @override
  void getOutboundCallNumbers() {}

  @override
  void getAgentStatus() {}

  ////////////////////////////////////////////////////////////////////
  String apiKey = '';
  String userPhoneNumber = '';
  String baseUrl = '';

  void initSdk({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) {
    this.apiKey = apiKey;
    this.userPhoneNumber = userPhoneNumber;
    this.baseUrl = baseUrl != null && baseUrl.isNotEmpty
        ? baseUrl
        : "https://crm-dev-v2.metechvn.com";
  }

  Future<ExtensionData?> getExtension({int retryTime = 0}) async {
    try {
      int retryCount = retryTime;
      final url = Uri.parse("$baseUrl/integration/extension/request");

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: json.encode({
              "phone_number": userPhoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      final result = ExtensionModel.fromJson(
        data.runtimeType is String ? jsonDecode(data) : data,
      );
      final message = result.message ?? '';

      if (result.success ?? false) {
        return result.data;
      } else {
        if (retryCount > 2) {
          throw Exception(message);
        }
        retryCount += 1;
        final releaseResult = await releaseExtension();
        if (!releaseResult) return null;
        return await getExtension(retryTime: retryCount);
      }
    } on Exception catch (e) {
      debugPrint("Error in getExtension: $e");
      throw Exception(e);
    }
  }

  Future<bool> releaseExtension() async {
    final url = Uri.parse('$baseUrl/integration/extension/release');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          "extension": userPhoneNumber,
        }),
      );

      final data = json.decode(response.body);
      final result = ReleaseExtensionModel.fromJson(data);
      if (result.success ?? false) {
        return true;
      } else {
        throw Exception(result.message ?? '');
      }
    } on Exception catch (e) {
      debugPrint("Error in releaseExtension: $e");
      throw Exception(e);
    }
  }
}
