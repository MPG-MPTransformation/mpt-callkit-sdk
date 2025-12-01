import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mpt_callkit/controller/mpt_client_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_callkit_auth_method.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'mpt_call_kit_controller_repo.dart';

class MptCallKitController {
  String extension = '';
  Map<String, dynamic>? currentUserInfo;
  ExtensionData? extensionData;
  ExtensionData? lastesExtensionData;
  Map<String, dynamic>? _configuration;
  bool? _isOnline = false;
  bool? get isOnline => _isOnline;
  BuildContext? context;
  bool isMakeCallByGuest = false;
  bool isVideoCall = false;
  bool? enableDebugLog = false;
  //hard code until have correct
  String localizedCallerName = "";
  String recordLabel = "";
  // file logging
  File? _logFile;
  bool _fileLoggingEnabled = false;
  void Function(String? message, {int? wrapWidth})? _originalDebugPrint;

  static const MethodChannel channel = MethodChannel('mpt_callkit');
  static const eventChannel = EventChannel('native_events');
  static final MptCallKitController _instance =
      MptCallKitController._internal();
  static const int DEFAULT_TENANT_ID = -1;
  static const int DEFAULT_AGENT_ID = -1;

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

  /// is remote video received stream
  final StreamController<bool> _isRemoteVideoReceived =
      StreamController<bool>.broadcast();
  Stream<bool> get isRemoteVideoReceived => _isRemoteVideoReceived.stream;

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

  /// SIP server connectivity stream
  /// Returns response time in milliseconds, null if connection failed
  final StreamController<int?> _sipPingStream =
      StreamController<int?>.broadcast();
  Stream<int?> get sipPingStream => _sipPingStream.stream;

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

  /// Get current SIP connectivity check status
  bool get isSipPinging => _isPinging;
  String? get sipServerUrl => _sipServerUrl;

  // Track the last sent media status
  Map<String, dynamic>? _lastSentMediaStatus;

  // Add StreamSubscription to manage the event channel subscription
  StreamSubscription<dynamic>? _eventChannelSubscription;
  // Track socket server connection status to forward to iOS native
  StreamSubscription<bool>? _socketConnectionSubscription;

  // Add Completer for guest registration
  Completer<bool>? _guestRegistrationCompleter;

  // Track socket connection process to prevent multiple simultaneous calls
  bool _isConnectingToSocket = false;
  Completer<bool>? _socketConnectionCompleter;
  StreamSubscription<bool>? _tempSocketStatusSubscription;
  Timer? _socketConnectionTimer;

  // SIP server connectivity check variables
  Timer? _pingTimer;
  String? _sipServerUrl;
  bool _isPinging = false;

  /// callback functions
  Function(bool)? onRegisterSIP;

  MptCallKitController._internal() {
    if (Platform.isAndroid) {
      _setupEventChannelListener();
    } else {
      channel.setMethodCallHandler((call) async {
        debugPrint("Received event from native: ${call.method}");
        if (call.method == 'onlineStatus') {
          _isOnline = call.arguments as bool;
          _onlineStatuslistener.add(call.arguments as bool);
          onRegisterSIP?.call(call.arguments as bool);
          debugPrint("onlineStatus: ${call.arguments}");

          // Handle SIP ping based on registration status
          if (call.arguments as bool) {
          } else {
            // SIP registration failed - stop ping
            stopSipPing();
          }
        }
        if (call.method == 'callState') {
          _currentCallState = call.arguments as String;
          _callEvent.add(call.arguments as String);
          _handleCallStateChanged(call.arguments as String);

          // Handle guest call specific logic
          if (isMakeCallByGuest) {
            if (call.arguments == CallStateConstants.FAILED) {
              debugPrint("makeCallByGuest() - Call failed!");
              offline(disablePushNoti: true);
              releaseExtension();
            }

            if (call.arguments == CallStateConstants.CLOSED) {
              debugPrint("makeCallByGuest() - Call ended!");
              offline(disablePushNoti: true);
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
          debugPrint(
              'Received callKitAnswerReceived event from native: ${call.arguments}');
        }

        if (call.method == 'recvCallMessage') {
          debugPrint('Received call message from native: ${call.arguments}');
          handleRecvCallMessage(call.arguments);
        }

        if (call.method == 'onVideoRawCallback') {
          debugPrint(
              'Received onVideoRawCallback from native: ${call.arguments}');
        }

        if (call.method == 'isRemoteVideoReceived') {
          debugPrint(
              'Received isRemoteVideoReceived from native: ${call.arguments}');
          _isRemoteVideoReceived.add(call.arguments as bool);
        }
      });
    }
  }

  factory MptCallKitController() {
    return _instance;
  }

  Future<String> enableFileLogging({String? customDirectory}) async {
    Directory baseDir;
    if (customDirectory != null) {
      baseDir = Directory(customDirectory);
    } else {
      if (Platform.isAndroid) {
        // Prefer external app-specific dir on Android so users can access the file without root
        final extDir = await getExternalStorageDirectory();
        baseDir = extDir ?? await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    }
    final Directory logsDir = Directory('${baseDir.path}/mpt_callkit_logs');
    if (!logsDir.existsSync()) {
      logsDir.createSync(recursive: true);
    }

    final String ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final String filePath = '${logsDir.path}/mpt_callkit_$ts.log';
    _logFile = File(filePath);

    debugPrint("record log to filePath: $filePath");

    if (!_fileLoggingEnabled) {
      _originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        try {
          final DateTime now = DateTime.now();
          final String ts =
              '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${(now.year % 100).toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
          final String platform = Platform.isIOS
              ? 'iOS'
              : (Platform.isAndroid ? 'Android' : 'Other');
          final String line = '[$ts] [flutter - $platform] ${message ?? ''}\n';
          _logFile?.writeAsStringSync(line, mode: FileMode.append, flush: true);
        } catch (_) {}
        // Do NOT forward to original debugPrint to avoid duplicate entries being captured by native stdout hooks
      };
      _fileLoggingEnabled = true;
    }

    try {
      await channel.invokeMethod('enableFileLogging', <String, dynamic>{
        'enabled': true,
        'filePath': filePath,
      });
    } catch (_) {}

    return filePath;
  }

  Future<void> disableFileLogging() async {
    debugPrint("disableFileLogging");
    try {
      await channel.invokeMethod('enableFileLogging', <String, dynamic>{
        'enabled': false,
      });
    } catch (_) {}

    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
    _fileLoggingEnabled = false;
    _logFile = null;
  }

  Future<void> initSdk({
    required String apiKey,
    String? baseUrl,
    String? pushToken,
    String? appId,
    bool? enableDebugLog,
    String? localizedCallerName,
    String? deviceInfo,
    String? recordLabel,
    bool? enableBlurBackground,
    String? bgPath,
  }) async {
    await enableFileLogging();

    final String resolvedBaseUrl = baseUrl != null && baseUrl.isNotEmpty
        ? baseUrl
        : "https://crm-dev-v2.metechvn.com";
    final String resolvedPushToken = pushToken ?? "";
    final String resolvedAppId = appId ?? "";
    final bool resolvedEnableDebug = enableDebugLog ?? false;
    final String resolvedCallerName = localizedCallerName ?? "Omicx call";
    final String resolvedDeviceInfo = deviceInfo ?? "";
    debugPrint(
        "initSDK: apiKey: $apiKey, baseUrl: $baseUrl, pushToken: $pushToken, appId: $appId, enableDebugLog: $enableDebugLog, localizedCallerName: $localizedCallerName, deviceInfo: $deviceInfo");

    this.enableDebugLog = resolvedEnableDebug;
    this.localizedCallerName = resolvedCallerName;
    if (recordLabel != null) {
      this.recordLabel = recordLabel;
    }

    try {
      await channel
          .invokeMethod(MptCallKitConstants.initialize, <String, dynamic>{
        'appId': appId,
        'enableDebugLog': resolvedEnableDebug,
        'pushToken': pushToken,
        'recordLabel': recordLabel,
        'enableBlurBackground': enableBlurBackground ?? false,
        'bgPath': bgPath,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to initialize SDK: '${e.message}'.");
    }

    // Persist initialization params to SharedPreferences
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(SDKPrefsKeyConstants.API_KEY, apiKey);
      await prefs.setString(SDKPrefsKeyConstants.BASE_URL, resolvedBaseUrl);
      await prefs.setString(SDKPrefsKeyConstants.PUSH_TOKEN, resolvedPushToken);
      await prefs.setString(SDKPrefsKeyConstants.APP_ID, resolvedAppId);
      await prefs.setBool(
          SDKPrefsKeyConstants.ENABLE_DEBUG_LOG, resolvedEnableDebug);
      await prefs.setString(
          SDKPrefsKeyConstants.LOCALIZED_CALLER_NAME, resolvedCallerName);
      await prefs.setString(
          SDKPrefsKeyConstants.DEVICE_INFO, resolvedDeviceInfo);
      if (recordLabel != null) {
        await prefs.setString(SDKPrefsKeyConstants.RECORD_LABEL, recordLabel);
      }
      if (enableBlurBackground != null) {
        await prefs.setBool(
            SDKPrefsKeyConstants.ENABLE_BLUR_BACKGROUND, enableBlurBackground);
      }
      if (bgPath != null) {
        await prefs.setString(SDKPrefsKeyConstants.BG_PATH, bgPath);
      }
    } catch (e) {
      debugPrint('Failed to persist initSdk params: $e');
    }

    _appEvent.add(AppEventConstants.READY);
    _currentAppEvent = AppEventConstants.READY;

    Map<String, dynamic> values = {
      "apiKey": apiKey,
      "baseUrl": baseUrl,
      "pushToken": pushToken,
      "appId": appId,
      "enableDebugLog": enableDebugLog,
      "localizedCallerName": localizedCallerName,
      "deviceInfo": deviceInfo,
      "recordLabel": recordLabel,
      "enableBlurBackground": enableBlurBackground,
      "bgPath": bgPath,
    };
    sendLog(
      values: values,
      title: MPTSDKLogTitleConstants.SDK_INIT,
    );
  }

  /// Restore previously saved SDK initialization params from SharedPreferences.
  /// Useful for keeping the SDK config across app restarts.
  Future<void> restoreInitFromPreferences() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Intentionally not restoring apiKey/baseUrl/pushToken/appId into fields,
      // these are accessed via getters.
      final bool? storedEnableDebugLog =
          prefs.getBool(SDKPrefsKeyConstants.ENABLE_DEBUG_LOG);
      final String? storedLocalizedCallerName =
          prefs.getString(SDKPrefsKeyConstants.LOCALIZED_CALLER_NAME);

      // Only restore runtime flags kept in memory (others read via getters)
      if (storedEnableDebugLog != null) {
        enableDebugLog = storedEnableDebugLog;
      }
      if (storedLocalizedCallerName != null &&
          storedLocalizedCallerName.isNotEmpty) {
        localizedCallerName = storedLocalizedCallerName;
      }
      // deviceInfo is stored for potential future use; no runtime field to restore
    } catch (e) {
      debugPrint('Failed to restore initSdk params: $e');
    }
  }

  /// Clear stored SDK initialization params from SharedPreferences.
  Future<void> clearInitPreferences() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // await prefs.remove(SDKPrefsKeyConstants.PUSH_TOKEN);
      await prefs.remove(SDKPrefsKeyConstants.ENABLE_DEBUG_LOG);
      await prefs.remove(SDKPrefsKeyConstants.LOCALIZED_CALLER_NAME);
      await prefs.remove(SDKPrefsKeyConstants.DEVICE_INFO);
      await prefs.remove(SDKPrefsKeyConstants.RECORD_LABEL);
      await prefs.remove(SDKPrefsKeyConstants.ENABLE_BLUR_BACKGROUND);
    } catch (e) {
      debugPrint('Failed to clear initSdk params: $e');
    }
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
      baseUrl: baseUrl ?? await getCurrentBaseUrl(),
      onError: onError,
      data: (e) {
        accessTokenResponse?.call(e["result"]["accessToken"]);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
    }

