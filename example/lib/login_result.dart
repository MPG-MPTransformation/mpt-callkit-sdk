import 'dart:async';

import 'package:example/components/callkit_constants.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
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

class _LoginResultScreenState extends State<LoginResultScreen> {
  final TextEditingController _destinationController =
      TextEditingController(text: "10001");
  StreamSubscription<String>? _callStateSubscription;
  StreamSubscription<String>? _callTypeSubscription;
  var tokenExpired = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        _initDataWhenLoginSuccess();
      }
    });
    // _callStateSubscription = MptCallKitController().callEvent.listen((state) {
    //   // Chỉ khi nhận được INCOMING mới route đến call_pad
    //   if (state == CallStateConstants.INCOMING && mounted) {
    //     _navigateToCallPad();
    //   }
    // });

    /* Route to CallPad if call session established */
    _callTypeSubscription = MptCallKitController().callType.listen((type) {
      if ((type == CallTypeConstants.INCOMING_CALL ||
              type == CallTypeConstants.OUTGOING_CALL) &&
          mounted) {
        _navigateToCallPad();
      }
    });
  }

  Future<void> _initDataWhenLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("saved_access_token");

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
      sipServerPort: extensionData.port ?? 5060,
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
      pushToken: MptCallKitController().pushToken,
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
    _callStateSubscription?.cancel();
    _callTypeSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          handleBackButton();
          return false;
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
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
                            border:
                                Border(bottom: BorderSide(color: Colors.grey))),
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

                                return Row(
                                  children: [
                                    Text(
                                      "Socket server connection: ${isSocketConnected ? 'Connected' : 'Disconnected'}",
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () {
                                        // Khi cần kết nối lại thủ công
                                        if (!isSocketConnected) {
                                          // Khởi tạo lại kết nối nếu cần
                                          _initDataWhenLoginSuccess();
                                        }
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
                            border:
                                Border(bottom: BorderSide(color: Colors.grey))),
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
                                          await doUnregiter();
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
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
      extraInfo: "",
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

  void _navigateToCallPad() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CallPad()),
    );
  }
}
