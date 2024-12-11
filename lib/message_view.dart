import 'package:flutter/material.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:mpt_callkit/conversation/input/app_bar_widget.dart';
import 'package:mpt_callkit/conversation/input/app_send_message_field.dart';
import 'package:mpt_callkit/conversation/messages/list_message.dart';
import 'package:mpt_callkit/conversation/models/message.dart';

class MessageView extends StatelessWidget {
  const MessageView({required this.phoneNumber, super.key});

  final String phoneNumber;

  /// add comment
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffedf0f3),
      body: Stack(
        children: [
          Positioned(
            child: Align(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 10),
                child: ListMessageWidget(
                  messages: [
                    Message(
                      id: '1',
                      message: 'FPT Long Châu có thể hỗ trợ gì cho Anh/Chị ạ?',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '2',
                      message: 'Xin chào, tôi cần hỗ trợ mua thuốc',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '3',
                      message: 'Dạ em xin phép được gọi anh để tư vấn cụ thể hơn được không ạ?',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '4',
                      message: 'Hello 4',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '5',
                      message: 'Hello',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '6',
                      message: 'Hello 2',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '7',
                      message: 'Hello 3',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '8',
                      message: 'Hello 4',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '1',
                      message: 'Hello',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '2',
                      message: 'Hello 2',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '3',
                      message: 'Hello 3',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '4',
                      message: 'Hello 4',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '5',
                      message: 'Hello',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '6',
                      message: 'Hello 2',
                      createdAt: DateTime.now(),
                      isMine: true,
                    ),
                    Message(
                      id: '7',
                      message: 'Hello 3',
                      createdAt: DateTime.now(),
                      isMine: false,
                    ),
                    Message(
                      id: '8',
                      message: 'Hello 4',
                      createdAt: DateTime.now(),
                      isMine: true,
                    )
                  ],
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
