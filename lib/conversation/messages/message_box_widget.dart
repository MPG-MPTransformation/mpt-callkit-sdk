import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/conversation/models/message.dart';

enum MessageAppearanceType {
  unknown,
  text,
  image,
}

class MessageBoxWidget extends StatelessWidget {
  MessageBoxWidget({
    super.key,
    required this.message,
    required this.onLongPress,
    required this.onTap,
  });

  Message? message;
  VoidCallback onLongPress;
  VoidCallback onTap;

  MessageAppearanceType type = MessageAppearanceType.text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // onTap.call();
      },
      onLongPress: () {
        if (!_isOutgoingMessage) onLongPress.call();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildMessage(),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    switch (type) {
      case MessageAppearanceType.text:
        return _buildMessageText();
      case MessageAppearanceType.image:
        return _buildMessageImage();
      default:
        return Container();
    }
  }

  // private params
  bool get _isOutgoingMessage => message?.isMine ?? true;

  Widget _buildMessageText() {
    final child = Text(
      message?.message ?? "",
      style: TextStyle(color: _isOutgoingMessage ? Colors.white: Colors.black, fontSize: 14),
    );

    if (_isOutgoingMessage) {
      return _buildOutgoingMessage(
        _buildBackgroundOutgoingMessage(child: child),
      );
    } else {
      return _buildIncomingMessage(
        _buildBackgroundIncomingMessage(child: child),
      );
    }
  }

  Widget _buildOutgoingMessage(Widget child) {
    return Container(
      alignment: Alignment.centerRight,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingMessage(Widget child) {
    return Container(
      alignment: Alignment.centerLeft,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Row(
                children: [
                  Flexible(
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOutgoingMessage({
    required Widget child,
  }) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xff1250dc),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              child,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundIncomingMessage({
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 16, 0),
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Image.asset(
              'packages/mpt_callkit/lib/assets/images/avatar_example.png',
              // (blur ?? true) ? Icons.send : Icons.send_and_archive,
              width: 36,
              height: 36,
            )
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeMessage({
    required DateTime? time,
  }) {
    if (time == null) return Container();

    final format = DateFormat('HH:mm').format(time);
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            format,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xff576675),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageImage() {
    return Container();
  }

}
