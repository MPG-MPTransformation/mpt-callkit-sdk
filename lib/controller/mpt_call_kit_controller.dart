import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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
        print("Received event from native: ${call.method}");
        if (call.method == 'onlineStatus') {
          _isOnline = call.arguments as bool;
          _onlineStatuslistener.add(call.arguments as bool);
          onRegisterSIP?.call(call.arguments as bool);
          print("onlineStatus: ${call.arguments}");

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
              print("makeCallByGuest() - Call failed!");
              offline(disablePushNoti: true);
              releaseExtension();
            }

            if (call.arguments == CallStateConstants.CLOSED) {
              print("makeCallByGuest() - Call ended!");
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
          print(
              'Received callKitAnswerReceived event from native: ${call.arguments}');
        }

        if (call.method == 'recvCallMessage') {
          print('Received call message from native: ${call.arguments}');
          handleRecvCallMessage(call.arguments);
        }

        if (call.method == 'onVideoRawCallback') {
          print('Received onVideoRawCallback from native: ${call.arguments}');
        }

        if (call.method == 'isRemoteVideoReceived') {
          print(
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

    print("record log to filePath: $filePath");

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
    print("disableFileLogging");
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
    print(
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
            print("Timeout waiting to join initial rooms");
          }
        } else {
          _appEvent.add(AppEventConstants.ERROR);
          onError?.call("Failed to connect to socket server");
          _currentAppEvent = AppEventConstants.ERROR;
          print("Failed to connect to socket server");
        }
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
        resolution: _configuration!["MOBILE_SIP_RESOLUTION"],
        bitrate: _configuration!["MOBILE_SIP_BITRATE"],
        frameRate: _configuration!["MOBILE_SIP_FRAMERATE"],
      );

      var regResult = await refreshRegistration();

      Future.delayed(const Duration(milliseconds: 500), () async {
        {
          if (regResult == 0 && _isOnline == true) {
            print("SIP already online");
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
                print("Error in register to sip server: ${p0.toString()}");
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

    if (currentUserInfo != null &&
        currentUserInfo!["user"] != null &&
        currentUserInfo!["tenant"] != null) {
      _appEvent.add(AppEventConstants.LOGGED_IN);
      _currentAppEvent = AppEventConstants.LOGGED_IN;
      print("Get current user info success, ready to connect to socket server");
    }
  }

  Future<bool> connectToSocketServer(String accessToken) async {
    print("connectToSocketServer");

    // Prevent multiple simultaneous connection attempts
    if (_isConnectingToSocket && _socketConnectionCompleter != null) {
      print(
          "Socket connection already in progress, waiting for existing attempt...");
      return await _socketConnectionCompleter!.future;
    }

    // Check if already connected
    if (MptSocketSocketServer.getCurrentConnectionState()) {
      print("Socket server already connected");
      try {
        await channel.invokeMethod('socketStatus', {'ready': true});
      } catch (e) {
        print('Failed to notify iOS about socket status: $e');
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
            print("Message received in callback: $p0");
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
            print('Failed to notify iOS about socket status: $e');
          }
        });

        // Set up timeout
        _socketConnectionTimer = Timer(const Duration(seconds: 10), () {
          _tempSocketStatusSubscription?.cancel();
          if (!_socketConnectionCompleter!.isCompleted) {
            _socketConnectionCompleter!.complete(false);
            print("Socket connection timeout after 10 seconds");
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
            print("Socket server connected successfully");
          }
        });

        // Check if already connected (race condition check)
        if (MptSocketSocketServer.getCurrentConnectionState()) {
          try {
            await channel.invokeMethod('socketStatus', {
              'ready': true,
            });
          } catch (e) {
            print('Failed to notify iOS about socket status: $e');
          }
          _socketConnectionTimer?.cancel();
          _tempSocketStatusSubscription?.cancel();
          if (!_socketConnectionCompleter!.isCompleted) {
            _socketConnectionCompleter!.complete(true);
            print("Socket server already connected (race condition)");
          }
          _isConnectingToSocket = false;
        }

        final result = await _socketConnectionCompleter!.future;
        _socketConnectionCompleter = null;
        return result;
      } catch (e) {
        print("Error in connect to socket server: ${e.toString()}");
        _isConnectingToSocket = false;
        _socketConnectionCompleter = null;
        _tempSocketStatusSubscription?.cancel();
        _socketConnectionTimer?.cancel();
        return false;
      }
    } else {
      print("Cannot connect agent to socket server - configuration is null");
      return false;
    }
  }

  // get configuration
  Future<void> _getConfiguration(String accessToken) async {
    _configuration = await MptCallkitAuthMethod().getConfiguration(
      baseUrl: await getCurrentBaseUrl(),
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
      print('Failed to notify iOS about socket disconnect: $e');
    }

    isLogoutAccountSuccess = await offline(disablePushNoti: true);

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

      print("extension result: $result");

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
          print('Cancelling previous guest registration attempt...');
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
            print('SIP Registration has failed');
            onError?.call('SIP Registration failed');
          }
        } catch (e) {
          print('Registration timeout or error: $e');
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
      print("getExtension - Response status code: ${response.statusCode}");
      print("getExtension - Response headers: ${response.headers}");
      print("getExtension - Response body: ${response.body}");

      // Check if response is successful
      if (response.statusCode != 200) {
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
        print("getExtension - JSON parsing error: $e");
        print("getExtension - Raw response body: '${response.body}'");
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
      print("releaseExtension - Response status code: ${response.statusCode}");
      print("releaseExtension - Response body: ${response.body}");

      // Check if response is successful
      if (response.statusCode != 200) {
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
        print("releaseExtension - JSON parsing error: $e");
        print("releaseExtension - Raw response body: '${response.body}'");
        throw Exception('Invalid JSON response from server: $e');
      }

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
    print("isMakeCallByGuest: $isMakeCallByGuest");

    print("sipServer: $sipServer");

    startSipPing(sipServer);

    try {
      final hasPermission = await requestPermission(context);
      if (!hasPermission) {
        onError?.call('Permission denied');
        print("Permission denied");
        return false;
      }
      print("login");
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

      print("login result: $result");

      return result;
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
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
    this.isVideoCall = isVideoCall ?? false;
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };
    return await MptCallKitControllerRepo().makeCall(
      baseUrl: await getCurrentBaseUrl(),
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
    this.isVideoCall = isVideoCall ?? false;
    var extraInfoResult = {
      "type": isVideoCall == true ? CallType.VIDEO : CallType.VOICE,
      "extraInfo": extraInfo,
    };

    return await MptCallKitControllerRepo().makeCallInternal(
      baseUrl: await getCurrentBaseUrl(),
      tenantId: currentUserInfo!["tenant"]["id"],
      applicationId: destination,
      senderId: senderId ?? currentUserInfo!["user"]["extension"],
      agentId: currentUserInfo!["user"]["id"] ?? 0,
      extraInfo: jsonEncode(extraInfoResult),
      authToken: accessToken,
      onError: onError,
    );
  }

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
        baseUrl: await getCurrentBaseUrl(),
        accessToken: accessToken,
        onError: onError,
        deviceInfo: await getCurrentDeviceInfo(),
      );
    } else {
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
      return null;
    }

    final cloudAgentId = currentUserInfo!["user"]["id"];
    final cloudTenantId = currentUserInfo!["tenant"]["id"];
    final cloudAgentName = currentUserInfo!["user"]["fullName"] ?? "";

    if (cloudAgentId == null || cloudTenantId == null) {
      onError?.call("getCurrentAgentStatus: missing required user info");
      return null;
    }

    return await MptCallKitControllerRepo().getCurrentAgentStatus(
      cloudAgentId: cloudAgentId,
      cloudTenantId: cloudTenantId,
      cloudAgentName: cloudAgentName,
      baseUrl: await getCurrentBaseUrl(),
      accessToken: accessToken,
      onError: onError,
    );
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
      return result;
      // }
    } on PlatformException catch (e) {
      debugPrint("Failed to go offline: '${e.message}'.");
      return false;
    }
  }

  Future<int> hangup() async {
    // If hangup success, return 0 - failed in others case
    try {
      final result = await channel.invokeMethod("hangup");
      print("hangup result: $result");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'hangup' mothod: '${e.message}'.");
      return -1;
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

  Future<int> answerCall() async {
    try {
      final result = await channel.invokeMethod("answer");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'answer' mothod: '${e.message}'.");
      return -10;
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
      print('Audio devices: ${result.toString()}');
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
    print("updateVideoCall: $isVideo");
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

        // if (!isMakeCallByGuest) {
        //   // Update video call after 2.5 seconds in the agent side
        //   Future.delayed(const Duration(milliseconds: 100), () {
        //     updateVideoCall(isVideo: true);
        //   });
        // }
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
      // if (Platform.isAndroid) {
      //   print("showAndroidCallKit");
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
            print('onlineStatus from native: $data');
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
                print("makeCallByGuest() - Call failed!");
                offline(disablePushNoti: true);
                releaseExtension();
              }

              if (data == CallStateConstants.CLOSED) {
                print("makeCallByGuest() - Call ended!");
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
            print('Received call message from native: $data');
            handleRecvCallMessage(data);
            break;
          case 'onVideoRawCallback':
            print('Received onVideoRawCallback from native: $data');
            break;
          case 'isRemoteVideoReceived':
            print('Received isRemoteVideoReceived from native: $data');
            // updateVideoCall(isVideo: true);
            _isRemoteVideoReceived.add(data as bool);
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
    _guestRegistrationCompleter ??= Completer<bool>();

    if (!_guestRegistrationCompleter!.isCompleted) {
      if (data == true) {
        print('SIP Registration successful for guest');
        _guestRegistrationCompleter!.complete(true);
      } else {
        print('SIP Registration has failed for guest');
        _guestRegistrationCompleter!.complete(false);
      }
    } else {
      print(
          'Guest registration completer is null or already completed - ignoring state: $data');
    }
  }

  // 🔧 FIX: Helper method to cleanup guest registration state safely
  Future<void> _cleanupGuestRegistrationState() async {
    try {
      print('Cleaning up guest registration state...');

      // Complete any pending completer
      if (_guestRegistrationCompleter != null &&
          !_guestRegistrationCompleter!.isCompleted) {
        _guestRegistrationCompleter!.complete(false);
      }
      _guestRegistrationCompleter = null;

      // Cleanup SIP state
      await offline(disablePushNoti: true);

      // Reset guest flag and extension data
      isMakeCallByGuest = false;
      extensionData = null;

      // Small delay to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 500));

      print('Guest registration state cleanup completed');
    } catch (e) {
      print('Error during guest registration cleanup: $e');
    }
  }

  // Dispose method to clean up resources
  void dispose() {
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
        print('Ensured view listeners are registered');
      }
    } catch (e) {
      print('Error ensuring view listeners registered: $e');
    }
  }

  /// Start checking SIP server connectivity to monitor connection quality
  void startSipPing(String sipServerUrl,
      {Duration interval = const Duration(seconds: 5)}) {
    stopSipPing(); // Stop any existing connectivity check

    _sipServerUrl = sipServerUrl;
    _isPinging = true;

    print('Starting SIP connectivity check to: $sipServerUrl');

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
    print('Stopped SIP connectivity check');
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
      // print(
      //     'SIP connectivity check to $host:$port: ${pingTime}ms (TCP connection successful)');
    } on SocketException catch (e) {
      _sipPingStream.add(null);
      if (e.message.contains('timed out')) {
        print('SIP connectivity check to $_sipServerUrl timed out');
      } else {
        print('SIP connectivity check to $_sipServerUrl failed: ${e.message}');
      }
    } catch (e) {
      _sipPingStream.add(null);
      print('SIP connectivity check to $_sipServerUrl error: $e');
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

            if (this.isVideoCall) {
              Future.delayed(const Duration(seconds: 1), () {
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
              print('Invalid agentInfo type: ${value.runtimeType}');
              break;
            }

            print("Agent Info received: ${agentInfo.toString()}");

            final int agentId = agentInfo["agentId"] as int;
            final int tenantId = agentInfo["tenantId"] as int;

            print('Agent ID received: $agentId');
            print('Tenant ID received: $tenantId');

            if (agentId != DEFAULT_AGENT_ID &&
                tenantId != DEFAULT_TENANT_ID &&
                isMakeCallByGuest) {
              reportMediaDeviceStatus(tenantId: tenantId, agentId: agentId);
            }
          } catch (e) {
            print('Error parsing agentInfo: $e');
            print('agentInfo value: $value (type: ${value.runtimeType})');
          }
          break;

        // case "isVideo":
        //   final bool isVideo = value as bool;
        //   print(
        //       'Remote party send request reinvite video call state: $isVideo');
        //   if (isVideo) {
        //     updateVideoCall(isVideo: isVideo);
        //   }
        //   break;

        default:
          print('Unknown call state key: $key');
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
      if (isSuccess) {
        print("End call API success");
      } else {
        print("End call API failed");
      }
    } catch (e) {
      print("End call API error: $e");
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
    print("refreshRegistration result code: $result");
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
    return await MptCallKitControllerRepo().deleteRegistration(
      baseUrl: baseUrl,
      onError: onError,
      tenantId: tenantId,
      agentId: agentId,
    );
  }

  // Change agent status in queue
  Future<bool> changeAgentStatusInQueue({
    required String queueId,
    required bool enabled,
    Function(String?)? onError,
  }) async {
    return await MptCallKitControllerRepo().putAgentQueues(
      baseUrl: await getCurrentBaseUrl(),
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      queueId: queueId,
      enabled: enabled,
      onError: onError,
    );
  }

  // Get all agent's queues
  Future<List<QueueDataByAgent>?> getAgentQueues({
    Function(String?)? onError,
  }) async {
    return await MptCallKitControllerRepo().getAgentQueues(
      baseUrl: await getCurrentBaseUrl(),
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      onError: onError,
    );
  }

  // Get all queues
  Future<List<QueueData>?> getAllQueues({
    Function(String?)? onError,
  }) async {
    return await MptCallKitControllerRepo().getAllQueues(
      agentId: currentUserInfo?["user"]["id"] ?? 0,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      baseUrl: await getCurrentBaseUrl(),
      onError: onError,
    );
  }

  // Get all agents in queue by extension
  Future<List<AgentDataByQueue>?> getAllAgentInQueueByQueueExtension({
    required String extension,
    Function(String?)? onError,
  }) async {
    return await MptCallKitControllerRepo().getAllAgentInQueueByQueueExtension(
      extension: extension,
      tenantId: currentUserInfo?["tenant"]["id"] ?? 0,
      baseUrl: await getCurrentBaseUrl(),
      onError: onError,
    );
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
      print("getCurrentCallSessionId result: $result");
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed in 'getCurrentCallSessionId' mothod: '${e.message}'.");
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
      "extensionRole": isMakeCallByGuest ? "caller" : "callee",
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

    print("reportMediaDeviceStatus - payload: ${jsonEncode(payload)}");

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
}
