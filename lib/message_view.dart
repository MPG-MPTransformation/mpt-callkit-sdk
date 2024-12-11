import 'package:flutter/material.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:mpt_callkit/conversation/input/app_send_message_field.dart';

class MessageView extends StatelessWidget {
  const MessageView({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    GlobalKey<FlutterMentionsState> mentionsKey = GlobalKey<FlutterMentionsState>();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Expanded(child: Text(phoneNumber)),
            AppSendMessageField(
              mentionsKey: mentionsKey,
              onTextChange: (String text) {
                // AppToast.showWarning(message: text);
              },
              onSendPressed: () {
                /// do something here
              },
            )
          ],
        ),
      ),
    );
  }

}