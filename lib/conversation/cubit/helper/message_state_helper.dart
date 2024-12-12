import 'package:mpt_callkit/conversation/cubit/message_cubit.dart';
import 'package:mpt_callkit/conversation/models/message.dart';

extension MessageStateHelper on MessageState {
  MessageInitial toMessageInitial() =>
      const MessageInitial();

  FetchingMessage toFetchingMessage() =>
      FetchingMessage(messages: messages);

  FetchMessageSuccess toFetchMessageSuccess({required List<Message> value}) =>
      FetchMessageSuccess(messages: value);

  FetchMessageFail toFetchMessageFail({required String message}) =>
      FetchMessageFail(message: message, messages: messages);

  SendingMessageSuccess toSendingMessageSuccess({required List<Message> value}) =>
      SendingMessageSuccess(messages: value);
}