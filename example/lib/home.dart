import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_socket.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const baseUrl = "https://crm-dev-v2.metechvn.com";
  static const apiKey = "0c16d4aa-abe7-4098-b47a-7b914f9b7444";

  final TextEditingController _callTo = TextEditingController();

  connectChat() async {
    await MptSocket.connectSocket(
      baseUrl,
      guestAPI: '/integration/security/guest-token',
      barrierToken: apiKey,
      appId: '88888888',
      phoneNumber: widget.phoneNumber,
      userName: widget.name,
    );

    // if (widget.isFirstLogin == true) {
    //   ChatSocket.sendMessage(
    //       "Chat session is being connected from mobile", null);
    // }
  }

  @override
  void initState() {
    super.initState();
    _callTo.text = "88888888";
    connectChat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().initSdk(
            apiKey: apiKey,
            baseUrl: baseUrl,
            userPhoneNumber: widget.phoneNumber,
          );
          MptCallKitController().makeCall(
              context: context,
              phoneNumber: _callTo.text,
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                initialValue: widget.name,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  enabled: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                initialValue: widget.phoneNumber,
                keyboardType: TextInputType.none,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  enabled: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
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
          ],
        ),
      ),
    );
  }
}
