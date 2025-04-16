import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotifications {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isLocalNotificationInitialized = false;

  // request notification permission
  static Future init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications first
    await localNotiInit();

    getFCMToken();
  }

// get the fcm device token
  static Future getFCMToken({int maxRetires = 3}) async {
    try {
      String? token;
      if (kIsWeb) {
        // get the device fcm token
        token = await _firebaseMessaging.getToken(
            vapidKey:
                "BJzRufH-VxRc7wLunA6WOaf-gVurFKhDluPRFB8644PQHw6OfWH8uzybtYsFBTA326_yy3PEG-L7OK_ojVsMmrI");
        print("for web device token: $token");
      } else {
        // get the device fcm token
        token = await _firebaseMessaging.getToken();
        print("for android device token: $token");
      }
      return token;
    } catch (e) {
      print("failed to get device token");
      if (maxRetires > 0) {
        print("try after 10 sec");
        await Future.delayed(const Duration(seconds: 10));
        return getFCMToken(maxRetires: maxRetires - 1);
      } else {
        return null;
      }
    }
  }

// initalize local notifications
  static Future localNotiInit() async {
    try {
      // Create notification channel for Android 8.0+
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description:
            'This channel is used for important notifications', // description
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        onDidReceiveLocalNotification: (id, title, body, payload) => null,
      );
      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Open notification');
      final InitializationSettings initializationSettings =
          InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsDarwin,
              linux: initializationSettingsLinux);

      // Đăng ký callback cho foreground và background notification tap
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
          print(
              "Notification tapped with payload: ${notificationResponse.payload}");
        },
        onDidReceiveBackgroundNotificationResponse:
            (NotificationResponse notificationResponse) {
          print(
              "Notification tapped with payload: ${notificationResponse.payload}");
        },
      );

      print(
          "Local notification callbacks registered: onDidReceiveNotificationResponse & notificationTapBackground");

      // Create the channel on Android devices
      if (!kIsWeb && !Platform.isIOS && !Platform.isMacOS) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        print("Android notification channel created successfully");
      }

      _isLocalNotificationInitialized = true;
      print("Local notifications initialized successfully");
    } catch (e) {
      print("Error initializing local notifications: $e");
      _isLocalNotificationInitialized = false;
    }
  }

  // show a simple notification
  static Future<bool> showSimpleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      // Ensure local notifications are initialized
      if (!_isLocalNotificationInitialized) {
        print("Local notifications not initialized. Initializing now...");
        await localNotiInit();
      }

      // Use a unique identifier for each notification
      final int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);

      await _flutterLocalNotificationsPlugin.show(
          notificationId, title, body, notificationDetails,
          payload: payload);

      print("Notification shown successfully with ID: $notificationId");
      return true;
    } catch (e) {
      print("Error showing notification: $e");
      return false;
    }
  }
}
