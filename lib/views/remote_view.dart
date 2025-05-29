import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RemoteView extends StatefulWidget {
  const RemoteView({Key? key}) : super(key: key);

  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'RemoteView',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return AndroidView(
        viewType: 'RemoteView',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
  }

  void _onPlatformViewCreated(int id) {}
}
