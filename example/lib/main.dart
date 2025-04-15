import 'package:example1/push_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/home.dart';
import 'services/firebase_service.dart';

const String _tokenKey = 'fcm_token';

Future<void> _saveTokenToLocal(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tokenKey, token);
  print('Saved FCM token to local storage');
}

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // // Initialize Firebase
  // await Firebase.initializeApp();
  // FirebaseService firebaseService = FirebaseService();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  PushNotifications.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // String payloadData = jsonEncode(message.data);
    print("Got a message in foreground" + message.data.toString());
    PushNotifications.showSimpleNotification(
        title: message.data['msg_title'],
        body: message.data['msg_content'],
        payload: message.data.toString());

    // Handle message
  });

  // Listen for notifications when app is opened from background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened from notification: ${message.data.toString()}');
  });

  FirebaseMessaging.instance.getToken().then((token) {
    print('Device Token FCM: $token');
    if (token != null) {
      _saveTokenToLocal(token);
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    print('FCM Token refresh: $token');
    _saveTokenToLocal(token);
  }).onError((error) {
    print("onTokenRefresh failed: ${error.toString()}");
  });

  runApp(const MyApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔹 Background Message: ${message.data.toString()}');
  PushNotifications.showSimpleNotification(
      title: message.data['msg_title'],
      body: message.data['msg_content'],
      payload: message.data.toString());
  // Lưu vào SharedPreferences hoặc gửi qua IsolatePort nếu muốn
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
