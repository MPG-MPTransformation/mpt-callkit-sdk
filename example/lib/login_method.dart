import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/login_method_view/login.dart';
import 'components/callkit_constants.dart';
import 'login_method_view/login_sso.dart';

class LoginMethod extends StatefulWidget {
  const LoginMethod({super.key});

  @override
  State<LoginMethod> createState() => _LoginMethodState();
}

class _LoginMethodState extends State<LoginMethod> {
  String? _fcmToken;
  static const String _tokenKey = 'fcm_token';

  @override
  void initState() {
    super.initState();
    _loadFcmToken();
  }

  Future<void> _loadFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fcmToken = prefs.getString(_tokenKey);
    });
    print('FCM Token in LoginMethod: $_fcmToken');

    // Initialize SDK after getting FCM token
    // MptCallKitController().initSdk(
    //   apiKey: CallkitConstants.API_KEY,
    //   baseUrl: CallkitConstants.BASE_URL,
    //   pushToken: Platform.isAndroid ? _fcmToken : null,
    //   appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
    //   enableDebugLog: true,
    //   deviceInfo: "deviceInfo",
    //   recordLabel: "Khách hàng",
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login Method"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Choose a login method"),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Login(),
                  ),
                );
              },
              child: const Text("Login with account"),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginSSO(),
                  ),
                );
              },
              child: const Text("Login SSO"),
            ),
          ],
        ),
      ),
    );
  }
}
