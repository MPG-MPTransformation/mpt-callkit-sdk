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
    'speakerLoud',
    'speakerEarphone',
    // 'speakerBluetooth',
    // 'speakerWiredHeadset',
    // 'getAudioDevices',
    'hangup',
  ];

  String _callState = MptCallKitController().currentCallState ?? "IDLE";

  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isOnHold = false;
  String _agentStatus = "";

  // Media states using the controller's values
  bool _localCamState = true;
  bool _localMicState = true;
  bool _remoteCamState = true;
  bool _remoteMicState = true;

  String _currentAudioDevice = MptCallKitController().currentAudioDevice ?? "";

  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _agentStatusSubscription;
  StreamSubscription<bool>? _microphoneStateSubscription;
  StreamSubscription<bool>? _cameraStateSubscription;
  StreamSubscription<bool>? _holdCallStateSubscription;
  StreamSubscription<String>?
      _currentAudioDeviceSubscription; // Thêm subscription cho currentAudioDeviceStream

  // New subscriptions for media states
  StreamSubscription<bool>? _localCamStateSubscription;
  StreamSubscription<bool>? _localMicStateSubscription;
  StreamSubscription<bool>? _remoteCamStateSubscription;
  StreamSubscription<bool>? _remoteMicStateSubscription;

  @override
  void initState() {
    super.initState();

    // call state listener
    _callStateSubscription = MptCallKitController().callEvent.listen((state) {
      if (mounted) {
        setState(() {
          _callState = state;
        });

        if (_callState == CallStateConstants.CONNECTED) {
          MptCallKitController().subscribeToMediaStatusChannel();
        }

        // show dialog when call ended
        if (state == CallStateConstants.CLOSED ||
            state == CallStateConstants.FAILED) {
          Future.delayed(const Duration(milliseconds: 500), () {
            MptCallKitController().leaveCallMediaRoomChannel();

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
          _localMicState = !isActive; // update local microphone state
        });

        // Update controller's microphone state
        MptCallKitController().updateLocalMicrophoneState(!isActive);
      }
    });

    // camera state listener
    _cameraStateSubscription =
        MptCallKitController().cameraState.listen((isActive) {
      if (mounted) {
        setState(() {
          _isCameraOn = isActive; // true when camera is on
          _localCamState = isActive; // update local camera state
        });

        // Update controller's camera state
        MptCallKitController().updateLocalCameraState(isActive);
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

    // Listen to media state changes from controller
    _localCamStateSubscription =
        MptCallKitController().localCamStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _localCamState = state;
        });
      }
    });

    _localMicStateSubscription =
        MptCallKitController().localMicStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _localMicState = state;
        });
      }
    });

    _remoteCamStateSubscription =
        MptCallKitController().remoteCamStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _remoteCamState = state;
        });
      }
    });

    _remoteMicStateSubscription =
        MptCallKitController().remoteMicStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _remoteMicState = state;
        });
      }
    });

    // Lắng nghe sự kiện thay đổi thiết bị âm thanh
    _currentAudioDeviceSubscription =
        MptCallKitController().currentAudioDeviceStream.listen((deviceName) {
      if (mounted) {
        setState(() {
          _currentAudioDevice = deviceName;
        });
      }
    });
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _microphoneStateSubscription?.cancel();
    _cameraStateSubscription?.cancel();
    _agentStatusSubscription?.cancel();
    _holdCallStateSubscription?.cancel();
    _localCamStateSubscription?.cancel();
    _localMicStateSubscription?.cancel();
    _remoteCamStateSubscription?.cancel();
    _remoteMicStateSubscription?.cancel();
    _currentAudioDeviceSubscription
        ?.cancel(); // Hủy subscription khi widget bị dispose

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
                Text(
                  'Current Audio Device: $_currentAudioDevice',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local Camera: ${_localCamState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Local Microphone: ${_localMicState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remote Camera: ${_remoteCamState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remote Microphone: ${_remoteMicState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
        MptCallKitController().leaveCallMediaRoomChannel();
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
      case 'speakerLoud': // loa ngoài
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.SPEAKER_PHONE);
        break;
      case 'speakerEarphone': // loa nhỏ
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.EARPIECE);
        break;
      // case 'speakerBluetooth': // bluetooth
      //   MptCallKitController()
      //       .setSpeaker(state: SpeakerStatusConstants.BLUETOOTH);
      //   break;
      // case 'speakerWiredHeadset': // tai nghe dây cắm
      //   MptCallKitController()
      //       .setSpeaker(state: SpeakerStatusConstants.WIRED_HEADSET);
      //   break;
      // case 'getAudioDevices':
      //   MptCallKitController().getAudioDevices();
      //   break;
      case 'reject':
        MptCallKitController().rejectCall();
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
