import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/login_result.dart';
import '../components/callkit_constants.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController(text: "agent2");
  final passwordController = TextEditingController(text: "123456aA@");
  final String _baseUrl = CallkitConstants.BASE_URL;
  final String _apiKey = CallkitConstants.API_KEY;
  final tenantId = CallkitConstants.TENANT_ID;
  Map<String, dynamic>? userData;

  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';

  Future<void> _saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
    print('Saved credentials: $username, $password');
  }

  @override
  Widget build(BuildContext context) {
    void login() async {
      if (formKey.currentState!.validate()) {
        var username = usernameController.text;
        var password = passwordController.text;

        var result = await MptCallKitController().loginRequest(
          username: username,
          password: password,
          tenantId: tenantId,
          baseUrl: _baseUrl,
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error ?? 'Login failed')),
            );
          },
        );

        if (result) {
          // Lưu thông tin đăng nhập khi đăng nhập thành công
          await _saveCredentials(username, password);

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
