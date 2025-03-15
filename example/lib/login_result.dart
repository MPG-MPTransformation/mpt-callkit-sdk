import 'package:example/call_pad.dart';
import 'package:example/components/repo.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/mpt_callkit.dart';

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

  @override
  void initState() {
    super.initState();

    getCurrentUserInfo();
  }

  void getCurrentUserInfo() async {
    if (widget.userData != null) {
      _currentUserInfo = await Repo().getCurrentUserInfo(
        baseUrl: widget.baseUrl,
        accessToken: widget.userData!["result"]["accessToken"],
        onError: (e) {
          print("Error in get current user info: $e");
        },
      );

      if (_currentUserInfo != null) {
        _extensionData = ExtensionData(
          username: _currentUserInfo!["user"]["extension"],
          password: _currentUserInfo!["user"]["sipPassword"],
          domain: "voice.omicx.vn",
          sipServer: "portsip.omicx.vn",
          port: 5060,
        );
      }
    } else {
      print("Access token is null");
    }
  }

  void logout() async {
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

    if (logoutResult) {
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
                OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CallPad(
                                  apiKey: widget.apiKey,
                                  baseUrl: widget.baseUrl,
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
