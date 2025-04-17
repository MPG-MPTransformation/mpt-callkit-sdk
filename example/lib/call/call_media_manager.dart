import 'package:mpt_callkit/mpt_socket.dart';

/// Hằng số cho loại cuộc gọi
class MediaCallType {
  static const String OUTGOING_CALL = "OUTGOING_CALL";
  static const String INCOMING_CALL = "INCOMING_CALL";
}

/// Quản lý trạng thái media (micro, camera) trong cuộc gọi
class CallMediaManager {
  static String? _currentSessionId;
  static String? _callType;

  /// Khởi tạo thông tin cuộc gọi
  static Future<bool> initializeCall({
    required String sessionId,
    required String callType, // "OUTGOING_CALL" hoặc "INCOMING_CALL"
  }) async {
    _currentSessionId = sessionId;
    _callType = callType;

    // Khởi tạo kênh với trạng thái mặc định
    return await _initializeMediaChannel();
  }

  /// Tạo kênh và thiết lập trạng thái mặc định
  static Future<bool> _initializeMediaChannel() async {
    if (_currentSessionId == null) return false;

    // Trạng thái mặc định: tất cả đều bật
    try {
      final success = await MptSocketSocketServer.sendToChannel(
          'call_media_status_$_currentSessionId', 'media_status_update', {
        "callerMicEnabled": true,
        "calleeMicEnabled": true,
        "callerCameraEnabled": true,
        "calleeCameraEnabled": true,
      });

      if (success) {
        print("Media channel initialized successfully with default values");
      } else {
        print("Failed to initialize media channel");
      }

      return success;
    } catch (e) {
      print("Error initializing media channel: $e");
      return false;
    }
  }

  /// Cập nhật trạng thái microphone của user hiện tại
  static Future<bool> updateMicrophoneStatus(bool isEnabled) async {
    if (_currentSessionId == null || _callType == null) {
      print("Cannot update mic status: Missing session information");
      return false;
    }

    bool isCurrentUserCaller = _callType == MediaCallType.OUTGOING_CALL;

    Map<String, dynamic> updateData = {};

    // Cập nhật trường tương ứng dựa vào vai trò của người dùng hiện tại
    if (isCurrentUserCaller) {
      updateData["callerMicEnabled"] = isEnabled;
    } else {
      updateData["calleeMicEnabled"] = isEnabled;
    }

    try {
      final success = await MptSocketSocketServer.sendToChannel(
          'call_media_status_$_currentSessionId',
          'media_status_update',
          updateData);

      if (success) {
        print(
            "Microphone status updated successfully: ${isEnabled ? 'ON' : 'OFF'}");
      } else {
        print("Failed to update microphone status");
      }

      return success;
    } catch (e) {
      print("Error updating microphone status: $e");
      return false;
    }
  }

  /// Cập nhật trạng thái camera của user hiện tại
  static Future<bool> updateCameraStatus(bool isEnabled) async {
    if (_currentSessionId == null || _callType == null) {
      print("Cannot update camera status: Missing session information");
      return false;
    }

    bool isCurrentUserCaller = _callType == MediaCallType.OUTGOING_CALL;

    Map<String, dynamic> updateData = {};

    // Cập nhật trường tương ứng dựa vào vai trò của người dùng hiện tại
    if (isCurrentUserCaller) {
      updateData["callerCameraEnabled"] = isEnabled;
    } else {
      updateData["calleeCameraEnabled"] = isEnabled;
    }

    try {
      final success = await MptSocketSocketServer.sendToChannel(
          'call_media_status_$_currentSessionId',
          'media_status_update',
          updateData);

      if (success) {
        print(
            "Camera status updated successfully: ${isEnabled ? 'ON' : 'OFF'}");
      } else {
        print("Failed to update camera status");
      }

      return success;
    } catch (e) {
      print("Error updating camera status: $e");
      return false;
    }
  }

  /// Đăng ký lắng nghe thay đổi trạng thái
  static void subscribeToMediaUpdates(
      Function(Map<String, dynamic>) onMediaUpdate) {
    if (_currentSessionId == null) {
      print("Cannot subscribe: No active call session");
      return;
    }

    MptSocketSocketServer.subscribeToChannel(
        'call_media_status_$_currentSessionId', (message) {
      if (message.name == 'media_status_update' && message.data is Map) {
        onMediaUpdate(message.data as Map<String, dynamic>);
      }
    });
  }

  /// Xóa thông tin khi kết thúc cuộc gọi
  static void clearCallData() {
    _currentSessionId = null;
    _callType = null;
  }

  /// Kiểm tra xem user hiện tại có phải là người gọi không
  static bool isCurrentUserCaller() {
    return _callType == MediaCallType.OUTGOING_CALL;
  }

  /// Kiểm tra xem user hiện tại có phải là người nhận không
  static bool isCurrentUserCallee() {
    return _callType == MediaCallType.INCOMING_CALL;
  }

  /// Kiểm tra xem có phiên cuộc gọi đang hoạt động không
  static bool hasActiveCall() {
    return _currentSessionId != null;
  }

  /// Lấy session ID của cuộc gọi hiện tại
  static String? get currentSessionId => _currentSessionId;
}
