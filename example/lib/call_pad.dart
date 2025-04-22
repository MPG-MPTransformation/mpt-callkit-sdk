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
    'loudSpeakerOn',
    'loudSpeakerOff',
    'hangup',
  ];

  String _callState = "";

  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isOnHold = false;
  String _agentStatus = "";
  String _callType = "";
  String? _sessionId;

  // Thay thế các biến callerCameraState, calleeCameraState, callerMicState, calleeMicState
  bool _myCamState = true; // Trạng thái camera của người dùng hiện tại
  bool _myMicState = true; // Trạng thái mic của người dùng hiện tại
  bool _otherCamState = true; // Trạng thái camera của người khác
  bool _otherMicState = true; // Trạng thái mic của người khác
  final int _myUserId = MptCallKitController().currentUserInfo!["user"]
      ["id"]; // UserId của người dùng hiện tại

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

    // Giả định userId của người dùng hiện tại, có thể lấy từ hệ thống
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

        // Subscribe to media status channel when call is answered
        if (state == CallStateConstants.IN_CONFERENCE) {
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
          _myMicState =
              !isActive; // cập nhật trạng thái mic của người dùng hiện tại
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
          _myCamState =
              isActive; // cập nhật trạng thái camera của người dùng hiện tại
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
        print('Subscribing to event with sessionId: $_sessionId');

        // Subscribe to the socket event
        MptSocketSocketServer.subscribeToMediaStatusChannel((data) {
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
          print('Retrying subscribe to event with sessionId: $_sessionId');
          MptSocketSocketServer.subscribeToMediaStatusChannel((data) {
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

        // Kiểm tra tin nhắn có định dạng mới với agentId, cameraState, và mircroState
        if (data.containsKey('agentId') &&
            data.containsKey('cameraState') &&
            data.containsKey('mircroState')) {
          final messageUserId = data['agentId'];
          final cameraState = data['cameraState'] as bool;
          final micState = data['mircroState'] as bool;

          // Determine if the message is from the current user
          if (messageUserId == _myUserId) {
            // Message from the current user, update local status
            setState(() {
              _myCamState = cameraState;
              _myMicState = micState;
              _isCameraOn = cameraState;
              _isMuted = !micState; // _isMuted is true when mic is off
            });
            print('Updated my status: camera=$cameraState, mic=$micState');
          } else {
            // Message from other user, update their status
            setState(() {
              _otherCamState = cameraState;
              _otherMicState = micState;
            });
            print('Updated other status: camera=$cameraState, mic=$micState');
          }
        } else {
          print('Cannot recognize media message format');
        }
      }
    } catch (e) {
      print('Error processing media status message: $e');
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
                        'My Camera: ${_myCamState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'My Microphone: ${_myMicState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Other Camera: ${_otherCamState ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Other Microphone: ${_otherMicState ? "ON" : "OFF"}',
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
        MptSocketSocketServer.leaveCallMediaRoomChannel();
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
      case 'loudSpeakerOn':
        MptCallKitController().setSpeaker(enable: true);
        break;
      case 'loudSpeakerOff':
        MptCallKitController().setSpeaker(enable: false);
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
      // Tạo định dạng trạng thái media mới
      Map<String, dynamic> mediaStatus = {
        'agentId': _myUserId,
        'cameraState': _myCamState,
        'mircroState': _myMicState,
      };

      // Kiểm tra có thay đổi trạng thái so với lần gửi trước
      bool shouldSend = true;
      if (_lastSentMediaStatus != null) {
        bool hasChanges = false;
        mediaStatus.forEach((key, value) {
          // Nếu có bất kỳ giá trị nào thay đổi, cần gửi lại
          if (_lastSentMediaStatus![key] != value) {
            hasChanges = true;
          }
        });
        shouldSend = hasChanges;
      }

      if (shouldSend) {
        // Gửi tin nhắn sử dụng sự kiện Socket.IO
        await MptSocketSocketServer.instance
            .sendMediaStatusMessage(mediaStatus);

        // Lưu trạng thái đã gửi
        _lastSentMediaStatus = Map<String, dynamic>.from(mediaStatus);

        print('Updated media status: $mediaStatus');
      } else {
        print('Skipping media status update: $mediaStatus');
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
                MptSocketSocketServer.leaveCallMediaRoomChannel();

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
