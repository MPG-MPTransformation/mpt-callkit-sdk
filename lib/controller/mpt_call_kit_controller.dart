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

import 'mpt_call_kit_controller_repo.dart';

class MptCallKitController {
  String apiKey = '';
  String baseUrl = '';
  String extension = '';
  String pushToken = "";
  String appId = "";
  Map<String, dynamic>? currentUserInfo;
  ExtensionData? extensionData;
  Map<String, dynamic>? _configuration;
  bool? _isOnline = false;
  bool? get isOnline => _isOnline;
  BuildContext? context;
  bool isMakeCallByGuest = false;

  static const MethodChannel channel = MethodChannel('mpt_callkit');
  static const eventChannel = EventChannel('native_events');
  static final MptCallKitController _instance =
      MptCallKitController._internal();

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

  /* -------------------------------------------------------------------------------
  current audio device stream
  1. Android 
    * If wired headset is connected, it will be the only speaker.
    * Possible values: 
      - "WIRED_HEADSET".
      - "SPEAKER_PHONE".
      - "BLUETOOTH".
      - "EARPIECE".
  2. iOS 
    * If bluetooth is connected, it will be the only speaker.
    * Possible values: 
      - "SPEAKER_PHONE".
      - "EARPIECE".
    * Cannot handle if bluetooth is connected.
  -------------------------------------------------------------------------------*/
  final StreamController<String> _currentAudioDeviceStream =
      StreamController<String>.broadcast();
  Stream<String> get currentAudioDeviceStream =>
      _currentAudioDeviceStream.stream;

  /// audio devices stream, ONLY AVAILABLE ON ANDROID
  final StreamController<List<String>> _audioDevicesAvailable =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get audioDevicesAvailable =>
      _audioDevicesAvailable.stream;

  /// local camera state stream
  final StreamController<bool> _localCamStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get localCamStateStream => _localCamStateController.stream;

  /// local microphone state stream
  final StreamController<bool> _localMicStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get localMicStateStream => _localMicStateController.stream;

  /// remote camera state stream
  final StreamController<bool> _remoteCamStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get remoteCamStateStream => _remoteCamStateController.stream;

  /// remote microphone state stream
  final StreamController<bool> _remoteMicStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get remoteMicStateStream => _remoteMicStateController.stream;

  /// remote party answer stream
  /// when remote party answer the call, this stream will be triggered
  final StreamController<bool> _calleeAnsweredStream =
      StreamController<bool>.broadcast();
  Stream<bool> get calleeAnsweredStream => _calleeAnsweredStream.stream;

  String? _currentSessionId = "";
  String? get currentSessionId => _currentSessionId;

  // Media states
  bool _localCamState = true;
  bool get localCamState => _localCamState;

  bool _localMicState = true;
  bool get localMicState => _localMicState;

  bool _remoteCamState = true;
  bool get remoteCamState => _remoteCamState;

  bool _remoteMicState = true;
  bool get remoteMicState => _remoteMicState;

  String? _currentAudioDevice = "";
  String? get currentAudioDevice => _currentAudioDevice;

  String? _currentCallState = "";
  String? get currentCallState => _currentCallState;

  final bool _calleeAnswered = false;
  bool? get calleeAnswered => _calleeAnswered;

  String? _currentAppEvent = "";
  String? get currentAppEvent => _currentAppEvent;

  /// current available audio devices, ONLY AVAILABLE ON ANDROID
  List<String>? _currentAvailableAudioDevices = [];
  List<String>? get currentAvailableAudioDevices =>
      _currentAvailableAudioDevices;

  // Track the last sent media status
  Map<String, dynamic>? _lastSentMediaStatus;

  // Add StreamSubscription to manage the event channel subscription
  StreamSubscription<dynamic>? _eventChannelSubscription;

  // Add Completer for guest registration
  Completer<bool>? _guestRegistrationCompleter;

  ///

