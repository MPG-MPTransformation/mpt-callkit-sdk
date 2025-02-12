import 'dart:collection';

import 'package:example/home.dart';
import 'package:example/share_pref/share_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

final listDropdownEnv = <String>["UAT", "DEV"];

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final apiKeyDEV = '0c16d4aa-abe7-4098-b47a-7b914f9b7444';
  final apiKeyUAT = "53801c57-a9ef-495b-ab92-797ba1be2a60";
  final baseUrlDEV = "https://crm-dev-v2.metechvn.com";
  final baseUrlUAT = "https://crm-uat-v2.metechvn.com";

  @override
  void initState() {
    super.initState();

    // nameController.text = "donno2";
    // phoneNumberController.text = "0342615577";
  }

  final listDropdownEnvEntries = UnmodifiableListView(
    listDropdownEnv.map<DropdownMenuEntry<String>>(
        (String name) => DropdownMenuEntry<String>(value: name, label: name)),
  );

  bool isUAT = true;

  @override
  Widget build(BuildContext context) {
    void gotoHomeScreen() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHomePage(
            isFirstLogin: true,
          ),
        ),
      );
    }

    void login() async {
      if (formKey.currentState!.validate()) {
        await SharePref.saveInfo(
          name: nameController.text,
          phoneNumber: phoneNumberController.text,
          apiKey: isUAT ? apiKeyUAT : apiKeyDEV,
          baseUrl: isUAT ? baseUrlUAT : baseUrlDEV,
        );

        gotoHomeScreen();
      }
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OmiCX v2 demo'),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Form(
            key: formKey,
            child: Column(
              spacing: 5,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownMenu<String>(
                  initialSelection: listDropdownEnv.first,
                  onSelected: (String? value) {
                    if (value == null) return;
                    if (value == "UAT") {
                      setState(() {
                        isUAT = true;
                      });
                    } else {
                      setState(() {
                        isUAT = false;
                      });
                    }
                  },
                  dropdownMenuEntries: listDropdownEnvEntries,
                ),
                const Text("Name"),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Cannot empty';
                    }
                    return null;
                  },
                ),
                const Text("Phone number"),
                TextFormField(
                  controller: phoneNumberController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Cannot empty';
                    }
                    return null;
                  },
                ),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      login();
                    },
                    child: const Text("Enter"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
