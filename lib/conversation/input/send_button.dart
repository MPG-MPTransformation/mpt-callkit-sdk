import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SendButtonWidget extends StatelessWidget {
  const SendButtonWidget({super.key, this.onPressed, this.blur});

  final VoidCallback? onPressed;
  final bool? blur;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if(!(blur ?? true)) {
          onPressed?.call();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        color: Colors.white,
        child: Image.asset(
          'packages/mpt_callkit/lib/assets/images/send.png',
          // (blur ?? true) ? Icons.send : Icons.send_and_archive,
          width: 40,
          height: 40,
          color: (blur ?? true) ? Colors.grey : Colors.blue,
        )
      ),
    );
  }

}