  MptCallKitController._internal() {
    if (Platform.isAndroid) {
      _setupEventChannelListener();
    } else {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onlineStatus') {
          _isOnline = call.arguments as bool;
          _onlineStatuslistener.add(call.arguments as bool);
          print("onlineStatus: ${call.arguments}");
        }
        if (call.method == 'callState') {
          _currentCallState = call.arguments as String;
          _callEvent.add(call.arguments as String);
          _handleCallStateChanged(call.arguments as String);

          // Handle guest call specific logic
          if (isMakeCallByGuest) {
            if (call.arguments == CallStateConstants.FAILED) {
              print("makeCallByGuest() - Call failed!");
              offline();
              releaseExtension();
            }

            if (call.arguments == CallStateConstants.CLOSED) {
              print("makeCallByGuest() - Call ended!");
              offline();
              releaseExtension();
            }
          }
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

        if (call.method == 'currentAudioDevice') {
          _currentAudioDevice = call.arguments as String;
          _currentAudioDeviceStream.add(call.arguments as String);
        }

        if (call.method == 'audioDevices') {
          _currentAvailableAudioDevices = call.arguments as List<String>;
          _audioDevicesAvailable.add(call.arguments as List<String>);
        }

        if (call.method == "registrationStateStream") {
          if (isMakeCallByGuest) {
            _handleGuestRegistrationState(call.arguments);
          }
        }

        if (call.method == 'callKitAnswerReceived') {
          print(
              'Received callKitAnswerReceived event from native: ${call.arguments}');
        }

        if (call.method == 'recvCallMessage') {
          print('Received call message from native: ${call.arguments}');
          handleRecvCallMessage(call.arguments);
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
    _currentAppEvent = AppEventConstants.READY;
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
    Function(String?)? accessTokenResponse,
    Function(String?)? onError,
  }) async {
    var result = await MptCallkitAuthMethod().login(
      username: username,
      password: password,
      tenantId: tenantId,
      baseUrl: baseUrl,
      onError: onError,
      data: (e) {
        accessTokenResponse?.call(e["result"]["accessToken"]);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
    }
    return result;
  }

  Future<bool> loginSSORequest({
    required String ssoToken,
    required String organization,
    String? baseUrl,
    Function(String?)? onError,
    Function(String?)? accessTokenResponse,
  }) async {
    var result = await MptCallkitAuthMethod().loginSSO(
      ssoToken: ssoToken,
      organization: organization,
      baseUrl: baseUrl,
      onError: onError,
      data: (e) {
        accessTokenResponse?.call(e["result"]["accessToken"]);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
    }
    return result;
  }

  Future<void> initDataWhenLoginSuccess({
    required BuildContext context,
    Function(String?)? onError,
    String? accessToken,
  }) async {
    this.context = context;

    if (accessToken != null) {
      await _getCurrentUserInfo(accessToken);
      await _getConfiguration(accessToken);

      if (currentUserInfo != null &&
          currentUserInfo!["user"] != null &&
          currentUserInfo!["tenant"] != null &&
          _configuration!["MOBILE_SIP_URL"] != null &&
          _configuration!["MOBILE_SIP_PORT"] != null) {
        await _connectToSocketServer(accessToken);
        await _registerToSipServer(context: context);
      } else {
        _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
        onError?.call("Access token is expired");
        print("Access token is expired");
        _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
      }
    } else {
      print("Access token is null");
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      onError?.call("Access token is null");
      _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
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
          username: extensionData?.username ?? "",
          displayName: extensionData?.username ?? "", // ??
          srtpType: 0,
          authName: extensionData?.username ?? "", // ??
          password: extensionData?.password ?? "",
          userDomain: extensionData?.domain ?? "",
          sipServer: extensionData?.sipServer ?? "",
          sipServerPort: extensionData?.port ?? 5060,
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
        _currentAppEvent = AppEventConstants.ERROR;
      }
    } else {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
    }
  }

  // get current user info
  Future<void> _getCurrentUserInfo(String accessToken) async {
    currentUserInfo = await MptCallkitAuthMethod().getCurrentUserInfo(
      baseUrl: baseUrl,
      accessToken: accessToken,
      onError: (p0) {
        print("Error in get current user info: ${p0.toString()}");
      },
    );
    if (currentUserInfo != null &&
        currentUserInfo!["user"] == null &&
        currentUserInfo!["tenant"] == null) {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
      print("Access token is expired");
    }
  }

  Future<void> _connectToSocketServer(String accessToken) async {
    print("connectToSocketServer");

    if (_configuration != null) {
      try {
        MptSocketSocketServer.initialize(
          tokenParam: accessToken,
          configuration: _configuration!,
          currentUserInfo: currentUserInfo!,
          onMessageReceivedParam: (p0) {
            print("Message received in callback: $p0");
          },
        );
      } catch (e) {
        print("Error in connect to socket server: ${e.toString()}");
      }
    } else {
      print("Cannot connect agent to socket server - configuration is null");
    }
  }

  // get configuration
  Future<void> _getConfiguration(String accessToken) async {
    _configuration = await MptCallkitAuthMethod().getConfiguration(
      baseUrl: baseUrl,
      accessToken: accessToken,
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
      _currentAppEvent = AppEventConstants.LOGGED_OUT;
      return true;
    } else {
      _appEvent.add(AppEventConstants.ERROR);
      _currentAppEvent = AppEventConstants.ERROR;
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
    required String destination,
    required String extraInfo,
    bool isVideoCall = false,
    Function(String?)? onError,
  }) async {
    try {
      extension = '';
      final result = await getExtension(phoneNumber: userPhoneNumber);

      var extraInfoResult = {
        "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
        "extraInfo": extraInfo,
      };

      if (result != null) {
        online(
          username: result.username ?? "",
          displayName: userPhoneNumber,
          authName: '',
          password: result.password ?? "",
          userDomain: result.domain ?? "",
          sipServer: result.sipServer ?? "",
          sipServerPort: result.port ?? 5060,
          transportType: 0,
          srtpType: 0,
          context: context,
          appId: appId,
          pushToken: pushToken,
          isMakeCallByGuest: true,
        );

        // Wait for SIP registration to complete
        _guestRegistrationCompleter = Completer<bool>();

        try {
          // Wait for registration result with timeout
          final registrationResult = await _guestRegistrationCompleter!.future
              .timeout(const Duration(seconds: 30));

          if (registrationResult) {
            await MptCallKitControllerRepo().makeCallByGuest(
              phoneNumber: userPhoneNumber,
              extension: result.username ?? "",
              destination: destination,
              authToken: apiKey,
              extraInfo: jsonEncode(extraInfoResult),
              onError: onError,
            );
            // showAndroidCallKit();
          } else {
            print('SIP Registration has failed');
            onError?.call('SIP Registration failed');
          }
        } catch (e) {
          print('Registration timeout or error: $e');
          onError?.call('Registration timeout');
        } finally {
          _guestRegistrationCompleter = null;
        }
      } else {
        onError?.call('Cannot get extension data');
        print("Cannot get extension data");
      }
    } on Exception catch (e) {
      onError?.call(e.toString());
      debugPrint("Failed to call: '${e.toString()}'.");
      // if (Platform.isIOS) Navigator.pop(context);
    }
  }

  Future<ExtensionData?> getExtension(
      {int retryTime = 0, required String phoneNumber}) async {
    try {
      print("getExtension");
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
        if (retryCount > 2) {
          throw Exception(message);
        }
        retryCount += 1;
        final releaseResult = await releaseExtension();
        if (!releaseResult) return null;
        return await getExtension(
            retryTime: retryCount, phoneNumber: phoneNumber);
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
        print("Release extension has done");
        return true;
      } else {
        print("Release extension has failed: ${result.message}");
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
                      Navigator.of(context).pop();
                      await channel.invokeMethod('openAppSetting');
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
    bool? isMakeCallByGuest = false,
  }) async {
    this.isMakeCallByGuest = isMakeCallByGuest ?? false;
    print("isMakeCallByGuest: $isMakeCallByGuest");

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
      // if (Platform.isIOS) {
      //   Navigator.pop(context);
      // } else {
      //   await channel.invokeMethod("finishActivity");
      // }
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
    required String accessToken,
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
      authToken: accessToken,
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
    required String accessToken,
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
      authToken: accessToken,
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
    required String accessToken,
  }) async {
    if (currentUserInfo != null) {
      return await MptCallKitControllerRepo().changeAgentStatus(
        cloudAgentId: currentUserInfo!["user"]["id"],
        cloudTenantId: currentUserInfo!["tenant"]["id"],
        cloudAgentName: currentUserInfo!["user"]["fullName"] ?? "",
        reasonCodeId: reasonCodeId,
        statusName: statusName,
        baseUrl: baseUrl,
        accessToken: accessToken,
        onError: onError,
      );
    } else {
      onError?.call(
          "changeAgentStatus: current user info is null - currentUserInfo: $currentUserInfo");
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

  Future<bool> setSpeaker({required String state}) async {
    try {
      final result = await channel.invokeMethod('setSpeaker', {
        'state': state,
      });
      return result ?? false;
    } catch (e) {
      print('Error setting speaker: $e');
      return false;
    }
  }

  // Only for android
  Future<void> getAudioDevices() async {
    try {
      final result = await channel.invokeMethod('getAudioDevices');
      print('Audio devices: $result');
    } catch (e) {
      print('Error getting audio devices: $e');
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

  Future<bool> updateVideoCall({required bool isVideo}) async {
    try {
      final result = await channel.invokeMethod("updateVideoCall", {
        "isVideo": isVideo,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'updateVideoCall' mothod: '${e.message}'.");
      return false;
    }
  }

  // Subscribe to media status channel
  Future<void> subscribeToMediaStatusChannel() async {
    try {
      // Get session ID
      if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
        print('Subscribing to event with sessionId: $_currentSessionId');

        // Subscribe to the socket event
        MptSocketSocketServer.subscribeToMediaStatusChannel(_currentSessionId!,
            (data) {
          print('Received media status message: $data');
          handleMediaStatusMessage(data);
        });
      } else {
        print(
            'Cannot subscribe to media status event: sessionId is null or empty');

        // If there's no sessionId, wait 1s and check again
        await Future.delayed(const Duration(seconds: 1));

        if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
          print(
              'Retrying subscribe to event with sessionId: $_currentSessionId');
          MptSocketSocketServer.subscribeToMediaStatusChannel(
              _currentSessionId!, (data) {
            print('Received media status message: $data');
            handleMediaStatusMessage(data);
          });
        } else {
          print('Still cannot get sessionId after retry');
        }
      }
    } catch (e) {
      print('Error subscribing to media status event: $e');
    }
  }

  // Handle media status message
  void handleMediaStatusMessage(dynamic messageData) {
    try {
      // Parse message data
      Map<dynamic, dynamic>? data;
      if (messageData is Map) {
        data = messageData;
      } else if (messageData is String) {
        data = Map<String, dynamic>.from(jsonDecode(messageData));
      }

      if (data != null) {
        // Process media status message based on your app's requirements
        print('Media status data: $data');

        // Check if message has the expected format with agentId, cameraState, and mircroState
        if (data.containsKey('agentId') &&
            data.containsKey('cameraState') &&
            data.containsKey('mircroState')) {
          final messageUserId = data['agentId'];
          final cameraState = data['cameraState'] as bool;
          final micState = data['mircroState'] as bool;

          // Determine if the message is from the current user
          if (messageUserId == currentUserInfo?["user"]["id"]) {
            // Message from the current user, update local status
            _localCamState = cameraState;
            _localMicState = micState;
            _cameraState.add(cameraState);
            _microState.add(!micState); // _isMuted is true when mic is off

            // Broadcast the updated states
            _localCamStateController.add(cameraState);
            _localMicStateController.add(micState);

            print('Updated local status: camera=$cameraState, mic=$micState');
          } else {
            // Message from remote user, update their status
            _remoteCamState = cameraState;
            _remoteMicState = micState;

            // Broadcast the updated states
            _remoteCamStateController.add(cameraState);
            _remoteMicStateController.add(micState);

            print(
                'Updated remote media status: camera=$cameraState, mic=$micState');
          }
        } else {
          print('Cannot recognize media message format');
        }
      }
    } catch (e) {
      print('Error processing media status message: $e');
    }
  }

  // Send media status to socket event
  Future<void> sendMediaStatus() async {
    if (_currentSessionId == null || _currentSessionId!.isEmpty) {
      print('Cannot send media status: sessionId is null or empty');
      return;
    }

    try {
      // Create new media status format
      Map<String, dynamic> mediaStatus = {
        'agentId': currentUserInfo?["user"]["id"],
        'cameraState': _localCamState,
        'mircroState': _localMicState,
      };

      // Check if status has changed since last sent
      bool shouldSend = true;
      if (_lastSentMediaStatus != null) {
        bool hasChanges = false;
        mediaStatus.forEach((key, value) {
          // If any value has changed, need to send again
          if (_lastSentMediaStatus![key] != value) {
            hasChanges = true;
          }
        });
        shouldSend = hasChanges;
      }

      if (shouldSend) {
        // Send message using Socket.IO event
        await MptSocketSocketServer.instance
            .sendMediaStatusMessage(_currentSessionId!, mediaStatus);

        // Save sent status
        _lastSentMediaStatus = Map<String, dynamic>.from(mediaStatus);

        print('Updated media status: $mediaStatus');
      } else {
        print('Skipping media status update: $mediaStatus');
      }
    } catch (e) {
      print('Error sending media status: $e');
    }
  }

  // Update camera state
  void updateLocalCameraState(bool state) {
    _localCamState = state;
    _localCamStateController.add(state);
    // Send updated state
    sendMediaStatus();
  }

  // Update microphone state
  void updateLocalMicrophoneState(bool state) {
    _localMicState = state;
    _localMicStateController.add(state);
    // Send updated state
    sendMediaStatus();
  }

  void leaveCallMediaRoomChannel() {
    if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
      MptSocketSocketServer.leaveCallMediaRoomChannel(_currentSessionId!);

      // Reset media states when leaving the call
      _localCamState = true;
      _localMicState = true;
      _remoteCamState = true;
      _remoteMicState = true;

      // Broadcast the reset states to streams
      _localCamStateController.add(true);
      _localMicStateController.add(true);
      _remoteCamStateController.add(true);
      _remoteMicStateController.add(true);

      // Reset the last sent media status
      _lastSentMediaStatus = null;

      print('Reset all media states after leaving call channel');
    } else {
      print('Session ID is null or empty');
    }
  }

  void _handleCallStateChanged(String state) async {
    print("handleCallStateChanged: $state");

    // Reset remote states when call ends
    if (state == CallStateConstants.CLOSED ||
        state == CallStateConstants.FAILED) {
      _resetRemoteStates();
    }

    if ((_currentSessionId!.isNotEmpty || _currentSessionId != null) &&
        MptSocketSocketServer.instance.checkConnection()) {
      if (state == CallStateConstants.CLOSED) {
        MptSocketSocketServer.instance.sendAgentState(
          _currentSessionId!,
          AgentStateConstants.IDLE,
        );
      }

      if (state == CallStateConstants.ANSWERED) {
        MptSocketSocketServer.instance.sendAgentState(
          _currentSessionId!,
          AgentStateConstants.TALKING,
        );
      }
    } else {
      print(
          "Cannot send agent state: sessionId is null or empty or Socket server is not connected");
    }

    // if (state == CallStateConstants.CLOSED) {
    //   MptSocketSocketServer.instance.sendAgentState(
    //     _currentSessionId!,
    //     AgentStateConstants.IDLE,
    //   );
    // } else {
    //   print("Cannot send agent state: sessionId is null or empty");
    // }

    if (state == CallStateConstants.CONNECTED) {
      if (Platform.isAndroid) {
        print("showAndroidCallKit");
        showAndroidCallKit();
      } else {
        //show ios callkit
      }
    }
  }

  /// Reset remote states when call ends
  void _resetRemoteStates() {
    print('Resetting remote states after call ended');

    // Reset remote camera and microphone states to default (true)
    _remoteCamState = true;
    _remoteMicState = true;

    // Broadcast the reset states to streams
    _remoteCamStateController.add(true);
    _remoteMicStateController.add(true);
    _calleeAnsweredStream.add(false);

    print('Remote states reset: camera=true, microphone=true');
  }

  Future<void> showAndroidCallKit() async {
    // print("showAndroidCallKit");
    // await channel.invokeMethod("startActivity");
  }

  // Centralized event channel listener setup
  void _setupEventChannelListener() {
    // Cancel existing subscription if any
    _eventChannelSubscription?.cancel();

    _eventChannelSubscription =
        eventChannel.receiveBroadcastStream().listen((event) async {
      print('Received event from native 1212: $event');
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
            _currentCallState = data.toString();
            _callEvent.add(data.toString());
            _handleCallStateChanged(data.toString());

            // Handle guest call specific logic
            if (isMakeCallByGuest) {
              if (data == CallStateConstants.FAILED) {
                print("makeCallByGuest() - Call failed!");
                offline();
                releaseExtension();
              }

              if (data == CallStateConstants.CLOSED) {
                print("makeCallByGuest() - Call ended!");
                offline();
                releaseExtension();
              }
            }
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
          case 'currentAudioDevice':
            _currentAudioDevice = data.toString();
            _currentAudioDeviceStream.add(data.toString());
            break;
          case 'audioDevices':
            _currentAvailableAudioDevices = data as List<String>;
            _audioDevicesAvailable.add(data);
            break;
          case "registrationStateStream":
            // Handle guest call registration
            if (isMakeCallByGuest) {
              _handleGuestRegistrationState(data);
            }
            break;
          case 'recvCallMessage':
            print('Received call message from native: $data');
            handleRecvCallMessage(data);
            break;
          // case "releaseExtension":
          //   if (isMakeCallByGuest) {
          //     print('Release extension has started');
          //     await releaseExtension();
          //     print('Release extension has done');
          //   }
          //   break;
        }
      }
    });
  }

  // Handle guest registration state
  void _handleGuestRegistrationState(dynamic data) async {
    if (data == true) {
      print('SIP Registration successful for guest');
      _guestRegistrationCompleter?.complete(true);
    } else {
      print('SIP Registration has failed');
      _guestRegistrationCompleter?.complete(false);
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _eventChannelSubscription?.cancel();
    _guestRegistrationCompleter?.complete(false);
    _guestRegistrationCompleter = null;

    // Close all stream controllers
    _onlineStatuslistener.close();
    _callEvent.close();
    _appEvent.close();
    _cameraState.close();
    _microState.close();
    _holdCallState.close();
    _callType.close();
    _sessionId.close();
    _currentAudioDeviceStream.close();
    _audioDevicesAvailable.close();
    _localCamStateController.close();
    _localMicStateController.close();
    _remoteCamStateController.close();
    _remoteMicStateController.close();
  }

  /// Ensure LocalView and RemoteView listeners are registered
  /// Call this when app returns from background, especially after FCM processing
  static Future<void> ensureViewListenersRegistered() async {
    try {
      if (Platform.isAndroid) {
        await channel.invokeMethod('ensureViewListenersRegistered');
        print('Ensured view listeners are registered');
      }
    } catch (e) {
      print('Error ensuring view listeners registered: $e');
    }
  }

  void handleRecvCallMessage(dynamic data) {
    try {
      // Parse JSON data
      if (data is! String) {
        print('Invalid data type for recvCallMessage: ${data.runtimeType}');
        return;
      }

      final Map<String, dynamic> message = jsonDecode(data);
      print('Parsed message: $message');

      // Extract message components
      final String? receivedSessionId = message['sessionId'];
      final String? extension = message['extension'];
      final String? type = message['type'];
      final Map<String, dynamic>? payload = message['payload'];

      // Validate required fields
      if (receivedSessionId == null ||
          extension == null ||
          type == null ||
          payload == null) {
        print('Invalid message format: missing required fields');
        return;
      }

      // Check if received sessionId matches current sessionId
      if (_currentSessionId == null || _currentSessionId!.isEmpty) {
        print('Current session ID is null or empty, ignoring message');
        return;
      }

      if (receivedSessionId != _currentSessionId) {
        print(
            'Session ID mismatch: received=$receivedSessionId, current=$_currentSessionId');
        return;
      }

      // // Check if extension is different from current user extension
      // if (this.extension.isEmpty) {
      //   print('Current extension is empty, ignoring message');
      //   return;
      // }

      // if (extension == this.extension ||
      //     extension == currentUserInfo!["user"]["extension"]) {
      //   print(
      //       'Extension matches current user ($extension), ignoring message from self');
      //   return;
      // }

      print(
          'Processing message for session: $receivedSessionId, type: $type, from extension: $extension');

      // Handle different message types
      switch (type) {
        case 'update_media_state':
          _handleUpdateMediaState(payload);
          break;

        case 'call_state':
          _handleCallStateUpdate(payload);
          break;

        default:
          print('Unknown message type: $type');
          break;
      }
    } catch (e) {
      print('Error parsing recvCallMessage: $e');
      print('Raw data: $data');
    }
  }

  /// Handle media state updates (camera, microphone)
  void _handleUpdateMediaState(Map<String, dynamic> payload) {
    print('Handling media state update: $payload');

    payload.forEach((key, value) {
      switch (key) {
        case 'microphone':
          final bool micState = value as bool;
          print('Remote microphone state: $micState');
          _remoteMicState = micState;
          _remoteMicStateController.add(micState);
          break;

        case 'camera':
          final bool camState = value as bool;
          print('Remote camera state: $camState');
          _remoteCamState = camState;
          _remoteCamStateController.add(camState);
          break;

        default:
          print('Unknown media state key: $key');
          break;
      }
    });
  }

  /// Handle call state updates
  void _handleCallStateUpdate(Map<String, dynamic> payload) {
    print('Handling call state update: $payload');

    payload.forEach((key, value) {
      switch (key) {
        case 'answered':
          final bool isAnswered = value as bool;
          print('Call answered state: $isAnswered');
          if (isAnswered) {
            // Handle call answered logic
            print('Remote party answered the call');
            _calleeAnsweredStream.add(true);
          }
          break;

        default:
          print('Unknown call state key: $key');
          break;
      }
    });
  }
}
