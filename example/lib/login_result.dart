import 'dart:async';
import 'dart:io';

import 'package:example/components/callkit_constants.dart';
import 'package:example/login_res_tabviews/call_pad.dart';
import 'package:example/services/callkit_service.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/models.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_res_tabviews/video_view.dart';

class LoginResultScreen extends StatefulWidget {
  const LoginResultScreen({
    super.key,
    required this.title,
    required this.baseUrl,
    required this.apiKey,
  });

  final String title;
  final String baseUrl;
  final String apiKey;
  @override
  State<LoginResultScreen> createState() => _LoginResultScreenState();
}

class _LoginResultScreenState extends State<LoginResultScreen>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _callTypeSubscription;
  StreamSubscription<CallEventSocketRecv>? _callEventSocketSubscription;
  var tokenExpired = false;
  String? _currentAgentStatus;
  var currCallSesssionID = "";
  final List<String> _socketCallStateList = [];
  DateTime startTime = DateTime.now();
  AgentData? agentData;
  List<QueueDataByAgent>? agentQueues;

  bool isNavigatedToCallPad = false;
  final String _tokenKey = 'fcm_token';
  bool isFirstTime = true;

  // Save ScaffoldMessenger reference
  ScaffoldMessengerState? _scaffoldMessenger;

  // Bottom navigation bar index
  int _currentTabIndex = 0;

  String? _sipCallEvent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save ScaffoldMessenger reference for safe access after disposal
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();

    MptCallKitController().onRegisterSIP = (isOnline) {
      if (mounted && _scaffoldMessenger != null) {
        if (isOnline) {
          _scaffoldMessenger!.showSnackBar(
            const SnackBar(
              content: Text("SIP registration: TRUE!"),
            ),
          );
        } else {
          // doRegister();
          _scaffoldMessenger!.showSnackBar(
            const SnackBar(
              content: Text("SIP registration: FALSE!"),
            ),
          );
        }
      }
    };

    /* Route to CallPad if call session established */
    _callTypeSubscription =
        MptCallKitController().callEvent.listen((type) async {
      print("MptCallKitController().callEvent: $type");
      // if (type == CallStateConstants.INCOMING) {
      //   if (mounted && !isNavigatedToCallPad) {
      //     isNavigatedToCallPad = true;
      //     await _navigateToCallPad();
      //   }
      // }
      // if (type == CallStateConstants.CLOSED) {
      //   // if (mounted && isNavigatedToCallPad) {
      //   isNavigatedToCallPad = false;
      //   // }
      // }

      if (mounted) {
        setState(() {
          _sipCallEvent = type ?? "";
        });
      }
    });

    _callEventSocketSubscription =
        MptSocketSocketServer.callEvent.listen((callEvent) async {
      if (mounted) {
        setState(() {
          _socketCallStateList.add(callEvent.state ?? "NONE");
        });

        if (callEvent.state == CallEventSocketConstants.OFFER_CALL) {
          // currCallSesssionID = callEvent.sessionId ?? "";
          // if (mounted && !isNavigatedToCallPad) {
          //   isNavigatedToCallPad = true;
          //   await _navigateToCallPad();
          // }

          print("Incoming call: ${callEvent.toJson()}");

          _showCallIncomingDialog();
        }

        if (callEvent.state == CallEventSocketConstants.REJECT_CALL ||
            callEvent.state == CallEventSocketConstants.END_CALL) {
          if (Platform.isAndroid) {
            CallKitService.endCallkit();
          }
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (mounted) {
        // await Future.delayed(const Duration(seconds: 1));
        await _initDataWhenLoginSuccess();
        isFirstTime = false;
      }
    });
  }

  void _showCallIncomingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Incoming Call',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('You have an incoming call'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Hangup - Reject the call
                Navigator.of(context).pop();
                MptCallKitController().hangup();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hangup'),
            ),
            TextButton(
              onPressed: () async {
                // Answer - Accept the call
                Navigator.of(context).pop();
                MptCallKitController().answerCall();
                if (mounted && !isNavigatedToCallPad) {
                  isNavigatedToCallPad = true;
                  // Navigate to call pad or video view
                  setState(() {
                    _currentTabIndex = 2; // Switch to Video Call tab
                  });
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Answer'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && !isFirstTime) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString("saved_access_token");
      if (accessToken != null) {
        // await Future.delayed(const Duration(seconds: 1));
        await MptCallKitController().connectToSocketServer(accessToken);
      }
    }
  }

  Future<void> _initDataWhenLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("saved_access_token");
    MptCallKitController().initSdk(
      apiKey: CallkitConstants.API_KEY,
      baseUrl: CallkitConstants.BASE_URL,
      pushToken: Platform.isAndroid ? prefs.getString(_tokenKey) : null,
      appId: Platform.isAndroid ? CallkitConstants.ANDROID_APP_ID : null,
      enableDebugLog: true,
      deviceInfo: "deviceInfo",
      recordLabel: "",
      enableBlurBackground: true,
      bgPath: "https://s3-sgn09.fptcloud.com/ict-mvno/Background_eho_mvno.png",
    );

    await MptCallKitController().initDataWhenLoginSuccess(
      context: context,
      accessToken: accessToken,
      onError: (p0) {
        tokenExpired = true;
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content:
                  Text("Error in initDataWhenLoginSuccess: ${p0.toString()}"),
              backgroundColor: Colors.grey,
            ),
          );
        }
      },
    );

    // Test getCurrentAgentStatus API after successful init
    if (!tokenExpired && accessToken != null) {
      await _testGetCurrentAgentStatus(accessToken);
    }

    agentData = await MptCallKitController().getCurrentAgentData(
      accessToken ?? "",
    );

    agentQueues = await MptCallKitController().getAgentQueues();

    print("getCurrentAgentData result: $agentData");
  }

  // Test getCurrentAgentStatus API
  Future<void> _testGetCurrentAgentStatus(String accessToken) async {
    try {
      final agentStatus = await MptCallKitController().getCurrentAgentStatus(
        accessToken: accessToken,
        onError: (error) {
          print("Error getting current agent status: $error");
          if (_scaffoldMessenger != null) {
            _scaffoldMessenger!.showSnackBar(
              SnackBar(
                content: Text("Error getting agent status: $error"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );

      if (agentStatus != null && mounted && _scaffoldMessenger != null) {
        setState(() {
          _currentAgentStatus = agentStatus;
        });
        print("Current agent status: $agentStatus");

        // Show success message
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text("Agent status loaded: $agentStatus"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Exception in _testGetCurrentAgentStatus: $e");
    }
  }

  // register SIP
  Future<bool> doRegister() async {
    var extensionData = MptCallKitController().extensionData;

    if (extensionData == null) {
      if (_scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text("Không có thông tin extension")),
        );
      }
      return false;
    }

    return await MptCallKitController().online(
      username: extensionData.username!,
      displayName: extensionData.username!, // ??
      srtpType: 0,
      authName: extensionData.username!, // ??
      password: extensionData.password!,
      userDomain: extensionData.domain!,
      sipServer: extensionData.sipServer!,
      sipServerPort: extensionData.port ?? 5063,
      // sipServerPort: 5063,
      transportType: 0,
      onError: (p0) {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text("Error in online: ${p0.toString()}"),
              backgroundColor: Colors.grey,
            ),
          );
        }
      },
      context: context,
      pushToken: await MptCallKitController().getCurrentPushToken(),
      appId: CallkitConstants.ANDROID_APP_ID,
    );
  }

  // unregister SIP
  Future<bool> doUnregiter() async {
    return await MptCallKitController().offline(
      onError: (error) {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text("Lỗi: $error"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  // Logout account
  Future<void> logout() async {
    if (MptCallKitController().currentAppEvent ==
            AppEventConstants.TOKEN_EXPIRED ||
        MptCallKitController().currentAppEvent == AppEventConstants.ERROR) {
      // Remove saved credentials
      print("Current app event: ${MptCallKitController().currentAppEvent}");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("saved_access_token");

      Navigator.pop(context);
      return;
    }

    var result = await MptCallKitController().logout(
      onError: (e) {
        if (_scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text(e ?? 'Logout failed'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      },
    );

    if (result) {
      // Remove saved credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("saved_access_token");

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _callTypeSubscription?.cancel();
    _callEventSocketSubscription?.cancel();
    super.dispose();
  }

  handleBackButton() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alert'),
        content: const Text('Logout?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              await logout();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  // change status method
  Future<bool> changeStatus({
    required String statusName,
    required int reasonCodeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("saved_access_token");

    bool result = await MptCallKitController().changeAgentStatus(
      reasonCodeId: reasonCodeId,
      statusName: statusName,
      accessToken: accessToken ?? "",
      onError: (error) {
        print("Change status failed! $error");

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Change agent status failed, '),
            content: const Text('Logout?'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await logout();
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  // Tab 1: Status & Information
  Widget _buildStatusTab() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agent name: ${MptCallKitController().currentUserInfo?["user"]["fullName"].toString() ?? ""}",
                  ),
                  StreamBuilder<bool>(
                    stream: MptSocketSocketServer.connectionStatus,
                    initialData:
                        MptSocketSocketServer.getCurrentConnectionState(),
                    builder: (context, snapshot) {
                      final isSocketConnected = snapshot.data ?? false;

                      print("Socket server connection: $isSocketConnected");

                      return Row(
                        children: [
                          Text(
                            "Socket server connection: ${isSocketConnected ? 'Connected' : 'Disconnected'}",
                            style: const TextStyle(
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 5),
                          IconButton(
                            onPressed: () {
                              // Khởi tạo lại kết nối nếu cần
                              _initDataWhenLoginSuccess();
                              // }
                            },
                            icon: Icon(
                              isSocketConnected
                                  ? Icons.check_circle
                                  : Icons.undo,
                            ),
                            color: isSocketConnected
                                ? Colors.green
                                : Colors.deepOrange,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "To get Call-Incoming:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                      "Make sure you have registered to SIP server and your agent status is READY"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey))),
              child: Column(
                children: [
                  StreamBuilder<bool>(
                    stream: MptCallKitController().onlineStatuslistener,
                    initialData: MptCallKitController().isOnline,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("SIP connection status:"),
                                Text(
                                  snapshot.data == true
                                      ? 'Registered'
                                      : 'Unregistered',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (snapshot.data == true) {
                                // Nếu đang online thì chuyển sang offline
                                await MptCallKitController().offline();
                              } else {
                                // Nếu đang offline thì chuyển sang online
                                if (MptCallKitController().extensionData !=
                                    null) {
                                  await doRegister();
                                } else {
                                  if (_scaffoldMessenger != null) {
                                    _scaffoldMessenger!.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Không có thông tin extension"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                            ),
                            child: Text(
                              snapshot.data == true
                                  ? "do unregister"
                                  : "do register",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            changeStatus(
                                reasonCodeId: 1001, statusName: "READY");
                          },
                          child: const Text("change to ready")),
                      const SizedBox(width: 10),
                      ElevatedButton(
                          onPressed: () {
                            changeStatus(
                                reasonCodeId: 1000, statusName: "NOT_READY");
                          },
                          child: const Text("change to busy")),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Display current agent status from API
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Current Agent Status (API):",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_currentAgentStatus != null)
                          Text("Status: $_currentAgentStatus")
                        else
                          const Text("No agent status data"),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final accessToken =
                                prefs.getString("saved_access_token");
                            if (accessToken != null) {
                              await _testGetCurrentAgentStatus(accessToken);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 36),
                          ),
                          child: const Text("Refresh Agent Status"),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Socket call state: [${_socketCallStateList.join(", ")}]",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 2: Actions & Call Functions
  Widget _buildCallPadTab() {
    return const CallPad();
  }

  // Tab 3: Call Pad (embedded without scaffold wrapper)
  Widget _buildVideoViewTab() {
    // Using ClipRect to prevent CallPad's AppBar from showing
    // by wrapping it in a sized box that clips the top portion
    return ClipRect(
      child: Container(
        child: const VideoView(isGuest: false),
      ),
    );
  }

  Widget _getCurrentTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return _buildStatusTab();
      case 1:
        return _buildCallPadTab();
      case 2:
        return _buildVideoViewTab();
      default:
        return _buildStatusTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () {
                handleBackButton();
              },
              icon: const Icon(Icons.logout),
            )
          ],
          title: const Text('Login Result'),
        ),
        body: Column(children: [
          Row(
            children: [
              Text(
                "[${MptCallKitController().currentUserInfo?["user"]["userName"].toString() ?? ""} - ${MptCallKitController().currentUserInfo?["user"]["extension"].toString() ?? ""}]",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 10),
              StreamBuilder<String>(
                stream: MptSocketSocketServer.agentStatusEvent,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      "Agent Status: ${snapshot.data!}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    return const Text("Agent Status: null");
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: MptCallKitController().onlineStatuslistener,
                initialData: MptCallKitController().isOnline,
                builder: (context, snapshot) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("SIP Status:"),
                        Text(
                          snapshot.data == true ? 'Registered' : 'Unregistered',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Text(" - "),
              StreamBuilder<String>(
                stream: MptCallKitController().callEvent,
                builder: (context, snapshot) {
                  return Text("SIP Call Event: ${snapshot.data ?? ""}");
                },
              ),
            ],
          ),
          Container(
            height: 1,
            color: Colors.grey,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(_currentTabIndex == 2 ? 0.0 : 10.0),
              child: _getCurrentTabContent(),
            ),
          ),
        ]),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              label: 'Status',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dialpad),
              label: 'Call Pad',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.videocam),
              label: 'Video Call',
            ),
          ],
        ),
      ),
    );
  }
}
