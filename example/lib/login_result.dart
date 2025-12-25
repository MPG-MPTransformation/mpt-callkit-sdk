import 'dart:async';
import 'dart:io';

import 'package:example/components/callkit_constants.dart';
import 'package:example/services/callkit_service.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_callkit_incoming/entities/entities.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/models.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_callkit.dart';
import 'package:mpt_callkit/mpt_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/call_pad.dart';

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
  final TextEditingController _destinationController =
      TextEditingController(text: "10001");
  final TextEditingController _extraInfoController =
      TextEditingController(text: "extraInfo");
  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _callTypeSubscription;
  StreamSubscription<CallEventSocketRecv>? _callEventSocketSubscription;
  final CallEventSocketRecv _callEventData = CallEventSocketRecv();
  var tokenExpired = false;
  String? _currentAgentStatus;
  var currCallSesssionID = "";
  final List<String> _socketCallStateList = [];
  DateTime startTime = DateTime.now();
  AgentData? agentData;
  List<QueueDataByAgent>? agentQueues;

  bool isOnCall = false;
  bool isNavigatedToCallPad = false;
  final String _tokenKey = 'fcm_token';
  bool isFirstTime = true;

  int timeNetworkQualityTest = 0;
  double downloadSpeedNetworkQualityTest = 0.0;
  double uploadSpeedNetworkQualityTest = 0.0;
  double latencyNetworkQualityTest = 0.0;
  bool isNetworkTestLoading = false;

  // Method to show network test options dialog
  Future<void> _showNetworkTestDialog() async {
    bool includeDownload = true;
    bool includeUpload = true;
    bool includeLatency = true;

    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Network Quality Test Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Download Speed Test'),
                    value: includeDownload,
                    onChanged: (bool? value) {
                      setState(() {
                        includeDownload = value ?? true;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Upload Speed Test'),
                    value: includeUpload,
                    onChanged: (bool? value) {
                      setState(() {
                        includeUpload = value ?? true;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Latency Test'),
                    value: includeLatency,
                    onChanged: (bool? value) {
                      setState(() {
                        includeLatency = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!includeDownload && !includeUpload && !includeLatency) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn ít nhất một test!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'includeDownload': includeDownload,
                      'includeUpload': includeUpload,
                      'includeLatency': includeLatency,
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _runNetworkTest(
        includeDownload: result['includeDownload'] ?? false,
        includeUpload: result['includeUpload'] ?? false,
        includeLatency: result['includeLatency'] ?? false,
      );
    }
  }

  // Method to run network test with selected options
  Future<void> _runNetworkTest({
    required bool includeDownload,
    required bool includeUpload,
    required bool includeLatency,
  }) async {
    setState(() {
      isNetworkTestLoading = true;
    });

    try {
      final stopwatch = Stopwatch()..start();
      var res = await MptNetworkSpeedTest.instance.runSelectiveSpeedTest(
        includeLatency: includeLatency,
        downloadDataSizeKB: includeDownload ? 1024 * 2 : 0,
        uploadDataSizeKB: includeUpload ? 1024 * 2 : 0,
      );
      stopwatch.stop();

      setState(() {
        timeNetworkQualityTest = stopwatch.elapsedMilliseconds;
        downloadSpeedNetworkQualityTest = res.downloadSpeed ?? 0.0;
        uploadSpeedNetworkQualityTest = res.uploadSpeed ?? 0.0;
        latencyNetworkQualityTest = res.latency ?? 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network test completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isNetworkTestLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();

    MptCallKitController().onRegisterSIP = (isOnline) {
      if (mounted) {
        if (isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("SIP registration: TRUE!"),
            ),
          );
        } else {
          // doRegister();
          ScaffoldMessenger.of(context).showSnackBar(
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
      if (type == CallStateConstants.INCOMING ||
          type == CallStateConstants.CONNECTED) {
        isOnCall = true;
      } else {
        isOnCall = false;
      }
      if (type == CallStateConstants.CONNECTED) {
        if (mounted && !isNavigatedToCallPad) {
          isNavigatedToCallPad = true;
          await _navigateToCallPad();
        }
      }
      if (type == CallStateConstants.CLOSED) {
        // if (mounted && isNavigatedToCallPad) {
        isNavigatedToCallPad = false;
        // }
      }
    });

    _callEventSocketSubscription =
        MptSocketSocketServer.callEvent.listen((callEvent) async {
      if (mounted) {
        setState(() {
          _socketCallStateList.add(callEvent.state ?? "NONE");
        });

        if ((callEvent.state == CallEventSocketConstants.OFFER_CALL) &&
            callEvent.sessionId != currCallSesssionID) {
          currCallSesssionID = callEvent.sessionId ?? "";
          if (mounted && !isNavigatedToCallPad) {
            isNavigatedToCallPad = true;
            await _navigateToCallPad();
          }
        }

        if (callEvent.state == CallEventSocketConstants.REJECT_CALL ||
            callEvent.state == CallEventSocketConstants.END_CALL) {
          if (Platform.isAndroid) {
            CallKitService.endCallkit();
          }
        }
      }
    });

    // _listenCallkitEvent();

    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (mounted) {
        // await Future.delayed(const Duration(seconds: 1));
        await _initDataWhenLoginSuccess();
        isFirstTime = false;
      }
    });
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

    // if ((state == AppLifecycleState.paused ||
    //         state == AppLifecycleState.inactive) &&
    //     isOnCall == false) {
    //   await MptSocketSocketServer.disconnect();
    // }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Error in initDataWhenLoginSuccess: ${p0.toString()}"),
            backgroundColor: Colors.grey,
          ),
        );
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

  Future<void> _testUploadSpeed() async {
    final stopwatch = Stopwatch()..start();
    var res = await MptNetworkSpeedTest.instance.testUploadSpeed(
      dataSizeKB: 2048,
    );
    stopwatch.stop();
    print(
        'Run Quick Speed Test finished (t=${stopwatch.elapsedMilliseconds} ms) - Upload: ${res.speed} Mbps');
  }

  // Test getCurrentAgentStatus API
  Future<void> _testGetCurrentAgentStatus(String accessToken) async {
    try {
      final agentStatus = await MptCallKitController().getCurrentAgentStatus(
        accessToken: accessToken,
        onError: (error) {
          print("Error getting current agent status: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error getting agent status: $error"),
              backgroundColor: Colors.orange,
            ),
          );
        },
      );

      if (agentStatus != null && mounted) {
        setState(() {
          _currentAgentStatus = agentStatus;
        });
        print("Current agent status: $agentStatus");

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không có thông tin extension")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error in online: ${p0.toString()}"),
            backgroundColor: Colors.grey,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi: $error"),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e ?? 'Logout failed'),
            backgroundColor: Colors.grey,
          ),
        );
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
    _destinationController.dispose();
    _extraInfoController.dispose();
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

  // Future<void> _listenCallkitEvent() async {
  //   try {
  //     FlutterCallkitIncoming.onEvent.listen((event) {
  //       print("Listener event: ${event?.event.toString()}");
  //       switch (event!.event) {
  //         case Event.actionCallIncoming:
  //           // TODO: received an incoming call
  //           break;
  //         case Event.actionCallStart:
  //           // TODO: started an outgoing call
  //           // TODO: show screen calling in Flutter
  //           break;
  //         case Event.actionCallAccept:
  //           print("actionCallAccept");
  //           break;
  //         case Event.actionCallDecline:
  //           // TODO: declined an incoming call
  //           print("actionCallDecline");
  //           break;
  //         case Event.actionCallEnded:
  //           // TODO: ended an incoming/outgoing call
  //           print("actionCallEnded");
  //           break;
  //         case Event.actionCallTimeout:
  //           // TODO: missed an incoming call
  //           break;
  //         case Event.actionCallCallback:
  //           // TODO: only Android - click action `Call back` from missed call notification
  //           break;
  //         case Event.actionCallCustom:
  //           break;
  //         case Event.actionCallConnected:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionDidUpdateDevicePushTokenVoip:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionCallToggleHold:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionCallToggleMute:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionCallToggleDmtf:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionCallToggleGroup:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //         case Event.actionCallToggleAudioSession:
  //           // TODO: Handle this case.
  //           throw UnimplementedError();
  //       }
  //       // callback(event);
  //     });
  //   } on Exception catch (e) {
  //     print("Listener event Exception: $e");
  //   }
  // }

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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        handleBackButton();
        return false;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                      onPressed: () {
                        handleBackButton();
                      },
                      icon: const Icon(Icons.logout))
                ],
                title: const Text('Login Result'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(10.0),
                child: SingleChildScrollView(
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Login status: ${widget.title}",
                              ),
                              StreamBuilder<bool>(
                                stream: MptSocketSocketServer.connectionStatus,
                                initialData: MptSocketSocketServer
                                    .getCurrentConnectionState(),
                                builder: (context, snapshot) {
                                  final isSocketConnected =
                                      snapshot.data ?? false;

                                  print(
                                      "Socket server connection: $isSocketConnected");

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
                              ElevatedButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final accessToken =
                                      prefs.getString("saved_access_token");
                                  if (accessToken != null) {
                                    MptCallKitController()
                                        .connectToSocketServer(accessToken);
                                  }
                                },
                                child: const Text("Connect socket"),
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
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey))),
                          child: Column(
                            children: [
                              StreamBuilder<bool>(
                                stream:
                                    MptCallKitController().onlineStatuslistener,
                                initialData: MptCallKitController().isOnline,
                                builder: (context, snapshot) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                                "SIP connection status:"),
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
                                            await MptCallKitController()
                                                .offline();
                                          } else {
                                            // Nếu đang offline thì chuyển sang online
                                            if (MptCallKitController()
                                                    .extensionData !=
                                                null) {
                                              await doRegister();
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      "Không có thông tin extension"),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
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
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
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
                              const SizedBox(height: 10),
                              // Display current agent status from API
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
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
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        final accessToken = prefs
                                            .getString("saved_access_token");
                                        if (accessToken != null) {
                                          await _testGetCurrentAgentStatus(
                                              accessToken);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 36),
                                      ),
                                      child: const Text("Refresh Agent Status"),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () {
                                        // MptCallKitController().refreshRegister();
                                      },
                                      child: const Text("Refresh Register"),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                      onPressed: () {
                                        changeStatus(
                                            reasonCodeId: 1001,
                                            statusName: "READY");
                                      },
                                      child: const Text("change to ready")),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                      onPressed: () {
                                        changeStatus(
                                            reasonCodeId: 1000,
                                            statusName: "NOT_READY");
                                      },
                                      child: const Text("change to busy")),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Make call outbound"),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _destinationController,
                                keyboardType: TextInputType.phone,
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
                                stream:
                                    MptCallKitController().onlineStatuslistener,
                                initialData: MptCallKitController().isOnline,
                                builder: (context, snapshot) {
                                  return ElevatedButton(
                                    onPressed: () async {
                                      await _makeCallOutbound();
                                    },
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.all(
                                          Colors.blueGrey),
                                      foregroundColor:
                                          WidgetStateProperty.all(Colors.white),
                                      minimumSize: WidgetStateProperty.all(
                                          const Size(double.infinity, 50)),
                                    ),
                                    child: const Text('Call'),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  await _showNetworkTestDialog();
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      Colors.deepOrange),
                                  foregroundColor:
                                      WidgetStateProperty.all(Colors.white),
                                  minimumSize: WidgetStateProperty.all(
                                      const Size(double.infinity, 50)),
                                ),
                                child: const Text('Network Quality Test'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                "Network Quality Test Results:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Time spent: $timeNetworkQualityTest ms",
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (downloadSpeedNetworkQualityTest > 0)
                                Text(
                                  "Download Speed: ${downloadSpeedNetworkQualityTest.toStringAsFixed(2)} Mbps",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (uploadSpeedNetworkQualityTest > 0)
                                Text(
                                  "Upload Speed: ${uploadSpeedNetworkQualityTest.toStringAsFixed(2)} Mbps",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (latencyNetworkQualityTest > 0)
                                Text(
                                  "Latency: ${latencyNetworkQualityTest.toStringAsFixed(2)} ms",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (timeNetworkQualityTest == 0)
                                const Text(
                                  "No test results yet",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
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
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       var res = await MptCallKitController()
                        //           .changeAgentStatusInQueue(
                        //         queueId: "aaacb2e9-e163-4ff9-be47-44c96ea4379f",
                        //         enabled: true,
                        //       );
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content: Text(
                        //               "changeAgentStatusInQueue result: $res"),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("enable changeAgentStatusInQueue")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       var res = await MptCallKitController()
                        //           .changeAgentStatusInQueue(
                        //         queueId: "aaacb2e9-e163-4ff9-be47-44c96ea4379f",
                        //         enabled: false,
                        //       );
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content: Text(
                        //               "changeAgentStatusInQueue result: $res"),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("disable changeAgentStatusInQueue")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       var res =
                        //           await MptCallKitController().getAgentQueues();
                        //       agentQueues = res;
                        //       print("getAgentQueues result: ${res?.length}");
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content: Text(
                        //               "getAgentQueues length: ${res?.length}"),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("getAgentQueues")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       var res =
                        //           await MptCallKitController().getAllQueues();
                        //       print("getAllQueues result: ${res?.length}");
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content:
                        //               Text("getAllQueues length: ${res?.length}"),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("getAllQueues")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       var res = await MptCallKitController()
                        //           .getAllAgentInQueueByQueueExtension(
                        //         extension: "30037",
                        //       );
                        //       print(
                        //           "getAllAgentInQueueByQueueExtension result: ${res?.length}");
                        //       ScaffoldMessenger.of(context).showSnackBar(
                        //         SnackBar(
                        //           content: Text(
                        //               "getAllAgentInQueueByQueueExtension length: ${res?.length}"),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("getAllAgentInQueueByQueueExtension")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       final stopwatch = Stopwatch()..start();
                        //       var res =
                        //           await MptNetworkSpeedTest.instance.runSpeedTest(
                        //         downloadDurationSeconds: 5,
                        //         uploadDataSizeKB: 1024,
                        //         latencyAttempts: 3,
                        //       );
                        //       stopwatch.stop();
                        //       print(
                        //           'Run Speed Test finished (t=${stopwatch.elapsedMilliseconds} ms) - Download: ${res.downloadSpeed} Mbps, Upload: ${res.uploadSpeed} Mbps, Latency: ${res.latency} ms');
                        //     },
                        //     child: Text("Run Speed Test")),
                        // ElevatedButton(
                        //     onPressed: () async {
                        //       final stopwatch = Stopwatch()..start();
                        //       var res = await MptNetworkSpeedTest.instance
                        //           .runSelectiveSpeedTest(
                        //         includeLatency: false,
                        //         downloadDataSizeKB: 2048,
                        //         uploadDataSizeKB: 1024,
                        //       );
                        //       stopwatch.stop();
                        //       print(
                        //           'Run runSelectiveSpeedTest finished (t=${stopwatch.elapsedMilliseconds} ms) - Download: ${res.downloadSpeed} Mbps, Upload: ${res.uploadSpeed} Mbps, Latency: ${res.latency} ms');
                        //     },
                        //     child: Text("Run Selective Speed Test")),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 10,
                            children: [
                              ElevatedButton(
                                  onPressed: () async {
                                    final stopwatch = Stopwatch()..start();
                                    var res = await MptNetworkSpeedTest.instance
                                        .testUploadSpeed(
                                      dataSizeKB: 2048,
                                    );
                                    stopwatch.stop();
                                    print(
                                        'Run Quick Speed Test finished (t=${stopwatch.elapsedMilliseconds} ms) - Upload: ${res.speed} Mbps');
                                  },
                                  child: Text(
                                    "Test Upload",
                                  )),
                              ElevatedButton(
                                  onPressed: () async {
                                    final stopwatch = Stopwatch()..start();
                                    var res = await MptNetworkSpeedTest.instance
                                        .testDownloadSpeed(
                                      chunkTimeoutSeconds: 5,
                                      dataSizeKB: 2048,
                                    );
                                    stopwatch.stop();
                                    print(
                                        'Run Quick Speed Test finished (t=${stopwatch.elapsedMilliseconds} ms) - Download: ${res.speed} Mbps');
                                  },
                                  child: Text("Test Download")),
                              ElevatedButton(
                                  onPressed: () async {
                                    final stopwatch = Stopwatch()..start();
                                    var res = await MptNetworkSpeedTest.instance
                                        .testLatency();
                                    stopwatch.stop();
                                    print(
                                        'Run Quick Speed Test finished (t=${stopwatch.elapsedMilliseconds} ms) - Latency: ${res.latency} ms');
                                  },
                                  child: Text("Test Latency")),
                            ],
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Loading overlay
            if (isNetworkTestLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Running network quality test...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter destination number!"),
        ),
      );
      return;
    }

    if (MptCallKitController().isOnline == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SIP server has not registered!"),
        ),
      );
      return;
    }

    if (MptSocketSocketServer.instance.checkConnection() == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Socket server has disconnected!"),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Call outbound failed!'),
            backgroundColor: Colors.red,
          ),
        );
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
    // if (success) {
    //   _navigateToCallPad();
    // }
  }

  Future<void> _navigateToCallPad() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CallPad()),
    );
    isNavigatedToCallPad = false;
  }
}
