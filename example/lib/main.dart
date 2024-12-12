import 'package:flutter/material.dart';
import 'package:mpt_callkit/camera_view.dart';
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = "200011";
    _callTo.text = "20015";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().initSdk(
            apiKey: "0c16d4aa-abe7-4098-b47a-7b914f9b7444",
            baseUrl: "https://crm-dev-v2.metechvn.com",
            userPhoneNumber: _phoneController.text,
          );
          MptCallKitController().makeCall(
            context: context,
            phoneNumber: _callTo.text,
            isVideoCall: true,
            onError: (errorMessage){
              if(errorMessage == null) return;
              var snackBar = SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.grey,
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }
          );
        },
        child: const Icon(Icons.call),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _callTo,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Call to',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Text(
              'Click button to make a call',
            ),
          ],
        ),
      ),
    );
  }
}
