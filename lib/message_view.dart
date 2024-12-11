import 'package:flutter/material.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:mpt_callkit/conversation/input/app_bar_widget.dart';
import 'package:mpt_callkit/conversation/input/app_send_message_field.dart';

class MessageView extends StatelessWidget {
  const MessageView({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Stack(
        children: [
          Positioned(
            child: Align(
              child: ColoredBox(
                color: Colors.green,
                child: Center(
                  child: Text(phoneNumber),
                ),
              ),
            ),
          ),
          Positioned(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildAppBar(context))),
          Positioned(child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildSendButton(context))),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
            aspectRatio: 375 / 100,
            child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Image.asset(
                  'packages/mpt_callkit/lib/assets/images/communication_bg.png',
                  fit: BoxFit.cover,
                ))),
        Positioned.fill(
          top: 44,
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                          'packages/mpt_callkit/lib/assets/images/back.png',
                          width: 24,
                          height: 24),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Bs. Lương Văn Luân',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // do something here
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                          'packages/mpt_callkit/lib/assets/images/call.png',
                          width: 24,
                          height: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    GlobalKey<FlutterMentionsState> mentionsKey =
        GlobalKey<FlutterMentionsState>();
    return AppSendMessageField(
      mentionsKey: mentionsKey,
      onTextChange: (String text) {
        // AppToast.showWarning(message: text);
      },
      onSendPressed: () {
        /// do something here
      },
    );
  }
}
