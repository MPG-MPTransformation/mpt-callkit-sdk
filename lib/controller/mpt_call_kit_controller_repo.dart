import 'dart:convert' as convert;
import 'dart:convert';

import 'package:http/http.dart' as http;

class MptCallKitControllerRepo {
  final _changeStatusApi = "/acd-asm-chat/agent-status/change";
  final _getCurrentStatusApi = "/acd-asm-chat/agent-status/current-status";
  final _channelCall = "CALL";
  final _makeCallOutboundAPI = "/chat-acd/conversation/start-outbound";
  final _makeCallByGuestAPI = "/integration/make-call";

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
          print(
              "MptCallKitControllerRepo - changeAgentStatus - Change agent status success: $responseData");
          return true;
        } else {
          print(
              "MptCallKitControllerRepo - changeAgentStatus - Change agent status failed: $responseData");
          onError
              ?.call(responseData["message"] ?? "Change agent status failed");
          return false;
        }
      } else {
        print(
            'MptCallKitControllerRepo - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        onError?.call(
            'MptCallKitControllerRepo - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print(
          "MptCallKitControllerRepo - changeAgentStatus - Error in change agent status: $e");
      onError?.call("Change agent status with error: $e");
      return false;
    }
  }

  // Get current agent status
  Future<String?> getCurrentAgentStatus({
    required int cloudAgentId,
    required int cloudTenantId,
    required String cloudAgentName,
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
      final url = Uri.parse("$baseUrl$_getCurrentStatusApi").replace(
        queryParameters: {
          'cloudAgentId': cloudAgentId.toString(),
          'cloudTenantId': cloudTenantId.toString(),
          'cloudAgentName': cloudAgentName,
        },
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      print(
          "MptCallKitControllerRepo - getCurrentAgentStatus - Response status code: ${response.statusCode}");
      print(
          "MptCallKitControllerRepo - getCurrentAgentStatus - Response body: ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }

        final responseData = convert.jsonDecode(response.body);
        if (responseData != null &&
            responseData["status"] == true &&
            responseData["success"] == true) {
          print(
              "MptCallKitControllerRepo - getCurrentAgentStatus - Get current agent status success");
          final statusName = responseData["data"]?["statusName"] as String?;
          return statusName;
        } else {
          print(
              "MptCallKitControllerRepo - getCurrentAgentStatus - Get current agent status failed: $responseData");
          onError?.call(
              responseData["message"] ?? "Get current agent status failed");
          return null;
        }
      } else {
        print(
            'MptCallKitControllerRepo - getCurrentAgentStatus - Failed to get current agent status. Status code: ${response.statusCode}');
        onError?.call(
            'Failed to get current agent status. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print(
          "MptCallKitControllerRepo - getCurrentAgentStatus - Error in get current agent status: $e");
      onError?.call("Get current agent status with error: $e");
      return null;
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

      print(
          "MptCallKitControllerRepo - makeCallInternal - Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print(
            'MptCallKitControllerRepo - makeCallInternal - Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print(
                "MptCallKitControllerRepo - makeCallInternal - Call outbound success!");
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
      print(
          "MptCallKitControllerRepo - makeCallInternal - Error in logout: $e");
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

      print(
          "MptCallKitControllerRepo - makeCall - Call outbound body: ${jsonEncode(body)}");

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
            print(
                "MptCallKitControllerRepo - makeCall - Call outbound success!");
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
      print("MptCallKitControllerRepo - makeCall - Error in logout: $e");
      onError?.call("Logout failed with error: $e");
      return false;
    }
  }

  Future<bool> makeCallByGuest({
    required String phoneNumber,
    required String extension,
    required String destination,
    required String extraInfo,
    String? baseUrl,
    required String authToken,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Authorization': "Bearer $authToken",
        'Content-Type': 'application/json',
      };

      final body = {
        "phoneNumber": phoneNumber,
        "extension": extension,
        "destination": destination,
        "extraInfo": extraInfo
      };

      print(
          "MptCallKitControllerRepo - makeCallByGuest - makeCallByGuest body: ${jsonEncode(body)}");
      print("makeCallByGuest headers: ${jsonEncode(headers)}");
      print(
          "makeCallByGuest API: ${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print(
            'MptCallKitControllerRepo - makeCallByGuest - makeCallByGuest Response data: $responseData');
        return true;
      }
      onError?.call(
          "Make call by guest failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print(
          "MptCallKitControllerRepo - makeCallByGuest - Error in makeCallByGuest: $e");
      onError?.call("Make call by guest failed with error: $e");
      return false;
    }
  }

  Future<bool> postEndCall({
    String? baseUrl,
    required String sessionId,
    required int agentId,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final body = {
        "sessionId": sessionId,
        "agentId": agentId,
      };

      print("Post end call API body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}/workflow/$sessionId/end"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          final responseData = jsonDecode(response.body);
          if (responseData["success"]) {
            return true;
          } else {
            onError?.call(
                "Post end call API failed: success=${responseData["success"]}, message: ${responseData["message"].toString()}");
            return false;
          }
        } else {
          onError?.call("Post end call API failed, response with empty body");
          return false;
        }
      } else {
        onError?.call(
            "Post end call API failed, response with status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print(
          "MptCallKitControllerRepo - postEndCall - Error in postEndCall: $e");
      onError?.call("Post end call API failed with error: $e");
      return false;
    }
  }
}
