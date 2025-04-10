import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

import '/login_method_view/login.dart';
import 'components/callkit_constants.dart';
import 'login_method_view/login_sso.dart';
import 'services/firebase_service.dart';

class LoginMethod extends StatefulWidget {
  const LoginMethod({Key? key}) : super(key: key);

  @override
  State<LoginMethod> createState() => _LoginMethodState();
}

class _LoginMethodState extends State<LoginMethod> {
  FirebaseService? _firebaseService;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initFirebaseService();
  }

  Future<void> _initFirebaseService() async {
    _firebaseService = FirebaseService();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _fcmToken = _firebaseService?.token;
    });
    print('FCM Token in LoginMethod: $_fcmToken');

    // Initialize SDK after getting FCM token
    MptCallKitController().initSdk(
      apiKey: CallkitConstants.API_KEY,
      baseUrl: CallkitConstants.BASE_URL,
      pushToken: _fcmToken,
      appId: CallkitConstants.APP_ID,
    );
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
