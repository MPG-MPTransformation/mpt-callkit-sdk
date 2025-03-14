import 'dart:convert' as convert;

import 'package:example/components/aehelper.dart';
import 'package:http/http.dart' as http;

class Repo {
  String decryptText(String encrypted) => AESHelper.decryptAesB64(encrypted);

  Future<Map<String, dynamic>?> getCurrentUserInfo({
    String? baseUrl,
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
        Uri.parse(
            "${baseUrl ?? "https://crm-dev-v2.metechvn.com"}$userInfoApi"),
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
}
