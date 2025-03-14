import 'package:example/components/repo.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_callkit.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.title, required this.userData});

  final String title;
  final Map<String, dynamic>? userData;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();
  final _baseUrl = "https://crm-dev-v2.metechvn.com";
  Map<String, dynamic>? _currentUserInfo;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "200011";
    _callTo.text = "20015";
    getCurrentUserInfo();
  }

  void getCurrentUserInfo() async {
    if (widget.userData != null) {
      _currentUserInfo = await Repo().getCurrentUserInfo(
        baseUrl: _baseUrl,
        accessToken: widget.userData!["result"]["accessToken"],
        onError: (e) {
          print("Error in get current user info: $e");
        },
      );
    } else {
      print("Access token is null");
    }
  }

  void logout() async {
    var logoutResult = await MptCallkit().logout(
      cloudAgentId: _currentUserInfo!["user"]["id"],
      cloudAgentName: _currentUserInfo!["user"]["fullName"] ?? "",
      cloudTenantId: _currentUserInfo!["tenant"]["id"],
      baseUrl: _baseUrl,
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
        title: const Text('Logout'),
        content: const Text('Do you want to logout from server?'),
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            MptCallKitController().initSdk(
              apiKey: "0c16d4aa-abe7-4098-b47a-7b914f9b7444",
              baseUrl: _baseUrl,
              userPhoneNumber: _phoneController.text,
            );
            MptCallKitController().makeCall(
                context: context,
                phoneNumber: _callTo.text,
                isVideoCall: true,
                onError: (errorMessage) {
                  if (errorMessage == null) return;
                  var snackBar = SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.grey,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                });
          },
          child: const Icon(Icons.call),
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                onPressed: () {
                  handleBackButton();
                },
                icon: const Icon(Icons.logout))
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Login status: ${widget.title}",
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _callTo,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Call to',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Text(
              'Click button to make a call',
            ),
          ],
        ),
      ),
    );
  }
}
