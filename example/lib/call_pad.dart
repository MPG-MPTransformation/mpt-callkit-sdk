import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/extension_model.dart';

class CallPad extends StatefulWidget {
  const CallPad({
    super.key,
    required this.apiKey,
    required this.baseUrl,
    required this.ounboundNumber,
  });
  final String apiKey;
  final String baseUrl;
  final String ounboundNumber;

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

  final TextEditingController _destController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _destController.text = "20015";
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
                  controller: _destController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
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
        MptCallKitController().callMethod(
            context: context,
            destination: _destController.text,
            isVideoCall: true,
            onError: (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$e"),
                ),
              );
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
