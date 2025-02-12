import 'dart:io';
import 'dart:typed_data';

import 'package:example/chat_screen/components/msg_item_selected.dart';
import 'package:example/login_screen.dart';
import 'package:example/share_pref/share_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/chat_socket.dart';
import 'package:mpt_callkit/models/msg_data.dart';
import 'package:intl/intl.dart';
import 'components/msg_item_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<MsgData> listMsg = [];
  final imageExtensions = [
    '.jpg',
    '.png',
  ];

  var chatFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    listMsg = SharePref.getMessages();
    ChatSocket.onReceiveMessage((data) {
      print("Data log: ${data.toString()}");
      if (data is Map<String, dynamic>) {
        var msgData = MsgData.fromJson(data);

        msgData.creationTime =
            DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());

        if (mounted) {
          setState(() {
            // add message to list messages and save it to local
            listMsg.add(msgData);
          });

          Future.delayed(const Duration(milliseconds: 500), () {
            scrollDownToEnd();
          });
        }
      } else {
        debugPrint("Error: Invalid data format or 'message' key not found.");
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      scrollDownToEnd();
    });

    chatFocusNode.addListener(() {
      if (chatFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          scrollDownToEnd();
        });
      }
    });
  }

  //scroll controller
  ScrollController scrollController = ScrollController();
  void scrollDownToEnd() {
    // scrollController.jumpTo(scrollController.position.maxScrollExtent);
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 300,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  //send message
  _sendMessage(String msg, List<dynamic> attachments) async {
    hasFileSelected = false;
    await ChatSocket.sendMessage(msg, attachments);
    debugPrint("Attachments: ${attachments.toString()}");

    chatFocusNode.unfocus();
    scrollDownToEnd();
  }

  List<dynamic> listFilesSelected = [];
  bool hasFileSelected = false;

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      withData: true,
      allowedExtensions: ['pdf', 'doc', 'docx', "xlsx", "png", "jpg"],
    );

    if (result != null) {
      for (var file in result.files) {
        Uint8List? fileBytes = file.bytes;
        String fileName = file.name;

        if (File(file.path!).lengthSync() > 5 * 1024 * 1024) {
          debugPrint("Error: File selected is bigger than 5MB");
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                    "Error: File selected is bigger than 5MB. Please select another file."),
              ),
            );
          }
        } else {
          var fileInfo = {
            "buffer": fileBytes,
            "fileName": fileName,
            "originalname": fileName,
            "type": _isImage(fileName) ? "image" : "file",
          };

          listFilesSelected.add(fileInfo);
          hasFileSelected = true;

          setState(() {});
        }
      }
    }
  }

  bool _isImage(String fileName) {
    final fileExtension = fileName.toLowerCase().split(".").last;
    return imageExtensions.contains(".$fileExtension");
  }

  @override
  void dispose() {
    SharePref.saveMessages(listMsg);
    listMsg.clear();
    scrollController.removeListener(() {});
    scrollController.dispose();
    chatFocusNode.dispose();
    super.dispose();
  }

  final controller = TextEditingController();

  final userInfo = SharePref.getInfo();

  handleReconnectChat() async {
    await ChatSocket.connectChat(
      userInfo!["baseUrl"],
      guestAPI: '/integration/security/guest-token',
      barrierToken: userInfo!["apiKey"],
      appId: '88888888',
      phoneNumber: userInfo!["phoneNumber"],
      userName: userInfo!["name"],
    );
  }

  var isConnected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.blueGrey[100],
        appBar: AppBar(
          backgroundColor: Colors.black45,
          title: StreamBuilder<bool>(
            stream: ChatSocket.connectionStatusStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                isConnected = snapshot.data as bool;
                return Row(
                  children: [
                    Text(
                      isConnected ? "Connected" : "Disconnected...",
                      style: TextStyle(
                          fontSize: 18,
                          color: isConnected ? Colors.white : Colors.red),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isConnected ? Icons.check_circle : Icons.error,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ],
                );
              } else {
                return const SizedBox();
              }
            },
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
                onPressed: () {
                  if (!isConnected) {
                    handleReconnectChat();
                  }
                },
                child: const Text(
                  "Reconnect",
                  style: TextStyle(color: Colors.yellow),
                )),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: listMsg.length,
                      itemBuilder: (context, index) {
                        return MsgItemView(
                          item: listMsg[index],
                        );
                      },
                    ),
                  ),
                  hasFileSelected
                      ? Container(
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white54,
                            border:
                                Border(top: BorderSide(color: Colors.blueGrey)),
                          ),
                          child: ListView.builder(
                            itemCount: listFilesSelected.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              return MsgItemSelected(
                                msgData: listFilesSelected[index],
                                onTab: () {
                                  listFilesSelected.removeAt(index);

                                  if (listFilesSelected.isEmpty) {
                                    hasFileSelected = false;
                                  }
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        )
                      : const SizedBox(),
                ],
              ),
            ),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black45),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5), topRight: Radius.circular(5)),
              ),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () {
                        pickFiles();
                      },
                      icon: const Icon(
                        Icons.attach_file,
                        // size: 50,
                      )),
                  Expanded(
                      child: TextFormField(
                    controller: controller,
                    focusNode: chatFocusNode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      hintText: 'Type a message',
                    ),
                  )),
                  IconButton(
                      onPressed: () async {
                        await _sendMessage(controller.text, listFilesSelected);
                        listFilesSelected.clear();
                        controller.clear();
                      },
                      icon: const Icon(
                        Icons.send,
                        // size: 50,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
