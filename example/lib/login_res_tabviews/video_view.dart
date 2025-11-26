import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/models.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:mpt_callkit/views/local_view.dart';
import 'package:mpt_callkit/views/remote_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoView extends StatefulWidget {
  final bool? isGuest;
  const VideoView({super.key, this.isGuest = false});

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  String _callState = MptCallKitController().currentCallState ?? "IDLE";

  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isOnHold = false;
  final bool _isConference = false;

  // Media states using the controller's values
  bool _localCamState = true;
  bool _localMicState = true;
  bool _remoteCamState = true;

  String _currentAudioDevice = MptCallKitController().currentAudioDevice ?? "";

  CallEventSocketRecv _callEventSocketData = CallEventSocketRecv();

  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<Map<String, String>>? _callExtraInfoSubscription;
  StreamSubscription<bool>? _microphoneStateSubscription;
  StreamSubscription<bool>? _cameraStateSubscription;
  StreamSubscription<bool>? _holdCallStateSubscription;
  StreamSubscription<String>?
      _currentAudioDeviceSubscription; // Thêm subscription cho currentAudioDeviceStream
  StreamSubscription<bool>? _calleeAnswerSubscription;
  StreamSubscription<CallEventSocketRecv>? _callEventSocketSubscription;

  // New subscriptions for media states
  StreamSubscription<bool>? _localCamStateSubscription;
  StreamSubscription<bool>? _localMicStateSubscription;
  StreamSubscription<bool>? _remoteCamStateSubscription;
  StreamSubscription<bool>? _remoteMicStateSubscription;

  final TextEditingController inviteExtensionController =
      TextEditingController();

  // SIP ping subscription
  StreamSubscription<int?>? _sipPingSubscription;
  int? _pingTime;

  // is remote video received subscription
  var callStatusCode = -999;

  // Save ScaffoldMessenger reference
  ScaffoldMessengerState? _scaffoldMessenger;

  // Local view position for dragging
  Offset _localViewPosition = const Offset(20, 100);
  final double _localViewWidth = 120;
  final double _localViewHeight = 160;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save ScaffoldMessenger reference for safe access after disposal
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    _callEventSocketData =
        MptSocketSocketServer.instance.currentCallEventSocketData ??
            CallEventSocketRecv();

    _callEventSocketSubscription =
        MptSocketSocketServer.callEvent.listen((callEvent) {
      if (mounted) {
        setState(() {
          _callEventSocketData = callEvent;
          print("Call Event Data: ${_callEventSocketData.toJson()}");
        });
      }
    });

    // call state listener
    _callStateSubscription = MptCallKitController().callEvent.listen((state) {
      if (mounted) {
        setState(() {
          _callState = state;
        });

        if (_callState == CallStateConstants.INCOMING) {}

        // show dialog when call ended
        if (state == CallStateConstants.CLOSED ||
            state == CallStateConstants.FAILED) {
          // Future.delayed(const Duration(milliseconds: 500), () {
          //   if (mounted) {
          //     _showCallEndedDialog(state);
          //   }
          // });
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
          print("local microphone state: $isActive");
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

    _remoteCamStateSubscription =
        MptCallKitController().remoteCamStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _remoteCamState = state;
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

    // SIP ping listener
    _sipPingSubscription =
        MptCallKitController().sipPingStream.listen((pingTime) {
      if (mounted) {
        setState(() {
          _pingTime = pingTime;
        });
      }
    });
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _microphoneStateSubscription?.cancel();
    _cameraStateSubscription?.cancel();
    _callExtraInfoSubscription?.cancel();
    _holdCallStateSubscription?.cancel();
    _localCamStateSubscription?.cancel();
    _localMicStateSubscription?.cancel();
    _remoteCamStateSubscription?.cancel();
    _remoteMicStateSubscription?.cancel();
    _currentAudioDeviceSubscription
        ?.cancel(); // Hủy subscription khi widget bị dispose
    _calleeAnswerSubscription?.cancel();
    _callEventSocketSubscription?.cancel();
    _sipPingSubscription?.cancel();
    inviteExtensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Remote view - Full screen
          const Positioned.fill(
            child: RemoteView(),
          ),

          // Local view - Draggable
          Positioned(
            left: _localViewPosition.dx,
            top: _localViewPosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Update position with boundary checks
                  double newX = _localViewPosition.dx + details.delta.dx;
                  double newY = _localViewPosition.dy + details.delta.dy;

                  // Ensure the local view stays within screen bounds
                  newX = newX.clamp(0.0, screenSize.width - _localViewWidth);
                  newY = newY.clamp(0.0, screenSize.height - _localViewHeight);

                  _localViewPosition = Offset(newX, newY);
                });
              },
              child: Stack(
                children: [
                  Container(
                    width: _localViewWidth,
                    height: _localViewHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LocalView(),
                    ),
                  ),
                  // Switch camera button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          _executeToggleFunction('switchCamera');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.cameraswitch,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Optional: Add call controls at the bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute/Unmute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: _isMuted ? Colors.red : Colors.white,
            onPressed: () {
              if (_isMuted) {
                _executeToggleFunction('unmute');
              } else {
                _executeToggleFunction('mute');
              }
            },
          ),

          // Camera on/off button
          _buildControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            color: _isCameraOn ? Colors.white : Colors.red,
            onPressed: () {
              if (_isCameraOn) {
                _executeToggleFunction('cameraOff');
              } else {
                _executeToggleFunction('cameraOn');
              }
            },
          ),

          // // Switch camera button
          // _buildControlButton(
          //   icon: Icons.cameraswitch,
          //   color: Colors.white,
          //   onPressed: () {
          //     _executeToggleFunction('switchCamera');
          //   },
          // ),

          // Conference button
          _buildControlButton(
            icon: Icons.group_add,
            color: Colors.white,
            onPressed: () {
              _executeToggleFunction('inviteToConference');
            },
          ),

          // Speaker button
          _buildControlButton(
            icon: Icons.volume_up,
            color: Colors.white,
            onPressed: () {
              _executeToggleFunction('speakerLoud');
            },
          ),

          // Hangup button
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            backgroundColor: Colors.white,
            onPressed: () {
              _executeToggleFunction('hangup');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: backgroundColor ?? Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Icon(
            icon,
            color: color,
            size: 28,
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

  Future<void> _executeToggleFunction(String functionName) async {
    print('Executing $functionName function');

    switch (functionName) {
      case 'answer':
        var answerCode = await MptCallKitController().answerCall();
        setState(() {
          callStatusCode = answerCode;
        });
        break;
      case 'hangup':
        MptCallKitController().hangup();
        // if (widget.isGuest == false) {
        //   MptCallKitController().leaveCallMediaRoomChannel();
        // }
        break;
      case 'endCallAPI':
        {
          final String sessionId =
              MptCallKitController().currentSessionId ?? "";
          final int agentId = int.parse(widget.isGuest == true
              ? MptCallKitController().lastesExtensionData?.username ?? '0'
              : MptCallKitController().currentUserInfo?['user']?['id']);

          if (sessionId.isEmpty) {
            if (_scaffoldMessenger != null) {
              _scaffoldMessenger!.showSnackBar(
                const SnackBar(
                  content:
                      Text('Không đủ dữ liệu: thiếu sessionId hoặc agentId'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            break;
          }

          await MptCallKitController().endCallAPI(
            sessionId: sessionId,
            agentId: agentId,
            onError: (err) {
              if (err == null) return;
              if (_scaffoldMessenger != null) {
                _scaffoldMessenger!.showSnackBar(
                  SnackBar(
                    content: Text(err),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );

          if (_scaffoldMessenger != null) {
            _scaffoldMessenger!.showSnackBar(
              const SnackBar(
                content: Text('Đã gửi yêu cầu End Call API'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;
      case 'showAndroidCallKit':
        MptCallKitController().showAndroidCallKit();
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
      case 'switchCamera':
        MptCallKitController().switchCamera();
        break;
      case 'cameraOff':
        MptCallKitController().cameraOff();
        break;
      case 'cameraOn':
        MptCallKitController().cameraOn();
        break;
      /* -------------------------------------------------------------------------------
      Speaker:
        1. Với android: 
          - Nếu có tai nghe có dây đang được cắm thì đó là speaker duy nhất được chọn.
          - Nếu không có tai nghe có dây đang được cắm, sẽ có 3 lựa chọn speaker: loa nhỏ, loa ngoài và bluetooth.
        2. Với iOS:
          - Tai nghe bluetooth đang được kết nối thì đó là speaker duy nhất được chọn (Ẩn nút chọn bluetooth).
          - Nếu không có tai nghe bluetooth đang được kết nối, sẽ có 2 lựa chọn speaker: loa nhỏ và loa ngoài.
      -------------------------------------------------------------------------------*/
      case 'speakerLoud': // loa ngoài
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.SPEAKER_PHONE);
        break;
      case 'speakerEarphone': // loa nhỏ
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.EARPIECE);
        break;
      case 'speakerBluetooth': // bluetooth
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.BLUETOOTH);
        break;
      case 'getAudioDevices':
        MptCallKitController().getAudioDevices();
        break;
      case 'reject':
        MptCallKitController().rejectCall();
        break;
      case 'updateVideoCall':
        MptCallKitController().updateVideoCall(isVideo: true);
        break;
      // case 'conference':
      //   await MptCallKitController().updateToConference(isConference: true);
      //   final isConference = await MptCallKitController().getConferenceState();
      //   setState(() {
      //     _isConference = isConference;
      //   });
      //   break;
      // case 'distroyConference':
      //   await MptCallKitController().updateToConference(isConference: false);
      //   final isConference = await MptCallKitController().getConferenceState();
      //   setState(() {
      //     _isConference = isConference;
      //   });
      //   break;
      case "inviteToConference":
        _showInviteToConferenceDialog();
      default:
        print('Function $functionName not implemented');
    }
  }

  void _showInviteToConferenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite to Conference'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the extension number to invite:'),
            const SizedBox(height: 16),
            TextField(
              controller: inviteExtensionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Extension',
                hintText: 'Enter extension number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final extension = inviteExtensionController.text.trim();
              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString("saved_access_token");

              if (extension.isEmpty) {
                if (_scaffoldMessenger != null) {
                  _scaffoldMessenger!.showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an extension number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              Navigator.of(context).pop();

              try {
                await MptCallKitController().inviteToConference(
                  destination: extension,
                  accessToken: accessToken!,
                  extraInfo: "extraInfo",
                  onError: (error) {
                    if (error == null) return;
                    print("Error: $error");
                  },
                );

                inviteExtensionController.clear();

                if (mounted && _scaffoldMessenger != null) {
                  _scaffoldMessenger!.showSnackBar(
                    SnackBar(
                      content: Text('Inviting $extension to conference...'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted && _scaffoldMessenger != null) {
                  _scaffoldMessenger!.showSnackBar(
                    SnackBar(
                      content: Text('Failed to invite: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _showCallEndedDialog(String state) {
    String message = state == CallStateConstants.CLOSED
        ? "Call ended"
        : state == CallEventSocketConstants.REJECT_CALL
            ? "Call rejected"
            : state == CallEventSocketConstants.END_CALL
                ? "Call ended"
                : "Call failed";

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
}
