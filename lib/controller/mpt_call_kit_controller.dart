import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/camera_view.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'dart:io';

class MptCallKitController {
  String apiKey = '';
  String userPhoneNumber = '';
  String baseUrl = '';
  String extension = '';

  static const MethodChannel channel = MethodChannel('mpt_callkit');

  static final MptCallKitController _instance =
      MptCallKitController._internal();

  MptCallKitController._internal();

  factory MptCallKitController() {
    return _instance;
  }

  final StreamController<bool> _isGetExtensionSuccess = StreamController();

  Stream<bool> get isGetExtensionSuccess => _isGetExtensionSuccess.stream;

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

  Future<void> makeCall({
    required BuildContext context,
    required String phoneNumber,
    bool isVideoCall = false,
    Function(String?)? onError,
  }) async {
    try {
      final hasPerrmission = await requestPermission(context);
      if (!hasPerrmission) {
        onError?.call('Permission denied');
        return;
      }

      if (Platform.isAndroid) {
        channel.invokeListMethod("startActivity");
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const CameraView()));
      }

      final result = await getExtension();
      if (result != null) {
        _isGetExtensionSuccess.add(true);
        await online(
          username: result.username ?? "",
          displayName: phoneNumber,
          authName: '',
          password: result.password!,
          userDomain: result.domain!,
          sipServer: result.sipServer!,
          sipServerPort: result.port ?? 5060,
          transportType: 0,
          srtpType: 0,
          phoneNumber: phoneNumber,
          isVideoCall: isVideoCall,
          onBusy: () {
            onError?.call('Tổng đài bận, liên hệ hỗ trợ');
          },
          context: context,
        );
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => const CameraView(),
        //   ),
        // );
      } else {
        onError?.call('Tổng đài bận, liên hệ hỗ trợ');
        // _isGetExtensionSuccess.add(false);
        if (Platform.isIOS)
          Navigator.pop(context);
        else
          await channel.invokeMethod("finishActivity");
      }
    } on Exception catch (e) {
      // _isGetExtensionSuccess.add(false);
      onError?.call(e.toString());
      debugPrint("Failed to call: '${e.toString()}'.");
      if (Platform.isIOS) Navigator.pop(context);
    }
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
        extension = result.data?.username ?? '';
        return result.data;
      } else {
        return null;
        // if (retryCount > 2) {
        //   throw Exception(message);
        // }
        // retryCount += 1;
        // final releaseResult = await releaseExtension();
        // if (!releaseResult) return null;
        // return await getExtension(retryTime: retryCount);
      }
    } on Exception catch (e) {
      debugPrint("Error in getExtension: $e");
      return null;
    }
  }

  Future<bool> releaseExtension() async {
    final url = Uri.parse('$baseUrl/integration/extension/release');
    try {
      if (extension.isEmpty) return true;
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          "extension": extension,
        }),
      );

      final data = json.decode(response.body);
      final result = ReleaseExtensionModel.fromJson(data);
      extension = '';
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

  Future<bool> requestPermission(BuildContext context) async {
    final bool permissionResult =
        await channel.invokeMethod('requestPermission');

    if (permissionResult) {
      return true;
    } else {
      // write a dialog to open app setting
      Dialog dialog = Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Permission denied',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please allow the app to access the camera and microphone in the app settings',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await channel.invokeMethod('openAppSetting');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Go to Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      showDialog(
        context: context,
        builder: (context) => dialog,
      );
      return false;
    }
  }

  Future<bool> online({
    required String username,
    required String displayName,
    required String authName,
    required String password,
    required String userDomain,
    required String sipServer,
    required int sipServerPort,
    required int transportType,
    required int srtpType,
    required String phoneNumber,
    bool isVideoCall = false,
    void Function()? onBusy,
    required BuildContext context,
  }) async {
    try {
      if (Platform.isAndroid) {
        channel.setMethodCallHandler((call) async {
          /// lắng nghe kết quả register
          if (call.method == 'registrationStateStream') {
            /// nếu thành công thì call luôn
            /// mở màn hình video call
            // channel.invokeMethod('startActivity');
            if (call.arguments == true) {
              final bool callResult = await channel.invokeMethod(
                'call',
                <String, dynamic>{
                  'phoneNumber': phoneNumber,
                  'isVideoCall': isVideoCall
                },
              );
              if (!callResult) {
                onBusy?.call();
                print('quanth: call has failed');
                await offline();
                if (Platform.isIOS)
                  Navigator.pop(context);
                else
                  await channel.invokeMethod("finishActivity");
              }
            } else {
              print('quanth: registration has failed');
              if (Platform.isIOS)
                Navigator.pop(context);
              else {
                await channel.invokeMethod("finishActivity");
              }
            }
          } else if (call.method == 'releaseExtension') {
            print('quanth: releaseExtension has started');
            await releaseExtension();
            print('quanth: releaseExtension has done');
          }
        });
      }
      final bool result = await channel.invokeMethod(
        MptCallKitConstants.login,
        {
          'username': username,
          'displayName': userPhoneNumber,
          'authName': authName,
          'password': password,
          'userDomain': userDomain,
          'sipServer': sipServer,
          'sipServerPort': sipServerPort,
          'transportType': transportType,
          'srtpType': srtpType,
          'phoneNumber': phoneNumber,
          'isVideoCall': isVideoCall,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
      if (Platform.isIOS)
        Navigator.pop(context);
      else
        await channel.invokeMethod("finishActivity");
      return false;
    }
  }

  Future<void> offline() async {
    try {
      await channel.invokeMethod(MptCallKitConstants.offline);
    } on PlatformException catch (e) {
      debugPrint("Failed to go offline: '${e.message}'.");
    }
  }
}
