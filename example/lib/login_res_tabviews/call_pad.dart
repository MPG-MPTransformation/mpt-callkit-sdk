import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallPad extends StatefulWidget {
  const CallPad({super.key});

  @override
  State<CallPad> createState() => _CallPadState();
}

class _CallPadState extends State<CallPad> {
  final TextEditingController _destinationController =
      TextEditingController(text: "10001");
  final TextEditingController _extraInfoController =
      TextEditingController(text: "extraInfo");
  final TextEditingController inviteExtensionController =
      TextEditingController();

  final String _currentAudioDevice =
      MptCallKitController().currentAudioDevice ?? "";
  int? _pingTime;

  // Save ScaffoldMessenger reference
  ScaffoldMessengerState? _scaffoldMessenger;

  final List<String> _functionNames = [
    "answer",
    "reject",
    'hold',
    'unhold',
    'speakerLoud',
    'speakerEarphone',
    if (Platform.isAndroid) 'speakerBluetooth',
    if (Platform.isAndroid) 'getAudioDevices',
    'updateVideoCall',
    'hangup',
    'endCallAPI',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save ScaffoldMessenger reference for safe access after disposal
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _extraInfoController.dispose();
    inviteExtensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _destinationController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: 'Enter destination number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _extraInfoController,
                    decoration: const InputDecoration(
                      labelText: 'Extra Info',
                      hintText: 'Enter extra info',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<bool>(
                    stream: MptCallKitController().onlineStatuslistener,
                    initialData: MptCallKitController().isOnline,
                    builder: (context, snapshot) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                await _makeCallOutbound();
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.all(Colors.blueGrey),
                                foregroundColor:
                                    WidgetStateProperty.all(Colors.white),
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 50)),
                              ),
                              child: const Text('Make call Internal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                await _makeNativeCall();
                              },
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.all(Colors.blueGrey),
                                foregroundColor:
                                    WidgetStateProperty.all(Colors.white),
                                minimumSize:
                                    WidgetStateProperty.all(const Size(0, 50)),
                              ),
                              child: const Text('Make native call'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Divider
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // Call Control Actions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.black87),
                      const SizedBox(width: 8),
                      Text(
                        'Call Control Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Action buttons grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _functionNames.length,
                    itemBuilder: (context, index) {
                      final functionName = _functionNames[index];
                      return _buildActionButton(functionName);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Audio Device Info (if available)
                  if (_currentAudioDevice.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.headset,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Audio Device: $_currentAudioDevice',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Ping Info (if available)
                  if (_pingTime != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.network_check,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'SIP Ping: ${_pingTime}ms',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCallOutbound() async {
    final String destination = _destinationController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("saved_access_token");

    if (destination.isEmpty) {
      if (_scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          const SnackBar(
            content: Text("Please enter destination number!"),
          ),
        );
      }
      return;
    }

    if (MptCallKitController().isOnline == false) {
      if (_scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          const SnackBar(
            content: Text("SIP server has not registered!"),
          ),
        );
      }
      return;
    }

    if (MptSocketSocketServer.instance.checkConnection() == false) {
      if (_scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          const SnackBar(
            content: Text("Socket server has disconnected!"),
          ),
        );
      }
      return;
    }

    /*
     * Thực hiện cuộc gọi và kiểm tra kết quả
     */

    // call internal
    final success = await MptCallKitController().makeCallInternal(
      destination: _destinationController.text.trim(),
      senderId: MptCallKitController().currentUserInfo!["user"]["extension"],
      isVideoCall: true,
      extraInfo: _extraInfoController.text.trim(),
      accessToken: accessToken ?? "",
      onError: (error) {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(error ?? 'Call outbound failed!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    // // call to a destination number
    // final success = await MptCallKitController().makeCall(
    //   outboundNumber: "18006601",
    //   destination: _destinationController.text.trim(),
    //   extraInfo: "",
    //   onError: (error) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(error ?? 'Call outbound failed!'),
    //         backgroundColor: Colors.red,
    //       ),
    //     );
    //   },
    // );

    print("Call outbound success: $success");
  }

  Future<void> _makeNativeCall() async {
    await MptCallKitController().makeNativeCall(
      destination: _destinationController.text.trim(),
      isVideoCall: true,
    );
    print("makeNativeCall");
  }

  Widget _buildActionButton(String functionName) {
    final buttonConfig = _getButtonConfig(functionName);

    return Material(
      color: buttonConfig['color'] as Color,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: () => _executeToggleFunction(functionName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                buttonConfig['icon'] as IconData,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                buttonConfig['label'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getButtonConfig(String functionName) {
    switch (functionName) {
      case 'answer':
        return {
          'icon': Icons.call,
          'label': 'Answer',
          'color': Colors.green,
        };
      case 'reject':
        return {
          'icon': Icons.call_end,
          'label': 'Reject',
          'color': Colors.red,
        };
      case 'hold':
        return {
          'icon': Icons.pause_circle,
          'label': 'Hold',
          'color': Colors.orange,
        };
      case 'unhold':
        return {
          'icon': Icons.play_circle,
          'label': 'Unhold',
          'color': Colors.green,
        };
      case 'mute':
        return {
          'icon': Icons.mic_off,
          'label': 'Mute',
          'color': Colors.red,
        };
      case 'unmute':
        return {
          'icon': Icons.mic,
          'label': 'Unmute',
          'color': Colors.green,
        };
      case 'switchCamera':
        return {
          'icon': Icons.cameraswitch,
          'label': 'Switch Cam',
          'color': Colors.purple,
        };
      case 'cameraOn':
        return {
          'icon': Icons.videocam,
          'label': 'Cam On',
          'color': Colors.green,
        };
      case 'cameraOff':
        return {
          'icon': Icons.videocam_off,
          'label': 'Cam Off',
          'color': Colors.red,
        };
      case 'speakerLoud':
        return {
          'icon': Icons.volume_up,
          'label': 'Speaker',
          'color': Colors.indigo,
        };
      case 'speakerEarphone':
        return {
          'icon': Icons.phone_in_talk,
          'label': 'Earpiece',
          'color': Colors.teal,
        };
      case 'speakerBluetooth':
        return {
          'icon': Icons.bluetooth_audio,
          'label': 'Bluetooth',
          'color': Colors.blue,
        };
      case 'getAudioDevices':
        return {
          'icon': Icons.headset,
          'label': 'Devices',
          'color': Colors.cyan,
        };
      case 'updateVideoCall':
        return {
          'icon': Icons.video_call,
          'label': 'Update Video Call',
          'color': Colors.blue,
        };
      case 'hangup':
        return {
          'icon': Icons.call_end,
          'label': 'Hangup',
          'color': Colors.red[700]!,
        };
      case 'endCallAPI':
        return {
          'icon': Icons.phone_disabled,
          'label': 'End API',
          'color': Colors.grey[700]!,
        };
      default:
        return {
          'icon': Icons.settings,
          'label': functionName,
          'color': Colors.grey,
        };
    }
  }

  Future<void> _executeToggleFunction(String functionName) async {
    print('Executing $functionName function');

    switch (functionName) {
      case 'answer':
        await MptCallKitController().answerCall();
        break;
      case 'hangup':
        MptCallKitController().hangup();
        break;
      case 'endCallAPI':
        {
          final String sessionId =
              MptCallKitController().currentSessionId ?? "";
          final int agentId = int.parse(
              MptCallKitController().currentUserInfo?['user']?['id'] ?? '0');

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
      case 'speakerLoud':
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.SPEAKER_PHONE);
        break;
      case 'speakerEarphone':
        MptCallKitController()
            .setSpeaker(state: SpeakerStatusConstants.EARPIECE);
        break;
      case 'speakerBluetooth':
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
      default:
        print('Function $functionName not implemented');
    }
  }
}
