import 'package:mpt_callkit/mpt_call_kit_constant.dart';

/// SDKCallServices class chứa các callback của call state từ native code
/// Các callback này được gọi từ PortSIP SDK callbacks trong iOS và Android
///
/// Sử dụng Singleton pattern để đảm bảo chỉ có một instance duy nhất
///
/// Example:
/// ```dart
/// // Đăng ký callbacks
/// SDKCallServices.instance.onInviteIncoming = (sessionId, caller, ...) {
///   print('Cuộc gọi đến từ: $caller');
/// };
///
/// // Callbacks sẽ tự động được gọi khi có sự kiện từ native
/// ```
class SDKCallServices {
  // Singleton instance
  static final SDKCallServices _instance = SDKCallServices._internal();

  /// Lấy instance duy nhất của SDKCallServices
  static SDKCallServices get instance => _instance;

  /// Private constructor
  SDKCallServices._internal();

  /// Factory constructor trả về singleton instance
  factory SDKCallServices() => _instance;
  // ============================================================================
  // REGISTRATION CALLBACKS
  // ============================================================================

  /// Called when SIP registration succeeds
  /// [statusText] - Status message from server
  /// [statusCode] - SIP status code
  /// [sipMessage] - Full SIP message
  Function(String statusText, int statusCode, String sipMessage)?
      onRegisterSuccess;

  /// Called when SIP registration fails
  /// [statusText] - Status message from server
  /// [statusCode] - SIP status code
  /// [sipMessage] - Full SIP message
  Function(String statusText, int statusCode, String sipMessage)?
      onRegisterFailure;

  // ============================================================================
  // INVITE CALLBACKS - Incoming Call
  // ============================================================================

  /// Called when receiving an incoming call
  /// [sessionId] - Unique session identifier
  /// [callerDisplayName] - Display name of caller
  /// [caller] - Caller's SIP URI
  /// [calleeDisplayName] - Display name of callee
  /// [callee] - Callee's SIP URI
  /// [audioCodecNames] - Audio codecs negotiated
  /// [videoCodecNames] - Video codecs negotiated
  /// [existsAudio] - Whether audio stream exists
  /// [existsVideo] - Whether video stream exists
  /// [sipMessage] - Full SIP INVITE message
  Function(
      int sessionId,
      String callerDisplayName,
      String caller,
      String calleeDisplayName,
      String callee,
      String audioCodecNames,
      String videoCodecNames,
      bool existsAudio,
      bool existsVideo,
      String sipMessage)? onInviteIncoming;

  // ============================================================================
  // INVITE CALLBACKS - Call Progress
  // ============================================================================

  /// Called when outgoing call is trying (100 Trying received)
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onInviteTrying;

  /// Called when call session is progressing (183 Session Progress)
  /// [sessionId] - Unique session identifier
  /// [audioCodecNames] - Audio codecs negotiated
  /// [videoCodecNames] - Video codecs negotiated
  /// [existsAudio] - Whether audio stream exists
  /// [existsVideo] - Whether video stream exists
  /// [sipMessage] - Full SIP message
  Function(
      int sessionId,
      String audioCodecNames,
      String videoCodecNames,
      bool existsAudio,
      bool existsVideo,
      String sipMessage)? onInviteSessionProgress;

  /// Called when remote party is ringing (180 Ringing)
  /// [sessionId] - Unique session identifier
  /// [statusText] - Status message
  /// [statusCode] - SIP status code
  /// [sipMessage] - Full SIP message
  Function(int sessionId, String statusText, int statusCode, String sipMessage)?
      onInviteRinging;

