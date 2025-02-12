import 'package:example/call_screen/call_screen.dart';
import 'package:flutter/material.dart';

class BubbleHeader extends StatelessWidget {
  const BubbleHeader({
    super.key,
  });

  routeToCallScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xff021c6b),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          children: [
            Text(
              "OmiCX Version 2",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  decoration: TextDecoration.none),
            ),
            Expanded(
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
