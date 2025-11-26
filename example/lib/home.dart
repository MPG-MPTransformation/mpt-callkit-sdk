import 'dart:io';

import 'package:example/login_res_tabviews/video_view.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/login_method.dart';
import 'components/callkit_constants.dart';
import 'login_result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _apiKey = CallkitConstants.API_KEY;
  final String _baseUrl = CallkitConstants.BASE_URL;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();
  final TextEditingController _extraInfo = TextEditingController();
  String? _fcmToken;
  static const String _tokenKey = 'fcm_token';

  @override
  void initState() {
    super.initState();
    _phoneController.text = "200011";
    _callTo.text = "20015";
    _extraInfo.text = "extraInfo";
    _loadFcmToken();
    _checkSavedCredentials();
  }

  Future<void> _loadFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fcmToken = prefs.getString(_tokenKey);
    });
    print('FCM Token in Home: $_fcmToken');
  }

  Future<void> _checkSavedCredentials() async {
    await autoLogin(context);
  }

  // Auto login with saved credentials - Login by account and password
  Future<bool> autoLogin(BuildContext? context) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("saved_access_token");

    if (accessToken != null && accessToken.isNotEmpty) {
      print('Auto login with saved credentials: $accessToken');

      await MptCallKitController().initSdk(
        apiKey: CallkitConstants.API_KEY,
        baseUrl: CallkitConstants.BASE_URL,
        pushToken: Platform.isAndroid ? prefs.getString(_tokenKey) : null,
        appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
        enableDebugLog: true,
        deviceInfo: "deviceInfo",
        recordLabel: "",
        enableBlurBackground: true,
        bgPath:
            "https://s3-sgn09.fptcloud.com/ict-mvno/Background_eho_mvno.png",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return const VideoView(
              isGuest: true,
            );
          }));
          await MptCallKitController().initSdk(
            apiKey: _apiKey,
            baseUrl: _baseUrl,
            // pushToken: Platform.isAndroid ? _fcmToken : null,
            // appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
            enableDebugLog: true,
            deviceInfo: "deviceInfo",
            recordLabel: "",
            enableBlurBackground: false,
          );
          await MptCallKitController().makeCallByGuest(
              context: context,
              userPhoneNumber: _phoneController.text,
              destination: _callTo.text,
              isVideoCall: true,
              // extraInfo: _extraInfo.text,
              extraInfo: "{'requestId': 'requestId', 'name': '', 'gender': ''}",
              onError: (errorMessage) {
                if (errorMessage == null) return;
                var snackBar = SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.grey,
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              });
        },
        child: const Icon(Icons.call),
      ),
      appBar: AppBar(
        title: const Text("Mpt Callkit SDK demo"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _callTo,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Call to',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _extraInfo,
              decoration: const InputDecoration(
                labelText: 'Extra Info',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Text(
            'Click button to make a call',
          ),
          const SizedBox(height: 30),
          const Text("OR"),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return const LoginMethod();
                }));
              },
              child: const Text("Call with account")),
          OutlinedButton(
              onPressed: () {
                print(
                    "Latest extension number: ${MptCallKitController().lastesExtensionData?.username.toString()}");
              },
              child: const Text("Get latest extension data"))
        ],
      ),
    );
  }
}
