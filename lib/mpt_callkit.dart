import 'package:mpt_callkit/mpt_callkit_auth_method.dart';

import 'mpt_callkit_platform_interface.dart';

class MptCallkit {
  Future<String?> getPlatformVersion() {
    return MptCallkitPlatform.instance.getPlatformVersion();
  }

  Future<Map<String, dynamic>> initSipConnection({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) async {
    return MptCallkitPlatform.instance.initSipConnection(
        apiKey: apiKey, baseUrl: baseUrl, userPhoneNumber: userPhoneNumber);
  }

  void registrationStateStream({
    required void Function() onSuccess,
    required void Function() onFailure,
  }) {
    MptCallkitPlatform.instance
        .registrationStateStream(onSuccess: onSuccess, onFailure: onFailure);
  }

  Future<bool> unregisterConnection() async {
    return await MptCallkitPlatform.instance.unregisterConnection();
  }

  bool call(String phone, bool isVideoCall) {
    return MptCallkitPlatform.instance.call(phone, isVideoCall);
  }

  void hangup() {
    MptCallkitPlatform.instance.hangup();
  }

  void startActivity() {
    MptCallkitPlatform.instance.startActivity();
  }

  Future<bool> login({
    required String username,
    required String password,
    required int tenantId,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    return MptCallkitAuthMethod().login(
      username: username,
      password: password,
      tenantId: tenantId,
      baseUrl: baseUrl,
      onError: onError,
      data: data,
    );
  }

  Future<bool> loginSSO({
    required String ssoToken,
    required String organization,
    String? baseUrl,
    Function(String?)? onError,
    Function(Map<String, dynamic>)? data,
  }) async {
    return MptCallkitAuthMethod().loginSSO(
      ssoToken: ssoToken,
      organization: organization,
      baseUrl: baseUrl,
      onError: onError,
      data: data,
    );
  }

  Future<bool> logout({
    String? baseUrl,
    Function(String?)? onError,
    required String cloudAgentName,
    required int cloudAgentId,
    required int cloudTenantId,
  }) async {
    return MptCallkitAuthMethod().logout(
      baseUrl: baseUrl,
      onError: onError,
      cloudAgentName: cloudAgentName,
      cloudAgentId: cloudAgentId,
      cloudTenantId: cloudTenantId,
    );
  }
}
