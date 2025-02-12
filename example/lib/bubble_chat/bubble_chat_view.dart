import 'package:example/bubble_chat/bubble_chat_footer.dart';
import 'package:example/call_screen/call_screen.dart';
import 'package:example/chat_screen/chat_screen.dart';
import 'package:flutter/material.dart';

import 'bubble_header.dart';

class BubbleChatView extends StatelessWidget {
  const BubbleChatView({
    super.key,
    required this.phoneNumber,
  });

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Column(
          children: [
            const BubbleHeader(),
            Expanded(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ChatScreen(userId: phoneNumber)));
                    },
                    child: const Text("Chat"),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CallScreen()));
                  },
                  child: const Text("Call"),
                ),
              ],
            )),
            const BubbleChatFooter(),
          ],
        ),
      ),
    );
  }
}
