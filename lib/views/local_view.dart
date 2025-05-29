import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LocalView extends StatefulWidget {
  const LocalView({Key? key}) : super(key: key);

  @override
  State<LocalView> createState() => _LocalViewState();
}

class _LocalViewState extends State<LocalView> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'LocalView',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return AndroidView(
        viewType: 'LocalView',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
  }

  void _onPlatformViewCreated(int id) {}
}
