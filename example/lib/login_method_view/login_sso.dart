import 'package:flutter/material.dart';
import 'package:mpt_callkit/controller/mpt_call_kit_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/login_result.dart';
import '../components/callkit_constants.dart';

class LoginSSO extends StatefulWidget {
  const LoginSSO({super.key});

  @override
  State<LoginSSO> createState() => _LoginSSOState();
}

class _LoginSSOState extends State<LoginSSO> {
  final formKey = GlobalKey<FormState>();

  final ssoTokenController =
      TextEditingController(text: "414c7fdf-dc8f-4212-8a82-0d3a2f88e248");
  final organizationController =
      TextEditingController(text: "D1B85F69-5565-4301-8602-0FAA88DB6F39");
  final String baseUrl = CallkitConstants.BASE_URL;
  final String apiKey = CallkitConstants.API_KEY;
  String? accessTokenResponse;

  static const String _accessTokenKey = 'saved_access_token';

  Future<void> _saveCredentials(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    print('Saved credentials access token: $accessToken');
  }

  @override
  Widget build(BuildContext context) {
    void login() async {
      if (formKey.currentState!.validate()) {
        var result = await MptCallKitController().loginSSORequest(
          ssoToken: ssoTokenController.text,
          organization: organizationController.text,
          baseUrl: baseUrl,
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error ?? 'Login SSO failed')),
            );
          },
          accessTokenResponse: (accessToken) {
            accessTokenResponse = accessToken;
            print("Response data: $accessTokenResponse");
          },
        );

        if (result && accessTokenResponse != null) {
          await _saveCredentials(accessTokenResponse!);

          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => LoginResultScreen(
                      title: 'Login SSO Successful',
                      baseUrl: baseUrl,
                      apiKey: apiKey,
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
          title: const Text('Login SSO Screen'),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ssoToken"),
                TextFormField(
                  controller: ssoTokenController,
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
                const Text("organization"),
                TextFormField(
                  controller: organizationController,
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