    Map<String, dynamic> values = {
      "type": "username_password",
      "username": username,
      "tenantId": tenantId,
      "baseUrl": baseUrl ?? await getCurrentBaseUrl(),
      "result": result,
    };
    sendLog(
      values: values,
      title: MPTSDKLogTitleConstants.AGENT_LOGIN,
      tenantId: tenantId,
      isGuest: false,
    );
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
      baseUrl: baseUrl ?? await getCurrentBaseUrl(),
      onError: onError,
      data: (e) {
        accessTokenResponse?.call(e["result"]["accessToken"]);
      },
    );
    if (result) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
    }
    Map<String, dynamic> values = {
      "type": "sso",
      "baseUrl": baseUrl ?? await getCurrentBaseUrl(),
      "result": result,
    };
    sendLog(
      values: values,
      title: MPTSDKLogTitleConstants.AGENT_LOGIN,
      isGuest: false,
    );
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
        final isSocketConnected = await connectToSocketServer(accessToken);
        if (isSocketConnected) {
          // Wait until initial rooms joined before SIP registration
          final roomsJoined =
              await MptSocketSocketServer.waitUntilInitialRoomsJoined(
                  timeout: const Duration(seconds: 5));
          if (roomsJoined) {
            await _registerToSipServer(context: context);
          } else {
            _appEvent.add(AppEventConstants.ERROR);
            onError?.call("Timeout waiting to join initial rooms");
            _currentAppEvent = AppEventConstants.ERROR;
            debugPrint("Timeout waiting to join initial rooms");
          }
        } else {
          _appEvent.add(AppEventConstants.ERROR);
          onError?.call("Failed to connect to socket server");
          _currentAppEvent = AppEventConstants.ERROR;
          debugPrint("Failed to connect to socket server");
        }
      } else {
        _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
        onError?.call("Access token is expired");
        debugPrint("Access token is expired");
        _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
      }
    } else {
      debugPrint("Access token is null");
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
        resolution: _configuration!["MOBILE_SIP_RESOLUTION"],
        bitrate: _configuration!["MOBILE_SIP_BITRATE"],
        frameRate: _configuration!["MOBILE_SIP_FRAMERATE"],
      );

      var regResult = await refreshRegistration();

      Future.delayed(const Duration(milliseconds: 500), () async {
        {
          if (regResult == 0 && _isOnline == true) {
            debugPrint("SIP already online");
            return;
          }

          if (extensionData != null) {
            lastesExtensionData = extensionData;
            // Register to SIP server
            await MptCallKitController().online(
              username: extensionData?.username ?? "",
              displayName: extensionData?.username ?? "", // ??
              srtpType: 0,
              authName: extensionData?.username ?? "", // ??
              password: extensionData?.password ?? "",
              userDomain: extensionData?.domain ?? "",
              sipServer: extensionData?.sipServer ?? "",
              sipServerPort: extensionData?.port ?? 5063,
              // sipServerPort: 5063,
              transportType: 0,
              pushToken: await getCurrentPushToken(),
              appId: await getCurrentAppId(),
              onError: (p0) {
                debugPrint("Error in register to sip server: ${p0.toString()}");
              },
              context: context,
              resolution: extensionData?.resolution,
              bitrate: extensionData?.bitrate,
              frameRate: extensionData?.frameRate,
              recordLabel: await getCurrentRecordLabel(),
              autoLogin: true,
              enableBlurBackground: true,
              bgPath: await getCurrentBgPath(),
              tenantId: currentUserInfo!["tenant"]["id"] ?? DEFAULT_TENANT_ID,
              agentId: currentUserInfo!["user"]["id"] ?? DEFAULT_AGENT_ID,
            );
          } else {
            _appEvent.add(AppEventConstants.ERROR);
            _currentAppEvent = AppEventConstants.ERROR;
          }
        }
      });
    } else {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
    }
  }

  // get current user info
  Future<void> _getCurrentUserInfo(String accessToken) async {
    currentUserInfo = await MptCallkitAuthMethod().getCurrentUserInfo(
      baseUrl: await getCurrentBaseUrl(),
      accessToken: accessToken,
      onError: (p0) {
        debugPrint("Error in get current user info: ${p0.toString()}");
      },
    );
    if (currentUserInfo != null &&
        currentUserInfo!["user"] == null &&
        currentUserInfo!["tenant"] == null) {
      _appEvent.add(AppEventConstants.TOKEN_EXPIRED);
      _currentAppEvent = AppEventConstants.TOKEN_EXPIRED;
      debugPrint("Access token is expired");
    }

    if (currentUserInfo != null &&
        currentUserInfo!["user"] != null &&
        currentUserInfo!["tenant"] != null) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
      debugPrint(
          "Get current user info success, ready to connect to socket server");
    }
  }

  Future<bool> connectToSocketServer(String accessToken) async {
    debugPrint("connectToSocketServer");

    // Prevent multiple simultaneous connection attempts
    if (_isConnectingToSocket && _socketConnectionCompleter != null) {
      debugPrint(
          "Socket connection already in progress, waiting for existing attempt...");
      return await _socketConnectionCompleter!.future;
    }

    // Check if already connected
    if (MptSocketSocketServer.getCurrentConnectionState()) {
      debugPrint("Socket server already connected");
      try {
        await channel.invokeMethod('socketStatus', {'ready': true});
      } catch (e) {
        debugPrint('Failed to notify iOS about socket status: $e');
      }
      return true;
    }

    if (_configuration != null) {
      try {
        // Set connecting flag
        _isConnectingToSocket = true;

        // Clean up any previous temporary resources
        _tempSocketStatusSubscription?.cancel();
        _socketConnectionTimer?.cancel();

        // Create new completer for this attempt
        _socketConnectionCompleter = Completer<bool>();

        MptSocketSocketServer.initialize(
          tokenParam: accessToken,
          configuration: _configuration!,
          currentUserInfo: currentUserInfo!,
          onMessageReceivedParam: (p0) {
            debugPrint("Message received in callback: $p0");
          },
        );

        // Forward ongoing socket connection status changes to iOS
        _socketConnectionSubscription?.cancel();
        _socketConnectionSubscription =
            MptSocketSocketServer.connectionStatus.listen((isConnected) async {
          try {
            await channel.invokeMethod('socketStatus', {
              'ready': isConnected,
            });
          } catch (e) {
            debugPrint('Failed to notify iOS about socket status: $e');
          }
        });

        // Set up timeout
        _socketConnectionTimer = Timer(const Duration(seconds: 10), () {
          _tempSocketStatusSubscription?.cancel();
          if (!_socketConnectionCompleter!.isCompleted) {
            _socketConnectionCompleter!.complete(false);
            debugPrint("Socket connection timeout after 10 seconds");
          }
          _isConnectingToSocket = false;
        });

        // Listen to connection status
        _tempSocketStatusSubscription =
            MptSocketSocketServer.connectionStatus.listen((isConnected) {
          if (isConnected && !_socketConnectionCompleter!.isCompleted) {
            _socketConnectionTimer?.cancel();
            _tempSocketStatusSubscription?.cancel();
            _socketConnectionCompleter!.complete(true);
            _isConnectingToSocket = false;
            debugPrint("Socket server connected successfully");
          }
        });

        // Check if already connected (race condition check)
        if (MptSocketSocketServer.getCurrentConnectionState()) {
          try {
            await channel.invokeMethod('socketStatus', {
              'ready': true,
            });
          } catch (e) {
            debugPrint('Failed to notify iOS about socket status: $e');
          }
          _socketConnectionTimer?.cancel();
          _tempSocketStatusSubscription?.cancel();
          if (!_socketConnectionCompleter!.isCompleted) {
            _socketConnectionCompleter!.complete(true);
            debugPrint("Socket server already connected (race condition)");
          }
          _isConnectingToSocket = false;
        }

        final result = await _socketConnectionCompleter!.future;
        _socketConnectionCompleter = null;
        return result;
      } catch (e) {
        debugPrint("Error in connect to socket server: ${e.toString()}");
        _isConnectingToSocket = false;
        _socketConnectionCompleter = null;
        _tempSocketStatusSubscription?.cancel();
        _socketConnectionTimer?.cancel();
        return false;
      }
    } else {
      debugPrint(
          "Cannot connect agent to socket server - configuration is null");
      return false;
    }
  }

  // get configuration
  Future<void> _getConfiguration(String accessToken) async {
    _configuration = await MptCallkitAuthMethod().getConfiguration(
      baseUrl: await getCurrentBaseUrl(),
      accessToken: accessToken,
      onError: (p0) {
        debugPrint("Error in get configuration: ${p0.toString()}");
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
      baseUrl: baseUrl ?? await getCurrentBaseUrl(),
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
    bool isDeleteRegistrationSuccess = false;

    // Cancel socket status forwarding and notify iOS
    try {
      // Ngắt kết nối socket
      await MptSocketSocketServer.disconnect();

      // Clean up all socket-related subscriptions and timers
      _socketConnectionSubscription?.cancel();
      _socketConnectionSubscription = null;
      _tempSocketStatusSubscription?.cancel();
      _tempSocketStatusSubscription = null;
      _socketConnectionTimer?.cancel();
      _socketConnectionTimer = null;
      _isConnectingToSocket = false;
      _socketConnectionCompleter = null;
      isVideoCall = false;

      await channel.invokeMethod('socketStatus', {'ready': false});
    } catch (e) {
      debugPrint('Failed to notify iOS about socket disconnect: $e');
    }

    isLogoutAccountSuccess = await offline(disablePushNoti: true);

    Map<String, dynamic> values = {
      "type": "logout",
      "tenantId": currentUserInfo!["tenant"]["id"] ?? 0,
      "agentId": currentUserInfo!["user"]["id"] ?? 0,
      "result": isLogoutAccountSuccess,
    };
    sendLog(
      values: values,
      title: MPTSDKLogTitleConstants.AGENT_LOGOUT,
      isGuest: false,
      tenantId: currentUserInfo!["tenant"]["id"] ?? 0,
    );

    if (currentUserInfo != null &&
        currentUserInfo!["user"] != null &&
        currentUserInfo!["tenant"] != null) {
      // clear all SIP registration of agent's extension on server
      isDeleteRegistrationSuccess = await deleteRegistration(
        tenantId: currentUserInfo!["tenant"]["id"] ?? 0,
        agentId: currentUserInfo!["user"]["id"] ?? 0,
        baseUrl: await getCurrentBaseUrl(),
        onError: onError,
      );

      // logout account from server
      isUnregistered = await logoutRequest(
        cloudAgentId: currentUserInfo!["user"]["id"],
        cloudAgentName: currentUserInfo!["user"]["fullName"] ?? "",
        cloudTenantId: currentUserInfo!["tenant"]["id"],
        baseUrl: await getCurrentBaseUrl(),
        onError: onError,
      );
    }

    // Important: Destroy instance when logout
    await MptSocketSocketServer.destroyInstance();

    await clearInitPreferences();

    currentUserInfo = null;

    if (isDeleteRegistrationSuccess && isUnregistered) {
      _appEvent.add(AppEventConstants.LOGGED_OUT);
      _currentAppEvent = AppEventConstants.LOGGED_OUT;
      setLoggedAgentId(DEFAULT_AGENT_ID);
      setLoggedTenantId(DEFAULT_TENANT_ID);
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
      this.isVideoCall = isVideoCall;
      extension = '';
      final result = await getExtension(phoneNumber: userPhoneNumber);

      var extraInfoResult = {
        "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
        "extraInfo": extraInfo,
      };

      debugPrint("extension result: $result");

      sendLog(
          values: {
            "extension": result?.username ?? "",
            "destination": destination,
            "extraInfo": extraInfo,
            "isVideoCall": isVideoCall,
          },
          title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());

      if (result != null) {
        // Set extension data for guest call (needed for SIP ping)
        extensionData = result;
        lastesExtensionData = extensionData;

        online(
          username: result.username ?? "",
          displayName: userPhoneNumber,
          authName: '',
          password: result.password ?? "",
          userDomain: result.domain ?? "",
          sipServer: result.sipServer ?? "",
          sipServerPort: result.port ?? 5063,
          // sipServerPort: 5063,
          transportType: 0,
          srtpType: 0,
          context: context,
          appId: await getCurrentAppId(),
          pushToken: await getCurrentPushToken(),
          isMakeCallByGuest: true,
          resolution: result.resolution,
          bitrate: result.bitrate,
          frameRate: result.frameRate,
          recordLabel: await getCurrentRecordLabel(),
          autoLogin: false,
          enableBlurBackground: await getCurrentEnableBlurBackground(),
          bgPath: await getCurrentBgPath(),
          agentId: DEFAULT_AGENT_ID,
          tenantId: DEFAULT_TENANT_ID,
        );

        // 🔧 FIX: Ensure no previous completer is pending
        if (_guestRegistrationCompleter != null &&
            !_guestRegistrationCompleter!.isCompleted) {
          debugPrint('Cancelling previous guest registration attempt...');
          _guestRegistrationCompleter!.complete(false);
        }

        // Wait for SIP registration to complete
        _guestRegistrationCompleter = Completer<bool>();

        try {
          // Wait for registration result with timeout
          final registrationResult = await _guestRegistrationCompleter!.future
              .timeout(const Duration(seconds: 20));

          if (registrationResult) {
            await MptCallKitControllerRepo().makeCallByGuest(
              phoneNumber: userPhoneNumber,
              extension: result.username ?? "",
              destination: destination,
              authToken: await getCurrentApiKey(),
              extraInfo: jsonEncode(extraInfoResult),
              baseUrl: await getCurrentBaseUrl(),
              onError: onError,
            );
          } else {
            debugPrint('SIP Registration has failed');
            sendLog(
                values: {
                  "message": "SIP Registration failed",
                },
                title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
                tenantId: getLoggedTenantId(),
                agentId: getLoggedAgentId());
            onError?.call('SIP Registration failed');
          }
        } catch (e) {
          debugPrint('Registration timeout or error: $e');
          sendLog(
              values: {
                "message": "Registration timeout",
              },
              title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
              tenantId: getLoggedTenantId(),
              agentId: getLoggedAgentId());
          onError?.call('Registration timeout');

          // 🔧 FIX: Use helper method to cleanup state properly
          await _cleanupGuestRegistrationState();
        } finally {
          // Ensure completer is always cleaned up
          if (_guestRegistrationCompleter != null &&
              !_guestRegistrationCompleter!.isCompleted) {
            _guestRegistrationCompleter!.complete(false);
          }
          _guestRegistrationCompleter = null;
        }
      } else {
        onError?.call('Cannot get extension data');
        debugPrint("Cannot get extension data");
        sendLog(
            values: {
              "message": "Cannot get extension data",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
      }
    } on Exception catch (e) {
      onError?.call(e.toString());
      sendLog(
          values: {
            "message": "Failed to call: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      debugPrint("Failed to call: '${e.toString()}'.");
      // if (Platform.isIOS) Navigator.pop(context);
    }
  }

  Future<ExtensionData?> getExtension(
      {int retryTime = 0, required String phoneNumber}) async {
    try {
      debugPrint("getExtension");
      int retryCount = retryTime;
      final String base = await getCurrentBaseUrl();
      final url = Uri.parse("$base/integration/extension/request");

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${await getCurrentApiKey()}',
            },
            body: json.encode({
              "phone_number": phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // Log response details for debugging
      debugPrint("getExtension - Response status code: ${response.statusCode}");
      debugPrint("getExtension - Response headers: ${response.headers}");
      debugPrint("getExtension - Response body: ${response.body}");

      // Check if response is successful
      if (response.statusCode != 200) {
        sendLog(
            values: {
              "message":
                  "Get extension failed: Server returned ${response.statusCode}: ${response.body}",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      // Check if response body is not empty
      if (response.body.isEmpty) {
        sendLog(
            values: {
              "message": "Get extension failed: Server returned empty response",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        throw Exception('Server returned empty response');
      }

      // Try to parse JSON with better error handling
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint("getExtension - JSON parsing error: $e");
        debugPrint("getExtension - Raw response body: '${response.body}'");
        sendLog(
            values: {
              "message":
                  "Get extension failed: Invalid JSON response from server: $e",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        throw Exception('Invalid JSON response from server: $e');
      }

      final result = ExtensionModel.fromJson(
        data.runtimeType is String ? jsonDecode(data) : data,
      );
      final message = result.message ?? '';

      if (result.success ?? false) {
        extension = result.data?.username ?? '';
        return result.data;
      } else {
        if (retryCount > 2) {
          sendLog(
              values: {
                "message": "Get extension failed: $message",
              },
              title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
              tenantId: getLoggedTenantId(),
              agentId: getLoggedAgentId());
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
      sendLog(
          values: {
            "message": "Get extension failed: ${e.toString()}",
          },
          title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return null;
    }
  }

  Future<bool> releaseExtension() async {
    final String base = await getCurrentBaseUrl();
    final url = Uri.parse('$base/integration/extension/release');
    try {
      if (extension.isEmpty) return true;
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getCurrentApiKey()}',
        },
        body: json.encode({
          "extension": extension,
        }),
      );

      // Log response details for debugging
      debugPrint(
          "releaseExtension - Response status code: ${response.statusCode}");
      debugPrint("releaseExtension - Response body: ${response.body}");

      // Check if response is successful
      if (response.statusCode != 200) {
        sendLog(
            values: {
              "message":
                  "Release extension failed: Server returned ${response.statusCode}: ${response.body}",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      // Check if response body is not empty
      if (response.body.isEmpty) {
        throw Exception('Server returned empty response');
      }

      // Try to parse JSON with better error handling
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint("releaseExtension - JSON parsing error: $e");
        debugPrint("releaseExtension - Raw response body: '${response.body}'");
        throw Exception('Invalid JSON response from server: $e');
      }

      final result = ReleaseExtensionModel.fromJson(data);
      extension = '';
      if (result.success ?? false) {
        debugPrint("Release extension has done");
        sendLog(
            values: {
              "message": "Release extension has done",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        return true;
      } else {
        debugPrint("Release extension has failed: ${result.message}");
        sendLog(
            values: {
              "message": "Release extension failed: ${result.message}",
            },
            title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
        throw Exception(result.message ?? '');
      }
    } on Exception catch (e) {
      debugPrint("Error in releaseExtension: $e");
      sendLog(
          values: {
            "message": "Release extension failed: ${e.toString()}",
          },
          title: MPTSDKLogTitleConstants.GUEST_MAKE_CALL,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
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
    int? agentId,
    int? tenantId,
    bool? isMakeCallByGuest = false,
    String? resolution,
    int? bitrate,
    int? frameRate,
    String? recordLabel,
    bool? autoLogin,
    bool? enableBlurBackground,
    String? bgPath,
    // required String localizedCallerName,
  }) async {
    this.isMakeCallByGuest = isMakeCallByGuest ?? false;
    debugPrint("isMakeCallByGuest: $isMakeCallByGuest");

    debugPrint("sipServer: $sipServer");

    startSipPing(sipServer);

    setLoggedAgentId(agentId);
    setLoggedTenantId(tenantId);

    try {
      final hasPermission = await requestPermission(context);
      if (!hasPermission) {
        onError?.call('Permission denied');
        debugPrint("Permission denied");
        return false;
      }
      debugPrint("login");
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
          "agentId": agentId ?? "",
          "tenantId": tenantId ?? "",
          "enableDebugLog": enableDebugLog ?? false,
          "localizedCallerName": localizedCallerName,
          "resolution": resolution ?? "720P",
          "bitrate": bitrate ?? 1024,
          "frameRate": frameRate ?? 30,
          "recordLabel": recordLabel ?? "Customer",
          "autoLogin": autoLogin ?? false,
          "enableBlurBackground": enableBlurBackground ?? false,
          "bgPath": bgPath,
        },
      );

      sendLog(
          values: {
            "username": username,
            "displayName": displayName,
            "authName": authName,
            "userDomain": userDomain,
            "sipServer": sipServer,
            "sipServerPort": sipServerPort,
          },
          title: MPTSDKLogTitleConstants.SIP_REGISTER,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());

      debugPrint("login result: $result");

      return result;
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
      return false;
    }
  }

  var loggedAgentId = DEFAULT_AGENT_ID;
  var loggedTenantId = DEFAULT_TENANT_ID;

  void setLoggedAgentId(int? agent) {
    loggedAgentId = agent ?? DEFAULT_AGENT_ID;
  }

  void setLoggedTenantId(int? tenant) {
    loggedTenantId = tenant ?? DEFAULT_TENANT_ID;
  }

  int getLoggedAgentId() {
    return loggedAgentId;
  }

  int getLoggedTenantId() {
    return loggedTenantId;
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
    this.isVideoCall = isVideoCall ?? false;
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };
    var result = await MptCallKitControllerRepo().makeCall(
      baseUrl: await getCurrentBaseUrl(),
      tenantId: currentUserInfo!["tenant"]["id"],
      applicationId: outboundNumber,
      senderId: destination,
      agentId: currentUserInfo!["user"]["id"] ?? 0,
      extraInfo: jsonEncode(extraInfoResult),
      authToken: accessToken,
      onError: onError,
    );

    sendLog(
        values: {
          "makeCallMethod": "makeCall",
          "destination": destination,
          "outboundNumber": outboundNumber,
          "extraInfo": extraInfo,
          "isVideoCall": isVideoCall,
          "result": result,
        },
        title: MPTSDKLogTitleConstants.MAKE_CALL_API,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());

    return result;
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
    this.isVideoCall = isVideoCall ?? false;
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };

    var result = await MptCallKitControllerRepo().makeCallInternal(
      baseUrl: await getCurrentBaseUrl(),
      tenantId: currentUserInfo!["tenant"]["id"],
      applicationId: destination,
      senderId: senderId ?? currentUserInfo!["user"]["extension"],
      agentId: currentUserInfo!["user"]["id"] ?? 0,
      extraInfo: jsonEncode(extraInfoResult),
      authToken: accessToken,
      onError: onError,
    );

    sendLog(
        values: {
          "makeCallMethod": "makeCallInternal",
          "destination": destination,
          "extraInfo": extraInfo,
          "isVideoCall": isVideoCall,
          "result": result,
        },
        title: MPTSDKLogTitleConstants.MAKE_CALL_API,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());

    return result;
  }

  Future<bool> changeAgentStatus({
    required int reasonCodeId,
    required String statusName,
    Function(String?)? onError,
    required String accessToken,
  }) async {
    if (currentUserInfo != null) {
      var result = await MptCallKitControllerRepo().changeAgentStatus(
        cloudAgentId: currentUserInfo!["user"]["id"],
        cloudTenantId: currentUserInfo!["tenant"]["id"],
        cloudAgentName: currentUserInfo!["user"]["fullName"] ?? "",
        reasonCodeId: reasonCodeId,
        statusName: statusName,
        baseUrl: await getCurrentBaseUrl(),
        accessToken: accessToken,
        onError: onError,
        deviceInfo: await getCurrentDeviceInfo(),
      );

      sendLog(
          values: {
            "cloudAgentId": currentUserInfo!["user"]["id"],
            "cloudTenantId": currentUserInfo!["tenant"]["id"],
            "cloudAgentName": currentUserInfo!["user"]["fullName"] ?? "",
            "reasonCodeId": reasonCodeId,
            "statusName": statusName,
            "result": result,
          },
          title: MPTSDKLogTitleConstants.CHANGE_AGENT_STATUS,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());

      return result;
    } else {
      sendLog(
          values: {
            "message":
                "changeAgentStatus: current user info is null - currentUserInfo: $currentUserInfo",
            "reasonCodeId": reasonCodeId,
            "statusName": statusName,
            "cloudAgentId": currentUserInfo!["user"]["id"],
            "cloudTenantId": currentUserInfo!["tenant"]["id"],
            "cloudAgentName": currentUserInfo!["user"]["fullName"] ?? "",
          },
          title: MPTSDKLogTitleConstants.CHANGE_AGENT_STATUS,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      onError?.call(
          "changeAgentStatus: current user info is null - currentUserInfo: $currentUserInfo");
      return false;
    }
  }

  // Get current agent status
  Future<String?> getCurrentAgentStatus({
    Function(String?)? onError,
    required String accessToken,
  }) async {
    if (currentUserInfo == null) {
      onError?.call("getCurrentAgentStatus: current user info is null");
      sendLog(
          values: {
            "method": "getCurrentAgentStatus()",
            "message": "getCurrentAgentStatus: current user info is null",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return null;
    }

    final cloudAgentId = currentUserInfo!["user"]["id"];
    final cloudTenantId = currentUserInfo!["tenant"]["id"];
    final cloudAgentName = currentUserInfo!["user"]["fullName"] ?? "";

    if (cloudAgentId == null || cloudTenantId == null) {
      onError?.call("getCurrentAgentStatus: missing required user info");
      sendLog(
          values: {
            "method": "getCurrentAgentStatus()",
            "message": "getCurrentAgentStatus: missing required user info",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return null;
    }

    var result = await MptCallKitControllerRepo().getCurrentAgentStatus(
      cloudAgentId: cloudAgentId,
      cloudTenantId: cloudTenantId,
      cloudAgentName: cloudAgentName,
      baseUrl: await getCurrentBaseUrl(),
      accessToken: accessToken,
      onError: onError,
    );

    sendLog(
        values: {
          "method": "getCurrentAgentStatus()",
          "message": "getCurrentAgentStatus: $result",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  // Method do unregister from SIP server
  Future<bool> offline({
    Function(String?)? onError,
    bool disablePushNoti = false,
  }) async {
    try {
      // Stop SIP connectivity check when going offline
      stopSipPing();

      await disableFileLogging();

      // if (isOnline == false) {
      //   onError?.call("You need register to SIP server first");
      //   return false;
      // } else {
      var result = await channel.invokeMethod(MptCallKitConstants.offline, {
        "disablePushNoti": disablePushNoti,
      });
      sendLog(
          values: {
            "disablePushNoti": disablePushNoti,
            "message": "offline: $result",
          },
          title: MPTSDKLogTitleConstants.SIP_UNREGISTER,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
      // }
    } on PlatformException catch (e) {
      debugPrint("Failed to go offline: '${e.message}'.");
      sendLog(
          values: {
            "message": "Failed to go offline: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.SIP_UNREGISTER,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<int> hangup() async {
    // If hangup success, return 0 - failed in others case
    try {
      final result = await channel.invokeMethod("hangup");
      debugPrint("hangup result: $result");
      sendLog(
          values: {
            "method": "hangup()",
            "message": "hangup result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'hangup' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "hangup()",
            "message": "Failed in 'hangup' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return -1;
    }
  }

  Future<bool> hold() async {
    try {
      final result = await channel.invokeMethod("hold");
      sendLog(
          values: {
            "method": "hold()",
            "message": "hold result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'hold' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "hold()",
            "message": "Failed in 'hold' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> unhold() async {
    try {
      final result = await channel.invokeMethod("unhold");
      sendLog(
          values: {
            "method": "unhold()",
            "message": "unhold result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'unhold' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "unhold()",
            "message": "Failed in 'unhold' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> mute() async {
    try {
      final result = await channel.invokeMethod("mute");
      sendLog(
          values: {
            "method": "mute()",
            "message": "mute result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'mute' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "mute()",
            "message": "Failed in 'mute' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> unmute() async {
    try {
      final result = await channel.invokeMethod("unmute");
      sendLog(
          values: {
            "method": "unmute()",
            "message": "unmute result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'unmute' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "unmute()",
            "message": "Failed in 'unmute' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> cameraOn() async {
    try {
      final result = await channel.invokeMethod("cameraOn");
      sendLog(
          values: {
            "method": "cameraOn()",
            "message": "cameraOn result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'cameraOn' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "cameraOn()",
            "message": "Failed in 'cameraOn' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> cameraOff() async {
    try {
      final result = await channel.invokeMethod("cameraOff");
      sendLog(
          values: {
            "method": "cameraOff()",
            "message": "cameraOff result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'cameraOff' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "cameraOff()",
            "message": "Failed in 'cameraOff' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> rejectCall() async {
    try {
      final result = await channel.invokeMethod("reject");
      sendLog(
          values: {
            "method": "reject()",
            "message": "reject result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'reject' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "reject()",
            "message": "Failed in 'reject' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<int> answerCall() async {
    try {
      final result = await channel.invokeMethod("answer");
      sendLog(
          values: {
            "method": "answer()",
            "message": "answer result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'answer' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "answer()",
            "message": "Failed in 'answer' mothod: '${e.message}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return -10;
    }
  }

  Future<bool> switchCamera() async {
    try {
      final result = await channel.invokeMethod('switchCamera');
      sendLog(
          values: {
            "method": "switchCamera()",
            "message": "switchCamera result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result ?? false;
    } catch (e) {
      debugPrint('Error switching camera: $e');
      sendLog(
          values: {
            "method": "switchCamera()",
            "message": "Failed in 'switchCamera' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<bool> setSpeaker({required String state}) async {
    try {
      final result = await channel.invokeMethod('setSpeaker', {
        'state': state,
      });
      sendLog(
          values: {
            "method": "setSpeaker()",
            "message": "setSpeaker result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting speaker: $e');
      sendLog(
          values: {
            "method": "setSpeaker()",
            "message": "Failed in 'setSpeaker' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  // Only for android
  Future<void> getAudioDevices() async {
    try {
      final result = await channel.invokeMethod('getAudioDevices');
      debugPrint('Audio devices: ${result.toString()}');
      sendLog(
          values: {
            "method": "getAudioDevices()",
            "message": "getAudioDevices result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
    } catch (e) {
      debugPrint('Error getting audio devices: $e');
      sendLog(
          values: {
            "method": "getAudioDevices()",
            "message": "Failed in 'getAudioDevices' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
    }
  }

  Future<bool> transfer({required String destination}) async {
    try {
      final result = await channel.invokeMethod("transfer", {
        "destination": destination,
      });
      sendLog(
          values: {
            "method": "transfer()",
            "destination": destination,
            "message": "transfer result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'transfer' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "transfer()",
            "destination": destination,
            "message": "Failed in 'transfer' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return false;
    }
  }

  Future<int> updateVideoCall({required bool isVideo}) async {
    debugPrint("updateVideoCall: $isVideo");
    try {
      final result = await channel.invokeMethod("updateVideoCall", {
        "isVideo": isVideo,
      });
      sendLog(
          values: {
            "method": "updateVideoCall()",
            "isVideo": isVideo,
            "message": "updateVideoCall result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'updateVideoCall' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "updateVideoCall()",
            "isVideo": isVideo,
            "message": "Failed in 'updateVideoCall' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: await getCurrentCallSessionId(),
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return -10;
    }
  }

  // Subscribe to media status channel
  Future<void> subscribeToMediaStatusChannel() async {
    try {
      // Get session ID
      if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
        debugPrint('Subscribing to event with sessionId: $_currentSessionId');

        // Subscribe to the socket event
        MptSocketSocketServer.subscribeToMediaStatusChannel(_currentSessionId!,
            (data) {
          debugPrint('Received media status message: $data');
          handleMediaStatusMessage(data);
        });
      } else {
        debugPrint(
            'Cannot subscribe to media status event: sessionId is null or empty');

        // If there's no sessionId, wait 1s and check again
        await Future.delayed(const Duration(seconds: 1));

        if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
          debugPrint(
              'Retrying subscribe to event with sessionId: $_currentSessionId');
          MptSocketSocketServer.subscribeToMediaStatusChannel(
              _currentSessionId!, (data) {
            debugPrint('Received media status message: $data');
            handleMediaStatusMessage(data);
          });
        } else {
          debugPrint('Still cannot get sessionId after retry');
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to media status event: $e');
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
        debugPrint('Media status data: $data');

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

            debugPrint(
                'Updated local status: camera=$cameraState, mic=$micState');
          } else {
            // Message from remote user, update their status
            _remoteCamState = cameraState;
            _remoteMicState = micState;

            // Broadcast the updated states
            _remoteCamStateController.add(cameraState);
            _remoteMicStateController.add(micState);

            debugPrint(
                'Updated remote media status: camera=$cameraState, mic=$micState');
          }
        } else {
          debugPrint('Cannot recognize media message format');
        }
      }
    } catch (e) {
      debugPrint('Error processing media status message: $e');
    }
  }

  // Send media status to socket event
  Future<void> sendMediaStatus() async {
    if (_currentSessionId == null || _currentSessionId!.isEmpty) {
      debugPrint('Cannot send media status: sessionId is null or empty');
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

        debugPrint('Updated media status: $mediaStatus');
      } else {
        debugPrint('Skipping media status update: $mediaStatus');
      }
    } catch (e) {
      debugPrint('Error sending media status: $e');
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

      debugPrint('Reset all media states after leaving call channel');
    } else {
      debugPrint('Session ID is null or empty');
    }
  }

  void _handleCallStateChanged(String state) async {
    debugPrint("handleCallStateChanged: $state");

    sendLog(
        values: {
          "sipCallState": state,
        },
        title: MPTSDKLogTitleConstants.SIP_CALL_STATE,
        sessionId: await getCurrentCallSessionId(),
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());

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

        // if (!isMakeCallByGuest) {
        //   // Update video call after 2.5 seconds in the agent side
        //   Future.delayed(const Duration(milliseconds: 100), () {
        //     updateVideoCall(isVideo: true);
        //   });
        // }
      }
    } else {
      debugPrint(
          "Cannot send agent state: sessionId is null or empty or Socket server is not connected");
    }

    // if (state == CallStateConstants.CLOSED) {
    //   MptSocketSocketServer.instance.sendAgentState(
    //     _currentSessionId!,
    //     AgentStateConstants.IDLE,
    //   );
    // } else {
    //  debugPrint("Cannot send agent state: sessionId is null or empty");
    // }

    if (state == CallStateConstants.CONNECTED) {
      // if (Platform.isAndroid) {
      //  debugPrint("showAndroidCallKit");
      //   showAndroidCallKit();
      // } else {
      //   //show ios callkit
      // }

      if (!isMakeCallByGuest) {
        reportMediaDeviceStatus(
          tenantId: currentUserInfo!["tenant"]["id"] ?? DEFAULT_TENANT_ID,
          agentId: currentUserInfo?["user"]["id"] ?? DEFAULT_AGENT_ID,
        );
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        setSpeaker(state: SpeakerStatusConstants.SPEAKER_PHONE);
      });
    }
  }

  /// Reset remote states when call ends
  void _resetRemoteStates() {
    debugPrint('Resetting remote states after call ended');

    // Reset remote camera and microphone states to default (true)
    _remoteCamState = true;
    _remoteMicState = true;

    // Broadcast the reset states to streams
    _remoteCamStateController.add(true);
    _remoteMicStateController.add(true);
    _calleeAnsweredStream.add(false);

    debugPrint('Remote states reset: camera=true, microphone=true');
  }

  Future<void> showAndroidCallKit() async {
    //debugPrint("showAndroidCallKit");
    // await channel.invokeMethod("startActivity");
  }

  // Centralized event channel listener setup
  void _setupEventChannelListener() {
    // Cancel existing subscription if any
    _eventChannelSubscription?.cancel();

    _eventChannelSubscription =
        eventChannel.receiveBroadcastStream().listen((event) async {
      debugPrint('Received event from native 1212: $event');
      if (event is Map) {
        // Handle map events with message and data
        final String message = event['message'];
        final dynamic data = event['data'];

        switch (message) {
          case 'onlineStatus':
            debugPrint('onlineStatus from native: $data');
            _isOnline = data as bool;
            _onlineStatuslistener.add(data);
            onRegisterSIP?.call(data);

            // Handle SIP ping based on registration status
            if (data) {
            } else {
              // SIP registration failed - stop ping
              stopSipPing();
            }
            break;
          case 'callState':
            _currentCallState = data.toString();
            _callEvent.add(data.toString());
            _handleCallStateChanged(data.toString());

            // Handle guest call specific logic
            if (isMakeCallByGuest) {
              if (data == CallStateConstants.FAILED) {
                debugPrint("makeCallByGuest() - Call failed!");
                offline(disablePushNoti: true);
                releaseExtension();
              }

              if (data == CallStateConstants.CLOSED) {
                debugPrint("makeCallByGuest() - Call ended!");
                offline(disablePushNoti: true);
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
            debugPrint('Received call message from native: $data');
            handleRecvCallMessage(data);
            break;
          case 'onVideoRawCallback':
            debugPrint('Received onVideoRawCallback from native: $data');
            break;
          case 'isRemoteVideoReceived':
            debugPrint('Received isRemoteVideoReceived from native: $data');
            // updateVideoCall(isVideo: true);
            _isRemoteVideoReceived.add(data as bool);
            break;
          // case "releaseExtension":
          //   if (isMakeCallByGuest) {
          //    debugPrint('Release extension has started');
          //     await releaseExtension();
          //    debugPrint('Release extension has done');
          //   }
          //   break;
        }
      }
    });
  }

  // Handle guest registration state
  void _handleGuestRegistrationState(dynamic data) async {
    _guestRegistrationCompleter ??= Completer<bool>();

    if (!_guestRegistrationCompleter!.isCompleted) {
      if (data == true) {
        debugPrint('SIP Registration successful for guest');
        _guestRegistrationCompleter!.complete(true);
        sendLog(
            values: {
              "method": "handleGuestRegistrationState()",
              "message": "SIP Registration successful for guest",
            },
            title: MPTSDKLogTitleConstants.METHOD_CALLED,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
      } else {
        debugPrint('SIP Registration has failed for guest');
        _guestRegistrationCompleter!.complete(false);
        sendLog(
            values: {
              "method": "handleGuestRegistrationState()",
              "message": "SIP Registration has failed for guest",
            },
            title: MPTSDKLogTitleConstants.METHOD_CALLED,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
      }
    } else {
      debugPrint(
          'Guest registration completer is null or already completed - ignoring state: $data');
    }
  }

  // 🔧 FIX: Helper method to cleanup guest registration state safely
  Future<void> _cleanupGuestRegistrationState() async {
    try {
      debugPrint('Cleaning up guest registration state...');

      // Complete any pending completer
      if (_guestRegistrationCompleter != null &&
          !_guestRegistrationCompleter!.isCompleted) {
        _guestRegistrationCompleter!.complete(false);
        sendLog(
            values: {
              "method": "cleanupGuestRegistrationState()",
              "message":
                  "Guest registration completer is null or already completed",
            },
            title: MPTSDKLogTitleConstants.METHOD_CALLED,
            tenantId: getLoggedTenantId(),
            agentId: getLoggedAgentId());
      }
      _guestRegistrationCompleter = null;

      // Cleanup SIP state
      await offline(disablePushNoti: true);

      // Reset guest flag and extension data
      isMakeCallByGuest = false;
      extensionData = null;

      // Small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));
      sendLog(
          values: {
            "method": "cleanupGuestRegistrationState()",
            "message": "Guest registration state cleanup completed",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());

      debugPrint('Guest registration state cleanup completed');
    } catch (e) {
      debugPrint('Error during guest registration cleanup: $e');
      sendLog(
          values: {
            "method": "cleanupGuestRegistrationState()",
            "message": "Error during guest registration cleanup: $e",
            "error": e.toString(),
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    sendLog(
        values: {
          "method": "dispose()",
          "message": "Dispose method called",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    _eventChannelSubscription?.cancel();

    // 🔧 FIX: Use helper method for consistent cleanup
    _cleanupGuestRegistrationState();

    // Legacy cleanup (keeping for safety)
    if (_guestRegistrationCompleter != null &&
        !_guestRegistrationCompleter!.isCompleted) {
      _guestRegistrationCompleter!.complete(false);
    }
    _guestRegistrationCompleter = null;

    // Stop SIP connectivity check
    stopSipPing();

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
    _sipPingStream.close();
  }

  /// Ensure LocalView and RemoteView listeners are registered
  /// Call this when app returns from background, especially after FCM processing
  static Future<void> ensureViewListenersRegistered() async {
    try {
      if (Platform.isAndroid) {
        await channel.invokeMethod('ensureViewListenersRegistered');
        debugPrint('Ensured view listeners are registered');
      }
    } catch (e) {
      debugPrint('Error ensuring view listeners registered: $e');
    }
  }

  /// Start checking SIP server connectivity to monitor connection quality
  void startSipPing(String sipServerUrl,
      {Duration interval = const Duration(seconds: 5)}) {
    stopSipPing(); // Stop any existing connectivity check

    _sipServerUrl = sipServerUrl;
    _isPinging = true;

    debugPrint('Starting SIP connectivity check to: $sipServerUrl');

    _pingTimer = Timer.periodic(interval, (timer) async {
      if (!_isPinging) {
        timer.cancel();
        return;
      }

      await _performPing();
    });

    // Perform initial check immediately
    _performPing();
  }

  /// Stop checking SIP server connectivity
  void stopSipPing() {
    _isPinging = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    debugPrint('Stopped SIP connectivity check');
  }

  /// Perform a single ping to SIP server using TCP socket connection
  Future<void> _performPing() async {
    if (_sipServerUrl == null || _sipServerUrl!.isEmpty) {
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Parse host and port
      String host = _sipServerUrl!;
      int port = 5063; // Default SIP port

      // Remove protocol prefix if exists
      if (host.startsWith('http://')) {
        host = host.substring(7);
      } else if (host.startsWith('https://')) {
        host = host.substring(8);
      }

      // Extract port if specified
      if (host.contains(':')) {
        final parts = host.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? 5063;
      }

      // Try to connect to the host via TCP socket
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      stopwatch.stop();
      final pingTime = stopwatch.elapsedMilliseconds;

      // Close the socket immediately
      await socket.close();

      _sipPingStream.add(pingTime);
      //debugPrint(
      //     'SIP connectivity check to $host:$port: ${pingTime}ms (TCP connection successful)');
    } on SocketException catch (e) {
      _sipPingStream.add(null);
      if (e.message.contains('timed out')) {
        debugPrint('SIP connectivity check to $_sipServerUrl timed out');
      } else {
        debugPrint(
            'SIP connectivity check to $_sipServerUrl failed: ${e.message}');
      }
    } catch (e) {
      _sipPingStream.add(null);
      debugPrint('SIP connectivity check to $_sipServerUrl error: $e');
    }
  }

  void handleRecvCallMessage(dynamic data) {
    try {
      // Parse JSON data
      if (data is! String) {
        debugPrint(
            'Invalid data type for recvCallMessage: ${data.runtimeType}');
        return;
      }

      final Map<String, dynamic> message = jsonDecode(data);
      debugPrint('Parsed message: $message');

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
        debugPrint('Invalid message format: missing required fields');
        return;
      }

      // Check if received sessionId matches current sessionId
      if (_currentSessionId == null || _currentSessionId!.isEmpty) {
        debugPrint('Current session ID is null or empty, ignoring message');
        return;
      }

      if (receivedSessionId != _currentSessionId) {
        debugPrint(
            'Session ID mismatch: received=$receivedSessionId, current=$_currentSessionId');
        return;
      }

      // // Check if extension is different from current user extension
      // if (this.extension.isEmpty) {
      //  debugPrint('Current extension is empty, ignoring message');
      //   return;
      // }

      // if (extension == this.extension ||
      //     extension == currentUserInfo!["user"]["extension"]) {
      //  debugPrint(
      //       'Extension matches current user ($extension), ignoring message from self');
      //   return;
      // }

      debugPrint(
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
          debugPrint('Unknown message type: $type');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing recvCallMessage: $e');
      debugPrint('Raw data: $data');
    }
  }

  /// Handle media state updates (camera, microphone)
  void _handleUpdateMediaState(Map<String, dynamic> payload) {
    debugPrint('Handling media state update: $payload');

    payload.forEach((key, value) {
      switch (key) {
        case 'microphone':
          final bool micState = value as bool;
          debugPrint('Remote microphone state: $micState');
          _remoteMicState = micState;
          _remoteMicStateController.add(micState);
          break;

        case 'camera':
          final bool camState = value as bool;
          debugPrint('Remote camera state: $camState');
          _remoteCamState = camState;
          _remoteCamStateController.add(camState);
          break;

        default:
          debugPrint('Unknown media state key: $key');
          break;
      }
    });
  }

  /// Handle call state updates
  void _handleCallStateUpdate(Map<String, dynamic> payload) {
    debugPrint('Handling call state update: $payload');

    payload.forEach((key, value) {
      switch (key) {
        case 'answered':
          final bool isAnswered = value as bool;
          debugPrint('Call answered state: $isAnswered');
          if (isAnswered) {
            // Handle call answered logic
            debugPrint('Remote party answered the call');
            _calleeAnsweredStream.add(true);

            if (isVideoCall) {
              Future.delayed(const Duration(milliseconds: 2500), () {
                updateVideoCall(isVideo: true);
              });
            }
          }
          break;
        // callee agent info
        case "agentInfo":
          try {
            Map<String, dynamic> agentInfo;

            // Handle both String and Map types
            if (value is String) {
              // If it's a string, try to parse it as JSON
              agentInfo = jsonDecode(value) as Map<String, dynamic>;
            } else if (value is Map) {
              // If it's already a Map, use it directly
              agentInfo = Map<String, dynamic>.from(value);
            } else {
              debugPrint('Invalid agentInfo type: ${value.runtimeType}');
              break;
            }

            debugPrint("Agent Info received: ${agentInfo.toString()}");

            final int agentId = agentInfo["agentId"] as int;
            final int tenantId = agentInfo["tenantId"] as int;

            debugPrint('Agent ID received: $agentId');
            debugPrint('Tenant ID received: $tenantId');

            if (agentId != DEFAULT_AGENT_ID &&
                tenantId != DEFAULT_TENANT_ID &&
                isMakeCallByGuest) {
              reportMediaDeviceStatus(tenantId: tenantId, agentId: agentId);
            }
          } catch (e) {
            debugPrint('Error parsing agentInfo: $e');
            debugPrint('agentInfo value: $value (type: ${value.runtimeType})');
          }
          break;

        // case "isVideo":
        //   final bool isVideo = value as bool;
        //  debugPrint(
        //       'Remote party send request reinvite video call state: $isVideo');
        //   if (isVideo) {
        //     updateVideoCall(isVideo: isVideo);
        //   }
        //   break;

        default:
          debugPrint('Unknown call state key: $key');
          break;
      }
    });
  }

  Future<void> endCallAPI({
    required String sessionId,
    required int agentId,
    Function(String?)? onError,
  }) async {
    try {
      final bool isSuccess = await MptCallKitControllerRepo().postEndCall(
        baseUrl: await getCurrentBaseUrl(),
        sessionId: sessionId,
        agentId: agentId,
        onError: onError,
      );
      sendLog(
          values: {
            "method": "endCallAPI()",
            "sessionId": sessionId,
            "agentId": agentId,
            "message": "End call API result: $isSuccess",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          tenantId: getLoggedTenantId(),
          sessionId: sessionId,
          agentId: getLoggedAgentId());
      if (isSuccess) {
        debugPrint("End call API success");
      } else {
        debugPrint("End call API failed");
      }
    } catch (e) {
      debugPrint("End call API error: $e");
      onError?.call("End call API error: $e");
    }
  }

  Future<bool> getCallkitAnsweredState() async {
    return await channel.invokeMethod("getCallkitAnsweredState");
  }

  // Accessors for SharedPreferences-backed init values
  Future<String> getCurrentBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(SDKPrefsKeyConstants.BASE_URL);
    return (value != null && value.isNotEmpty)
        ? value
        : "https://crm-dev-v2.metechvn.com";
  }

  Future<String> getCurrentApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.API_KEY) ?? '';
  }

  Future<String> getCurrentPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.PUSH_TOKEN) ?? '';
  }

  Future<String> getCurrentRecordLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.RECORD_LABEL) ?? 'Customer';
  }

  Future<bool> getCurrentEnableBlurBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SDKPrefsKeyConstants.ENABLE_BLUR_BACKGROUND) ?? false;
  }

  Future<String?> getCurrentBgPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.BG_PATH);
  }

  Future<String> getCurrentAppId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.APP_ID) ?? '';
  }

  Future<String> getCurrentDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SDKPrefsKeyConstants.DEVICE_INFO) ?? '';
  }

  Future<int> refreshRegistration() async {
    final result = await channel.invokeMethod("refreshRegister");
    debugPrint("refreshRegistration result code: $result");
    return result;
  }

  Future<int> refreshRegister() async {
    if (context == null) {
      return -1;
    }
    await _registerToSipServer(context: context!);
    return 0;
  }

  Future<int> unRegister() async {
    await offline();
    return 0;
  }

  Future<bool> deleteRegistration({
    required int tenantId,
    required int agentId,
    String? baseUrl,
    Function(String?)? onError,
  }) async {
    final result = await MptCallKitControllerRepo().deleteRegistration(
      baseUrl: baseUrl,
      onError: onError,
      tenantId: tenantId,
      agentId: agentId,
    );
    sendLog(
        values: {
          "method": "deleteRegistration()",
          "tenantId": tenantId,
          "agentId": agentId,
          "message": "Delete registration result: $result",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  // Change agent status in queue
  Future<bool> changeAgentStatusInQueue({
    required String queueId,
    required bool enabled,
    Function(String?)? onError,
  }) async {
    final result = await MptCallKitControllerRepo().putAgentQueues(
      baseUrl: await getCurrentBaseUrl(),
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      queueId: queueId,
      enabled: enabled,
      onError: onError,
    );
    sendLog(
        values: {
          "method": "changeAgentStatusInQueue()",
          "queueId": queueId,
          "enabled": enabled,
          "message": "Change agent status in queue result: $result",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  // Get all agent's queues
  Future<List<QueueDataByAgent>?> getAgentQueues({
    Function(String?)? onError,
  }) async {
    final result = await MptCallKitControllerRepo().getAgentQueues(
      baseUrl: await getCurrentBaseUrl(),
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      onError: onError,
    );
    sendLog(
        values: {
          "method": "getAgentQueues()",
          "message": "Get agent queues result: ${result?.toList().toString()}",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  // Get all queues
  Future<List<QueueData>?> getAllQueues({
    Function(String?)? onError,
  }) async {
    final result = await MptCallKitControllerRepo().getAllQueues(
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      baseUrl: await getCurrentBaseUrl(),
      onError: onError,
    );
    sendLog(
        values: {
          "method": "getAllQueues()",
          "message": "Get all queues result: ${result?.toList().toString()}",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  // Get all agents in queue by extension
  Future<List<AgentDataByQueue>?> getAllAgentInQueueByQueueExtension({
    required String extension,
    Function(String?)? onError,
  }) async {
    final result =
        await MptCallKitControllerRepo().getAllAgentInQueueByQueueExtension(
      extension: extension,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      baseUrl: await getCurrentBaseUrl(),
      onError: onError,
    );
    sendLog(
        values: {
          "method": "getAllAgentInQueueByQueueExtension()",
          "extension": extension,
          "message":
              "Get all agents in queue by extension result: ${result?.toList().toString()}",
        },
        title: MPTSDKLogTitleConstants.METHOD_CALLED,
        tenantId: getLoggedTenantId(),
        agentId: getLoggedAgentId());
    return result;
  }

  Future<AgentData?> getCurrentAgentData(String accessToken) async {
    await _getCurrentUserInfo(accessToken);

    return AgentData(
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      userId: currentUserInfo?["user"]["id"] ?? 0,
      userName: currentUserInfo?["user"]["userName"] ?? "",
      fullName: currentUserInfo?["user"]["fullName"] ?? "",
      extension: currentUserInfo?["user"]["extension"] ?? "",
    );
  }

  Future<String?> getCurrentCallSessionId() async {
    try {
      final result = await channel.invokeMethod("getCurrentCallSessionId");
      debugPrint("getCurrentCallSessionId result: $result");
      sendLog(
          values: {
            "method": "getCurrentCallSessionId()",
            "message": "Get current call session id result: $result",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: result,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'getCurrentCallSessionId' mothod: '${e.message}'.");
      sendLog(
          values: {
            "method": "getCurrentCallSessionId()",
            "message":
                "Failed in 'getCurrentCallSessionId' mothod: '${e.toString()}'.",
          },
          title: MPTSDKLogTitleConstants.METHOD_CALLED,
          sessionId: null,
          tenantId: getLoggedTenantId(),
          agentId: getLoggedAgentId());
      return null;
    }
  }

  Future<void> reportMediaDeviceStatus({
    required int tenantId,
    required int agentId,
    Function(String?)? onError,
  }) async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final hasPermission = await channel.invokeMethod('requestPermission');

    final currentTime = DateTime.now();
    final timeStamp = currentTime.millisecondsSinceEpoch;
    final date = DateFormat('dd/MM/yy HH:mm:ss').format(currentTime);

    var data = {
      "deviceType": "mobile",
      "devicePermissions": hasPermission,
      "extension": int.parse(lastesExtensionData?.username ?? "0"),
      "extensionRole": isMakeCallByGuest ? "guest" : "agent",
      "mptSDKVersion": MptSDKCoreConstants.VERSION,
    };

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      data["platform"] = "Android";
      data["androidVersion"] = androidInfo.version.release;
      data["androidSDKVersion"] = androidInfo.version.sdkInt;
      data["manufacturer"] = androidInfo.manufacturer;
      data["model"] = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      data["platform"] = "iOS";
      data["iosVersion"] = iosInfo.systemVersion;
      data["machine"] = iosInfo.utsname.machine;
      data["name"] = iosInfo.name;
    }

    final payload = {
      "values": (data),
      "title": MPTSDKLogTitleConstants.MEDIA_DEVICE_STATUS,
      "tabId": "",
      "date": date,
    };

    debugPrint("reportMediaDeviceStatus - payload: ${jsonEncode(payload)}");

    await MptCallKitControllerRepo().reportDynamicClientLog(
      baseUrl: await getCurrentBaseUrl(),
      tenantId: tenantId,
      // agentId: int.parse(lastesExtensionData?.username ?? "0"),
      agentId: agentId,
      sessionId: await getCurrentCallSessionId() ?? "",
      timeStamp: timeStamp,
      payload: jsonEncode(payload),
      onError: onError,
    );
  }

  Future<void> sendLog({
    required Map<String, dynamic>? values,
    String? sessionId,
    required String title,
    bool? isGuest = false,
    int? tenantId,
    int? agentId,
  }) async {
    MptClientLogger().sendLog(
      baseUrl: await getCurrentBaseUrl(),
      title: title,
      values: values,
      isGuest: isGuest ?? getLoggedAgentId() == DEFAULT_AGENT_ID,
      extension: int.parse(lastesExtensionData?.username ?? "0"),
      tenantId: tenantId ?? getLoggedTenantId(),
      agentId: agentId ?? getLoggedAgentId(),
      sessionId: sessionId ?? "",
      onError: (error) => debugPrint("sendLog error: $error"),
    );
  }
}
