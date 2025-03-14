import 'dart:convert';

import 'package:http/http.dart' as http;

class MptCallkitAuthMethod {
  final _headers = {
    "Content-Type": "application/json",
    "Accept": "*/*",
  };

  Future<bool> login({
    required String username,
    required String password,
    required int tenantId,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    const loginApi = "/api/TokenAuth/Authenticate";

    final body = {
      "tenantId": tenantId,
      "userNameOrEmailAddress": username,
      "password": password,
    };

    bool status = false;
    try {
      final response = await http.post(
        Uri.parse("${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginApi"),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        data?.call(responseData);
        print('Response data: $responseData');
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
    const loginSSOApi = "/api/TokenAuth/ExternalSystemAuthenticate";
    bool status = false;

    final body = {
      "partner_session": ssoToken,
      "partner_tenant": organization,
    };

    try {
      final response = await http.post(
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$loginSSOApi"),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        data?.call(responseData);
        print('Response data: $responseData');
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
    const logoutApi = "/acd-asm-chat/agent-status/logout";
    try {
      final body = {
        "cloudAgentId": cloudAgentId,
        "cloudTenantId": cloudTenantId,
        "cloudAgentName": cloudAgentName
      };

      final response = await http.post(
          Uri.parse(
              "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$logoutApi"),
          headers: _headers,
          body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Response data: $responseData');
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
}
