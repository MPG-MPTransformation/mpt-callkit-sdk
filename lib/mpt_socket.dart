import 'dart:async';
import 'dart:convert';

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

// SocketIO
class MptSocket {
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
    socket.dispose();
  }
}

class MptSocketAbly {
  static late String ablyKey;
  static late int tenantId;
  static late int userId;
  static late String userName;
  static bool isConnecting = false;
  static late ably.Realtime ablyClient;
  static late ably.RealtimeChannel channel;
  static late Function(ably.Message) onMessageReceived;

  static final _agentStatusController = StreamController<String>.broadcast();

  static Stream<String> get agentStatusStream => _agentStatusController.stream;

  static void initialize({
    required String ablyKeyParam,
    required Function(ably.Message) onMessageReceivedParam,
    required int tenantIdParam,
    required int userIdParam,
    required String userNameParam,
  }) {
    ablyKey = ablyKeyParam;
    onMessageReceived = onMessageReceivedParam;
    tenantId = tenantIdParam;
    userId = userIdParam;
    userName = userNameParam;
    _initAbly();
  }

  /// Khởi tạo kết nối đến Ably
  static void _initAbly() {
    ablyClient = ably.Realtime(
      options: ably.ClientOptions(
        key: ablyKey,
        clientId: "${tenantId}_${userId}_$userName",
      ),
    );

    ablyClient.connection.on().listen((ably.ConnectionStateChange stateChange) {
      if (stateChange.current == ably.ConnectionState.connected) {
        print("Ably socket connected");
        isConnecting = true;
        // _subscribeToChannelConversationTenantId();
        _subscribeToChannelAgentStatus();
      } else {
        print("Ably state change: ${stateChange.current}");
        isConnecting = false;
      }
    });
  }

  /// Subscribe to channel conversation tenant id
  static void _subscribeToChannelConversationTenantId() {
    print("Ably subscribe to channels: conversation_$tenantId");
    channel = ablyClient.channels.get('conversation_$tenantId');
    channel.subscribe().listen((ably.Message message) {
      _handleIncomingMessage(message);
    });
  }

  /// Subscribe to channel agent status
  static void _subscribeToChannelAgentStatus() {
    print("Ably subscribe to channels: agent_status_${tenantId}_$userId");
    channel = ablyClient.channels.get('agent_status_${tenantId}_$userId');
    channel.subscribe().listen((ably.Message message) {
      _handleIncomingMessage(message);
    });
  }

  /// Xử lý tin nhắn đến từ kênh Ably
  static void _handleIncomingMessage(ably.Message message) {
    if (message.name == "AGENT_STATUS_CHANGED") {
      print("Ably received message: ${message.name} - ${message.data}");

      final data = message.data as Map<dynamic, dynamic>;
      final statusName = data['statusName'] as String?;
      if (statusName != null) {
        _agentStatusController.add(statusName);
      } else {
        print("statusName is null");
      }
    }
    onMessageReceived(message);
  }

  /// Gửi tin nhắn lên kênh
  static Future<void> sendMessage(String name, dynamic data) async {
    await channel.publish(name: name, data: data);
    print("Ably sent message: $name - $data");
  }

  /// Ngắt kết nối Ably
  static Future<void> disconnect() async {
    await ablyClient.connection.close();
    _agentStatusController.close(); // Close the stream controller
    print("Ably disconnected from Ably");
  }
}
