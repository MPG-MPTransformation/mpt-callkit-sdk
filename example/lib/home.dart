import 'package:flutter/material.dart';
import 'package:mpt_callkit/chat_socket.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/float_button/floating_button.dart';

import 'bubble_chat/bubble_chat_view.dart';
import 'share_pref/share_pref.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.isFirstLogin = false,
  });

  final bool? isFirstLogin;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final userInfo = SharePref.getInfo();

  connectChat() async {
    await ChatSocket.connectChat(
      userInfo!["baseUrl"],
      guestAPI: '/integration/security/guest-token',
      barrierToken: userInfo!["apiKey"],
      appId: '88888888',
      phoneNumber: userInfo!["phoneNumber"],
      userName: userInfo!["name"],
    );

    if (widget.isFirstLogin == true) {
      ChatSocket.sendMessage(
          "Chat session is being connected from mobile", null);
    }
  }

  initCallSDK() {
    MptCallKitController().initSdk(
      apiKey: userInfo!["apiKey"],
      baseUrl: userInfo!["baseUrl"],
      userPhoneNumber: userInfo!["phoneNumber"],
    );
  }

  @override
  void initState() {
    super.initState();
    connectChat();
    // initCallSDK();
  }

  @override
  // void dispose() {
  //   ChatSocket.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return FloatingMenuButtonView(
      panelBackgroundColor: const Color(0xFFEDEDED),
      panelContentColor: Colors.black,
      panelBorderRadius: BorderRadius.circular(20.0),
      panelDockType: DockType.inside,
      panelDockOffset: 5.0,
      panelAnimDuration: 300,
      panelAnimCurve: Curves.easeOut,
      panelDockAnimDuration: 300,
      panelDockAnimCurve: Curves.easeOut,
      panelIcon: Icons.menu,
      panelSize: 50.0,
      panelIconSize: 24.0,
      panelBorderWidth: 1.0,
      panelBorderColor: Colors.black,
      panelOnPressed: (index) {},
      popupView: BubbleChatView(phoneNumber: userInfo!["phoneNumber"]),
      popupBorderRadius: BorderRadius.circular(10),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OmiCX v2 callkit demo'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Base-Url: ${userInfo!["baseUrl"]}"),
            Text("API-Key: ${userInfo!["apiKey"]}"),
            Text("Name: ${userInfo!["name"]}"),
            Text("Phone-number: ${userInfo!["phoneNumber"]}"),
          ],
        ),
      ),
    );
  }
}
