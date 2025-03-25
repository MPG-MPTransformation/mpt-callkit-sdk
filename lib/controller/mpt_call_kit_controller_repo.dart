import 'dart:convert' as convert;
import 'dart:convert';

import 'package:http/http.dart' as http;

class MptCallKitControllerRepo {
  final _changeStatusApi = "/acd-asm-chat/agent-status/change";
  final _channelCall = "CALL";
  final _makeCallOutboundAPI = "/chat-acd/conversation/start-outbound";

  // Change agent status
  Future<bool> changeAgentStatus({
    required int cloudAgentId,
    required int cloudTenantId,
    required String cloudAgentName,
    required int reasonCodeId,
    required String statusName,
    required String baseUrl,
    required String accessToken,
    Function(String?)? onError,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $accessToken",
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl$_changeStatusApi"),
        headers: headers,
        body: convert.jsonEncode({
          "cloudAgentId": cloudAgentId,
          "cloudTenantId": cloudTenantId,
          "cloudAgentName": cloudAgentName,
          "reasonCodeId": reasonCodeId,
          "statusName": statusName
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = convert.jsonDecode(response.body);
        if (responseData != null &&
            responseData["status"] == true &&
            responseData["success"] == true) {
          print("Change agent status success: $responseData");
          return true;
        } else {
          print("Change agent status failed: $responseData");
          onError
              ?.call(responseData["message"] ?? "Change agent status failed");
          return false;
        }
      } else {
        print(
            'Failed to change agent status. Status code: ${response.statusCode}');
        onError?.call(
            'Failed to change agent status. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print("Error in change agent status: $e");
      onError?.call("Change agent status with error: $e");
      return false;
    }
  }

  Future<bool> makeCallInternal({
    required int tenantId,
    required String applicationId,
    required String senderId,
    required int agentId,
    required String extraInfo,
    Function(String?)? onError,
    String? baseUrl,
    required String authToken,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
        "Abp.TenantId": tenantId.toString(),
        'Accept': '*/*',
      };

      final body = {
        "tenantId": tenantId,
        "applicationId": applicationId,
        "senderId": senderId,
        "channel": _channelCall,
        "agentId": agentId,
        "direction": "INTERNAL",
        "extraInfo": extraInfo,
      };

      print("Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print("Call outbound success!");
            return true;
          }
          onError?.call("Call outbound failed: ${responseData["message"]}");
          return false;
        }
        onError?.call("Call outbound data is null");
        return false;
      }
      onError?.call(
          "Call outbound failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("Error in logout: $e");
      onError?.call("Logout failed with error: $e");
      return false;
    }
  }

  Future<bool> makeCall({
    required int tenantId,
    required String applicationId,
    required String senderId,
    required int agentId,
    required String extraInfo,
    Function(String?)? onError,
    String? baseUrl,
    required String authToken,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
        "Abp.TenantId": tenantId.toString(),
        'Accept': '*/*',
      };

      final body = {
        "tenantId": tenantId,
        "applicationId": applicationId,
        "senderId": senderId,
        "channel": _channelCall,
        "agentId": agentId,
        "extraInfo": extraInfo,
      };

      print("Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print("Call outbound success!");
            return true;
          }
          onError?.call("Call outbound failed: ${responseData["message"]}");
          return false;
        }
        onError?.call("Call outbound data is null");
        return false;
      }
      onError?.call(
          "Call outbound failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("Error in logout: $e");
      onError?.call("Logout failed with error: $e");
      return false;
    }
  }
}
