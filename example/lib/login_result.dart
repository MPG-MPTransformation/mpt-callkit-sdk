import 'package:example/call_pad.dart';
import 'package:example/components/repo.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/mpt_callkit.dart';
import 'package:mpt_callkit/mpt_socket.dart';

class LoginResultScreen extends StatefulWidget {
  const LoginResultScreen(
      {super.key,
      required this.title,
      required this.userData,
      required this.baseUrl,
      required this.apiKey});

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
  final _outboundNumber = "200011";
  Map<String, dynamic>? getAll;

  @override
  void initState() {
    super.initState();

    initData();
  }

  initData() async {
    if (widget.userData != null) {
      await getCurrentUserInfo();
      getAll = await Repo().getAll(
        baseUrl: widget.baseUrl,
        accessToken: widget.userData!["result"]["accessToken"],
        onError: (e) {
          print("Error in get all: ${e.toString()}");
        },
      );

      await connectToSocketServer();
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

    // Get extension data from current user info
    if (_currentUserInfo != null) {
      _extensionData = ExtensionData(
        username: _currentUserInfo!["user"]["extension"],
        password: _currentUserInfo!["user"]["sipPassword"],
        domain: "voice.omicx.vn",
        sipServer: "portsip.omicx.vn",
        port: 5060,
      );

      if (_extensionData != null) {
        // Register to SIP server
        await MptCallKitController().online(
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
    }
  }

  // // @override
  // @override
  // void dispose() {
  //   MptCallKitController().disposeSocket();
  //   super.dispose();
  // }

  // Connect to socket server
  Future<void> connectToSocketServer() async {
    print("connectToSocketServer");
    if (getAll != null) {
      SDKAbly(
        ablyKey: getAll!["ABLY_KEY"],
        clientId:
            "${_currentUserInfo!["tenant"]["id"]}_${_currentUserInfo!["user"]["id"]}_${_currentUserInfo!["user"]["userName"]}",
        onMessageReceived: (p0) {
          print("Message received: $p0");
        },
      );
    } else {
      print("Cannot connect agent to socket server");
    }
  }

  // Logout account
  void logout() async {
    var unregisterResult = false;
    var logoutResult = await MptCallkit().logout(
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

    if (MptCallKitController().isOnline) {
      unregisterResult = await MptCallKitController().offline();
    } else {
      unregisterResult = true;
    }

    if (logoutResult && unregisterResult) {
      Navigator.pop(context);
    }
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
            onPressed: () {
              Navigator.of(context).pop(true);
              logout();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
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
          body: Center(
            child: Column(
              children: [
                Text(
                  "Login status: ${widget.title}",
                ),
                const SizedBox(height: 10),
                StreamBuilder<bool>(
                  stream: MptCallKitController().onlineStatusController,
                  initialData: MptCallKitController().isOnline,
                  builder: (context, snapshot) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Text("SIP Status:"),
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
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (snapshot.data == true) {
                              // Nếu đang online thì chuyển sang offline
                              await MptCallKitController().offline(
                                onError: (error) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Lỗi: $error"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                              );
                            } else {
                              // Nếu đang offline thì chuyển sang online
                              if (_extensionData != null) {
                                await MptCallKitController().online(
                                  username: _extensionData!.username!,
                                  displayName: _extensionData!.username!,
                                  srtpType: 0,
                                  authName: _extensionData!.username!,
                                  password: _extensionData!.password!,
                                  userDomain: _extensionData!.domain!,
                                  sipServer: _extensionData!.sipServer!,
                                  sipServerPort: _extensionData!.port ?? 5060,
                                  transportType: 0,
                                  onError: (error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Lỗi: $error"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  phoneNumber: _outboundNumber,
                                  context: context,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Không có thông tin extension"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: snapshot.data == true
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                          child: Text(
                            snapshot.data == true ? "Offline" : "Online",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CallPad(
                                  apiKey: widget.apiKey,
                                  baseUrl: widget.baseUrl,
                                  ounboundNumber: _outboundNumber,
                                )),
                      );
                    },
                    child: const Text("Go to call-pad")),
              ],
            ),
          ),
        ));
  }
}
