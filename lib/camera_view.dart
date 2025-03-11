import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:mpt_callkit/mpt_call_kit_constant.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        MptCallKitController.channel.setMethodCallHandler(
          (call) async {
            switch (call.method) {
              case MptCallKitConstants.hangOut:
                Navigator.pop(context);
                MptCallKitController().releaseExtension();
                break;
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: (Platform.isAndroid)
            ? AndroidView(
                viewType: 'VideoView',
                onPlatformViewCreated: _onPlatformViewCreated,
                creationParams: const <String, dynamic>{},
                creationParamsCodec: const StandardMessageCodec(),
              )
            : UiKitView(
                viewType: 'VideoView',
                onPlatformViewCreated: _onPlatformViewCreated,
                creationParams: const <String, dynamic>{},
                creationParamsCodec: const StandardMessageCodec(),
              ));
  }

  void _onPlatformViewCreated(int id) {}
}
