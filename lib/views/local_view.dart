import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/mpt_call_kit_controller.dart';

class LocalView extends StatefulWidget {
  final Future<void> Function(int id)? onViewCreated;
  const LocalView({Key? key, this.onViewCreated}) : super(key: key);

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

  Future<void> _onPlatformViewCreated(int id) async {
    print('LocalView - _onPlatformViewCreated');
    await MptCallKitController().setCamera(useFrontCamera: true);
    await widget.onViewCreated?.call(id);
  }
}
