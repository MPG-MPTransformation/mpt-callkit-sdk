import 'dart:collection';

import 'package:example/share_pref/share_pref.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

final listDropdownCallTypes = <String>["Video", "Audio Only"];

class _CallScreenState extends State<CallScreen> {
  final TextEditingController _callTo = TextEditingController();
  bool isVideoCall = true;
  final userInfo = SharePref.getInfo();

  @override
  void initState() {
    super.initState();
    _callTo.text = "88888888";
  }

  call() {
    MptCallKitController().initSdk(
      apiKey: userInfo!["apiKey"],
      baseUrl: userInfo!["baseUrl"],
      userPhoneNumber: userInfo!["phoneNumber"],
    );
    MptCallKitController().makeCall(
        context: context,
        phoneNumber: _callTo.text,
        isVideoCall: isVideoCall,
        onError: (errorMessage) {
          if (errorMessage == null) return;
          var snackBar = SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.grey,
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
  }

  static final listDropdownCallTypesEntries = UnmodifiableListView(
    listDropdownCallTypes.map<DropdownMenuEntry<String>>(
        (String name) => DropdownMenuEntry<String>(value: name, label: name)),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text("Your phone number: ${userInfo!["phoneNumber"]}"),
              const SizedBox(
                height: 20,
              ),
              DropdownMenu<String>(
                initialSelection: listDropdownCallTypes.first,
                onSelected: (String? value) {
                  if (value == null) return;
                  if (value == "Video") {
                    setState(() {
                      isVideoCall = true;
                    });
                  } else {
                    setState(() {
                      isVideoCall = false;
                    });
                  }
                },
                dropdownMenuEntries: listDropdownCallTypesEntries,
              ),
              const SizedBox(
                height: 20,
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
              const Text(
                'Click button to make a call',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                child: ElevatedButton(
                  onPressed: () => call(),
                  child: const Text("Call"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
