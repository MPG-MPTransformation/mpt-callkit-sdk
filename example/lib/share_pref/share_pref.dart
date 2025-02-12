import 'dart:convert';

import 'package:mpt_callkit/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharePref {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveInfo(
      {required String name,
      required String phoneNumber,
      required String apiKey,
      required String baseUrl}) async {
    await _prefs?.setString("name", name);
    await _prefs?.setString("phoneNumber", phoneNumber);
    await _prefs?.setString("apiKey", apiKey);
    await _prefs?.setString("baseUrl", baseUrl);
  }

  static Map<String, dynamic>? getInfo() {
    String? name = _prefs?.getString("name");
    String? phoneNumber = _prefs?.getString("phoneNumber");
    String? apiKey = _prefs?.getString("apiKey");
    String? baseUrl = _prefs?.getString("baseUrl");

    print(
        "name: $name, phoneNumber: $phoneNumber, apiKey: $apiKey, baseUrl: $baseUrl");

    if (name == null ||
        phoneNumber == null ||
        name.isEmpty ||
        phoneNumber.isEmpty) {
      return null;
    }

    return {
      "name": name,
      "phoneNumber": phoneNumber,
      "apiKey": apiKey,
      "baseUrl": baseUrl
    };
  }

  static Future<void> saveMessages(List<MsgData> messages) async {
    final messagesJson =
        jsonEncode(messages.map((msg) => msg.toJson()).toList());
    await _prefs?.setString('messages', messagesJson);
  }

  static Future<void> addMessage(MsgData newMessage) async {
    final messages = getMessages();
    messages.add(newMessage);
    await saveMessages(messages);
  }

  static List<MsgData> getMessages() {
    final messagesJson = _prefs?.getString("messages");

    if (messagesJson != null) {
      final List<dynamic> decoded = jsonDecode(messagesJson);
      return decoded.map((json) => MsgData.fromJson(json)).toList();
    }

    return [];
  }
}
