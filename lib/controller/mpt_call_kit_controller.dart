import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_callkit_auth_method.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:mpt_callkit/views/camera_view.dart';

import 'mpt_call_kit_controller_repo.dart';

class MptCallKitController {
  String apiKey = '';
  String baseUrl = '';
  String extension = '';
  String pushToken = "";
  String appId = "";
  Map<String, dynamic>? userData;
  Map<String, dynamic>? currentUserInfo;
  ExtensionData? extensionData;
  Map<String, dynamic>? _configuration;

  static const MethodChannel channel = MethodChannel('mpt_callkit');
  static const eventChannel = EventChannel('native_events');

  /// online status stream
  final StreamController<bool> _onlineStatuslistener =
      StreamController<bool>.broadcast();
  Stream<bool> get onlineStatuslistener => _onlineStatuslistener.stream;

  /// call state stream
  final StreamController<String> _callEvent =
      StreamController<String>.broadcast();
  Stream<String> get callEvent => _callEvent.stream;

  /// call state stream
  final StreamController<String> _appEvent =
      StreamController<String>.broadcast();
  Stream<String> get appEvent => _appEvent.stream;

  /// camera state stream
  final StreamController<bool> _cameraState =
      StreamController<bool>.broadcast();
  Stream<bool> get cameraState => _cameraState.stream;

  /// microphone state stream
  final StreamController<bool> _microState = StreamController<bool>.broadcast();
  Stream<bool> get microState => _microState.stream;

  /// hold call state stream
  final StreamController<bool> _holdCallState =
      StreamController<bool>.broadcast();
  Stream<bool> get holdCallState => _holdCallState.stream;

  /// call type state stream
  final StreamController<String> _callType =
      StreamController<String>.broadcast();
  Stream<String> get callType => _callType.stream;

  /// current session id stream
  final StreamController<String> _sessionId =
      StreamController<String>.broadcast();
  Stream<String> get sessionId => _sessionId.stream;

  String? _currentSessionId = "";
  String? get currentSessionId => _currentSessionId;

  ///

  bool? _isOnline = false;
  bool? get isOnline => _isOnline;

  static final MptCallKitController _instance =
      MptCallKitController._internal();

