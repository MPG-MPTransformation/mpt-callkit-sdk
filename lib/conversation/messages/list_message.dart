import 'package:flutter/material.dart';
import 'package:mpt_callkit/conversation/messages/message_box_widget.dart';
import 'package:mpt_callkit/conversation/models/message.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' as refresh;

class ListMessageWidget extends StatelessWidget {
  ListMessageWidget({required this.messages, super.key});

  final List<Message> messages;
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final controller = refresh.RefreshController();
    return refresh.SmartRefresher(
      controller: controller,
      reverse: true,
      onLoading: () {
        /// do something here
      },
      enablePullUp: false,
      enablePullDown: false,
      footer: Container(),
      child: CustomScrollView(
        controller: _scrollController,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  Message? currMessage = messages[index];
                  return MessageBoxWidget(
                    message: currMessage,
                    onLongPress: () {
                      /// do something here
                    },
                    onTap: () {
                      /// do something here
                    },
                  );
                },
                // Or, uncomment the following line:
                childCount: messages.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

}