import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:mpt_callkit/views/local_view.dart';
import 'package:mpt_callkit/views/remote_view.dart';

import 'call/call_media_manager.dart';

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

  // Trạng thái media của đối phương
  bool _remoteUserMicEnabled = true;
  bool _remoteUserCameraEnabled = true;

  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _agentStatusSubscription;
  StreamSubscription<bool>? _microphoneStateSubscription;
  StreamSubscription<bool>? _cameraStateSubscription;
  StreamSubscription<bool>? _holdCallStateSubscription;
  StreamSubscription<String>? _callTypeSubscription;

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
          // Xóa dữ liệu trạng thái media khi kết thúc cuộc gọi
          CallMediaManager.clearCallData();

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
        MptCallKitController().microState.listen((isActive) async {
      if (mounted) {
        setState(() {
          _isMuted = isActive; // true when microphone is off
        });

        // Cập nhật trạng thái micro lên kênh (không phát âm = true, phát âm = false)
        final success =
            await CallMediaManager.updateMicrophoneStatus(!isActive);
        print(
            "Local microphone state changed: ${!isActive ? 'ON' : 'OFF'}, Socket update: ${success ? 'Success' : 'Failed'}");
      }
    });

    // camera state listener
    _cameraStateSubscription =
        MptCallKitController().cameraState.listen((isActive) async {
      if (mounted) {
        setState(() {
          _isCameraOn = isActive; // true when camera is on
        });

        // Cập nhật trạng thái camera lên kênh
        final success = await CallMediaManager.updateCameraStatus(isActive);
        print(
            "Local camera state changed: ${isActive ? 'ON' : 'OFF'}, Socket update: ${success ? 'Success' : 'Failed'}");
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

    _callTypeSubscription =
        MptCallKitController().callType.listen((type) async {
      if (mounted) {
        setState(() {
          _callType = type;
        });

        // Lấy sessionId từ MptSocketSocketServer nếu có, hoặc tạo mới nếu chưa có
        final String sessionId = MptSocketSocketServer.currentSessionId ??
            DateTime.now().millisecondsSinceEpoch.toString();

        // Xác định loại cuộc gọi (đi hay đến)
        final String mediaCallType = type == CallTypeConstants.OUTGOING_CALL
            ? MediaCallType.OUTGOING_CALL
            : MediaCallType.INCOMING_CALL;

        print(
            "Initializing CallMediaManager with sessionId: $sessionId, callType: $mediaCallType");

        // Khởi tạo CallMediaManager và đợi kết quả
        final success = await CallMediaManager.initializeCall(
            sessionId: sessionId, callType: mediaCallType);

        if (success) {
          print("CallMediaManager initialized successfully");
          // Chỉ lắng nghe cập nhật nếu khởi tạo thành công
          _listenForRemoteMediaUpdates();
        } else {
          print("Failed to initialize CallMediaManager");
        }
      }
    });
  }

  void _listenForRemoteMediaUpdates() {
    CallMediaManager.subscribeToMediaUpdates((mediaData) {
      if (CallMediaManager.isCurrentUserCaller()) {
        bool? calleeMicEnabled = mediaData['calleeMicEnabled'];
        bool? calleeCameraEnabled = mediaData['calleeCameraEnabled'];

        if (calleeMicEnabled != null) {
          setState(() {
            _remoteUserMicEnabled = calleeMicEnabled;
          });
          print("Callee Mic status: $calleeMicEnabled");
        }

        if (calleeCameraEnabled != null) {
          setState(() {
            _remoteUserCameraEnabled = calleeCameraEnabled;
          });
          print("Callee camera status: $calleeCameraEnabled");
        }
      } else {
        bool? callerMicEnabled = mediaData['callerMicEnabled'];
        bool? callerCameraEnabled = mediaData['callerCameraEnabled'];

        if (callerMicEnabled != null) {
          setState(() {
            _remoteUserMicEnabled = callerMicEnabled;
          });
          print("Caller mic status: $callerMicEnabled");
        }

        if (callerCameraEnabled != null) {
          setState(() {
            _remoteUserCameraEnabled = callerCameraEnabled;
          });
          print("Caller camera status: $callerCameraEnabled");
        }
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
                // Hiển thị trạng thái mic và camera của đối phương
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Remote User Microphone: ${_remoteUserMicEnabled ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remote User Camera: ${_remoteUserCameraEnabled ? "ON" : "OFF"}',
                        style: const TextStyle(
                          fontSize: 16,
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
                ElevatedButton(
                    onPressed: () {
                      switchCamera();
                    },
                    child: const Icon(Icons.flip_camera_ios_outlined)),
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

  void _executeToggleFunction(String functionName) async {
    print('Executing $functionName function');

    switch (functionName) {
      case 'answer':
        await MptCallKitController().answerCall();
        break;
      case 'hangup':
        await MptCallKitController().hangup();

        break;
      case 'hold':
        MptCallKitController().hold();

        break;
      case 'unhold':
        await MptCallKitController().unhold();

        break;
      case 'mute':
        final result = await MptCallKitController().mute();
        if (result) {
          // Cập nhật trạng thái micro lên socket channel khi mute thành công
          CallMediaManager.updateMicrophoneStatus(false);
          print('Microphone muted successfully and status updated to socket');
        }
        break;
      case 'unmute':
        final result = await MptCallKitController().unmute();
        if (result) {
          // Cập nhật trạng thái micro lên socket channel khi unmute thành công
          CallMediaManager.updateMicrophoneStatus(true);
          print('Microphone unmuted successfully and status updated to socket');
        }
        break;
      case 'cameraOff':
        final result = await MptCallKitController().cameraOff();
        if (result) {
          // Cập nhật trạng thái camera lên socket channel khi tắt thành công
          CallMediaManager.updateCameraStatus(false);
          print('Camera turned off successfully and status updated to socket');
        }
        break;
      case 'cameraOn':
        final result = await MptCallKitController().cameraOn();
        if (result) {
          // Cập nhật trạng thái camera lên socket channel khi bật thành công
          CallMediaManager.updateCameraStatus(true);
          print('Camera turned on successfully and status updated to socket');
        }
        break;
      case 'reject':
        await MptCallKitController().rejectCall();

        break;
      default:
        print('Function $functionName not implemented');
    }
  }

  void _showCallEndedDialog(String state) {
    String message =
        state == CallStateConstants.CLOSED ? "Call ended" : "Call failed";

    // Xóa dữ liệu trạng thái media
    CallMediaManager.clearCallData();
    // Xóa sessionId từ socket
    MptSocketSocketServer.clearCurrentSessionId();

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
              // Xóa dữ liệu trạng thái media
              CallMediaManager.clearCallData();
              // Xóa sessionId từ socket
              MptSocketSocketServer.clearCurrentSessionId();

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

  void switchCamera() async {
    final result = await MptCallKitController().switchCamera();

    // Đảm bảo camera vẫn bật sau khi chuyển đổi (nếu đang bật)
    if (result && _isCameraOn) {
      final updateResult = CallMediaManager.updateCameraStatus(true);
      print(
          'Camera switched successfully. Socket update result: $updateResult');
    }
  }
}