  /// Called when call is answered (200 OK received)
  /// [sessionId] - Unique session identifier
  /// [callerDisplayName] - Display name of caller
  /// [caller] - Caller's SIP URI
  /// [calleeDisplayName] - Display name of callee
  /// [callee] - Callee's SIP URI
  /// [audioCodecs] - Audio codecs negotiated
  /// [videoCodecs] - Video codecs negotiated
  /// [existsAudio] - Whether audio stream exists
  /// [existsVideo] - Whether video stream exists
  /// [sipMessage] - Full SIP message
  Function(
      int sessionId,
      String callerDisplayName,
      String caller,
      String calleeDisplayName,
      String callee,
      String audioCodecs,
      String videoCodecs,
      bool existsAudio,
      bool existsVideo,
      String sipMessage)? onInviteAnswered;

  /// Called when call fails
  /// [sessionId] - Unique session identifier
  /// [callerDisplayName] - Display name of caller
  /// [caller] - Caller's SIP URI
  /// [calleeDisplayName] - Display name of callee
  /// [callee] - Callee's SIP URI
  /// [reason] - Failure reason
  /// [code] - SIP error code
  /// [sipMessage] - Full SIP message
  Function(
      int sessionId,
      String callerDisplayName,
      String caller,
      String calleeDisplayName,
      String callee,
      String reason,
      int code,
      String sipMessage)? onInviteFailure;

  /// Called when call is connected (ACK sent/received)
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onInviteConnected;

  /// Called when call is closed/terminated
  /// [sessionId] - Unique session identifier
  /// [sipMessage] - Full SIP BYE message
  Function(int sessionId, String sipMessage)? onInviteClosed;

  // ============================================================================
  // CALL UPDATE CALLBACKS
  // ============================================================================

  /// Called when call is updated (re-INVITE)
  /// [sessionId] - Unique session identifier
  /// [audioCodecs] - Audio codecs
  /// [videoCodecs] - Video codecs
  /// [screenCodecs] - Screen sharing codecs
  /// [existsAudio] - Whether audio stream exists
  /// [existsVideo] - Whether video stream exists
  /// [existsScreen] - Whether screen sharing exists
  /// [sipMessage] - Full SIP message
  Function(
      int sessionId,
      String audioCodecs,
      String videoCodecs,
      String screenCodecs,
      bool existsAudio,
      bool existsVideo,
      bool existsScreen,
      String sipMessage)? onInviteUpdated;

  // ============================================================================
  // HOLD/UNHOLD CALLBACKS
  // ============================================================================

  /// Called when remote party puts call on hold
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onRemoteHold;

  /// Called when remote party resumes call from hold
  /// [sessionId] - Unique session identifier
  /// [audioCodecs] - Audio codecs
  /// [videoCodecs] - Video codecs
  /// [existsAudio] - Whether audio stream exists
  /// [existsVideo] - Whether video stream exists
  Function(int sessionId, String audioCodecs, String videoCodecs,
      bool existsAudio, bool existsVideo)? onRemoteUnHold;

  // ============================================================================
  // TRANSFER CALLBACKS
  // ============================================================================

  /// Called when receiving a call transfer (REFER)
  /// [sessionId] - Unique session identifier
  /// [referId] - Reference identifier
  /// [to] - Transfer target
  /// [from] - Transfer initiator
  /// [referSipMessage] - Full REFER message
  Function(int sessionId, int referId, String to, String from,
      String referSipMessage)? onReceivedRefer;

  /// Called when call transfer is accepted
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onReferAccepted;

  /// Called when call transfer is rejected
  /// [sessionId] - Unique session identifier
  /// [reason] - Rejection reason
  /// [code] - SIP error code
  Function(int sessionId, String reason, int code)? onReferRejected;

  /// Called when transfer target is trying
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onTransferTrying;

  /// Called when transfer target is ringing
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onTransferRinging;

  /// Called when attended transfer succeeds
  /// [sessionId] - Unique session identifier
  Function(int sessionId)? onACTVTransferSuccess;

  /// Called when attended transfer fails
  /// [sessionId] - Unique session identifier
  /// [reason] - Failure reason
  /// [code] - SIP error code
  Function(int sessionId, String reason, int code)? onACTVTransferFailure;

