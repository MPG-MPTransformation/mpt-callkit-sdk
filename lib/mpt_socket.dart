import 'dart:async';
import 'dart:convert';

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'controller/mpt_call_kit_controller.dart';
import 'mpt_call_kit_constant.dart';

// SocketIO
class MptSocketLiveConnect {
  static late IO.Socket socket;

  static final _connectionStatusController = StreamController<bool>.broadcast();

  static Stream<bool> get connectionStatusStream async* {
    yield socket.connected;
    yield* _connectionStatusController.stream;
  }

  static _connectSocket(String token, String url, String path) {
    socket = IO.io(
      url,
      IO.OptionBuilder()
          .setPath("/live-connect")
          .enableReconnection()
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setTransports(["websocket"]).setAuth({"token": token}).setQuery(
        {"env": "widget", "type": "agent"},
      ).build(),
    );
    socket.connect();

    _listenSocket();
  }

  static void _listenSocket() {
    socket.onConnect((_) {
      print('SocketIO connection established!');
      _connectionStatusController.add(true);
    });
    socket.onError((error) => print(error.toString()));
    socket.onConnectError((error) => print(error.toString()));
    socket.onDisconnect(
      (_) {
        print('SocketIO disconnected!');
        _connectionStatusController.add(false);
      },
    );

    socket.onReconnect((_) {
      print('Reconnected');
      _connectionStatusController.add(true);
    });

    socket.onReconnectFailed((_) {
      print('Reconnect failed!');
      _connectionStatusController.add(false);
    });
  }

  static void onDisconnect(VoidCallback callback) {
    socket.onDisconnect((_) {
      print('SocketIO disconnected!');
      callback();
    });
  }

  static bool isConnected() {
    return socket.connected;
  }

  static sendMessage(String? msg, List<dynamic>? files) {
    if ((msg == null || msg.isEmpty) && (files == null || files.isEmpty)) {
      print("Message and files are empty!");
      return;
    }

    if (msg != null && files != null && msg.isNotEmpty && files.isNotEmpty) {
      socket.emit("msg", {"text": msg, "attachments": []});
      socket.emit("msg", {"text": msg, "attachments": files});
      return;
    }

    socket.emit("msg", {"text": msg, "attachments": files});
  }

  static void onReceiveMessage(Function(dynamic) callback) {
    socket.on("msg", (data) {
      print('Data received: $data');
      callback(data);
    });
  }

  static Future<String> _getGuestToken({
    required String guestAPI,
    required String barrierToken,
    required String appId,
    required String phoneNumber,
    required String userName,
  }) async {
    var token = "";

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $barrierToken",
    };

    final body = {
      "phone": phoneNumber,
      "name": userName,
      "email": "string",
      "appId": appId,
    };

    try {
      final response = await http.post(
        Uri.parse(guestAPI),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            var data = responseData["data"];
            if (data != null) {
              token = data["token"];
              debugPrint("Token: $token");
            }
          }
        }
      } else {
        print('Failed to post data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }

    return token;
  }

  static Future<void> connectSocketByGuest(
    String url, {
    required String guestAPI,
    required String barrierToken,
    required String appId,
    required String phoneNumber,
    required String userName,
  }) async {
    var token = await _getGuestToken(
      guestAPI: "$url$guestAPI",
      barrierToken: barrierToken,
      appId: appId,
      phoneNumber: phoneNumber,
      userName: userName,
    );

    _connectSocket(token, url, "/live-connect");
  }

  // static Future<void> connectSocketByUser(
  //   String url, {
  //   required String token,
  // }) async {
  //   _connectSocket(token, url, "/socket-server");
  // }

  static void dispose() {
    _connectionStatusController.close();
    if (socket.connected) {
      socket.disconnect();
    }
  }
}

///SocketAbly class - socket server
class MptSocketSocketServer {
  static MptSocketSocketServer? _instance;

  static MptSocketSocketServer get instance {
    _instance ??= MptSocketSocketServer._internal();
    return _instance!;
  }

  String? ablyKey;
  int? tenantId;
  int? userId;
  String? userName;
  bool isConnecting = false;
  ably.Realtime? ablyClient;
  ably.RealtimeChannel? channel;
  ably.RealtimeChannel? conversationChannel;
  Function(ably.Message)? onMessageReceived;

  // Stream cho trạng thái agent
  StreamController<String> _agentStatusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _agentStatusController.stream;

  // Thêm Stream cho trạng thái kết nối socket
  StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Constructor private
  MptSocketSocketServer._internal();

