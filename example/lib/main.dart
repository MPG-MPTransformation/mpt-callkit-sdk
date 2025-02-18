import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({key});

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
  const MyHomePage({key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _callTo = TextEditingController();
  bool _isVideoCall = false;
  bool _isUAT = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = "012345678";
    _callTo.text = "88888888";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MptCallKitController().initSdk(
            apiKey: _isUAT
                ? "53801c57-a9ef-495b-ab92-797ba1be2a60"
                : "0c16d4aa-abe7-4098-b47a-7b914f9b7444",
            baseUrl: _isUAT
                ? "https://crm-uat-v2.metechvn.com"
                : "https://crm-dev-v2.metechvn.com",
            userPhoneNumber: _phoneController.text,
          );
          MptCallKitController().makeCall(
              context: context,
              phoneNumber: _callTo.text,
              isVideoCall: _isVideoCall,
              onError: (errorMessage) {
                if (errorMessage == null) return;
                var snackBar = SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.grey,
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              });
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
                decoration: const InputDecoration(
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
                decoration: const InputDecoration(
                  labelText: 'Call to',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text("Is Video Call"),
                  Switch(
                    value: _isVideoCall,
                    onChanged: (value) {
                      setState(() {
                        _isVideoCall = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text("Is UAT"),
                  Switch(
                    value: _isUAT,
                    onChanged: (value) {
                      setState(() {
                        _isUAT = value;
                      });
                    },
                  ),
                ],
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
