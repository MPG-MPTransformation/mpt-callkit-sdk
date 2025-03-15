import 'package:example/call_in_native_view.dart';
import 'package:example/login.dart';
import 'package:example/login_sso.dart';
import 'package:flutter/material.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _apiKey = "0c16d4aa-abe7-4098-b47a-7b914f9b7444";
  final String _baseUrl = "https://crm-dev-v2.metechvn.com";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const SizedBox(height: 50),
            const Text("Choose a call method"),
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CallInNativeView(
                            apiKey: _apiKey, baseUrl: _baseUrl)),
                  );
                },
                child: const Text("Call with native-view")),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
