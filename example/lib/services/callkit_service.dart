import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();

  factory CallKitService() => _instance;

  CallKitService._internal();
  static String _currentUUID = Uuid().v4();

  static Future<void> showCallkitIncoming({
    required String callerName,
    required String callerNumber,
  }) async {
    _currentUUID = Uuid().v4();

    final params = CallKitParams(
      id: _currentUUID,
      nameCaller: callerName,
      appName: 'OmiCX',
      avatar: 'https://i.pravatar.cc/100',
      handle: callerNumber,
      type: 0,
      duration: 15000,
      textAccept: 'Trả lời',
      textDecline: 'Từ chối',
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#52c3cb',
        // backgroundUrl: 'assets/images/bg.jpg',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> endCallkit() async {
    print("endCallkit");
    await FlutterCallkitIncoming.endAllCalls();

    // or end specific call with uuid
    // await FlutterCallkitIncoming.endCall(uuid);
  }

  static Future<void> hideCallKit() async {
    CallKitParams params = CallKitParams(
      id: _currentUUID,
    );
    await FlutterCallkitIncoming.hideCallkitIncoming(params);
  }
}
