import 'package:example/login_result.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/mpt_callkit.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController(text: "hoangnt");
  final passwordController = TextEditingController(text: "123456aA@");
  final _baseUrl = "https://crm-dev-v2.metechvn.com";
  final String _apiKey = "0c16d4aa-abe7-4098-b47a-7b914f9b7444";
  final tenantId = 4;
  Map<String, dynamic>? userData;

  @override
  Widget build(BuildContext context) {
    void login() async {
      var result = await MptCallkit().login(
        username: usernameController.text,
        password: passwordController.text,
        tenantId: tenantId,
        baseUrl: _baseUrl,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'Login failed')),
          );
        },
        data: (data) {
          userData = data;
          print("Response data: $data");
        },
      );

      if (result) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => LoginResultScreen(
                    title: 'Login Successful',
                    userData: userData,
                    baseUrl: _baseUrl,
                    apiKey: _apiKey,
                  )),
        );
      }
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login Screen'),
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
                const Text("username"),
                TextFormField(
                  controller: usernameController,
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
                const Text("password"),
                TextFormField(
                  controller: passwordController,
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
