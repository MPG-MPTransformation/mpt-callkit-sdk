import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:mpt_callkit/views/local_view.dart';
import 'package:mpt_callkit/views/remote_view.dart';

class CallPad extends StatefulWidget {
  const CallPad({Key? key}) : super(key: key);

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
  bool _isOnHold = false;
  String _agentStatus = "";

  late StreamSubscription<String> _callStateSubscription;
  late StreamSubscription<String> _agentStatusSubscription;
  late StreamSubscription<bool> _microphoneStateSubscription;
  late StreamSubscription<bool> _cameraStateSubscription;
  late StreamSubscription<bool> _holdCallStateSubscription;

  @override
  void initState() {
    super.initState();

    // call state listener
    _callStateSubscription = MptCallKitController().callEvent.listen((state) {
      if (mounted) {
        setState(() {
          _callState = state;
        });

        // show dialog when call ended
        if (state == CallStateConstants.CLOSED ||
            state == CallStateConstants.FAILED) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showCallEndedDialog(state);
            }
          });
        }
      }
    });

    // microphone state listener
    _microphoneStateSubscription =
        MptCallKitController().microState.listen((isActive) {
      if (mounted) {
        setState(() {
          _isMuted = isActive; // true when microphone is off
        });
      }
    });

    // camera state listener
    _cameraStateSubscription =
        MptCallKitController().cameraState.listen((isActive) {
      if (mounted) {
        setState(() {
          _isCameraOn = isActive; // true when camera is on
        });
      }
    });

    // agent status listener
    _agentStatusSubscription =
        MptSocketSocketServer.agentStatusEvent.listen((status) {
      if (mounted) {
        setState(() {
          _agentStatus = status;
        });
      }
    });

    // hold call state listener
    _holdCallStateSubscription =
        MptCallKitController().holdCallState.listen((isOnHold) {
      if (mounted) {
        setState(() {
          _isOnHold = isOnHold;
        });
      }
    });
  }

  @override
  void dispose() {
    _callStateSubscription.cancel();
    _microphoneStateSubscription.cancel();
    _cameraStateSubscription.cancel();
    _agentStatusSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showEndCallConfirmDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Call Pad'),
          automaticallyImplyLeading: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
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
                Text(
                  'Hold Call: $_isOnHold',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Agent Status: ${_agentStatus.isEmpty ? "OFFLINE" : _agentStatus}',
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
                const SizedBox(height: 16),
                const Text("Camera"),
                const SizedBox(
                  height: 300,
                  width: 300,
                  child: LocalView(),
                ),
                const SizedBox(height: 16),
                const Text("Video"),
                const SizedBox(
                  height: 300,
                  width: 300,
                  child: RemoteView(),
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
        MptCallKitController().answerCall();
        break;
      case 'hangup':
        MptCallKitController().hangup();
        // Close call_pad screen
        Navigator.of(context).pop();
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
        MptCallKitController().rejectCall();
        break;
      case 'switchCamera':
        MptCallKitController().switchCamera();
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
              // Close dialog
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // End call
              MptCallKitController().hangup();

              // Go back to previous screen
              // Close dialog
              Navigator.of(context).pop();
              // Close call_pad screen
              Navigator.of(context).pop();
            },
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ),
            child: const Text('End call'),
          ),
        ],
      ),
    );
  }
}
