part of 'message_cubit.dart';

abstract class MessageState extends Equatable {
  const MessageState({this.messages});
  final List<Message>? messages;

  @override
  List<Object?> get props => [messages];
}

final class MessageInitial extends MessageState {
  const MessageInitial({super.messages});
}

final class FetchingMessage extends MessageState {
  const FetchingMessage({super.messages});
}

final class FetchMessageSuccess extends MessageState {
  const FetchMessageSuccess({super.messages});
}

final class FetchMessageFail extends MessageState {
  final String message;
  const FetchMessageFail({super.messages, required this.message});
}

final class SendingMessageSuccess extends MessageState {
  const SendingMessageSuccess({super.messages});
}


