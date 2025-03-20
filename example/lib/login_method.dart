import 'package:example/login_method_view/login.dart';
import 'package:flutter/material.dart';

import 'login_method_view/login_sso.dart';

class LoginMethod extends StatefulWidget {
  const LoginMethod({
    super.key,
  });

  @override
  State<LoginMethod> createState() => _LoginMethodState();
}

class _LoginMethodState extends State<LoginMethod> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login Method"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Choose a login method"),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Login(),
                  ),
                );
              },
              child: const Text("Login with account"),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginSSO(),
                  ),
                );
              },
              child: const Text("Login SSO"),
            ),
          ],
        ),
      ),
    );
  }
}
