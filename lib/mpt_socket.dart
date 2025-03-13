import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MptSocket {
  static late IO.Socket socket;

  static final _connectionStatusController = StreamController<bool>.broadcast();

  static Stream<bool> get connectionStatusStream async* {
    yield socket.connected;
    yield* _connectionStatusController.stream;
  }

  static _connectSocket(String token, String url) {
    socket = IO.io(
      url,
      IO.OptionBuilder()
          .setPath("/live-connect")
          .enableReconnection()
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setTransports(["websocket"]).setAuth({"token": token}).setQuery(
        {"env": "widget", "type": "guest"},
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

  static Future<void> connectSocket(
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

    _connectSocket(token, url);
  }

  static void dispose() {
    _connectionStatusController.close();
    socket.dispose();
  }
}