  MptCallKitController._internal() {
    if (Platform.isAndroid) {
      eventChannel.receiveBroadcastStream().listen((event) {
        print('🔥 Received event from native: $event');
        if (event is Map) {
          // Handle map events with message and data
          final String message = event['message'];
          final dynamic data = event['data'];

          switch (message) {
            case 'onlineStatus':
              _isOnline = data as bool;
              _onlineStatuslistener.add(data);
              break;
            case 'callState':
              _callEvent.add(data.toString());
              break;
            case 'cameraState':
              _cameraState.add(data as bool);
              break;
            case 'microphoneState':
              _microState.add(data as bool);
              break;
            case 'holdCallState':
              _holdCallState.add(data as bool);
              break;
            case 'callType':
              _callType.add(data.toString());
              break;
            case 'curr_sessionId':
              _sessionId.add(data as String);
              _currentSessionId = data;
              break;
          }
        }
      });
    } else {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onlineStatus') {
          _isOnline = call.arguments as bool;
          _onlineStatuslistener.add(call.arguments as bool);
        }

        if (call.method == 'callState') {
          _callEvent.add(call.arguments as String);
        }

        if (call.method == 'cameraState') {
          _cameraState.add(call.arguments as bool);
        }

        if (call.method == 'microphoneState') {
          _microState.add(call.arguments as bool);
        }

        if (call.method == 'holdCallState') {
          _holdCallState.add(call.arguments as bool);
        }

        if (call.method == 'callType') {
          _callType.add(call.arguments as String);
        }

        if (call.method == 'curr_sessionId') {
          _sessionId.add(call.arguments as String);
          _currentSessionId = call.arguments as String;
        }

        if (call.method == 'callKitAnswerReceived') {
          print(
              'Received callKitAnswerReceived event from native: ${call.arguments}');
        }
      });
    }
  }

  factory MptCallKitController() {
    return _instance;
  }

  void initSdk({
    required String apiKey,
    String? baseUrl,
    String? pushToken,
    String? appId,
  }) async {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl != null && baseUrl.isNotEmpty
        ? baseUrl
        : "https://crm-dev-v2.metechvn.com";
    this.pushToken = pushToken ?? "";
    this.appId = appId ?? "";

    print("init pushToken: $pushToken");
    print("init appId: $appId");

    _appEvent.add(AppEventConstants.READY);
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

  Future<bool> loginRequest({
    required String username,
    required String password,
    required int tenantId,
    String? baseUrl,
    Function(Map<String, dynamic>)? data,
    Function(String?)? onError,
  }) async {
    var result = await MptCallkitAuthMethod().login(
      username: username,
      password: password,
      tenantId: tenantId,
      baseUrl: baseUrl,
      onError: onError,
      data: (e) {
        userData = e;
        data?.call(e);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
    }
    return result;
  }

  Future<bool> loginSSORequest({
    required String ssoToken,
    required String organization,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    var result = await MptCallkitAuthMethod().loginSSO(
      ssoToken: ssoToken,
      organization: organization,
      baseUrl: baseUrl,
      onError: onError,
      data: (e) {
        userData = e;
        data?.call(e);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
    }
    return result;
  }

  Future<void> initDataWhenLoginSuccess({
    required BuildContext context,
    Function(String?)? onError,
  }) async {
    if (userData != null) {
      await _getCurrentUserInfo();
      await _getConfiguration();
      await _connectToSocketServer();
      await _registerToSipServer(context: context);
    } else {
      print("Access token is null");
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      onError?.call("Access token is null");
    }
  }

  // handle register to sip server
  Future<void> _registerToSipServer({
    required BuildContext context,
  }) async {
    // Get extension data from current user info
    if (currentUserInfo != null && _configuration != null) {
      extensionData = ExtensionData(
        username: currentUserInfo!["user"]["extension"],
        password: currentUserInfo!["user"]["sipPassword"],
        domain: currentUserInfo!["tenant"]["domainContext"],
        sipServer: _configuration!["MOBILE_SIP_URL"],
        port: _configuration!["MOBILE_SIP_PORT"],
      );

      if (extensionData != null) {
        // Register to SIP server
        await MptCallKitController().online(
          username: extensionData!.username!,
          displayName: extensionData!.username!, // ??
          srtpType: 0,
          authName: extensionData!.username!, // ??
          password: extensionData!.password!,
          userDomain: extensionData!.domain!,
          sipServer: extensionData!.sipServer!,
          sipServerPort: extensionData!.port ?? 5060,
          transportType: 0,
          pushToken: pushToken,
          appId: appId,
          onError: (p0) {
            print("Error in register to sip server: ${p0.toString()}");
          },
          context: context,
        );
      } else {
        _appEvent.add(AppEventConstants.ERROR);
      }
    } else {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
    }
  }

  // get current user info
  Future<void> _getCurrentUserInfo() async {
    currentUserInfo = await MptCallkitAuthMethod().getCurrentUserInfo(
      baseUrl: baseUrl,
      accessToken: userData!["result"]["accessToken"],
      onError: (p0) {
        print("Error in get current user info: ${p0.toString()}");
      },
    );
    if (currentUserInfo == null) {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
    }
  }

  Future<void> _connectToSocketServer() async {
    print("connectToSocketServer");
    if (_configuration != null) {
      MptSocketSocketServer.initialize(
        tokenParam: userData!["result"]["accessToken"],
        configuration: _configuration!,
        currentUserInfo: currentUserInfo!,
        onMessageReceivedParam: (p0) {
          print("Message received in callback: $p0");
        },
      );
    } else {
      print("Cannot connect agent to socket server - configuration is null");
    }
  }

  // get configuration
  Future<void> _getConfiguration() async {
    _configuration = await MptCallkitAuthMethod().getConfiguration(
      baseUrl: baseUrl,
      accessToken: userData!["result"]["accessToken"],
      onError: (p0) {
        print("Error in get configuration: ${p0.toString()}");
      },
    );
  }

  // logout user account from server
  Future<bool> logoutRequest({
    String? baseUrl,
    Function(String?)? onError,
    required String cloudAgentName,
    required int cloudAgentId,
    required int cloudTenantId,
  }) async {
    var result = await MptCallkitAuthMethod().logout(
      baseUrl: baseUrl,
      onError: onError,
      cloudAgentName: cloudAgentName,
      cloudAgentId: cloudAgentId,
      cloudTenantId: cloudTenantId,
    );

    return result;
  }

  Future<bool> logout({
    Function(String?)? onError,
  }) async {
    bool isLogoutAccountSuccess = false;
    bool isUnregistered = false;

    // Ngắt kết nối socket
    await MptSocketSocketServer.disconnect();

    isLogoutAccountSuccess = await offline();
    // if (isOnline == true) {
    // } else {
    //   isLogoutAccountSuccess = true;
    // }

    isUnregistered = await logoutRequest(
      cloudAgentId: currentUserInfo!["user"]["id"],
      cloudAgentName: currentUserInfo!["user"]["fullName"] ?? "",
      cloudTenantId: currentUserInfo!["tenant"]["id"],
      baseUrl: baseUrl,
      onError: onError,
    );

    // Important: Destroy instance when logout
    await MptSocketSocketServer.destroyInstance();

    if (isLogoutAccountSuccess && isUnregistered) {
      _appEvent.add(AppEventConstants.LOGGED_OUT);
      return true;
    } else {
      _appEvent.add(AppEventConstants.ERROR);
      return false;
    }
  }

  Future<void> connectSocketByGuest({
    required String apiKey,
    required String baseUrl,
    String? appId,
    String? userName,
    required String phoneNumber,
  }) async {
    await MptSocketLiveConnect.connectSocketByGuest(
      baseUrl,
      guestAPI: '/integration/security/guest-token',
      barrierToken: apiKey,
      appId: appId ?? '88888888',
      phoneNumber: phoneNumber,
      userName: userName ?? "guest",
    );
  }

  disposeSocket() {
    MptSocketLiveConnect.dispose();
  }

  // Make call by guest
  Future<void> makeCallByGuest({
    required BuildContext context,
    required String userPhoneNumber,
    required String destinationPhoneNumber,
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
      final result =
          userExtensionData ?? await getExtension(phoneNumber: userPhoneNumber);
      if (result != null) {
        if (Platform.isAndroid) {
          channel.setMethodCallHandler((call) async {
            /// lắng nghe kết quả register
            if (call.method == 'registrationStateStream') {
              // connect socket by guest
              await connectSocketByGuest(
                apiKey: apiKey,
                baseUrl: baseUrl,
                appId: "88888888",
                userName: "guest",
                phoneNumber: userPhoneNumber,
              );

              /// nếu thành công thì call luôn
              if (call.arguments == true) {
                // make call by guest
                final bool callResult = await channel.invokeMethod(
                  'call',
                  <String, dynamic>{
                    'phoneNumber': destinationPhoneNumber,
                    'isVideoCall': isVideoCall
                  },
                );
                if (!callResult) {
                  onError?.call('Tổng đài bận, liên hệ hỗ trợ');
                  print('quanth: call has failed');
                  await offline();
                  if (isShowNativeView) {
                    {
                      if (Platform.isIOS) {
                        Navigator.pop(context);
                      } else {
                        await channel.invokeMethod("finishActivity");
                      }
                    }
                  }
                }
              } else {
                print('quanth: registration has failed');
                if (Platform.isIOS) {
                  Navigator.pop(context);
                } else {
                  await channel.invokeMethod("finishActivity");
                }
              }
            } else if (call.method == 'releaseExtension') {
              print('quanth: releaseExtension has started');
              await releaseExtension();
              print('quanth: releaseExtension has done');
              disposeSocket();
            }
          });
        }
        await online(
          username: result.username ?? "",
          displayName: userPhoneNumber,
          authName: '',
          password: result.password!,
          userDomain: result.domain!,
          sipServer: result.sipServer!,
          sipServerPort: result.port ?? 5060,
          transportType: 0,
          srtpType: 0,
          context: context,
          appId: appId,
          pushToken: pushToken,
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
            if (Platform.isIOS) {
              Navigator.pop(context);
            } else {
              await channel.invokeMethod("finishActivity");
            }
          }
        }
      }
    } on Exception catch (e) {
      onError?.call(e.toString());
      debugPrint("Failed to call: '${e.toString()}'.");
      if (Platform.isIOS) Navigator.pop(context);
    }
  }

  Future<ExtensionData?> getExtension(
      {int retryTime = 0, required String phoneNumber}) async {
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
              "phone_number": phoneNumber,
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
    Function(String?)? onError,
    required BuildContext context,
    String? pushToken,
    String? appId,
  }) async {
    try {
      final hasPermission = await requestPermission(context);
      if (!hasPermission) {
        onError?.call('Permission denied');
        return false;
      }
      if (isOnline == true) {
        onError?.call("You already registered. Please unregister first!");
        return false;
      } else {
        final bool result = await channel.invokeMethod(
          MptCallKitConstants.login,
          {
            'username': username,
            'displayName': displayName,
            'authName': authName,
            'password': password,
            'userDomain': userDomain,
            'sipServer': sipServer,
            'sipServerPort': sipServerPort,
            'transportType': transportType,
            'srtpType': srtpType,
            "pushToken": pushToken ?? "",
            "appId": appId ?? "",
          },
        );

        return result;
      }
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
      if (Platform.isIOS) {
        Navigator.pop(context);
      } else {
        await channel.invokeMethod("finishActivity");
      }
      return false;
    }
  }

// Call to a destination number
  Future<bool> makeCall({
    required String destination,
    required String outboundNumber,
    required String extraInfo,
    bool? isVideoCall,
    Function(String?)? onError,
  }) async {
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };
    return await MptCallKitControllerRepo().makeCall(
      baseUrl: baseUrl,
      tenantId: currentUserInfo!["tenant"]["id"],
      applicationId: outboundNumber,
      senderId: destination,
      agentId: currentUserInfo!["user"]["id"] ?? 0,
      extraInfo: jsonEncode(extraInfoResult),
      authToken: userData!["result"]["accessToken"],
      onError: onError,
    );
  }

  // Make call internal : agent extension to agent extension
  Future<bool> makeCallInternal({
    String? senderId,
    required String destination,
    required String extraInfo,
    bool? isVideoCall,
    Function(String?)? onError,
  }) async {
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };

    return await MptCallKitControllerRepo().makeCallInternal(
      baseUrl: baseUrl,
      tenantId: currentUserInfo!["tenant"]["id"],
      applicationId: destination,
      senderId: senderId ?? currentUserInfo!["user"]["extension"],
      agentId: currentUserInfo!["user"]["id"] ?? 0,
      extraInfo: jsonEncode(extraInfoResult),
      authToken: userData!["result"]["accessToken"],
      onError: onError,
    );
  }

  // Future<bool> callMethod({
  //   required BuildContext context,
  //   required String destination,
  //   required bool isVideoCall,
  //   Function(String?)? onError,
  // }) async {
  //   try {
  //     final hasPermission = await requestPermission(context);
  //     if (!hasPermission) {
  //       onError?.call("Permission denied");
  //       return false;
  //     }
  //     if (!isOnline) {
  //       onError?.call("You need register to SIP server first");
  //       return false;
  //     } else {
  //       final result = await channel.invokeMethod('call', {
  //         'destination': destination,
  //         'isVideoCall': isVideoCall,
  //       });
  //       if (result == false) {
  //         onError?.call("Current line is busy");
  //         return false;
  //       } else {
  //         return true;
  //       }
  //     }
  //   } on PlatformException catch (e) {
  //     debugPrint("Failed to call: '${e.message}'.");
  //     return false;
  //   }
  // }

  Future<bool> changeAgentStatus({
    required int reasonCodeId,
    required String statusName,
    Function(String?)? onError,
  }) async {
    if (currentUserInfo != null && userData != null) {
      return await MptCallKitControllerRepo().changeAgentStatus(
          cloudAgentId: currentUserInfo!["user"]["id"],
          cloudTenantId: currentUserInfo!["tenant"]["id"],
          cloudAgentName: currentUserInfo!["user"]["fullName"] ?? "",
          reasonCodeId: reasonCodeId,
          statusName: statusName,
          baseUrl: baseUrl,
          accessToken: userData!["result"]["accessToken"]);
    } else {
      onError
          ?.call("changeAgentStatus: current user info or user data is null");
      return false;
    }
  }

  // Method do unregister from SIP server
  Future<bool> offline({Function(String?)? onError}) async {
    try {
      // if (isOnline == false) {
      //   onError?.call("You need register to SIP server first");
      //   return false;
      // } else {
      var result = await channel.invokeMethod(MptCallKitConstants.offline);
      return result;
      // }
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

  Future<bool> rejectCall() async {
    try {
      final result = await channel.invokeMethod("reject");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'reject' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> answerCall() async {
    try {
      final result = await channel.invokeMethod("answer");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'answer' mothod: '${e.message}'.");
      return false;
    }
  }

  Future<bool> switchCamera() async {
    try {
      final result = await channel.invokeMethod('switchCamera');
      return result ?? false;
    } catch (e) {
      print('Error switching camera: $e');
      return false;
    }
  }

  Future<bool> setSpeaker({required bool enable}) async {
    try {
      final result = await channel.invokeMethod('setSpeaker', {
        'enable': enable,
      });
      return result ?? false;
    } catch (e) {
      print('Error setting speaker: $e');
      return false;
    }
  }

  Future<bool> transfer({required String destination}) async {
    try {
      final result = await channel.invokeMethod("transfer", {
        "destination": destination,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'transfer' mothod: '${e.message}'.");
      return false;
    }
  }
}