  // ============================================================================
  // MESSAGE CALLBACKS
  // ============================================================================

  /// Called when receiving an instant message
  /// [sessionId] - Unique session identifier
  /// [mimeType] - MIME type of message
  /// [subMimeType] - Sub MIME type
  /// [messageData] - Message content as bytes
  /// [messageLength] - Length of message
  Function(int sessionId, String mimeType, String subMimeType,
      List<int> messageData, int messageLength)? onRecvMessage;

  /// Called when sending message succeeds
  /// [sessionId] - Unique session identifier
  /// [messageId] - Message identifier
  /// [sipMessage] - Full SIP message
  Function(int sessionId, int messageId, String sipMessage)?
      onSendMessageSuccess;

  /// Called when sending message fails
  /// [sessionId] - Unique session identifier
  /// [messageId] - Message identifier
  /// [reason] - Failure reason
  /// [code] - SIP error code
  /// [sipMessage] - Full SIP message
  Function(int sessionId, int messageId, String reason, int code,
      String sipMessage)? onSendMessageFailure;

  /// Called when receiving out-of-dialog message
  /// [fromDisplayName] - Sender's display name
  /// [from] - Sender's SIP URI
  /// [toDisplayName] - Recipient's display name
  /// [to] - Recipient's SIP URI
  /// [mimeType] - MIME type
  /// [subMimeType] - Sub MIME type
  /// [messageData] - Message content
  /// [messageLength] - Message length
  /// [sipMessage] - Full SIP message
  Function(
      String fromDisplayName,
      String from,
      String toDisplayName,
      String to,
      String mimeType,
      String subMimeType,
      List<int> messageData,
      int messageLength,
      String sipMessage)? onRecvOutOfDialogMessage;

  /// Called when sending out-of-dialog message succeeds
  /// [messageId] - Message identifier
  /// [fromDisplayName] - Sender's display name
  /// [from] - Sender's SIP URI
  /// [toDisplayName] - Recipient's display name
  /// [to] - Recipient's SIP URI
  /// [sipMessage] - Full SIP message
  Function(
      int messageId,
      String fromDisplayName,
      String from,
      String toDisplayName,
      String to,
      String sipMessage)? onSendOutOfDialogMessageSuccess;

  /// Called when sending out-of-dialog message fails
  /// [messageId] - Message identifier
  /// [fromDisplayName] - Sender's display name
  /// [from] - Sender's SIP URI
  /// [toDisplayName] - Recipient's display name
  /// [to] - Recipient's SIP URI
  /// [reason] - Failure reason
  /// [code] - SIP error code
  /// [sipMessage] - Full SIP message
  Function(
      int messageId,
      String fromDisplayName,
      String from,
      String toDisplayName,
      String to,
      String reason,
      int code,
      String sipMessage)? onSendOutOfDialogMessageFailure;

  // ============================================================================
  // PRESENCE CALLBACKS
  // ============================================================================

  /// Called when receiving presence subscription request
  /// [subscribeId] - Subscription identifier
  /// [fromDisplayName] - Subscriber's display name
  /// [from] - Subscriber's SIP URI
  /// [subject] - Subscription subject
  Function(
          int subscribeId, String fromDisplayName, String from, String subject)?
      onPresenceRecvSubscribe;

  /// Called when presence status changes to online
  /// [fromDisplayName] - User's display name
  /// [from] - User's SIP URI
  /// [stateText] - Presence state text
  Function(String fromDisplayName, String from, String stateText)?
      onPresenceOnline;

  /// Called when presence status changes to offline
  /// [fromDisplayName] - User's display name
  /// [from] - User's SIP URI
  Function(String fromDisplayName, String from)? onPresenceOffline;

  // ============================================================================
  // MEDIA CALLBACKS
  // ============================================================================

  /// Called when playing audio file finishes
  /// [sessionId] - Unique session identifier
  /// [fileName] - Name of audio file
  Function(int sessionId, String fileName)? onPlayFileFinished;

