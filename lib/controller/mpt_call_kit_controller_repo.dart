import 'dart:convert' as convert;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class MptCallKitControllerRepo {
  final _changeStatusApi = "/acd-asm-chat/agent-status/change";
  final _getCurrentStatusApi = "/acd-asm-chat/agent-status/current-status";
  final _channelCall = "CALL";
  final _makeCallOutboundAPI = "/chat-acd/conversation/start-outbound";
  final _makeCallByGuestAPI = "/integration/make-call";
  final _deleteRegistrationAPI = "/contact-center/agent/registration";
  final _agentQueuesAPI = "/contact-center/agent/queues";
  final _getQueuesAPI = "/contact-center/queue";
  final _getAllAgentInQueueByExtensionAPI =
      "/contact-center/queue/agentsByExtension";
  final _dynamicClientLogAPI = "/dynamic-report/api/v2/reports/client-log";

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

    debugPrint(
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
          debugPrint(
              "[Mpt_API] - changeAgentStatus - Change agent status success: $responseData");
          return true;
        } else {
          debugPrint(
              "[Mpt_API] - changeAgentStatus - Change agent status failed: $responseData");
          onError
              ?.call(responseData["message"] ?? "Change agent status failed");
          return false;
        }
      } else {
        debugPrint(
            '[Mpt_API] - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        onError?.call(
            '[Mpt_API] - changeAgentStatus - Failed to change agent status. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint(
          "[Mpt_API] - changeAgentStatus - Error in change agent status: $e");
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

      debugPrint(
          "[Mpt_API] - getCurrentAgentStatus - Response status code: ${response.statusCode}");
      debugPrint(
          "[Mpt_API] - getCurrentAgentStatus - Response body: ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }

        final responseData = convert.jsonDecode(response.body);
        if (responseData != null &&
            responseData["status"] == true &&
            responseData["success"] == true) {
          debugPrint(
              "[Mpt_API] - getCurrentAgentStatus - Get current agent status success");
          final statusName = responseData["data"]?["statusName"] as String?;
          return statusName;
        } else {
          debugPrint(
              "[Mpt_API] - getCurrentAgentStatus - Get current agent status failed: $responseData");
          onError?.call(
              responseData["message"] ?? "Get current agent status failed");
          return null;
        }
      } else {
        debugPrint(
            '[Mpt_API] - getCurrentAgentStatus - Failed to get current agent status. Status code: ${response.statusCode}');
        onError?.call(
            '[Mpt_API] - getCurrentAgentStatus - Failed to get current agent status. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint("[Mpt_API] - getCurrentAgentStatus - Error: $e");
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

      debugPrint(
          "[Mpt_API] - makeCallInternal - Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint(
            '[Mpt_API] - makeCallInternal - Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            debugPrint("[Mpt_API] - makeCallInternal - Call outbound success!");
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
      debugPrint("[Mpt_API] - makeCallInternal - Error: $e");
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

      debugPrint(
          "[Mpt_API] - makeCall - Call outbound body: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallOutboundAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint(
            '[Mpt_API] - makeCall - Make call outbound Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            debugPrint("[Mpt_API] - makeCall - Call outbound success!");
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
      debugPrint("[Mpt_API] - makeCall - Error: $e");
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

      debugPrint("[Mpt_API] - makeCallByGuest - body: ${jsonEncode(body)}");
      debugPrint(
          "[Mpt_API] - makeCallByGuest - headers: ${jsonEncode(headers)}");
      debugPrint(
          "[Mpt_API] - makeCallByGuest - API: ${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI");

      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_makeCallByGuestAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint('[Mpt_API] - makeCallByGuest - data: $responseData');
        return true;
      }
      onError?.call(
          "[Mpt_API] - makeCallByGuest - failed, response with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      debugPrint("[Mpt_API] - makeCallByGuest - Error: $e");
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

      debugPrint("[Mpt_API] - postEndCall - body: ${jsonEncode(body)}");

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
      debugPrint("[Mpt_API] - postEndCall - Error: $e");
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

      debugPrint("[Mpt_API] - deleteRegistration - body: ${jsonEncode(body)}");

      final response = await http.delete(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_deleteRegistrationAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint('[Mpt_API] - deleteRegistration - data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            debugPrint("[Mpt_API] - deleteRegistration - success!");
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
      debugPrint("[Mpt_API] - deleteRegistration - Error: $e");
      onError?.call("[Mpt_API] - deleteRegistration - Error: $e");
      return false;
    }
  }

  // Toggle change agent status in queue
  Future<bool> putAgentQueues({
    required int agentId,
    required int tenantId,
    String? baseUrl,
    required String queueId,
    required bool enabled,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final body = {
        "agent_id": agentId,
        "tenant_id": tenantId,
        "queue_id": queueId,
        "enabled": enabled,
      };

      debugPrint("[Mpt_API] - putAgentQueues - body: ${jsonEncode(body)}");

      final response = await http.put(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_agentQueuesAPI"),
        headers: headers,
        body: convert.jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint("[Mpt_API] - putAgentQueues - data: $responseData");
        if (responseData["success"]) {
          return true;
        }
        onError?.call(
            "[Mpt_API] - putAgentQueues - failed: ${responseData["message"]}");
        return false;
      }
      onError?.call(
          "[Mpt_API] - putAgentQueues - failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      debugPrint("[Mpt_API] - putAgentQueues - Error: $e");
      onError?.call("[Mpt_API] - putAgentQueues - Error: $e");
      return false;
    }
  }

  // Get all queues by agent
  Future<List<QueueDataByAgent>?> getAgentQueues({
    required int agentId,
    required int tenantId,
    String? baseUrl,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final url = Uri.parse(
        "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_agentQueuesAPI",
      ).replace(queryParameters: {
        "tenantId": tenantId.toString(),
        "agentId": agentId.toString(),
      });

      debugPrint("[Mpt_API] - getAgentQueues - url: $url");

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData != null && responseData["success"] == true) {
          final List<dynamic> list = responseData["data"] ?? [];
          final result = list
              .map((e) => QueueDataByAgent.fromJson(
                  e is Map<String, dynamic> ? e : jsonDecode(e.toString())))
              .toList();
          return result;
        }
        onError?.call(
            "[Mpt_API] - getAgentQueues - failed: ${responseData?["message"]}");
        return <QueueDataByAgent>[];
      } else {
        onError?.call(
            "[Mpt_API] - getAgentQueues - failed with status code: ${response.statusCode}");
        return <QueueDataByAgent>[];
      }
    } catch (e) {
      debugPrint("[Mpt_API] - getAgentQueues - Error: $e");
      onError?.call("[Mpt_API] - getAgentQueues - Error: $e");
    }
    return <QueueDataByAgent>[];
  }

  // Get all queues
  Future<List<QueueData>?> getAllQueues({
    required int tenantId,
    required int agentId,
    String? baseUrl,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final url = Uri.parse(
        "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_getQueuesAPI",
      ).replace(queryParameters: {
        "tenantId": tenantId.toString(),
        "agentId": agentId.toString(),
      });

      debugPrint("[Mpt_API] - getAllQueues - url: $url");

      final response = await http.get(url, headers: headers);

      final responseData = jsonDecode(response.body);
      debugPrint("[Mpt_API] - getAllQueues - responseData: $responseData");
      if (responseData != null && responseData["success"] == true) {
        final List<dynamic> list = responseData["data"] ?? [];
        debugPrint("[Mpt_API] - getAllQueues - list: $list");
        final result = list
            .map((e) => QueueData.fromJson(
                e is Map<String, dynamic> ? e : jsonDecode(e.toString())))
            .toList();
        return result;
      }
      onError?.call(
          "[Mpt_API] - getAllQueues - failed with status code: ${response.statusCode}");
      return <QueueData>[];
    } catch (e) {
      debugPrint("[Mpt_API] - getAllQueues - Error: $e");
      onError?.call("[Mpt_API] - getAllQueues - Error: $e");
      return <QueueData>[];
    }
  }

  // Get all agents in queue by extension
  Future<List<AgentDataByQueue>?> getAllAgentInQueueByQueueExtension({
    required String extension,
    required int tenantId,
    String? baseUrl,
    Function(String?)? onError,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      final url = Uri.parse(
        "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_getAllAgentInQueueByExtensionAPI",
      ).replace(queryParameters: {
        "queueExtension": extension.toString(),
        "tenantId": tenantId.toString(),
      });

      debugPrint("[Mpt_API] - getAllAgentInQueueByQueueExtension - url: $url");

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData != null && responseData["success"] == true) {
          final List<dynamic> list = responseData["data"] ?? [];
          final result = list
              .map((e) => AgentDataByQueue.fromJson(
                  e is Map<String, dynamic> ? e : jsonDecode(e.toString())))
              .toList();
          debugPrint(
              "[Mpt_API] - getAllAgentInQueueByQueueExtension - result: ${result.length}");
          return result;
        }
      }
    } catch (e) {
      debugPrint("[Mpt_API] - getAllAgentInQueueByQueueExtension - Error: $e");
      onError
          ?.call("[Mpt_API] - getAllAgentInQueueByQueueExtension - Error: $e");
      return <AgentDataByQueue>[];
    }
    return null;
  }

  Future<int> reportDynamicClientLog({
    String? baseUrl,
    required int tenantId,
    required int agentId,
    required String sessionId,
    required int timeStamp,
    required String payload,
    Function(String?)? onError,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = {
      "tenantId": tenantId,
      "agentId": agentId,
      "sessionId": sessionId,
      "timeStamp": timeStamp,
      "payload": payload,
    };

    final response = await http.post(
      Uri.parse(
          "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$_dynamicClientLogAPI"),
      headers: headers,
      body: convert.jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.statusCode;
    } else {
      onError?.call(
          "[Mpt_API] - reportDynamicClientLog - failed with status code: ${response.statusCode}");
      return -1;
    }
  }
}
