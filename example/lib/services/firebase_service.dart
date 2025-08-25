import 'dart:async';
import 'dart:io';

import 'package:example/services/callkit_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/models.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../components/callkit_constants.dart';
import '../login_result.dart';
import '../push_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔹 Background Message: ${message.data.toString()}');

  try {
    // Đảm bảo khởi tạo flutter_local_notifications trước khi sử dụng
    await PushNotifications.localNotiInit();

    // Giải quyết vấn đề với SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('navigate_from_notification', true);
      print(
          'Set navigate_from_notification flag to true from background handler');

      // Lưu thêm dữ liệu message để xử lý sau khi mở lại ứng dụng nếu cần
      await prefs.setString('last_message_data', message.data.toString());
    } catch (e) {
      print('Error saving notification state: $e');
    }

    /* ------------------------------------------------------------
   Show call notification if have call incoming:
    1. Make sure app is in background.
    2. Or if app terminated, you have to auto login step by step (follow the code in HomeScreen()):
    2.1. Call to method MptCallKitController().initSdk().
    2.2. Call to method login (login with account or sso login)
    with saved credentials and navigate to LoginResultScreen to get call incoming.
    -------------------------------------------------------------*/

    /* dictionaryPayload JSON Format
        Payload: {
        "message_id" = "96854b5d-9d0b-4644-af6d-8d97798d9c5b";
        "msg_content" = "Received a call.";
        "msg_title" = "Received a new call";
        "msg_type" = "call";// im message is "im"
        "X-Push-Id" = "pvqxCpo-j485AYo9J1cP5A..";
        "send_from" = "102";
        "send_to" = "sip:105@portsip.com";
        }
      */

    if (message.data['msg_title'] == "Received a new call.") {
      const String tokenKey = 'fcm_token';
      const String accessTokenKey = 'saved_access_token';
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(accessTokenKey);
      print('Access Token: $accessToken');
      if (accessToken != null && accessToken.isNotEmpty) {
        print('Auto login with saved credentials: $accessToken');

        MptCallKitController().initSdk(
          apiKey: CallkitConstants.API_KEY,
          baseUrl: CallkitConstants.BASE_URL,
          pushToken: Platform.isAndroid ? prefs.getString(tokenKey) : null,
          appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
          enableDebugLog: true,
        );
        MptCallKitController().refreshRegister();
      }
      await CallKitService.showCallkitIncoming(
        callerName: message.data['msg_title'] ?? "Thông báo mới",
        callerNumber: message.data['msg_content'] ?? "Nhấn để xem chi tiết",
      );
      // await PushNotifications.showSimpleNotification(
      //     title: message.data['msg_title'] ?? "Thông báo mới",
      //     body: message.data['msg_content'] ?? "Nhấn để xem chi tiết",
      //     payload: message.data.toString());

      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
        switch (event?.event ?? Event.actionCallIncoming) {
          case Event.actionCallIncoming:
            // TODO: received an incoming call
            break;
          case Event.actionCallStart:
            // TODO: started an outgoing call
            // TODO: show screen calling in Flutter
            break;
          case Event.actionCallAccept:
            await MptCallKitController().unRegister();
            // TODO: accepted an incoming call
            // TODO: show screen calling in Flutter
            break;
          case Event.actionCallDecline:
            // TODO: declined an incoming call
            MptCallKitController().rejectCall();

            await Future.delayed(const Duration(seconds: 1));
            await MptCallKitController().unRegister();
            break;
          case Event.actionCallEnded:
            // TODO: ended an incoming/outgoing call
            break;
          case Event.actionCallTimeout:
            // TODO: missed an incoming call
            break;
          case Event.actionCallCallback:
            // TODO: click action `Call back` from missed call notification
            break;
          case Event.actionCallToggleHold:
            // TODO: only iOS
            break;
          case Event.actionCallToggleMute:
            // TODO: only iOS
            break;
          case Event.actionCallToggleDmtf:
            // TODO: only iOS
            break;
          case Event.actionCallToggleGroup:
            // TODO: only iOS
            break;
          case Event.actionCallToggleAudioSession:
            // TODO: only iOS
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            // TODO: only iOS
            break;
          case Event.actionCallCustom:
            // TODO: for custom action
            break;
          default:
            print('Unknown event: ${event?.event}');
            break;
        }
      });

      StreamSubscription<String>? callTypeSubscription =
          MptCallKitController().callEvent.listen((type) async {
        print("MptCallKitController().callEvent: $type");
        if (type == CallStateConstants.CLOSED ||
            type == CallStateConstants.FAILED) {
          await CallKitService.hideCallKit();
        }
      });
    }
  } catch (e) {
    print('Error in background handler: $e');
  }
}

// GlobalKey để truy cập Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _tokenFCM = "";
  static const String _tokenKey = 'fcm_token';
  static const String _accessTokenKey = 'saved_access_token';

  FirebaseService() {
    _initializeFCM();
    _loadTokenFromLocal();
  }

  Future<void> _loadTokenFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    if (storedToken != null && storedToken.isNotEmpty) {
      _tokenFCM = storedToken;
      print('Loaded FCM token from local: $_tokenFCM');
    }
  }

  Future<void> _saveTokenToLocal(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('Saved FCM token to local storage');
  }

  String? get token => _tokenFCM;

  Future<bool> autoLogin(BuildContext? context) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);

    if (accessToken != null && accessToken.isNotEmpty) {
      print('Auto login with saved credentials: $accessToken');

      MptCallKitController().initSdk(
        apiKey: CallkitConstants.API_KEY,
        baseUrl: CallkitConstants.BASE_URL,
        pushToken: Platform.isAndroid ? prefs.getString(_tokenKey) : null,
        appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
        enableDebugLog: true,
      );

      // var result = await MptCallKitController().loginRequest(
      //   username: username,
      //   password: password,
      //   tenantId: CallkitConstants.TENANT_ID,
      //   baseUrl: CallkitConstants.BASE_URL,
      //   onError: (error) {
      //     print('Auto login failed: $error');
      //   },
      // );

      if (context != null) {
        print('Auto login successful');

        // Chuyển hướng đến màn hình LoginResultScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginResultScreen(
              title: 'Login Successful',
              baseUrl: CallkitConstants.BASE_URL,
              apiKey: CallkitConstants.API_KEY,
            ),
          ),
        );

        return true;
      }
    } else {
      print('No saved credentials found for auto login');
    }

    return false;
  }

  Future<void> _initializeFCM() async {
    print("initializeFCM");
    // // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission for FCM
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Save FCM token
    _firebaseMessaging.getToken().then((token) {
      print('Device Token FCM: $token');
      if (token != null) {
        _tokenFCM = token;
        _saveTokenToLocal(token);
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((token) {
      print('FCM Token refresh: $token');
      _tokenFCM = token;
      _saveTokenToLocal(token);
    }).onError((error) {
      print("onTokenRefresh failed: ${error.toString()}");
    });

    // Listen for incoming messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received message: ${message.notification?.title}');
      MptCallKitController().refreshRegister();
      // Handle message
    });

    // Listen for notifications when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from notification: ${message.notification?.title}');
      // Handle message
      // When app waked up from background, if has call incoming, register to SIP server
      // Attempt auto login when app is opened from notification
      print('Calling navigateAfterLogin from onMessageOpenedApp');
    });

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print(
            'App opened from terminated state: ${message.notification?.title}');
        // Handle message and auto login
        print('Calling navigateAfterLogin from getInitialMessage');
      }
    });
  }
}
