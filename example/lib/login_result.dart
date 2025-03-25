import 'dart:async';

import 'package:example/call_pad.dart';
import 'package:example/components/repo.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'package:mpt_callkit/mpt_callkit.dart';
import 'package:mpt_callkit/mpt_socket.dart';

class LoginResultScreen extends StatefulWidget {
  const LoginResultScreen({
    super.key,
    required this.title,
    required this.userData,
    required this.baseUrl,
    required this.apiKey,
  });

  final String title;
  final Map<String, dynamic>? userData;
  final String baseUrl;
  final String apiKey;
  @override
  State<LoginResultScreen> createState() => _LoginResultScreenState();
}

class _LoginResultScreenState extends State<LoginResultScreen> {
  Map<String, dynamic>? _currentUserInfo;
  ExtensionData? _extensionData;
  final _outboundNumber = "18006602"; // your outbound number
  Map<String, dynamic>? _configuration;
  final TextEditingController _destinationController =
      TextEditingController(text: "0988712192");
  late StreamSubscription<String> _callStateSubscription;

  @override
  void initState() {
    super.initState();
    initData();

    _callStateSubscription =
        MptCallKitController().callStateListener.listen((state) {
      // Chỉ khi nhận được INCOMING mới route đến call_pad
      if (state == CallStateConstants.INCOMING) {
        _navigateToCallPad();
      }
    });
  }

  Future<void> initData() async {
    if (widget.userData != null) {
      await getCurrentUserInfo();
      await getConfiguration();
      await connectToSocketServer();
      await registerToSipServer();
    } else {
      print("Access token is null");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access token is null"),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  // get configuration
  Future<void> getConfiguration() async {
    _configuration = await Repo().getConfiguration(
      baseUrl: widget.baseUrl,
      accessToken: widget.userData!["result"]["accessToken"],
      onError: (e) {
        print("Error in get all: ${e.toString()}");
      },
    );
  }

  // get current user info
  Future<void> getCurrentUserInfo() async {
    _currentUserInfo = await Repo().getCurrentUserInfo(
      baseUrl: widget.baseUrl,
      accessToken: widget.userData!["result"]["accessToken"],
      onError: (e) {
        print("Error in get current user info: ${e.toString()}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error in get current user info: ${e.toString()}"),
            backgroundColor: Colors.grey,
          ),
        );
      },
    );
  }

  // handle register to sip server
  Future<void> registerToSipServer() async {
    // Get extension data from current user info
    if (_currentUserInfo != null) {
      _extensionData = ExtensionData(
        username: _currentUserInfo!["user"]["extension"],
        password: _currentUserInfo!["user"]["sipPassword"],
        domain: _currentUserInfo!["tenant"]["domainContext"],
        sipServer: "portsip.omicx.vn",
        port: 5060,
      );

      if (_extensionData != null) {
        // Register to SIP server
        await doOnline();
      }
    }
  }

  // register SIP
  Future<bool> doOnline() async {
    return await MptCallKitController().online(
      username: _extensionData!.username!,
      displayName: _extensionData!.username!, // ??
      srtpType: 0,
      authName: _extensionData!.username!, // ??
      password: _extensionData!.password!,
      userDomain: _extensionData!.domain!,
      sipServer: _extensionData!.sipServer!,
      sipServerPort: _extensionData!.port ?? 5060,
      transportType: 0,
      onError: (p0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error in online: ${p0.toString()}"),
            backgroundColor: Colors.grey,
          ),
        );
      },
      phoneNumber: _outboundNumber,
      context: context,
    );
  }

  // unregister SIP
  Future<bool> doOffline() async {
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

  // Connect to socket server
  Future<void> connectToSocketServer() async {
    print("connectToSocketServer");
    if (_configuration != null) {
      MptSocketAbly.initialize(
        ablyKeyParam: _configuration!["ABLY_KEY"],
        tenantIdParam: _currentUserInfo!["tenant"]["id"],
        userIdParam: _currentUserInfo!["user"]["id"],
        userNameParam: _currentUserInfo!["user"]["userName"],
        onMessageReceivedParam: (p0) {
          print("Message received in callback: $p0");
        },
      );
    } else {
      print("Cannot connect agent to socket server - configuration is null");
    }
  }

  // Logout account
  Future<void> logout() async {
    bool isLogoutAccountSuccess = false;
    bool isUnregistered = false;

    // Ngắt kết nối socket
    await MptSocketAbly.disconnect();

    if (MptCallKitController().isOnline) {
      isLogoutAccountSuccess = await MptCallKitController().offline();
    } else {
      isLogoutAccountSuccess = true;
    }

    isUnregistered = await MptCallkit().logout(
      cloudAgentId: _currentUserInfo!["user"]["id"],
      cloudAgentName: _currentUserInfo!["user"]["fullName"] ?? "",
      cloudTenantId: _currentUserInfo!["tenant"]["id"],
      baseUrl: widget.baseUrl,
      onError: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e ?? 'Logout failed'),
            backgroundColor: Colors.grey,
          ),
        );
      },
    );

    // Quan trọng: Hủy hoàn toàn instance khi đăng xuất
    await MptSocketAbly.destroyInstance();

    if (isLogoutAccountSuccess && isUnregistered) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _callStateSubscription.cancel();
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
  void changeStatus({
    required String statusName,
    required int reasonCodeId,
  }) async {
    await Repo().changeAgentStatus(
        cloudAgentId: _currentUserInfo!["user"]["id"],
        cloudTenantId: _currentUserInfo!["tenant"]["id"],
        cloudAgentName: _currentUserInfo!["user"]["fullName"] ?? "",
        reasonCodeId: reasonCodeId,
        statusName: statusName,
        baseUrl: widget.baseUrl,
        accessToken: widget.userData!["result"]["accessToken"]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            handleBackButton();
          }
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
                                          await doOffline();
                                        } else {
                                          // Nếu đang offline thì chuyển sang online
                                          if (_extensionData != null) {
                                            await doOnline();
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
                                        backgroundColor: snapshot.data == true
                                            ? Colors.deepOrange
                                            : Colors.blueGrey,
                                      ),
                                      child: Text(
                                        snapshot.data == true
                                            ? "do offline"
                                            : "do online",
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
                              stream: MptSocketAbly.agentStatusStream,
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 50),
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
    if (destination.isEmpty || !MptCallKitController().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Failed: Please enter destination number and make sure registered to SIP server"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Thực hiện cuộc gọi và kiểm tra kết quả
    final success = await MptCallKitController().makeCallOutbound(
      baseUrl: widget.baseUrl,
      channel: "CALL",
      tenantId: _currentUserInfo!["tenant"]["id"],
      applicationId: _outboundNumber,
      senderId: destination,
      agentId: _currentUserInfo!["user"]["id"] ?? 0,
      direction: "INTERNAL",
      extraInfo: "",
      authToken: widget.userData!["result"]["accessToken"],
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Call outbound failed!'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
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