  /// Called when receiving DTMF tone
  /// [sessionId] - Unique session identifier
  /// [tone] - DTMF tone code
  Function(int sessionId, int tone)? onRecvDtmfTone;

  // ============================================================================
  // OTHER CALLBACKS
  // ============================================================================

  /// Called periodically with call statistics
  /// [sessionId] - Unique session identifier
  /// [statistics] - Statistics data (JSON format)
  Function(int sessionId, String statistics)? onStatistics;

  /// Called when receiving SIP OPTIONS request
  /// [optionsMessage] - Full OPTIONS message
  Function(String optionsMessage)? onRecvOptions;

  /// Called when receiving SIP INFO request
  /// [infoMessage] - Full INFO message
  Function(String infoMessage)? onRecvInfo;

  /// Called when receiving SIP signaling (for debugging)
  /// [sessionId] - Unique session identifier
  /// [message] - SIP message
  Function(int sessionId, String message)? onReceivedSignaling;

  /// Called when sending SIP signaling (for debugging)
  /// [sessionId] - Unique session identifier
  /// [message] - SIP message
  Function(int sessionId, String message)? onSendingSignaling;

  /// Called when call is being forwarded
  /// [forwardTo] - Forward destination
  Function(String forwardTo)? onInviteBeginingForward;

  /// Called when dialog state is updated
  /// [btsId] - BTS identifier
  /// [callId] - Call identifier
  /// [dialogStatus] - Dialog status
  /// [sipMessage] - Full SIP message
  Function(String btsId, String callId, String dialogStatus, String sipMessage)?
      onDialogStateUpdated;

  /// Called when receiving notification of subscription
  /// [subscribeId] - Subscription identifier
  /// [notifyMessage] - Notification message
  /// [messageData] - Message content
  /// [messageLength] - Message length
  Function(int subscribeId, String notifyMessage, List<int> messageData,
      int messageLength)? onRecvNotifyOfSubscription;

  /// Called when subscription fails
  /// [subscribeId] - Subscription identifier
  /// [statusCode] - SIP status code
  Function(int subscribeId, int statusCode)? onSubscriptionFailure;

  /// Called when subscription is terminated
  /// [subscribeId] - Subscription identifier
  Function(int subscribeId)? onSubscriptionTerminated;

  /// Called when there's a waiting voice message
  /// [messageAccount] - Message account
  /// [urgentNewMessageCount] - Count of urgent new messages
  /// [urgentOldMessageCount] - Count of urgent old messages
  /// [newMessageCount] - Count of new messages
  /// [oldMessageCount] - Count of old messages
  Function(
      String messageAccount,
      int urgentNewMessageCount,
      int urgentOldMessageCount,
      int newMessageCount,
      int oldMessageCount)? onWaitingVoiceMessage;

  /// Called when there's a waiting fax message
  /// [messageAccount] - Message account
  /// [urgentNewMessageCount] - Count of urgent new messages
  /// [urgentOldMessageCount] - Count of urgent old messages
  /// [newMessageCount] - Count of new messages
  /// [oldMessageCount] - Count of old messages
  Function(
      String messageAccount,
      int urgentNewMessageCount,
      int urgentOldMessageCount,
      int newMessageCount,
      int oldMessageCount)? onWaitingFaxMessage;

  // ============================================================================
  // AUDIO/VIDEO RAW DATA CALLBACKS (for advanced processing)
  // ============================================================================

  /// Called when receiving audio raw data callback
  /// [sessionId] - Unique session identifier
  /// [callbackType] - Type of callback
  /// [audioData] - Raw audio data
  /// [dataLength] - Length of data
  /// [samplingFreqHz] - Sampling frequency
  Function(int sessionId, int callbackType, List<int> audioData, int dataLength,
      int samplingFreqHz)? onAudioRawCallback;

