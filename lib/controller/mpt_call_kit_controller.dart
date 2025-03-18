import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/camera_view.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';

class MptCallKitController {
  String apiKey = '';
  String userPhoneNumber = '';
  String baseUrl = '';
  String extension = '';

  static const MethodChannel channel = MethodChannel('mpt_callkit');

  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onlineStatusController => _onlineStatusController.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  static final MptCallKitController _instance =
      MptCallKitController._internal();

  MptCallKitController._internal() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onlineStatus') {
        _isOnline = call.arguments as bool;
        _onlineStatusController.add(call.arguments as bool);
      }
    });
  }

  factory MptCallKitController() {
    return _instance;
  }

  void initSdk({
    required String apiKey,
    String? baseUrl,
    bool isAgent = false,
    required String userPhoneNumber,
  }) async {
    this.apiKey = apiKey;
    this.userPhoneNumber = userPhoneNumber;
    this.baseUrl = baseUrl != null && baseUrl.isNotEmpty
        ? baseUrl
        : "https://crm-dev-v2.metechvn.com";
  }

  // Future<void> connectSocketByUser({
  //   required String baseUrl,
  //   required String userToken,
  // }) async {
  //   await MptSocket.connectSocketByUser(
  //     baseUrl,
  //     token: userToken,
  //   );
  // }

  Future<void> connectSocketByGuest({
    required String apiKey,
    required String baseUrl,
    String? appId,
    String? userName,
  }) async {
    await MptSocket.connectSocketByGuest(
      baseUrl,
      guestAPI: '/integration/security/guest-token',
      barrierToken: apiKey,
      appId: appId ?? '88888888',
      phoneNumber: userPhoneNumber,
      userName: userName ?? "guest",
    );
  }

  disposeSocket() {
    MptSocket.dispose();
  }

  Future<void> makeCallByGuest({
    required BuildContext context,
    required String phoneNumber,
    bool isShowNativeView = true,
    bool isVideoCall = false,
    ExtensionData? userExtensionData,
    Function(String?)? onError,
  }) async {
    try {
      final hasPermission = await requestPermission(context);
      if (!hasPermission) {
        onError?.call('Permission denied');
        return;
      }

      if (isShowNativeView) {
        if (Platform.isAndroid) {
          channel.invokeListMethod("startActivity");
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CameraView()));
        }
      }
      extension = userExtensionData?.username ?? '';
      final result = userExtensionData ?? await getExtension();
      if (result != null) {
        if (Platform.isAndroid) {
          channel.setMethodCallHandler((call) async {
            /// lắng nghe kết quả register
            if (call.method == 'registrationStateStream') {
              /// nếu thành công thì call luôn
              if (call.arguments == true) {
                final bool callResult = await channel.invokeMethod(
                  'call',
                  <String, dynamic>{
                    'phoneNumber': phoneNumber,
                    'isVideoCall': isVideoCall
                  },
                );
                if (!callResult) {
                  onError?.call('Tổng đài bận, liên hệ hỗ trợ');
                  print('quanth: call has failed');
                  await offline();
                  if (isShowNativeView) {
                    {
                      if (Platform.isIOS)
                        Navigator.pop(context);
                      else
                        await channel.invokeMethod("finishActivity");
                    }
                  }
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
        if (isShowNativeView) {
          {
            if (Platform.isIOS)
              Navigator.pop(context);
            else
              await channel.invokeMethod("finishActivity");
          }
        }
      }
    } on Exception catch (e) {
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

  // Method do register to SIP server
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
    Function(String?)? onError,
    required BuildContext context,
  }) async {
    try {
      if (isOnline) {
        onError?.call("You already registered. Please unregister first!");
        return false;
      } else {
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
          },
        );
        return result;
      }
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
      if (Platform.isIOS)
        Navigator.pop(context);
      else
        await channel.invokeMethod("finishActivity");
      return false;
    }
  }

  Future<bool> callMethod({
    required BuildContext context,
    required String destination,
    required bool isVideoCall,
    Function(String?)? onError,
  }) async {
    try {
      final hasPermission = await requestPermission(context);
      if (!hasPermission) {
        onError?.call("Permission denied");
        return false;
      }
      if (!isOnline) {
        onError?.call("You need register to SIP server first");
        return false;
      } else {
        final result = await channel.invokeMethod('call', {
          'destination': destination,
          'isVideoCall': isVideoCall,
        });
        if (result == false) {
          onError?.call("Current line is busy");
          return false;
        } else {
          return true;
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to call: '${e.message}'.");
      return false;
    }
  }

  // Method do unregister from SIP server
  Future<bool> offline({Function(String?)? onError}) async {
    try {
      if (!isOnline) {
        onError?.call("You need register to SIP server first");
        return false;
      } else {
        var result = await channel.invokeMethod(MptCallKitConstants.offline);
        return result;
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to go offline: '${e.message}'.");
      return false;
    }
  }

  Future<bool> hangup() async {
    try {
      final result = await channel.invokeMethod("hangup");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'hangup' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> hold() async {
    try {
      final result = await channel.invokeMethod("hold");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'hold' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> unhold() async {
    try {
      final result = await channel.invokeMethod("unhold");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'unhold' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> mute() async {
    try {
      final result = await channel.invokeMethod("mute");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'mute' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> unmute() async {
    try {
      final result = await channel.invokeMethod("unmute");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'unmute' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> cameraOn() async {
    try {
      final result = await channel.invokeMethod("cameraOn");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'cameraOn' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> cameraOff() async {
    try {
      final result = await channel.invokeMethod("cameraOff");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'cameraOff' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> reject() async {
    try {
      final result = await channel.invokeMethod("reject");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'reject' mothod: '${e.message}'.");
      return false;
    }
  }

  // Future<bool> transfer(String destination) async {
  //   try {
  //     final result = await channel.invokeMethod("transfer", {
  //       "destination": destination,
  //     });
  //     return result;
  //   } on PlatformException catch (e) {
  //     debugPrint("Failed in 'transfer' mothod: '${e.message}'.");
  //     return false;
  //   }
  // }
}
