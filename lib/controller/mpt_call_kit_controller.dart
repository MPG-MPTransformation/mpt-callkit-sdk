import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mpt_callkit/camera_view.dart';
import 'package:mpt_callkit/models/extension_model.dart';
import 'package:mpt_callkit/models/release_extension_model.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';
import 'dart:io';

class MptCallKitController {
  String apiKey = '';
  String userPhoneNumber = '';
  String baseUrl = '';
  String extension = '';

  static const MethodChannel channel = MethodChannel('mpt_callkit');

  static final MptCallKitController _instance =
      MptCallKitController._internal();

  MptCallKitController._internal();

  factory MptCallKitController() {
    return _instance;
  }

  void initSdk({
    required String apiKey,
    String? baseUrl,
    required String userPhoneNumber,
  }) {
    this.apiKey = apiKey;
    this.userPhoneNumber = userPhoneNumber;
    this.baseUrl = baseUrl != null && baseUrl.isNotEmpty
        ? baseUrl
        : "https://crm-dev-v2.metechvn.com";
  }

  Future<void> makeCall({
    required BuildContext context,
    required String phoneNumber,
    bool isVideoCall = true,
    Function(String?)? onError,
  }) async {
    try {
      final result = await getExtension();
      if (result != null) {
        await online(
          username: result.username ?? "",
          displayName: phoneNumber,
          authName: '',
          password: result.password!,
          userDomain: result.domain!,
          sipServer: result.sipServer!,
          sipServerPort: result.port ?? 5060,
          transportType: 0,
          srtpType: 0,
          phoneNumber: phoneNumber,
          isVideoCall: isVideoCall,
          onBusy: (){
          const snackBar = SnackBar(
            content: Text('Current line is busy now, please switch a line.'),
          );
          // Find the ScaffoldMessenger in the widget tree
          // and use it to show a SnackBar.
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
    );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraView(),
          ),
        );
      }
    } on Exception catch (e) {
      onError?.call(e.toString());
      debugPrint("Failed to call: '${e.toString()}'.");
    }
  }

  Future<ExtensionData?> getExtension({int retryTime = 0}) async {
    try {
      int retryCount = retryTime;
      final url = Uri.parse("$baseUrl/integration/extension/request");

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: json.encode({
              "phone_number": userPhoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      final result = ExtensionModel.fromJson(
        data.runtimeType is String ? jsonDecode(data) : data,
      );
      final message = result.message ?? '';

      if (result.success ?? false) {
        this.extension = result.data?.username ?? '';
        return result.data;
      } else {
        if (retryCount > 2) {
          throw Exception(message);
        }
        retryCount += 1;
        final releaseResult = await releaseExtension();
        if (!releaseResult) return null;
        return await getExtension(retryTime: retryCount);
      }
    } on Exception catch (e) {
      debugPrint("Error in getExtension: $e");
      throw Exception(e);
    }
  }

  Future<bool> releaseExtension() async {
    final url = Uri.parse('$baseUrl/integration/extension/release');
    try {
      if (this.extension.isEmpty) return true;
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          "extension": this.extension,
        }),
      );

      final data = json.decode(response.body);
      final result = ReleaseExtensionModel.fromJson(data);
      this.extension = '';
      if (result.success ?? false) {
        return true;
      } else {
        throw Exception(result.message ?? '');
      }
    } on Exception catch (e) {
      debugPrint("Error in releaseExtension: $e");
      throw Exception(e);
    }
  }

  Future<bool> online({
    required String username,
    required String displayName,
    required String authName,
    required String password,
    required String userDomain,
    required String sipServer,
    required int sipServerPort,
    required int transportType,
    required int srtpType,
    required String phoneNumber,
    bool isVideoCall = false,
    void Function()? onBusy,
  }) async {
    try {
      if(Platform.isAndroid) {
        channel.setMethodCallHandler((call) async {
          /// lắng nghe kết quả register
          if(call.method == 'registrationStateStream'){
            /// nếu thành công thì call luôn
            if(call.arguments == true){
              final bool callResult = await channel.invokeMethod('call',
                <String, dynamic>{
                  'phoneNumber': '200010',
                },
              );
              if(callResult) {
                /// nếu thành công thì mở màn hình video call luôn
                channel.invokeMethod('startActivity');
              } else {
                onBusy?.call();
                print('quanth: call has failed');
                await offline();
              }
            } else {
              print('quanth: registration has failed');
            }
          } else if(call.method == 'releaseExtension') {
            print('quanth: releaseExtension has started');
            await releaseExtension();
            print('quanth: releaseExtension has done');
          }
        });
      }
      final bool result = await channel.invokeMethod(
        MptCallKitConstants.login,
        {
          'username': username,
          'displayName': this.userPhoneNumber,
          'authName': authName,
          'password': password,
          'userDomain': userDomain,
          'sipServer': sipServer,
          'sipServerPort': sipServerPort,
          'transportType': transportType,
          'srtpType': srtpType,
          'phoneNumber': phoneNumber,
          'isVideoCall': isVideoCall,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint("Login failed: ${e.message}");
      return false;
    }
  }

  Future<void> offline() async {
    try {
      await channel.invokeMethod(MptCallKitConstants.offline);
    } on PlatformException catch (e) {
      debugPrint("Failed to go offline: '${e.message}'.");
    }
  }
}
