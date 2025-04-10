import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

import '/login_method.dart';
import 'components/callkit_constants.dart';
import 'services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _apiKey = CallkitConstants.API_KEY;
  final String _baseUrl = CallkitConstants.BASE_URL;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();
  FirebaseService? _firebaseService;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "200011";
    _callTo.text = "20015";
    _initFirebaseService();
  }

  Future<void> _initFirebaseService() async {
    _firebaseService = FirebaseService();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _fcmToken = _firebaseService?.token;
    });
    print('FCM Token in Home: $_fcmToken');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().initSdk(
            apiKey: _apiKey,
            baseUrl: _baseUrl,
            pushToken: _fcmToken,
            appId: CallkitConstants.APP_ID,
          );
          MptCallKitController().makeCallByGuest(
              context: context,
              userPhoneNumber: _phoneController.text,
              destinationPhoneNumber: _callTo.text,
              isVideoCall: true,
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
              child: const Text("Call with account"))
        ],
      ),
    );
  }
}