  /// Called when receiving video raw data callback
  /// [sessionId] - Unique session identifier
  /// [callbackType] - Type of callback
  /// [width] - Video width
  /// [height] - Video height
  /// [videoData] - Raw video data
  /// [dataLength] - Length of data
  Function(int sessionId, int callbackType, int width, int height,
      List<int> videoData, int dataLength)? onVideoRawCallback;

  /// Called when receiving RTP packet callback
  /// [sessionId] - Unique session identifier
  /// [mediaType] - Media type (audio/video)
  /// [direction] - Direction (send/receive)
  /// [rtpPacket] - RTP packet data
  /// [packetSize] - Packet size
  Function(int sessionId, int mediaType, int direction, List<int> rtpPacket,
      int packetSize)? onRTPPacketCallback;

  /// Internal static method để xử lý callbacks từ native
  /// Sử dụng singleton instance để gọi callbacks
  static void setCallStateCallBack(Map<String, dynamic> callStateData) {
    final String state = callStateData['state'] as String;
    final instance = SDKCallServices.instance; // ✅ Dùng singleton instance

    switch (state) {
      case CallStateConstants.INCOMING:
        instance.onInviteIncoming?.call(
          callStateData['sessionId'] as int,
          callStateData['callerDisplayName'] as String? ?? '',
          callStateData['caller'] as String? ?? '',
          callStateData['calleeDisplayName'] as String? ?? '',
          callStateData['callee'] as String? ?? '',
          callStateData['audioCodecNames'] as String? ?? '',
          callStateData['videoCodecNames'] as String? ?? '',
          callStateData['existsAudio'] as bool? ?? false,
          callStateData['existsVideo'] as bool? ?? false,
          callStateData['sipMessage'] as String? ?? '',
        );
        break;

      case CallStateConstants.TRYING:
        instance.onInviteTrying?.call(
          callStateData['sessionId'] as int,
        );
        break;

      case CallStateConstants.ANSWERED:
        instance.onInviteAnswered?.call(
          callStateData['sessionId'] as int,
          callStateData['callerDisplayName'] as String? ?? '',
          callStateData['caller'] as String? ?? '',
          callStateData['calleeDisplayName'] as String? ?? '',
          callStateData['callee'] as String? ?? '',
          callStateData['audioCodecs'] as String? ?? '',
          callStateData['videoCodecs'] as String? ?? '',
          callStateData['existsAudio'] as bool? ?? false,
          callStateData['existsVideo'] as bool? ?? false,
          callStateData['sipMessage'] as String? ?? '',
        );
        break;

      case CallStateConstants.FAILED:
        instance.onInviteFailure?.call(
          callStateData['sessionId'] as int,
          callStateData['callerDisplayName'] as String? ?? '',
          callStateData['caller'] as String? ?? '',
          callStateData['calleeDisplayName'] as String? ?? '',
          callStateData['callee'] as String? ?? '',
          callStateData['reason'] as String? ?? '',
          callStateData['code'] as int? ?? 0,
          callStateData['sipMessage'] as String? ?? '',
        );
        break;

      case CallStateConstants.CLOSED:
        instance.onInviteClosed?.call(
          callStateData['sessionId'] as int,
          callStateData['sipMessage'] as String? ?? '',
        );
        break;

      case CallStateConstants.CONNECTED:
        instance.onInviteConnected?.call(
          callStateData['sessionId'] as int,
        );
        break;

      case CallStateConstants.UPDATED:
        instance.onInviteUpdated?.call(
          callStateData['sessionId'] as int,
          callStateData['audioCodecs'] as String? ?? '',
          callStateData['videoCodecs'] as String? ?? '',
          callStateData['screenCodecs'] as String? ?? '',
          callStateData['existsAudio'] as bool? ?? false,
          callStateData['existsVideo'] as bool? ?? false,
          callStateData['existsScreen'] as bool? ?? false,
          callStateData['sipMessage'] as String? ?? '',
        );
        break;

      default:
        print('Unknown call state: $state');
    }
  }
}
