import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

class CallInNativeView extends StatefulWidget {
  const CallInNativeView({
    super.key,
    required this.apiKey,
    required this.baseUrl,
  });
  final String apiKey;
  final String baseUrl;

  @override
  State<CallInNativeView> createState() => _CallInNativeViewState();
}

class _CallInNativeViewState extends State<CallInNativeView> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = "200011";
    _callTo.text = "20015";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().initSdk(
            apiKey: widget.apiKey,
            baseUrl: widget.baseUrl,
            userPhoneNumber: _phoneController.text,
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
      appBar: AppBar(
        title: const Text("Call in native view"),
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
        ],
      ),
    );
  }
}
