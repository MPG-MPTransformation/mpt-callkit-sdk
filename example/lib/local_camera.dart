import 'package:flutter/material.dart';
import 'package:mpt_callkit/views/local_view.dart';

class LocalCameraViewExample extends StatefulWidget {
  const LocalCameraViewExample({super.key});

  @override
  State<LocalCameraViewExample> createState() => _LocalCameraViewExampleState();
}

class _LocalCameraViewExampleState extends State<LocalCameraViewExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Local Camera View Example"),
      ),
      body: const LocalView(),
    );
  }
}
