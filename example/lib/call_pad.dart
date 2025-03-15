import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

class CallPad extends StatefulWidget {
  const CallPad({super.key, required this.apiKey, required this.baseUrl});
  final String apiKey;
  final String baseUrl;

  @override
  State<CallPad> createState() => _CallPadState();
}

class _CallPadState extends State<CallPad> {
  final List<String> _functionNames = [
    'call',
    'hangup',
    'hold',
    'unhold',
    'mute',
    'unmute',
    'cameraOn',
    'cameraOff',
    "reject",
  ];

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
      appBar: AppBar(
        title: const Text('Call Pad'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 9,
                itemBuilder: (context, index) {
                  final functionName = _functionNames[index];
                  return ElevatedButton(
                    onPressed: () {
                      // Execute the corresponding function
                      _executeFunction(functionName);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Center(
                      child: Text(
                        functionName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _executeFunction(String functionName) {
    print('Executing $functionName function');

    switch (functionName) {
      case 'call':
        MptCallKitController().initSdk(
          apiKey: widget.apiKey, // dev
          baseUrl: widget.baseUrl, // dev
          userPhoneNumber: _phoneController.text,
        );
        MptCallKitController().makeCall(
            context: context,
            phoneNumber: _callTo.text,
            isVideoCall: true,
            isShowNativeView: false,
            onError: (errorMessage) {
              if (errorMessage == null) return;
              var snackBar = SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.grey,
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            });
        break;
      case 'hangup':
        MptCallKitController().hangup();
        break;
      case 'hold':
        MptCallKitController().hold();
        break;
      case 'unhold':
        MptCallKitController().unhold();
        break;
      case 'mute':
        MptCallKitController().mute();
        break;
      case 'unmute':
        MptCallKitController().unmute();
        break;
      case 'cameraOn':
        MptCallKitController().cameraOn();
        break;
      case 'cameraOff':
        MptCallKitController().cameraOff();
        break;
      case 'reject':
        MptCallKitController().reject();
        break;
      default:
        print('Function $functionName not implemented');
    }
  }
}
