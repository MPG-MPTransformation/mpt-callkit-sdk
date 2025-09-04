import 'dart:convert' as convert;
import 'dart:convert';

import 'package:http/http.dart' as http;

class MptCallKitControllerRepo {
  final _changeStatusApi = "/acd-asm-chat/agent-status/change";
  final _getCurrentStatusApi = "/acd-asm-chat/agent-status/current-status";
  final _channelCall = "CALL";
  final _makeCallOutboundAPI = "/chat-acd/conversation/start-outbound";
  final _makeCallByGuestAPI = "/integration/make-call";
  final _deleteRegistrationAPI = "/contact-center/agent/registration";

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
    String? deviceInfo,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $accessToken",
    };

    final body = {
      "cloudAgentId": cloudAgentId,
      "cloudTenantId": cloudTenantId,
      "cloudAgentName": cloudAgentName,
      "reasonCodeId": reasonCodeId,
      "statusName": statusName,
      "deviceInfo": deviceInfo,
    };

    print(
        "[Mpt_API] - changeAgentStatus - body: ${jsonEncode(body).toString()}");

    try {
      final response = await http.post(
        Uri.parse("$baseUrl$_changeStatusApi"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = convert.jsonDecode(response.body);
        if (responseData != null &&
            responseData["status"] == true &&
            responseData["success"] == true) {
          print(
              "[Mpt_API] - changeAgentStatus - Change agent status success: $responseData");
          return true;
        } else {
          print(
              "[Mpt_API] - changeAgentStatus - Change agent status failed: $responseData");
          onError
              ?.call(responseData["message"] ?? "Change agent status failed");
          return false;
        }
      } else {
        print(
            '[Mpt_API] - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        onError?.call(
            '[Mpt_API] - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print("[Mpt_API] - changeAgentStatus - Error in change agent status: $e");
      onError?.call("[Mpt_API] - changeAgentStatus - Error: $e");
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
          "[Mpt_API] - getCurrentAgentStatus - Response status code: ${response.statusCode}");
      print(
          "[Mpt_API] - getCurrentAgentStatus - Response body: ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }

        final responseData = convert.jsonDecode(response.body);
        if (responseData != null &&
            responseData["status"] == true &&
            responseData["success"] == true) {
          print(
              "[Mpt_API] - getCurrentAgentStatus - Get current agent status success");
          final statusName = responseData["data"]?["statusName"] as String?;
          return statusName;
        } else {
          print(
              "[Mpt_API] - getCurrentAgentStatus - Get current agent status failed: $responseData");
          onError?.call(
              responseData["message"] ?? "Get current agent status failed");
          return null;
        }
      } else {
        print(
            '[Mpt_API] - getCurrentAgentStatus - Failed to get current agent status. Status code: ${response.statusCode}');
        onError?.call(
            '[Mpt_API] - getCurrentAgentStatus - Failed to get current agent status. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print("[Mpt_API] - getCurrentAgentStatus - Error: $e");
      onError?.call("[Mpt_API] - getCurrentAgentStatus - Error: $e");
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
          "[Mpt_API] - makeCallInternal - Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print(
            '[Mpt_API] - makeCallInternal - Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print("[Mpt_API] - makeCallInternal - Call outbound success!");
            return true;
          }
          onError?.call(
              "[Mpt_API] - makeCallInternal - Call outbound failed: ${responseData["message"]}");
          return false;
        }
        onError
            ?.call("[Mpt_API] - makeCallInternal - Call outbound data is null");
        return false;
      }
      onError?.call(
          "[Mpt_API] - makeCallInternal - Call outbound failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("[Mpt_API] - makeCallInternal - Error: $e");
      onError?.call("[Mpt_API] - makeCallInternal - Error: $e");
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

      print("[Mpt_API] - makeCall - Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print(
            '[Mpt_API] - makeCall - Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print("[Mpt_API] - makeCall - Call outbound success!");
            return true;
          }
          onError?.call(
              "[Mpt_API] - makeCall - Call outbound failed: ${responseData["message"]}");
          return false;
        }
        onError?.call("[Mpt_API] - makeCall - data = null");
        return false;
      }
      onError?.call(
          "[Mpt_API] - makeCall - Call outbound failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("[Mpt_API] - makeCall - Error: $e");
      onError?.call("[Mpt_API] - makeCall - Error: $e");
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

      print("[Mpt_API] - makeCallByGuest - body: ${jsonEncode(body)}");
      print("[Mpt_API] - makeCallByGuest - headers: ${jsonEncode(headers)}");
      print(
          "[Mpt_API] - makeCallByGuest - API: ${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('[Mpt_API] - makeCallByGuest - data: $responseData');
        return true;
      }
      onError?.call(
          "[Mpt_API] - makeCallByGuest - failed, response with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("[Mpt_API] - makeCallByGuest - Error: $e");
      onError?.call("[Mpt_API] - makeCallByGuest - Error: $e");
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

      print("[Mpt_API] - postEndCall - body: ${jsonEncode(body)}");

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
                "[Mpt_API] - postEndCall - failed: success=${responseData["success"]}, message: ${responseData["message"].toString()}");
            return false;
          }
        } else {
          onError?.call(
              "[Mpt_API] - postEndCall - failed, response with empty body");
          return false;
        }
      } else {
        onError?.call(
            "[Mpt_API] - postEndCall - failed, response with status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("[Mpt_API] - postEndCall - Error: $e");
      onError?.call("[Mpt_API] - postEndCall - Error: $e");
      return false;
    }
  }

  Future<bool> deleteRegistration({
    required int tenantId,
    required int agentId,
    String? baseUrl,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final body = {
        "tenant_id": tenantId,
        "agent_id": agentId,
      };

      print("[Mpt_API] - deleteRegistration - body: ${jsonEncode(body)}");

      final response = await http.delete(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_deleteRegistrationAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('[Mpt_API] - deleteRegistration - data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            print("[Mpt_API] - deleteRegistration - success!");
            return true;
          }
          onError?.call(
              "[Mpt_API] - deleteRegistration - failed: ${responseData["message"]}");
          return false;
        }
        onError?.call("[Mpt_API] - deleteRegistration - data = null");
        return false;
      }
      onError?.call(
          "[Mpt_API] - deleteRegistration - failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      print("[Mpt_API] - deleteRegistration - Error: $e");
      onError?.call("[Mpt_API] - deleteRegistration - Error: $e");
      return false;
    }
  }
}
