import 'dart:convert';
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;
import 'package:mpt_callkit/mpt_aes_helper.dart';

class MptCallkitAuthMethod {
  final _headers = {
    "Content-Type": "application/json",
    "Accept": "*/*",
  };

  final loginAPI = "/api/TokenAuth/Authenticate";
  final loginSSOAPI = "/api/TokenAuth/ExternalSystemAuthenticate";
  final logoutAPI = "/acd-asm-chat/agent-status/logout";

  Future<bool> login({
    required String username,
    required String password,
    required int tenantId,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    final body = {
      "tenantId": tenantId,
      "userNameOrEmailAddress": username,
      "password": password,
    };

    bool status = false;

    print("Login body: ${jsonEncode(body)}");
    print(
        "Login API: ${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginAPI");
    try {
      final response = await http.post(
        Uri.parse("${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginAPI"),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        data?.call(responseData);
        print('Login Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            var result = responseData["result"];
            if (result != null) {
              status = result["status"];
              print("Login status: $status");
              if (!status) {
                onError?.call(
                    "Username or password is incorrect. Message: [${result["message"]}]");
              } else {
                print("Login successfully");
              }
              return status;
            }
            onError?.call("Login failed, result is null");
            return false;
          }
          onError?.call("Login failed, cannot get data response");
          return false;
        }
        onError?.call("Login failed, cannot get data response");
        return false;
      } else {
        print('Failed to post data. Status code: ${response.statusCode}');
        onError?.call("Login failed, please check your internet connection");
        return false;
      }
    } catch (e) {
      print("Error in login: $e");
      onError?.call("Login failed with error: $e");
      return false;
    }
  }

  Future<bool> loginSSO({
    required String ssoToken,
    required String organization,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    bool status = false;

    final body = {
      "partner_session": ssoToken,
      "partner_tenant": organization,
    };

    print("Login SSO body: ${jsonEncode(body)}");
    print(
        "Login SSO API: ${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginSSOAPI");

    try {
      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginSSOAPI"),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        data?.call(responseData);
        print('Login SSOResponse data: $responseData');
        if (responseData != null) {
          if (responseData["success"]) {
            var result = responseData["result"];
            if (result != null) {
              status = result["status"];
              print("Login SSO status: $status");
              if (!status) {
                onError?.call(
                    "Incorrect credentials. Message: [${result["message"]}]");
              } else {
                print("Login successfully");
              }
              return status;
            }
            onError?.call("Login failed, result is null");
            return false;
          }
          onError?.call("Login failed, cannot get data response");
          return false;
        }
        onError?.call("Login failed, cannot get data response");
        return false;
      } else {
        print('Failed to post data. Status code: ${response.statusCode}');
        onError?.call("Login failed, please check your internet connection");
        return false;
      }
    } catch (e) {
      print("Error in login SSO: $e");
      onError?.call("Login SSO failed with error: $e");
      return false;
    }
  }

  Future<bool> logout({
    String? baseUrl,
    Function(String?)? onError,
    required String cloudAgentName,
    required int cloudAgentId,
    required int cloudTenantId,
  }) async {
    try {
      final body = {
        "cloudAgentId": cloudAgentId,
        "cloudTenantId": cloudTenantId,
        "cloudAgentName": cloudAgentName
      };

      final response = await http.post(
          Uri.parse(
              "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$logoutAPI"),
          headers: _headers,
          body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Logout Response data: $responseData');
        if (responseData != null) {
          if (responseData["success"] && responseData["status"]) {
            return true;
          }
          return false;
        }
        return false;
      } else {
        print('Failed to post data. Status code: ${response.statusCode}');
        onError?.call("Logout failed, please check your internet connection");
        return false;
      }
    } catch (e) {
      print("Error in logout: $e");
      onError?.call("Logout failed with error: $e");
      return false;
    }
  }

  String decryptText(String encrypted) => MptAESHelper.decryptAesB64(encrypted);

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

  // Get all conversation
  Future<dynamic> getConfiguration({
    required String baseUrl,
    required String accessToken,
    Function(String?)? onError,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $accessToken",
    };

    final url =
        "$baseUrl/config/EncryptedAbpUserConfiguration/GetConfiguration";

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

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
      print("Error in getConfiguration: $e");
      onError?.call("Get all conversation with error: $e");
      return null;
    }
  }
}
