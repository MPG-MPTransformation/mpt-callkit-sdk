// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/models/models.dart';
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
          .setTransports(["websocket"]).setExtraHeaders(
              {"Authorization": "Bearer $token"}).setQuery({
        "env": "widget",
        "type": "agent",
      }).build(),
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
  // Add a Set to store subscribed rooms
  final Set<String> _subscribedRooms = {};

  static MptSocketSocketServer get instance {
    _instance ??= MptSocketSocketServer._internal();
    return _instance!;
  }

  String? serverUrl;
  String? token;
  int? tenantId;
  int? userId;
  String? userName;
  Map<String, dynamic>? currentUserInfo;
  Map<String, dynamic>? configuration;
  bool isConnecting = false;
  IO.Socket? socket;
  Function(dynamic)? onMessageReceived;
  String? currentCallEventSessionId;

  // Stream for agent status
  StreamController<String> _agentStatusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _agentStatusController.stream;

  // Stream for socket connection status
  StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Stream for call extra info
  StreamController<CallEventSocketRecv> _callEventController =
      StreamController<CallEventSocketRecv>.broadcast();
  Stream<CallEventSocketRecv> get callEventStream =>
      _callEventController.stream;

  CallEventSocketRecv? _currentCallEventSocketData;
  CallEventSocketRecv? get currentCallEventSocketData =>
      _currentCallEventSocketData;

  final participantType = "SUPERVISOR";
  final chanels = [
    ChannelConstants.FB_MESSAGE,
    ChannelConstants.ZL_MESSAGE,
    ChannelConstants.VOICE,
    ChannelConstants.LIVE_CONNECT
  ];

  // Private constructor
  MptSocketSocketServer._internal();

  void setup({
    required String serverUrlParam,
    required String tokenParam,
    required Function(dynamic) onMessageReceivedParam,
    required Map<String, dynamic> currentUserInfoParam,
    required Map<String, dynamic> configurationParam,
  }) {
    /// Create a new stream controller if it is closed
    if (_agentStatusController.isClosed) {
      _agentStatusController = StreamController<String>.broadcast();
    }

    // Create new connection status controller if closed
    if (_connectionStatusController.isClosed) {
      _connectionStatusController = StreamController<bool>.broadcast();
    }

    // Create new call extra info controller if closed
    if (_callEventController.isClosed) {
      _callEventController = StreamController<CallEventSocketRecv>.broadcast();
    }

    // Set parameters
    serverUrl = serverUrlParam;
    token = tokenParam;
    onMessageReceived = onMessageReceivedParam;
    tenantId = currentUserInfoParam["tenant"]["id"];
    userId = currentUserInfoParam["user"]["id"];
    userName = currentUserInfoParam["user"]["userName"];
    currentUserInfo = currentUserInfoParam;
    configuration = configurationParam;
    _initSocket();
  }

  /// Initialize Socket.IO connection
  void _initSocket() {
    // Check for null values before using
    if (serverUrl == null ||
        token == null ||
        tenantId == null ||
        userId == null ||
        userName == null) {
      print("ERROR: Required parameters are null in _initSocket");
      print(
          "serverUrl: $serverUrl, token: $token, tenantId: $tenantId, userId: $userId, userName: $userName");
      return;
    }

    print(
        "Initializing Socket.IO with clientId: ${tenantId}_${userId}_$userName");

    final _serverUrl = configuration!["socketIoCallConfig"]["url"];
    final _path = configuration!["socketIoCallConfig"]["options"]["path"];
    final _timeout = configuration!["socketIoCallConfig"]["options"]["timeout"];
    final _transports = List<String>.from(
        configuration!["socketIoCallConfig"]["options"]["transports"]);
    final _reconnectionAttempts =
        configuration!["socketIoCallConfig"]["options"]["reconnectionAttempts"];
    final _reconnectionDelay =
        configuration!["socketIoCallConfig"]["options"]["reconnectionDelay"];
    final _forceNew =
        configuration!["socketIoCallConfig"]["options"]["forceNew"];
    final _reconnection =
        configuration!["socketIoCallConfig"]["options"]["reconnection"];
    final _autoConnect =
        configuration!["socketIoCallConfig"]["options"]["autoConnect"];

    final socketOptionsBuilder = IO.OptionBuilder()
        .setPath(_path)
        .setTimeout(_timeout)
        .setTransports(_transports)
        .setReconnectionAttempts(_reconnectionAttempts)
        .setReconnectionDelay(_reconnectionDelay)
        .setAuth({"token": token}).setQuery({
      "participantType": participantType,
      "participantId": userId,
      "tenantId": tenantId,
      "channels": chanels.join(","),
      "fullName": userName,
      "forceNew": _forceNew,
    });

    // enable reconnection if configured
    if (_reconnection == true) {
      socketOptionsBuilder.enableReconnection();
    }

    // enable auto connect if configured
    if (_autoConnect == true) {
      socketOptionsBuilder.enableAutoConnect();
    }

    print(
        "socketUrl: $_serverUrl, path: $_path, timeout: $_timeout, transports: $_transports, reconnectionAttempts: $_reconnectionAttempts, reconnectionDelay: $_reconnectionDelay, forceNew: $_forceNew, reconnection: $_reconnection, autoConnect: $_autoConnect");

    // Create Socket.IO instance
    socket = IO.io(_serverUrl, socketOptionsBuilder.build());

    // Connect to socket
    socket!.connect();

    // Set up event listeners
    _setupSocketListeners();
  }

  /// Set up socket event listeners
  void _setupSocketListeners() {
    socket!.onConnect((_) {
      print("Socket server connected");
      isConnecting = true;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(true);
      }
      _listenEventChannels();
      // Rejoin all subscribed rooms after reconnection
      _rejoinSubscribedRooms();
    });

    socket!.onReconnect((data) {
      print("Socket.IO reconnected");
      isConnecting = true;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(true);
      }
      _listenEventChannels();
      // Rejoin all subscribed rooms after reconnection
      _rejoinSubscribedRooms();
    });

    socket!.onDisconnect((_) {
      print("Socket.IO disconnected");
      isConnecting = false;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(false);
      }
    });

    socket!.onConnectError((error) {
      print("Socket.IO connection error: $error");
      isConnecting = false;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(false);
      }
    });

    socket!.onError((error) {
      print("Socket.IO error: $error");
    });

    socket!.emitWithAck("agent_initialize", {
      "cloudTenantId": tenantId,
      "cloudAgentId": userId,
      "agentName":
          "${currentUserInfo?["user"]["fullName"]} (${currentUserInfo?["user"]["userName"]})",
      "applicationIds": currentUserInfo?["user"]["supportApplicationIds"],
      "fsAgentId": currentUserInfo?["user"]["fsAgentId"],
      "domainContext": currentUserInfo?["tenant"]["domainId"],
      "isEnableEmail": true,
      "isEnableChat": true,
    }, ack: (data) {
      final initialRooms = [
        "call_event_$tenantId",
        "${tenantId}_$userId",
        "agent_status_${tenantId}_$userId",
        "agent_status_chat",
      ];

      // Thêm vào _subscribedRooms
      _subscribedRooms.addAll(initialRooms);

      socket!.emitWithAck(
        "agent_join_rooms",
        {
          "rooms": initialRooms,
        },
        ack: (data) {
          print("Agent initialized: $data");
        },
      );
    });
  }

  void sendAgentState(String sessionId, String state) {
    if (socket == null || !socket!.connected) {
      print(
          "Socket server - sendAgentState - Cannot send message: socket is null or not connected");
      return;
    }

    try {
      socket!.emitWithAck("agent_state", {
        "sessionId": sessionId,
        "state": state,
      }, ack: (data) {
        print("Socket server - sendAgentState - Sent agent state: $data");
      });
    } catch (e) {
      print("Socket server - sendAgentState - Error sending agent state: $e");
    }
  }

  void _listenEventChannels() {
    // Remove existing listeners first
    socket!.off("agent_status_chat");
    socket!.off("CALL_EVENT");
    socket!.off("message");
    socket!.off("AGENT_STATUS_CHANGED");

    socket!.on("agent_status_chat", (data) {
      print("Socket server - AGENT_STATUS_CHAT - Received message: $data");
      _handleAgentStatusMessage(data);
    });

    // Listen for call events
    socket!.on("CALL_EVENT", (data) async {
      print("Socket server - CALL_EVENT - Received message: $data");

      if (data is Map) {
        var sessionId = data['sessionId'];
        print("Socket server - CALL_EVENT - Received sessionId - $sessionId");

        // if (data.containsKey('extraInfo')) {
        //   var extraInfo;
        //   if (data['extraInfo'] is String) {
        //     try {
        //       final extraInfoStr = data['extraInfo'] as String;
        //       if (extraInfoStr.isNotEmpty) {
        //         extraInfo = jsonDecode(extraInfoStr);
        //         print("Socket server - CALL_EVENT - extraInfo: $extraInfo");
        //       } else {
        //         print(
        //             "Socket server - CALL_EVENT - extraInfo is an empty string");
        //         return;
        //       }
        //     } catch (e) {
        //       print(
        //           "Socket server - CALL_EVENT - Error parsing extraInfo JSON: $e");
        //       return;
        //     }
        //   } else {
        //     extraInfo = data['extraInfo'];
        //   }

        //   if (extraInfo.containsKey('type')) {
        //     var callType = extraInfo['type'];

        //     if (callType.toString() == CallType.VIDEO.toString() &&
        //         data['state'] == MessageSocket.ANSWER_CALL) {
        //       // Handle video call
        //       try {
        //         await MptCallKitController.channel.invokeMethod('reInvite', {
        //           'sessionId': sessionId.toString(),
        //         });

        //         print(
        //             "Socket server - CALL_EVENT - currentSessionId: $sessionId");
        //       } catch (e) {
        //         print(
        //             "Socket server - CALL_EVENT - Error invoking reinvite method: $e");
        //       }
        //     } else {
        //       print("Socket server - CALL_EVENT - Call type has no video");
        //     }
        //   } else {
        //     print(
        //         "Socket server - CALL_EVENT - ExtraInfo has no type - state: ${data['state']}");
        //   }
        // } else {
        //   print("Socket server - CALL_EVENT - Data has no extraInfo");
        // }

        if (data.containsKey('agentId')) {
          var agentId = data['agentId'];

          if (agentId ==
              MptCallKitController().currentUserInfo?["user"]["id"]) {
            currentCallEventSessionId = sessionId;
            print(
                "Socket server - CALL_EVENT - agentId is equal to the current user id");
            // save call event info if agent is callee
            if (!_callEventController.isClosed) {
              _callEventController.add(
                  CallEventSocketRecv.fromJson(data as Map<String, dynamic>));
              _currentCallEventSocketData = CallEventSocketRecv.fromJson(data);
            } else {
              print(
                  "Socket server - CALL_EVENT - callEventController is closed");
            }

            //reInvite call if state is ANSWER_CALL
            if (data['state'] == CallEventSocketConstants.ANSWER_CALL) {
              if (data.containsKey('extraInfo')) {
                var extraInfo;
                if (data['extraInfo'] is String) {
                  try {
                    final extraInfoStr = data['extraInfo'] as String;
                    if (extraInfoStr.isNotEmpty) {
                      extraInfo = jsonDecode(extraInfoStr);
                    } else {
                      print(
                          "Socket server - CALL_EVENT - extraInfo is an empty string");
                      return;
                    }
                  } catch (e) {
                    print(
                        "Socket server - CALL_EVENT - Error parsing extraInfo JSON: $e");
                    return;
                  }
                } else {
                  extraInfo = data['extraInfo'];
                }

                if (extraInfo != null && extraInfo.containsKey('type')) {
                  if (extraInfo['type'].toString() ==
                      CallType.VIDEO.toString()) {
                    MptCallKitController().updateVideoCall(isVideo: true);
                  }
                } else {
                  print(
                      "Socket server - CALL_EVENT - extraInfo has no type field");
                }
              } else {
                print(
                    "Socket server - CALL_EVENT - data has no extraInfo field");
              }
            }
          } else {
            // save call event info if agent is caller
            if (currentCallEventSessionId == data['sessionId'] &&
                data['state'] != CallEventSocketConstants.OFFER_CALL) {
              // handle msg when call out going (agent logged in)
              if (!_callEventController.isClosed) {
                print(
                    "Socket server - CALL_EVENT - call out going with sessionId: $sessionId");
                _callEventController.add(
                    CallEventSocketRecv.fromJson(data as Map<String, dynamic>));
                _currentCallEventSocketData =
                    CallEventSocketRecv.fromJson(data);
              } else {
                print(
                    "Socket server - CALL_EVENT - callEventController is closed");
              }
            }
            print("Socket server - CALL_EVENT - data has no extraInfo");
          }
        } else {
          print("Socket server - CALL_EVENT - data has no agentId");
        }
      }

      if (onMessageReceived != null) {
        onMessageReceived!(data);
      }
    });

    // Generic event handler for any other messages
    socket!.on("message", (data) {
      print("Received generic message: $data");
      if (onMessageReceived != null) {
        onMessageReceived!(data);
      }
    });

    socket!.on("AGENT_STATUS_CHANGED", (data) {
      print("Socket server - AGENT_STATUS_CHANGED - Received message: $data");
      _handleAgentStatusMessage(data);
    });
  }

  /// Handle agent status messages
  void _handleAgentStatusMessage(dynamic data) {
    print("Processing agent status message: $data");

    Map<dynamic, dynamic>? statusData;
    try {
      if (data is Map) {
        statusData = data;
      } else if (data is String) {
        final dataStr = data;
        if (dataStr.isNotEmpty) {
          statusData = Map<String, dynamic>.from(jsonDecode(dataStr));
        } else {
          print(
              "Socket server - AGENT_STATUS_CHANGED - Received empty string for agent status message");
          return;
        }
      }
    } catch (e) {
      print(
          "Socket server - AGENT_STATUS_CHANGED - Error parsing message data: $e");
      return;
    }

    if (statusData != null) {
      final statusName = statusData['statusName'] as String?;
      if (statusName != null) {
        if (!_agentStatusController.isClosed) {
          print(
              "Socket server - AGENT_STATUS_CHANGED - Adding status to stream: $statusName");
          _agentStatusController.add(statusName);
        } else {
          print(
              "Socket server - AGENT_STATUS_CHANGED - Controller is closed. Creating a new one.");
          _agentStatusController = StreamController<String>.broadcast();
          _agentStatusController.add(statusName);
        }
      } else {
        print(
            "Socket server - AGENT_STATUS_CHANGED - statusName is null in data: $statusData");
      }
    } else {
      print(
          "Socket server - AGENT_STATUS_CHANGED - Could not parse data from message: $data");
    }
  }

  /// Send message through socket
  Future<void> sendMessage(String eventName, dynamic data) async {
    if (socket == null || !socket!.connected) {
      print(
          "Socket server - SEND_MESSAGE - Cannot send message: socket is null or not connected");
      return;
    }

    try {
      socket!.emitWithAck("send_message", {
        "rooms": [eventName],
        "event": eventName,
        "data": data,
      }, ack: (response) {
        print(
            "Socket server - SEND_MESSAGE - Sent message: $eventName - $data - $response");
      });
    } catch (e) {
      print("Socket server - SEND_MESSAGE - Error sending message: $e");
    }
  }

  /// Send message to conversation channel
  Future<void> sendConversationMessage(String eventName, dynamic data) async {
    // In Socket.IO we send to the same socket with different event names
    await sendMessage(eventName, data);
  }

  /// Close connection
  Future<void> closeConnection() async {
    try {
      if (socket != null && socket!.connected) {
        // Unsubscribe from all rooms before disconnecting
        if (_subscribedRooms.isNotEmpty) {
          socket!.emitWithAck(
            "agent_leave_rooms",
            {
              "rooms": _subscribedRooms.toList(),
            },
            ack: (data) {
              print(
                  "Socket server - AGENT_LEAVE_ROOMS - Left all rooms: $data");
            },
          );
          _subscribedRooms.clear();
        }

        socket!.disconnect();
        print("Socket.IO disconnected");
      } else {
        print("socket is null or not connected, nothing to disconnect");
      }
    } catch (e) {
      print("Error disconnecting from Socket.IO: $e");
    }
  }

  /// Close all resources
  Future<void> releaseResources() async {
    try {
      await closeConnection();
      _subscribedRooms.clear();

      if (!_agentStatusController.isClosed) {
        _agentStatusController.close();
      }

      // Close connection status controller
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.close();
      }

      // Close call extra info controller
      if (!_callEventController.isClosed) {
        _callEventController.close();
      }
    } catch (e) {
      print("Error disposing MptSocketSocketServer instance: $e");
    }
  }

  /// Check connection state
  bool checkConnection() {
    return socket != null && socket!.connected;
  }

  /// IMPORTANT: Destroy instance
  static Future<void> destroyInstance() async {
    if (_instance != null) {
      await _instance!.releaseResources();
      _instance = null;
      print("MptSocketSocketServer instance destroyed successfully");
    }
  }

  /// Create a single instance
  static void initialize({
    required String tokenParam,
    required Function(dynamic) onMessageReceivedParam,
    required Map<String, dynamic> currentUserInfo,
    required Map<String, dynamic> configuration,
  }) {
    // Ensure parameters are passed correctly
    instance.setup(
      serverUrlParam: configuration["socketIoCallConfig"]["url"],
      tokenParam: tokenParam,
      onMessageReceivedParam: onMessageReceivedParam,
      currentUserInfoParam: currentUserInfo,
      configurationParam: configuration,
    );
  }

  /// Static getter for agent status stream
  static Stream<String> get agentStatusEvent => instance.statusStream;

  /// Static getter for call extra info stream
  static Stream<CallEventSocketRecv> get callEvent => instance.callEventStream;

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

  /// Static getter for connection status stream
  static Stream<bool> get connectionStatus => instance.connectionStatusStream;

  /// Get current connection state
  static bool getCurrentConnectionState() {
    return _instance != null && _instance!.checkConnection();
  }

  /// Subscribe to a specific event
  void subscribeToEvent(String eventName, Function(dynamic) callback) {
    if (socket == null) {
      print("Cannot subscribe: Socket is not initialized");
      return;
    }

    print("Subscribing to event in socket: $eventName");

    // Store the room in the Set
    _subscribedRooms.add(eventName);

    socket!.emitWithAck(
      "agent_join_rooms",
      {
        "rooms": [eventName],
      },
      ack: (data) {
        print("Socket server - AGENT_JOIN_ROOMS - Agent join new room: $data");
      },
    );

    socket!.on(eventName, (data) {
      print("Received message for event $eventName: $data");
      callback(data);
    });
  }

  /// Static method to subscribe to events
  static void subscribeToEventStatic(
      String eventName, Function(dynamic) callback) {
    instance.subscribeToEvent(eventName, callback);
  }

  static void subscribeToMediaStatusChannel(
      String sessionId, Function(dynamic) callback) {
    instance.subscribeToEvent("call_media_$sessionId", callback);
  }

  Future<void> sendMediaStatusMessage(String sessionId, dynamic data) async {
    await instance.sendMessage("call_media_$sessionId", data);
  }

  static void leaveCallMediaRoomChannel(String sessionId) {
    instance.socket!.emitWithAck("agent_leave_rooms", {
      "rooms": [
        "call_media_$sessionId",
      ],
    }, ack: (data) {
      print("Socket server - AGENT_LEAVE_ROOMS - Agent leave room: $data");
    });
  }

  /// Static method to set session ID

  // Add new method to rejoin subscribed rooms
  void _rejoinSubscribedRooms() {
    if (_subscribedRooms.isEmpty) return;

    print("Rejoining subscribed rooms: $_subscribedRooms");
    socket!.emitWithAck(
      "agent_join_rooms",
      {
        "rooms": _subscribedRooms.toList(),
      },
      ack: (data) {
        print("Socket server - AGENT_JOIN_ROOMS - Rejoined rooms: $data");
      },
    );
  }

  // Add method to unsubscribe from a room
  void unsubscribeFromEvent(String eventName) {
    if (socket == null) {
      print("Cannot unsubscribe: Socket is not initialized");
      return;
    }

    _subscribedRooms.remove(eventName);
    socket!.emitWithAck(
      "agent_leave_rooms",
      {
        "rooms": [eventName],
      },
      ack: (data) {
        print("Socket server - AGENT_LEAVE_ROOMS - Left room: $data");
      },
    );
  }
}
