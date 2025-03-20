import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';

class CallPad extends StatefulWidget {
  const CallPad({
    super.key,
  });

  @override
  State<CallPad> createState() => _CallPadState();
}

class _CallPadState extends State<CallPad> {
  final List<String> _functionNames = [
    "answer",
    "reject",
    'hold',
    'unhold',
    'mute',
    'unmute',
    'cameraOn',
    'cameraOff',
    'hangup',
  ];

  String _callState = "";

  bool _isMuted = false;
  bool _isCameraOn = true;

  late StreamSubscription<String> _callStateSubscription;
  late StreamSubscription<bool> _microphoneStateSubscription;
  late StreamSubscription<bool> _cameraStateSubscription;

  @override
  void initState() {
    super.initState();

    // call state listener
    _callStateSubscription =
        MptCallKitController().callStateListener.listen((state) {
      setState(() {
        _callState = state;
      });

      // show dialog when call ended
      if (state == CallStateConstants.CLOSED ||
          state == CallStateConstants.FAILED) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && context.mounted) {
            _showCallEndedDialog(state);
          }
        });
      }
    });

    // microphone state listener
    _microphoneStateSubscription =
        MptCallKitController().microphoneStateListener.listen((isActive) {
      setState(() {
        _isMuted = !isActive; // true when microphone is off
      });
    });

    // camera state listener
    _cameraStateSubscription =
        MptCallKitController().cameraStateListener.listen((isActive) {
      setState(() {
        _isCameraOn = isActive; // true when camera is on
      });
    });
  }

  @override
  void dispose() {
    _callStateSubscription.cancel();
    _microphoneStateSubscription.cancel();
    _cameraStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, res) {
        if (!didPop) {
          _showEndCallConfirmDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Call Pad'),
          automaticallyImplyLeading: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _getCallStateColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Call State: ${_callState.isEmpty ? "IDLE" : _callState}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  'Microphone: ${_isMuted ? "OFF" : "ON"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Camera: ${_isCameraOn ? "ON" : "OFF"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _functionNames.length,
                  itemBuilder: (context, index) {
                    final functionName = _functionNames[index];

                    return ElevatedButton(
                      onPressed: () {
                        _executeToggleFunction(functionName);
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
      ),
    );
  }

  Color _getCallStateColor() {
    switch (_callState) {
      case CallStateConstants.CONNECTED:
        return Colors.green;
      case CallStateConstants.INCOMING:
        return Colors.blue;
      case CallStateConstants.TRYING:
        return Colors.orange;
      case CallStateConstants.FAILED:
        return Colors.red;
      case CallStateConstants.CLOSED:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _executeToggleFunction(String functionName) {
    print('Executing $functionName function');

    switch (functionName) {
      case 'answer':
        if (_callState == CallStateConstants.INCOMING) {
          MptCallKitController().answer();
        }
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
      case 'cameraOff':
        MptCallKitController().cameraOff();
        break;
      case 'cameraOn':
        MptCallKitController().cameraOn();
        break;
      case 'reject':
        MptCallKitController().reject();
        break;
      default:
        print('Function $functionName not implemented');
    }
  }

  void _showCallEndedDialog(String state) {
    String message =
        state == CallStateConstants.CLOSED ? "Call ended" : "Call failed";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                // Close dialog
                Navigator.of(context).pop();
                // Close call_pad screen
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showEndCallConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alert'),
        content: const Text('Do you want to end the call and go back?'),
        actions: [
          TextButton(
            onPressed: () {
              // Đóng dialog
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog
              Navigator.of(context).pop();

              // End call
              await MptCallKitController().hangup();

              // Go back to previous screen
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('End call'),
          ),
        ],
      ),
    );
  }
}
