import 'dart:async';
import 'dart:convert';

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
  String _callType = "";
  String? _sessionId;

  // Trạng thái media của cả caller và callee
  bool _callerCameraState = true;
  bool _calleeCameraState = true;
  bool _callerMicState = true;
  bool _calleeMicState = true;

  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _agentStatusSubscription;
  StreamSubscription<bool>? _microphoneStateSubscription;
  StreamSubscription<bool>? _cameraStateSubscription;
  StreamSubscription<bool>? _holdCallStateSubscription;
  StreamSubscription<String>? _callTypeSubscription;

  // Biến theo dõi trạng thái gửi đi gần nhất
  Map<String, dynamic>? _lastSentMediaStatus;

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

        // Subscribe to media status channel when call is connected
        if (state == CallStateConstants.CONNECTED) {
          _subscribeToMediaStatusChannel();
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

        // Gửi trạng thái mới khi microphone thay đổi
        _sendMediaStatus();
      }
    });

    // camera state listener
    _cameraStateSubscription =
        MptCallKitController().cameraState.listen((isActive) {
      if (mounted) {
        setState(() {
          _isCameraOn = isActive; // true when camera is on
        });

        // Gửi trạng thái mới khi camera thay đổi
        _sendMediaStatus();
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

    _callTypeSubscription = MptCallKitController().callType.listen((type) {
      if (mounted) {
        setState(() {
          _callType = type;
        });
      }
    });
  }

  // Subscribe to media status channel
  Future<void> _subscribeToMediaStatusChannel() async {
    try {
      // Get session ID from MptSocketSocketServer
      _sessionId = MptSocketSocketServer.currentSessionId;

      if (_sessionId != null && _sessionId!.isNotEmpty) {
        print('Subscribing to event: call_media_status_$_sessionId');

        // Subscribe to the socket event
        MptSocketSocketServer.subscribeToEventStatic(
            'call_media_status_$_sessionId', (data) {
          print('Received media status message: $data');
          _handleMediaStatusMessage(data);
        });
      } else {
        print(
            'Cannot subscribe to media status event: sessionId is null or empty');

        // If there's no sessionId, wait 1s and check again
        await Future.delayed(const Duration(seconds: 1));
        _sessionId = MptSocketSocketServer.currentSessionId;

        if (_sessionId != null && _sessionId!.isNotEmpty) {
          print('Retrying subscribe to event: call_media_status_$_sessionId');
          MptSocketSocketServer.subscribeToEventStatic(
              'call_media_status_$_sessionId', (data) {
            print('Received media status message: $data');
            _handleMediaStatusMessage(data);
          });
        } else {
          print('Still cannot get sessionId after retry');
        }
      }
    } catch (e) {
      print('Error subscribing to media status event: $e');
    }
  }

  // Handle media status message
  void _handleMediaStatusMessage(dynamic messageData) {
    try {
      // Parse message data
      Map<dynamic, dynamic>? data;
      if (messageData is Map) {
        data = messageData;
      } else if (messageData is String) {
        data = Map<String, dynamic>.from(jsonDecode(messageData));
      }

      if (data != null) {
        // Process media status message based on your app's requirements
        print('Media status data: $data');

        //
        bool isCaller = _callType == CallTypeConstants.OUTGOING_CALL;

        // Variables to store the state of the remote device
        bool? remoteCamera;
        bool? remoteMic;

        // Handle camera state
        if (data.containsKey('callerCameraState') &&
            data['callerCameraState'] != null) {
          bool callerCameraState = data['callerCameraState'] as bool;
          setState(() {
            _callerCameraState = callerCameraState;
          });
          print('Caller camera state: $callerCameraState');
          if (!isCaller) {
            // If the current device is callee, update the camera state of the caller
            remoteCamera = callerCameraState;
          }
        }

        if (data.containsKey('calleeCameraState') &&
            data['calleeCameraState'] != null) {
          bool calleeCameraState = data['calleeCameraState'] as bool;
          setState(() {
            _calleeCameraState = calleeCameraState;
          });
          print('Callee camera state: $calleeCameraState');
          if (isCaller) {
            // If the current device is caller, update the camera state of the callee
            remoteCamera = calleeCameraState;
          }
        }

        if (data.containsKey('callerMicState') &&
            data['callerMicState'] != null) {
          bool callerMicState = data['callerMicState'] as bool;
          setState(() {
            _callerMicState = callerMicState;
          });
          print('Caller microphone state: $callerMicState');
          if (!isCaller) {
            // If the current device is callee, update the microphone state of the caller
            remoteMic = callerMicState;
          }
        }

        if (data.containsKey('calleeMicState') &&
            data['calleeMicState'] != null) {
          bool calleeMicState = data['calleeMicState'] as bool;
          setState(() {
            _calleeMicState = calleeMicState;
          });
          print('Callee microphone state: $calleeMicState');
          if (isCaller) {
            // If the current device is caller, update the microphone state of the callee
            remoteMic = calleeMicState;
          }
        }
      }
    } catch (e) {
      print('Error handling media status message: $e');
    }
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _microphoneStateSubscription?.cancel();
    _cameraStateSubscription?.cancel();
    _agentStatusSubscription?.cancel();
    _holdCallStateSubscription?.cancel();
    _callTypeSubscription?.cancel();

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
                        'Caller Camera: ${_callerCameraState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Caller Microphone: ${_callerMicState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Callee Camera: ${_calleeCameraState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Callee Microphone: ${_calleeMicState ? "ON" : "OFF"}',
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
      default:
        print('Function $functionName not implemented');
    }
  }

  // Send media status to socket event
  Future<void> _sendMediaStatus() async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      print('Cannot send media status: sessionId is null or empty');
      return;
    }

    try {
      // Determine the role of the device as caller or callee - for example based on callType
      bool isCaller = _callType == CallTypeConstants.OUTGOING_CALL;

      // Create new media status
      Map<String, dynamic> mediaStatus = {};

      // Only send the status of the current device
      if (isCaller) {
        mediaStatus['callerCameraState'] = _isCameraOn;
        mediaStatus['callerMicState'] =
            !_isMuted; // _isMuted = true when mic is off
      } else {
        mediaStatus['calleeCameraState'] = _isCameraOn;
        mediaStatus['calleeMicState'] = !_isMuted;
      }

      // Check if there is a change in the state compared to the previous send
      bool shouldSend = true;
      if (_lastSentMediaStatus != null) {
        bool hasChanges = false;
        mediaStatus.forEach((key, value) {
          // If any value changes, need to send again
          if (_lastSentMediaStatus![key] != value) {
            hasChanges = true;
          }
        });
        shouldSend = hasChanges;
      }

      if (shouldSend) {
        // Send message using Socket.IO event
        await MptSocketSocketServer.instance
            .sendMessage('call_media_status_$_sessionId', mediaStatus);

        // Save the sent state
        _lastSentMediaStatus = Map<String, dynamic>.from(mediaStatus);

        print('Sent media status update: $mediaStatus');
      } else {
        print('Skip sending identical media status: $mediaStatus');
      }
    } catch (e) {
      print('Error sending media status: $e');
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