  void setup({
    required String ablyKeyParam,
    required Function(ably.Message) onMessageReceivedParam,
    required int tenantIdParam,
    required int userIdParam,
    required String userNameParam,
  }) {
    /// Create a new stream controller if it is closed
    if (_agentStatusController.isClosed) {
      _agentStatusController = StreamController<String>.broadcast();
    }

    // Tạo lại connection status controller nếu đã đóng
    if (_connectionStatusController.isClosed) {
      _connectionStatusController = StreamController<bool>.broadcast();
    }

    // Gán tham số vào thuộc tính của lớp
    ablyKey = ablyKeyParam;
    onMessageReceived = onMessageReceivedParam;
    tenantId = tenantIdParam;
    userId = userIdParam;
    userName = userNameParam;

    _initAbly();
  }

  /// Initialize Ably connection
  void _initAbly() {
    // Kiểm tra null trước khi sử dụng
    if (ablyKey == null ||
        tenantId == null ||
        userId == null ||
        userName == null) {
      print("ERROR: Required parameters are null in _initAbly");
      print(
          "ablyKey: $ablyKey, tenantId: $tenantId, userId: $userId, userName: $userName");
      return;
    }

    print("Initializing Ably with clientId: ${tenantId}_${userId}_$userName");
    ablyClient = ably.Realtime(
      options: ably.ClientOptions(
        key: ablyKey!,
        clientId: "${tenantId}_${userId}_$userName",
      ),
    );

    ablyClient!.connection
        .on()
        .listen((ably.ConnectionStateChange stateChange) {
      print("Ably connection state changed: ${stateChange.current}");

      // Cập nhật trạng thái kết nối khi có thay đổi
      bool isConnected = stateChange.current == ably.ConnectionState.connected;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(isConnected);
      }

      if (isConnected) {
        print("Ably socket connected");
        isConnecting = true;
        _subscribeToChannelAgentStatus();
        _subscribeToConversationChannel();
      } else {
        print("Ably state change: ${stateChange.current}");
        isConnecting = false;
      }
    });
  }

  /// Subscribe to channel agent status
  void _subscribeToChannelAgentStatus() {
    if (tenantId == null || userId == null) {
      print("Error: tenantId or userId is null. Cannot subscribe to channel.");
      return;
    }

    String channelName = 'agent_status_${tenantId}_$userId';
    print("Ably subscribe to channel: $channelName");

    // Close old channel if exists
    if (channel != null) {
      try {
        channel!.detach();
      } catch (e) {
        print("Error detaching old channel: $e");
      }
    }

    // Create new channel and subscribe
    channel = ablyClient!.channels.get(channelName);

    try {
      channel!.subscribe().listen((ably.Message message) {
        print(
            "Received message on channel $channelName: ${message.name} - ${message.data}");
        _handleIncomingMessage(message);
      }, onError: (error) {
        print("Error subscribing to channel $channelName: $error");
      });
      print("Successfully subscribed to channel $channelName");
    } catch (e) {
      print("Exception while subscribing to channel $channelName: $e");
    }
  }

  /// Subscribe to conversation channel - called automatically during initialization
  void _subscribeToConversationChannel() {
    if (tenantId == null) {
      print(
          "Error: tenantId is null. Cannot subscribe to conversation channel.");
      return;
    }

    String channelName = 'conversation_$tenantId';
    print("Subscribing to conversation channel: $channelName");

    // Close old conversation channel if exists
    if (conversationChannel != null) {
      try {
        conversationChannel!.detach();
      } catch (e) {
        print("Error detaching old conversation channel: $e");
      }
    }

    try {
      conversationChannel = ablyClient!.channels.get(channelName);

      conversationChannel!.subscribe().listen((ably.Message message) async {
        print(
            "Received message on conversation channel $channelName: ${message.name} - ${message.data}");
        if (message.name == MessageAbly.ANSWER_CALL) {
          print("Received call message: ${message.data}");
          if (message.data is Map) {
            Map<dynamic, dynamic> data = message.data as Map<dynamic, dynamic>;
            var sessionId = data['sessionId'];
            print("hienhh: Session ID: $sessionId");

            if (data.containsKey('extraInfo')) {
              var extraInfo = jsonDecode(data['extraInfo']);

              if (extraInfo.containsKey('type')) {
                var callType = extraInfo['type'];

                if (callType.toString() == CallType.VIDEO.toString()) {
                  // Xử lý cuộc gọi video
                  try {
                    await MptCallKitController.channel
                        .invokeMethod('reInvite', {
                      'sessionId': sessionId.toString(),
                    });
                  } catch (e) {
                    print("Error invoking reinvite method: $e");
                  }
                } else {
                  print("hienhh: Call type has no video");
                }
              } else {
                print("hienhh: ExtraInfo has no type");
              }
            } else {
              print("hienhh: Data has no extraInfo");
            }
          }
        }
        if (onMessageReceived != null) {
          onMessageReceived!(message);
        }
      }, onError: (error) {
        print("Error subscribing to conversation channel $channelName: $error");
      });

      print("Successfully subscribed to conversation channel $channelName");
    } catch (e) {
      print(
          "Exception while subscribing to conversation channel $channelName: $e");
    }
  }

  /// Handle incoming message from Ably
  void _handleIncomingMessage(ably.Message message) {
    print("Handling message: ${message.name} with data: ${message.data}");

    if (message.name == "AGENT_STATUS_CHANGED" ||
        message.name == "agent_status_chat") {
      print("Processing agent status message: ${message.data}");

      Map<dynamic, dynamic>? data;
      try {
        if (message.data is Map) {
          data = message.data as Map<dynamic, dynamic>;
        } else if (message.data is String) {
          data = Map<String, dynamic>.from(jsonDecode(message.data as String));
        }
      } catch (e) {
        print("Error parsing message data: $e");
      }

      if (data != null) {
        final statusName = data['statusName'] as String?;
        if (statusName != null) {
          if (!_agentStatusController.isClosed) {
            print("Adding status to stream: $statusName");
            _agentStatusController.add(statusName);
          } else {
            print("Warning: Controller is closed. Creating a new one.");
            _agentStatusController = StreamController<String>.broadcast();
            _agentStatusController.add(statusName);
          }
        } else {
          print("statusName is null in data: $data");
        }
      } else {
        print("Could not parse data from message: ${message.data}");
      }
    } else {
      print("Message name not recognized: ${message.name}");
    }

    if (onMessageReceived != null) {
      onMessageReceived!(message);
    }
  }

  /// Send message to Ably
  Future<void> sendMessage(String name, dynamic data) async {
    if (channel == null) {
      print("Cannot send message: channel is null");
      return;
    }

    try {
      await channel!.publish(name: name, data: data);
      print("Ably sent message: $name - $data");
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  /// Send message to conversation channel
  Future<void> sendConversationMessage(String name, dynamic data) async {
    if (conversationChannel == null) {
      print("Cannot send conversation message: conversationChannel is null");
      return;
    }

    try {
      await conversationChannel!.publish(name: name, data: data);
      print("Ably sent conversation message: $name - $data");
    } catch (e) {
      print("Error sending conversation message: $e");
    }
  }

  /// Close connection
  Future<void> closeConnection() async {
    try {
      if (ablyClient != null) {
        if (channel != null) {
          await channel!.detach();
          print("Channel detached");
        }
        if (conversationChannel != null) {
          await conversationChannel!.detach();
          print("Conversation channel detached");
        }
        await ablyClient!.connection.close();
        print("Ably disconnected from Ably");
      } else {
        print("ablyClient is null, nothing to disconnect");
      }
    } catch (e) {
      print("Error disconnecting from Ably: $e");
    }
  }

  /// Close all resources
  Future<void> releaseResources() async {
    try {
      await closeConnection();

      if (!_agentStatusController.isClosed) {
        _agentStatusController.close();
      }

      // Đóng connection status controller
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.close();
      }
    } catch (e) {
      print("Error disposing MptSocketAbly instance: $e");
    }
  }

  /// Check connection state
  bool checkConnection() {
    return ablyClient != null &&
        ablyClient!.connection.state == ably.ConnectionState.connected;
  }

  /// IMPORTANT: Destroy instance
  static Future<void> destroyInstance() async {
    if (_instance != null) {
      await _instance!.releaseResources();
      _instance = null;
      print("MptSocketAbly instance destroyed successfully");
    }
  }

  /// Create a single instance
  static void initialize({
    required String ablyKeyParam,
    required Function(ably.Message) onMessageReceivedParam,
    required int tenantIdParam,
    required int userIdParam,
    required String userNameParam,
  }) {
    // Đảm bảo các tham số được chuyển đúng
    instance.setup(
      ablyKeyParam: ablyKeyParam,
      onMessageReceivedParam: onMessageReceivedParam,
      tenantIdParam: tenantIdParam,
      userIdParam: userIdParam,
      userNameParam: userNameParam,
    );
  }

  /// Stream static
  static Stream<String> get agentStatusEvent => instance.statusStream;

  /// Disconnect
  static Future<void> disconnect() async {
    if (_instance != null) {
      await _instance!.closeConnection();
    }
  }

  /// Check connection
  static bool isConnected() {
    return _instance != null && _instance!.checkConnection();
  }

  /// Stream static getter cho trạng thái kết nối
  static Stream<bool> get connectionStatus => instance.connectionStatusStream;

  /// Truy cập trạng thái kết nối hiện tại
  static bool getCurrentConnectionState() {
    return _instance != null && _instance!.checkConnection();
  }
}
