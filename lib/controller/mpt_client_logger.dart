import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller_repo.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';

class MptClientLogger {
  static final MptClientLogger _instance = MptClientLogger._internal();
  factory MptClientLogger() => _instance;
  MptClientLogger._internal();

  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Future<void> sendLog({
    required String baseUrl,
    required String title,
    Map<String, dynamic>? values,
    String? tabId,
    required bool isGuest,
    required int extension,
    required int tenantId,
    required int agentId,
    required String sessionId,
    Function(String?)? onError,
  }) async {
    final currentTime = DateTime.now();
    final timeStamp = currentTime.millisecondsSinceEpoch;
    final date = DateFormat('dd/MM/yy HH:mm:ss').format(currentTime);

    var data = <String, dynamic>{
      "deviceType": "mobile",
      "extension": extension,
      "extensionRole": isGuest ? "caller" : "callee",
      "mptSDKVersion": MptSDKCoreConstants.VERSION,
      "values": jsonEncode(values)
    };

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      data["platform"] = "Android";
      data["androidVersion"] = androidInfo.version.release;
      data["androidSDKVersion"] = androidInfo.version.sdkInt;
      data["manufacturer"] = androidInfo.manufacturer;
      data["model"] = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      data["platform"] = "iOS";
      data["iosVersion"] = iosInfo.systemVersion;
      data["machine"] = iosInfo.utsname.machine;
      data["name"] = iosInfo.name;
    }

    final payload = {
      "values": (data),
      "title": title,
      "tabId": tabId ?? "",
      "date": date,
    };

    print(payload);

    await MptCallKitControllerRepo().reportDynamicClientLog(
      baseUrl: baseUrl,
      tenantId: tenantId,
      agentId: agentId,
      sessionId: sessionId,
      timeStamp: timeStamp,
      payload: jsonEncode(payload),
      onError: onError,
    );
  }
}
