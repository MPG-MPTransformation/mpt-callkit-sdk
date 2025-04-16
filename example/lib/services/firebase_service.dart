import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/callkit_constants.dart';
import '../login_result.dart';
import '../push_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔹 Background Message: ${message.data.toString()}');

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

  if (message.data['msg_title'] == "Received a new call.") {
    PushNotifications.showSimpleNotification(
        title: message.data['msg_title'] ?? "Thông báo mới",
        body: message.data['msg_content'] ?? "Nhấn để xem chi tiết",
        payload: message.data.toString());
  }
}

// GlobalKey để truy cập Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _tokenFCM = "";
  static const String _tokenKey = 'fcm_token';
  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';

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

  Future<bool> _autoLogin(BuildContext? context) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);

    if (username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty) {
      print('Auto login with saved credentials: $username');

      var result = await MptCallKitController().loginRequest(
        username: username,
        password: password,
        tenantId: CallkitConstants.TENANT_ID,
        baseUrl: CallkitConstants.BASE_URL,
        onError: (error) {
          print('Auto login failed: $error');
        },
      );

      if (result && context != null) {
        print('Auto login successful');

        // Chuyển hướng đến màn hình LoginResultScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginResultScreen(
              title: 'Login Successful',
              userData: MptCallKitController().userData,
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

      // Handle message
    });

    // Listen for notifications when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from notification: ${message.notification?.title}');
      // Handle message
      // When app waked up from background, if has call incoming, register to SIP server
      // Attempt auto login when app is opened from notification
      print('Calling navigateAfterLogin from onMessageOpenedApp');
      navigateAfterLogin();
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
        navigateAfterLogin();
      }
    });
  }

  // This method will be called when app is opened from background
  void navigateAfterLogin() async {
    print('======================================================');
    print('navigateAfterLogin: Token FCM: $_tokenFCM');
    print('======================================================');

    MptCallKitController().initSdk(
      apiKey: CallkitConstants.API_KEY,
      baseUrl: CallkitConstants.BASE_URL,
      pushToken: _tokenFCM,
      appId: CallkitConstants.ANDROID_APP_ID,
    );

    // Kiểm tra flag từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final shouldNavigate = prefs.getBool('navigate_from_notification') ?? false;
    final lastMessageData = prefs.getString('last_message_data');

    print('navigateAfterLogin: shouldNavigate = $shouldNavigate');
    print('navigateAfterLogin: lastMessageData = $lastMessageData');

    if (shouldNavigate) {
      print('Navigate from notification flag is true, resetting it');
      await prefs.setBool('navigate_from_notification', false);

      // Làm sạch dữ liệu thông báo sau khi đã sử dụng
      if (lastMessageData != null) {
        await prefs.remove('last_message_data');
      }
    }

    // Auto login with GlobalKey context
    if (navigatorKey.currentContext != null) {
      print('navigateAfterLogin: Context available, attempting auto login');
      await _autoLogin(navigatorKey.currentContext);
    } else if (shouldNavigate) {
      // Nếu không có context nhưng flag là true, ghi log để debug
      print(
          'No context available but navigation flag was set, waiting for context');

      // Cố gắng đợi và kiểm tra context sau một khoảng thời gian
      Future.delayed(const Duration(seconds: 2), () {
        if (navigatorKey.currentContext != null) {
          print('Context now available after delay, attempting auto login');
          _autoLogin(navigatorKey.currentContext);
        } else {
          print(
              'Still no context available after delay, trying one more time with longer delay');
          // Thử thêm lần nữa với delay dài hơn
          Future.delayed(const Duration(seconds: 5), () {
            if (navigatorKey.currentContext != null) {
              print(
                  'Context available after longer delay, attempting auto login');
              _autoLogin(navigatorKey.currentContext);
            } else {
              print('Still no context available after longer delay, giving up');
            }
          });
        }
      });
    } else {
      // If no context, do nothing
      print('Auto login executed but no navigator available for routing');
    }
  }
}
