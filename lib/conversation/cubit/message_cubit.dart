import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mpt_callkit/conversation/cubit/helper/message_state_helper.dart';
import 'package:mpt_callkit/conversation/models/message.dart';

part 'message_state.dart';

class MessageCubit extends Cubit<MessageState> {
  MessageCubit() : super(const MessageInitial());

  Future<void> fetchMessage() async {
    state.toFetchingMessage();
    Future.delayed(
      const Duration(seconds: 5),
      () {
        state.toFetchMessageSuccess(value: mock);
      },
    );
  }
}

List<Message> mock = [
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
];
