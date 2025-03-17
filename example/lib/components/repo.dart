import 'dart:convert' as convert;

import 'package:example/components/aehelper.dart';
import 'package:http/http.dart' as http;

class Repo {
  String decryptText(String encrypted) => AESHelper.decryptAesB64(encrypted);

  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUserInfo({
    required String baseUrl,
    required String accessToken,
    Function(String?)? onError,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $accessToken",
    };
    const userInfoApi = "/api/services/app/Session/GetCurrentLoginInformation";
    try {
      final response = await http.get(
        Uri.parse("$baseUrl$userInfoApi"),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = convert.jsonDecode(response.body);
        // print('Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            var result =
                convert.jsonDecode(decryptText(responseData["result"]));
            print("CurrentUserInfo: $result");
            return result;
          }
          return null;
        }
        return null;
      } else {
        print('Failed to get data. Status code: ${response.statusCode}');
        onError
            ?.call('Failed to get data. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print("Error in get current user info: $e");
      onError?.call("Get current user info with error: $e");
      return null;
    }
  }

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
    };

    const changeStatusApi = "/acd-asm-chat/agent-status/change";

    try {
      final response = await http.post(
        Uri.parse("$baseUrl$changeStatusApi"),
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

  // Get all conversation
  Future<dynamic> getAll({
    required String baseUrl,
    required String accessToken,
    Function(String?)? onError,
  }) async {
    final header = {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $accessToken",
    };

    final url = "$baseUrl/config/EncryptedAbpUserConfiguration/GetAll";

    try {
      final response = await http.get(Uri.parse(url), headers: header);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = convert.jsonDecode(response.body);
        if (responseData["success"]) {
          var result = convert.jsonDecode(decryptText(responseData["result"]));
          print("GetAll: ${result.isNotEmpty}");
          return result;
        }
        onError?.call("Failed to get data");
        return null;
      }
      onError
          ?.call("Failed to get data with status code: ${response.statusCode}");
      return null;
    } catch (e) {
      print("Error in GetAll: $e");
      onError?.call("Get all conversation with error: $e");
      return null;
    }
  }
}
