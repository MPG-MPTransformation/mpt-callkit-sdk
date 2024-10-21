import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    MptCallKitController().initSdk(
      apiKey: "0c16d4aa-abe7-4098-b47a-7b914f9b7444",
      baseUrl: "https://crm-dev-v2.metechvn.com",
      userPhoneNumber: "200011",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().makeCall(
            context: context,
            phoneNumber: "200010",
            isVideoCall: true,
          );
        },
        child: const Icon(Icons.call),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
